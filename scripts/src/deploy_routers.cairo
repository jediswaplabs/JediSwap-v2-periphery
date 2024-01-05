use sncast_std::{
    declare, deploy, invoke, call, DeclareResult, DeployResult, InvokeResult, CallResult
};
use starknet::{ ContractAddress, ClassHash };
use debug::PrintTrait;
use deploy_scripts::utils::{owner};

fn main() {
    let max_fee = 9999999999999999;
    let salt = 0x6;
    let factory_contract_address: ContractAddress = 0x6b4115fa43c48118d3f79fbc500c75917c8a28d0f867479acb81893ea1e036c.try_into().unwrap(); //TODO environment variable

    let nft_manager_declare_result = declare('JediSwapV2NFTPositionManager', Option::Some(max_fee));
    let nft_manager_class_hash = nft_manager_declare_result.class_hash;

    // let nft_manager_class_hash: ClassHash = 0x0650d6133fd0b21577cf4d66c4db648faba67334a926de77c2f5840248c3a62d.try_into().unwrap();
    
    let mut nft_manager_constructor_data = Default::default();
    Serde::serialize(@factory_contract_address, ref nft_manager_constructor_data);
    let nft_manager_deploy_result = deploy(nft_manager_class_hash, nft_manager_constructor_data, Option::Some(salt), true, Option::Some(max_fee));
    let nft_manager_contract_address = nft_manager_deploy_result.contract_address;

    'NFT Manager Deployed to '.print();
    nft_manager_contract_address.print();


    // let swap_router_declare_result = declare('JediSwapV2SwapRouter', Option::Some(max_fee));
    // let swap_router_class_hash = swap_router_declare_result.class_hash;

    let swap_router_class_hash: ClassHash = 0x003d239bae37b1796377b65c8cd8ecf1774b63173d770410424a4abb8db638cb.try_into().unwrap();
    
    let mut swap_router_constructor_data = Default::default();
    Serde::serialize(@factory_contract_address, ref swap_router_constructor_data);
    let swap_router_deploy_result = deploy(swap_router_class_hash, swap_router_constructor_data, Option::Some(salt), true, Option::Some(max_fee));
    let swap_router_contract_address = swap_router_deploy_result.contract_address;
    
    'Swap Router Deployed to '.print();
    swap_router_contract_address.print();
}