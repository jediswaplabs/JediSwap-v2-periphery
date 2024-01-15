use sncast_std::{
    declare, deploy, invoke, call, DeclareResult, DeployResult, InvokeResult, CallResult
};
use starknet::{ ContractAddress, ClassHash };
use debug::PrintTrait;
use deploy_scripts::utils::{owner};

fn main() {
    let max_fee = 9999999999999999;
    let salt = 0x6;
    let starting_nonce = 2; // Change it when running script, TODO get from environment
    let factory_contract_address: ContractAddress = 0x058d1ee73ba8e81db0400d0c98f7bcb19a297097e6c00fb0d1dfef01fc20afe7.try_into().unwrap(); //TODO environment variable

    // let nft_manager_declare_result = declare('JediSwapV2NFTPositionManager', Option::Some(max_fee), Option::Some(starting_nonce));
    // let nft_manager_class_hash = nft_manager_declare_result.class_hash;

    let nft_manager_class_hash: ClassHash = 0x004f93ff1521f93ccddbe344f7446ff485a73d54e8af6ed4d9adb481f16cceaa.try_into().unwrap();
    
    let mut nft_manager_constructor_data = Default::default();
    Serde::serialize(@factory_contract_address, ref nft_manager_constructor_data);
    let nft_manager_deploy_result = deploy(nft_manager_class_hash, nft_manager_constructor_data, Option::Some(salt), true, Option::Some(max_fee), Option::Some(starting_nonce + 1));
    let nft_manager_contract_address = nft_manager_deploy_result.contract_address;

    'NFT Manager Deployed to '.print();
    nft_manager_contract_address.print();


    let swap_router_declare_result = declare('JediSwapV2SwapRouter', Option::Some(max_fee), Option::Some(starting_nonce + 2));
    let swap_router_class_hash = swap_router_declare_result.class_hash;

    // let swap_router_class_hash: ClassHash = 0x003d239bae37b1796377b65c8cd8ecf1774b63173d770410424a4abb8db638cb.try_into().unwrap();
    
    let mut swap_router_constructor_data = Default::default();
    Serde::serialize(@factory_contract_address, ref swap_router_constructor_data);
    let swap_router_deploy_result = deploy(swap_router_class_hash, swap_router_constructor_data, Option::Some(salt), true, Option::Some(max_fee), Option::Some(starting_nonce + 3));
    let swap_router_contract_address = swap_router_deploy_result.contract_address;
    
    'Swap Router Deployed to '.print();
    swap_router_contract_address.print();
}