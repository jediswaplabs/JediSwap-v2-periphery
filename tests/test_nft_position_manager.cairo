use starknet::{ContractAddress, contract_address_try_from_felt252};
use integer::BoundedInt;
use jediswap_v2_core::libraries::signed_integers::{i32::i32, i128::i128, integer_trait::IntegerTrait};
use jediswap_v2_core::libraries::math_utils::pow;
use openzeppelin::token::erc20::{
    ERC20Component, interface::{IERC20Dispatcher, IERC20DispatcherTrait}
};
use jediswap_v2_core::libraries::tick_math::TickMath::{
    MIN_TICK, MAX_TICK, MAX_SQRT_RATIO, MIN_SQRT_RATIO, get_sqrt_ratio_at_tick,
    get_tick_at_sqrt_ratio
};
use jediswap_v2_core::jediswap_v2_factory::{
    IJediSwapV2FactoryDispatcher, IJediSwapV2FactoryDispatcherTrait, JediSwapV2Factory
};
use jediswap_v2_core::jediswap_v2_pool::{
    IJediSwapV2PoolDispatcher, IJediSwapV2PoolDispatcherTrait, JediSwapV2Pool
};
use jediswap_v2_periphery::jediswap_v2_nft_position_manager::{
    IJediSwapV2NFTPositionManagerDispatcher, IJediSwapV2NFTPositionManagerDispatcherTrait,
    MintParams, PositionDetail, PoolKey
};
use snforge_std::{
    PrintTrait, declare, ContractClassTrait, start_prank, stop_prank, CheatTarget, spy_events,
    SpyOn, EventSpy, EventFetcher, Event, EventAssertions
};

use super::utils::{owner, user1, user2, token0_1};

//TODO Use setup when available

fn setup_factory() -> (ContractAddress, ContractAddress) {
    let owner = owner();
    let pool_class = declare('JediSwapV2Pool');

    let factory_class = declare('JediSwapV2Factory');
    let mut factory_constructor_calldata = Default::default();
    Serde::serialize(@owner, ref factory_constructor_calldata);
    Serde::serialize(@pool_class.class_hash, ref factory_constructor_calldata);
    let factory_address = factory_class.deploy(@factory_constructor_calldata).unwrap();
    (owner, factory_address)
}

fn setup_nft_position_manager(
    factory_address: ContractAddress
) -> IJediSwapV2NFTPositionManagerDispatcher {
    let nft_class = declare('JediSwapV2NFTPositionManager');

    let mut nft_constructor_calldata = ArrayTrait::<felt252>::new();
    nft_constructor_calldata.append(factory_address.into());

    let nft_address = nft_class.deploy(@nft_constructor_calldata).unwrap();

    let nft_dispatcher = IJediSwapV2NFTPositionManagerDispatcher { contract_address: nft_address };

    nft_dispatcher
}

fn get_min_tick() -> i32 {
    IntegerTrait::<i32>::new(887220, true) // math.ceil(-887272 / 60) * 60
}

fn get_max_tick() -> i32 {
    IntegerTrait::<i32>::new(887220, false) // math.floor(887272 / 60) * 60
}

#[test]
fn test_create_and_initialize_pool_if_necessary_creates_pool_if_not_created() {
    let (owner, factory_address) = setup_factory();

    let nft_dispatcher = setup_nft_position_manager(factory_address);

    let mut spy = spy_events(SpyOn::Multiple(array![factory_address]));

    let (token0, token1) = token0_1();
    let fee = 3000;
    let sqrt_price_X96 = 79228162514264337593543950336; //  encode_price_sqrt(1, 1)

    nft_dispatcher.create_and_initialize_pool(token0, token1, fee, sqrt_price_X96);

    let factory_dispatcher = IJediSwapV2FactoryDispatcher { contract_address: factory_address };

    let pool_address = factory_dispatcher.get_pool(token0, token1, fee);

    spy
        .assert_emitted(
            @array![
                (
                    factory_address,
                    JediSwapV2Factory::Event::PoolCreated(
                        JediSwapV2Factory::PoolCreated {
                            token0: token0,
                            token1: token1,
                            fee: fee,
                            tick_spacing: 60,
                            pool: pool_address
                        }
                    )
                )
            ]
        );
}

#[test]
fn test_create_and_initialize_pool_works_if_pool_is_created_but_not_initialized() {
    let (owner, factory_address) = setup_factory();

    let nft_dispatcher = setup_nft_position_manager(factory_address);

    let factory_dispatcher = IJediSwapV2FactoryDispatcher { contract_address: factory_address };

    let (token0, token1) = token0_1();
    let fee = 3000;
    let sqrt_price_X96 = 79228162514264337593543950336; //  encode_price_sqrt(1, 1)

    factory_dispatcher.create_pool(token0, token1, fee);

    let pool_address = factory_dispatcher.get_pool(token0, token1, fee);

    let pool_dispatcher = IJediSwapV2PoolDispatcher { contract_address: pool_address };

    assert(pool_dispatcher.get_sqrt_price_X96() == 0, 'not created');

    nft_dispatcher.create_and_initialize_pool(token0, token1, fee, sqrt_price_X96);

    assert(pool_dispatcher.get_sqrt_price_X96() == sqrt_price_X96, 'not initialized');
}

