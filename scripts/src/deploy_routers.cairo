use sncast_std::{
    declare, deploy, invoke, call, DeclareResult, DeployResult, InvokeResult, CallResult
};
use starknet::{ContractAddress, ClassHash};
use debug::PrintTrait;
use deploy_scripts::utils::{owner};

fn main() {
    let max_fee = 9999999999999999;
    let salt = 0x6;
    let starting_nonce = 7; // Change it when running script, TODO get from environment
    let factory_contract_address: ContractAddress =
        0x04ba0de31008f4e3edd42b3c31db8f49490505885d684b78f5aa1572850b3a5a
        .try_into()
        .unwrap(); //TODO environment variable
    let mut current_nonce = starting_nonce;

    let nft_manager_declare_result = declare(
        'JediSwapV2NFTPositionManager', Option::Some(max_fee), Option::Some(current_nonce)
    );
    current_nonce = current_nonce + 1;
    let nft_manager_class_hash = nft_manager_declare_result.class_hash;

    // let nft_manager_class_hash: ClassHash = 0x004f93ff1521f93ccddbe344f7446ff485a73d54e8af6ed4d9adb481f16cceaa.try_into().unwrap();

    let mut nft_manager_constructor_data = Default::default();
    Serde::serialize(@factory_contract_address, ref nft_manager_constructor_data);
    let nft_manager_deploy_result = deploy(
        nft_manager_class_hash,
        nft_manager_constructor_data,
        Option::Some(salt),
        true,
        Option::Some(max_fee),
        Option::Some(current_nonce)
    );
    current_nonce = current_nonce + 1;
    let nft_manager_contract_address = nft_manager_deploy_result.contract_address;

    'NFT Manager Deployed to '.print();
    nft_manager_contract_address.print();

    let swap_router_declare_result = declare(
        'JediSwapV2SwapRouter', Option::Some(max_fee), Option::Some(current_nonce)
    );
    current_nonce = current_nonce + 1;
    let swap_router_class_hash = swap_router_declare_result.class_hash;

    // let swap_router_class_hash: ClassHash = 0x002c87d38636d7ac2ab33dab0a35c011c940b3399edf5c717d97193a6e1bbaf5.try_into().unwrap();

    let mut swap_router_constructor_data = Default::default();
    Serde::serialize(@factory_contract_address, ref swap_router_constructor_data);
    let swap_router_deploy_result = deploy(
        swap_router_class_hash,
        swap_router_constructor_data,
        Option::Some(salt),
        true,
        Option::Some(max_fee),
        Option::Some(current_nonce)
    );
    current_nonce = current_nonce + 1;
    let swap_router_contract_address = swap_router_deploy_result.contract_address;

    'Swap Router Deployed to '.print();
    swap_router_contract_address.print();
}
