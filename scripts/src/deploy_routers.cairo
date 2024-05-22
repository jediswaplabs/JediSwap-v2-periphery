use sncast_std::{
    declare, deploy, invoke, call, get_nonce, DeclareResult, DeployResult, InvokeResult, CallResult, DisplayContractAddress, DisplayClassHash
};
use starknet::{ContractAddress, ClassHash};
use debug::PrintTrait;

fn main() {
    let max_fee = 99999999999999999;
    let salt = 0x6;
    let factory_contract_address: ContractAddress =
        0x06dbda35590e23a4eb5f4550e4f783d3d3dc1f3cb7009dae72cf382fed225a0e
        .try_into()
        .unwrap(); //TODO environment variable

    let nft_manager_declare_result = declare(
        "JediSwapV2NFTPositionManager", Option::Some(max_fee), Option::None
    ).expect('nft declare failed');

    let nft_manager_class_hash = nft_manager_declare_result.class_hash;

    // let nft_manager_class_hash: ClassHash = 0x02f03dc1be00125726045d603b2a4bf568ec4ef3a11d80d1c5d04a70b14d6452.try_into().unwrap();

    let mut nft_manager_constructor_data = Default::default();
    Serde::serialize(@factory_contract_address, ref nft_manager_constructor_data);
    let nft_manager_deploy_result = deploy(
        nft_manager_class_hash,
        nft_manager_constructor_data,
        Option::Some(salt),
        true,
        Option::Some(max_fee),
        Option::None
    ).expect('nft deploy failed');

    let nft_manager_contract_address = nft_manager_deploy_result.contract_address;

    println!("NFT Manager Deployed to {}", nft_manager_contract_address);

    let swap_router_declare_result = declare(
        "JediSwapV2SwapRouter", Option::Some(max_fee), Option::None
    ).expect('swap declare failed');

    let swap_router_class_hash = swap_router_declare_result.class_hash;

    // let swap_router_class_hash: ClassHash = 0x02eb0fc47912fe0997d82d8c66aad672cfd8b3ec56161d42e3059c3443603f71.try_into().unwrap();

    let mut swap_router_constructor_data = Default::default();
    Serde::serialize(@factory_contract_address, ref swap_router_constructor_data);
    let swap_router_deploy_result = deploy(
        swap_router_class_hash,
        swap_router_constructor_data,
        Option::Some(salt),
        true,
        Option::Some(max_fee),
        Option::None
    ).expect('swap deploy failed');

    let swap_router_contract_address = swap_router_deploy_result.contract_address;

    println!("Swap Router Deployed to {}", swap_router_contract_address);
}
