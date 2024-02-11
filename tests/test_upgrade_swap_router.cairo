use starknet::{ContractAddress, contract_address_try_from_felt252};
use integer::BoundedInt;
use yas_core::numbers::signed_integer::{i32::i32, i128::i128, integer_trait::IntegerTrait};
use yas_core::utils::math_utils::{pow};
use openzeppelin::token::erc20::{
    ERC20Component, interface::{IERC20Dispatcher, IERC20DispatcherTrait}
};
use openzeppelin::upgrades::upgradeable::UpgradeableComponent;
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
use jediswap_v2_periphery::jediswap_v2_swap_router::{
    IJediSwapV2SwapRouterDispatcher, IJediSwapV2SwapRouterDispatcherTrait
};
use jediswap_v2_periphery::test_contracts::jediswap_v2_swap_router_v2::{
    IJediSwapV2SwapRouterV2Dispatcher, IJediSwapV2SwapRouterV2DispatcherTrait
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

fn setup_swap_router(factory_address: ContractAddress) -> IJediSwapV2SwapRouterDispatcher {
    let swap_router_class = declare('JediSwapV2SwapRouter');

    let mut swap_router_constructor_calldata = ArrayTrait::<felt252>::new();
    swap_router_constructor_calldata.append(factory_address.into());

    let swap_router_address = swap_router_class.deploy(@swap_router_constructor_calldata).unwrap();

    let swap_router_dispatcher = IJediSwapV2SwapRouterDispatcher {
        contract_address: swap_router_address
    };

    swap_router_dispatcher
}

#[test]
#[should_panic(expected: ('Invalid caller',))]
fn test_upgrade_fails_with_wrong_caller() {
    let (owner, factory_address) = setup_factory();

    let swap_router_dispatcher = setup_swap_router(factory_address);

    let new_swap_router_class_hash = declare('JediSwapV2SwapRouterV2').class_hash;

    swap_router_dispatcher.upgrade(new_swap_router_class_hash);
}

#[test]
fn test_upgrade_succeeds_with_owner_emits_event() {
    let (owner, factory_address) = setup_factory();

    let swap_router_dispatcher = setup_swap_router(factory_address);

    let swap_router_address = swap_router_dispatcher.contract_address;

    let new_swap_router_class_hash = declare('JediSwapV2SwapRouterV2').class_hash;

    let mut spy = spy_events(SpyOn::One(swap_router_address));

    start_prank(CheatTarget::One(swap_router_address), owner);
    swap_router_dispatcher.upgrade(new_swap_router_class_hash);
    stop_prank(CheatTarget::One(swap_router_address));

    spy
        .assert_emitted(
            @array![
                (
                    swap_router_address,
                    UpgradeableComponent::Event::Upgraded(
                        UpgradeableComponent::Upgraded { class_hash: new_swap_router_class_hash }
                    )
                )
            ]
        );
}

#[test]
#[should_panic(expected: ('Class hash cannot be zero',))]
fn test_upgrade_fails_with_zero_class_hash() {
    let (owner, factory_address) = setup_factory();

    let swap_router_dispatcher = setup_swap_router(factory_address);
    let swap_router_address = swap_router_dispatcher.contract_address;

    start_prank(CheatTarget::One(swap_router_address), owner);
    swap_router_dispatcher.upgrade(0.try_into().unwrap());
    stop_prank(CheatTarget::One(swap_router_address));
}

#[test]
#[should_panic]
fn test_upgrade_succeeds_old_selector_fails() {
    let (owner, factory_address) = setup_factory();

    let swap_router_dispatcher = setup_swap_router(factory_address);
    let swap_router_address = swap_router_dispatcher.contract_address;

    let new_swap_router_class_hash = declare('JediSwapV2SwapRouterV2').class_hash;

    start_prank(CheatTarget::One(swap_router_address), owner);
    swap_router_dispatcher.upgrade(new_swap_router_class_hash);
    stop_prank(CheatTarget::One(swap_router_address));

    swap_router_dispatcher.get_factory();
}

#[test]
fn test_upgrade_succeeds_new_selector() {
    let (owner, factory_address) = setup_factory();

    let swap_router_dispatcher = setup_swap_router(factory_address);
    let swap_router_address = swap_router_dispatcher.contract_address;

    let new_swap_router_class_hash = declare('JediSwapV2SwapRouterV2').class_hash;

    start_prank(CheatTarget::One(swap_router_address), owner);
    swap_router_dispatcher.upgrade(new_swap_router_class_hash);
    stop_prank(CheatTarget::One(swap_router_address));

    let swap_router_dispatcher = IJediSwapV2SwapRouterV2Dispatcher {
        contract_address: swap_router_address
    };

    assert(swap_router_dispatcher.get_factory_v2() == factory_address, 'New selector fails');
}

#[test]
fn test_upgrade_succeeds_state_remains_same() {
    let (owner, factory_address) = setup_factory();

    let swap_router_dispatcher = setup_swap_router(factory_address);
    let swap_router_address = swap_router_dispatcher.contract_address;

    let factory_address = swap_router_dispatcher.get_factory();

    let new_swap_router_class_hash = declare('JediSwapV2SwapRouterV2').class_hash;

    start_prank(CheatTarget::One(swap_router_address), owner);
    swap_router_dispatcher.upgrade(new_swap_router_class_hash);
    stop_prank(CheatTarget::One(swap_router_address));

    let swap_router_dispatcher = IJediSwapV2SwapRouterV2Dispatcher {
        contract_address: swap_router_address
    };

    assert(swap_router_dispatcher.get_factory_v2() == factory_address, 'State changed');
}
