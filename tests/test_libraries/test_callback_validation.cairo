use starknet::{ ContractAddress };
use snforge_std::{ ContractClassTrait, declare, start_prank, stop_prank };
use jediswap_v2_periphery::jediswap_v2_nft_position_manager::{IJediSwapV2NFTPositionManagerDispatcher, IJediSwapV2NFTPositionManagerDispatcherTrait};
use jediswap_v2_periphery::libraries::callback_validation::CallbackValidation::{verify_callback};
use super::super::utils::{owner};

#[test]
#[should_panic(expected: ('Invalid callback',))]
fn test_verify_callback_reverts_from_wrong_address() {
    let pool_class = declare('JediSwapV2Pool');

    let factory_class = declare('JediSwapV2Factory');

    let mut factory_constructor_data = Default::default();
    let owner = owner();
    Serde::serialize(@owner, ref factory_constructor_data);
    Serde::serialize(@pool_class.class_hash, ref factory_constructor_data);
    let factory_address = factory_class.deploy(@factory_constructor_data).unwrap();

    let nft_manager_class = declare('JediSwapV2NFTPositionManager');
    
    let mut nft_manager_constructor_data = Default::default();
    Serde::serialize(@factory_address, ref nft_manager_constructor_data);
    let nft_manager_address = nft_manager_class.deploy(@nft_manager_constructor_data).unwrap();

    let nft_manager_dispatcher = IJediSwapV2NFTPositionManagerDispatcher { contract_address: nft_manager_address };
    let token0: ContractAddress = 1.try_into().unwrap();
    let token1: ContractAddress = 2.try_into().unwrap();
    let fee = 100;
    let sqrt_price_X96 = 79228162514264337593543950336; //  encode_price_sqrt(1, 1)
    let pool_address = nft_manager_dispatcher.create_and_initialize_pool(token0, token1, fee, sqrt_price_X96);

    verify_callback(factory_address, token0, token1, fee);
}