#[test]
fn test_create_and_initialize_pool_works_if_pool_is_created_and_initialized() {
    let (owner, factory_address) = setup_factory();

    let nft_dispatcher = setup_nft_position_manager(factory_address);

    let factory_dispatcher = IJediSwapV2FactoryDispatcher { contract_address: factory_address };

    let (token0, token1) = token0_1();
    let fee = 3000;
    let sqrt_price_X96 = 79228162514264337593543950336; //  encode_price_sqrt(1, 1)

    factory_dispatcher.create_pool(token0, token1, fee);

    let pool_address = factory_dispatcher.get_pool(token0, token1, fee);

    let pool_dispatcher = IJediSwapV2PoolDispatcher { contract_address: pool_address };

    pool_dispatcher.initialize(sqrt_price_X96);

    assert(pool_dispatcher.get_sqrt_price_X96() == sqrt_price_X96, 'not initialized');

    nft_dispatcher.create_and_initialize_pool(token0, token1, fee, MAX_SQRT_RATIO);

    assert(pool_dispatcher.get_sqrt_price_X96() == sqrt_price_X96, 'not initialized');
}

#[test]
#[should_panic(expected: ('pool not created',))]
fn test_mint_fails_if_pool_does_not_exist() {
    let (owner, factory_address) = setup_factory();

    let nft_dispatcher = setup_nft_position_manager(factory_address);

    let (token0, token1) = token0_1();

    let mint_params = MintParams {
        token0: token0,
        token1: token1,
        fee: 3000,
        tick_lower: get_min_tick(),
        tick_upper: get_max_tick(),
        amount0_desired: 100,
        amount1_desired: 100,
        amount0_min: 0,
        amount1_min: 0,
        recipient: user1(),
        deadline: 1
    };

    nft_dispatcher.mint(mint_params);
}

#[test]
#[should_panic(expected: ('u256_sub Overflow',))]
fn test_mint_fails_if_can_not_transfer() {
    let (owner, factory_address) = setup_factory();

    let nft_dispatcher = setup_nft_position_manager(factory_address);

    let (token0, token1) = token0_1();
    let fee = 3000;
    let sqrt_price_X96 = 79228162514264337593543950336; //  encode_price_sqrt(1, 1)

    nft_dispatcher.create_and_initialize_pool(token0, token1, fee, sqrt_price_X96);

    let mint_params = MintParams {
        token0: token0,
        token1: token1,
        fee: 3000,
        tick_lower: get_min_tick(),
        tick_upper: get_max_tick(),
        amount0_desired: 100,
        amount1_desired: 100,
        amount0_min: 0,
        amount1_min: 0,
        recipient: user1(),
        deadline: 1
    };

    nft_dispatcher.mint(mint_params);
}

#[test]
fn test_mint_creates_a_token() {
    let (owner, factory_address) = setup_factory();

    let nft_dispatcher = setup_nft_position_manager(factory_address);

    let (token0, token1) = token0_1();
    let fee = 3000;
    let sqrt_price_X96 = 79228162514264337593543950336; //  encode_price_sqrt(1, 1)

    nft_dispatcher.create_and_initialize_pool(token0, token1, fee, sqrt_price_X96);

    let token0_dispatcher = IERC20Dispatcher { contract_address: token0 };
    start_prank(CheatTarget::One(token0), user1());
    token0_dispatcher.approve(nft_dispatcher.contract_address, 100 * pow(10, 18));
    stop_prank(CheatTarget::One(token0));

    let token1_dispatcher = IERC20Dispatcher { contract_address: token1 };
    start_prank(CheatTarget::One(token1), user1());
    token1_dispatcher.approve(nft_dispatcher.contract_address, 100 * pow(10, 18));
    stop_prank(CheatTarget::One(token1));

    let mint_params = MintParams {
        token0: token0,
        token1: token1,
        fee: 3000,
        tick_lower: get_min_tick(),
        tick_upper: get_max_tick(),
        amount0_desired: 15,
        amount1_desired: 15,
        amount0_min: 0,
        amount1_min: 0,
        recipient: user1(),
        deadline: 10
    };

    start_prank(CheatTarget::One(nft_dispatcher.contract_address), user1());
    nft_dispatcher.mint(mint_params);
    stop_prank(CheatTarget::One(nft_dispatcher.contract_address));

    let nft_token_dispatcher = IERC20Dispatcher {
        contract_address: nft_dispatcher.contract_address
    };

    assert(nft_token_dispatcher.balance_of(user1()) == 1, 'incorrect balance');

    let (position_detail, pool_key) = nft_dispatcher.get_position(1);

    assert(pool_key.token0 == token0, 'Incorrect token0');
    assert(pool_key.token1 == token1, 'Incorrect token1');
    assert(pool_key.fee == 3000, 'Incorrect fee');

    assert(position_detail.tick_lower == get_min_tick(), 'Incorrect tick_lower');
    assert(position_detail.tick_upper == get_max_tick(), 'Incorrect tick_upper');
    assert(position_detail.liquidity == 15, 'Incorrect liquidity');
    assert(position_detail.fee_growth_inside_0_last_X128 == 0, 'Incorrect fee_growth_inside_0');
    assert(position_detail.fee_growth_inside_1_last_X128 == 0, 'Incorrect fee_growth_inside_1');
    assert(position_detail.tokens_owed_0 == 0, 'Incorrect tokens_owed_0');
    assert(position_detail.tokens_owed_1 == 0, 'Incorrect tokens_owed_1');
}
