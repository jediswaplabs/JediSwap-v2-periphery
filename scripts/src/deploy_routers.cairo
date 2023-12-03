use sncast_std::{
    declare, deploy, invoke, call, DeclareResult, DeployResult, InvokeResult, CallResult
};
use starknet::{ ContractAddress, ClassHash };
use debug::PrintTrait;
use deploy_scripts::utils::{owner};

fn main() {
    let max_fee = 9999999999999999;
    let salt = 0x6;

    let nft_manager_declare_result = declare('JediSwapV2NFTPositionManager', Option::Some(max_fee));
    let nft_manager_class_hash = nft_manager_declare_result.class_hash;
    
    let mut nft_manager_constructor_data = Default::default();
    Serde::serialize(@owner(), ref nft_manager_constructor_data);
    let nft_manager_deploy_result = deploy(nft_manager_class_hash, nft_manager_constructor_data, Option::Some(salt), true, Option::Some(max_fee));
    let nft_manager_contract_address = nft_manager_deploy_result.contract_address;

    'NFT Manager Deployed to '.print();
    nft_manager_contract_address.print();


    let swap_router_declare_result = declare('JediSwapV2SwapRouter', Option::Some(max_fee));
    let swap_router_class_hash = swap_router_declare_result.class_hash;
    
    let mut swap_router_constructor_data = Default::default();
    Serde::serialize(@owner(), ref swap_router_constructor_data);
    let swap_router_deploy_result = deploy(swap_router_class_hash, swap_router_constructor_data, Option::Some(salt), true, Option::Some(max_fee));
    let swap_router_contract_address = swap_router_deploy_result.contract_address;
    
    'Swap Router Deployed to '.print();
    swap_router_contract_address.print();
}