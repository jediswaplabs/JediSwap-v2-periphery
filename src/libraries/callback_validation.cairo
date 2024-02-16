mod CallbackValidation {
    use starknet::{ContractAddress, get_caller_address};
    use jediswap_v2_core::jediswap_v2_factory::{
        IJediSwapV2FactoryDispatcher, IJediSwapV2FactoryDispatcherTrait
    };
    use jediswap_v2_periphery::jediswap_v2_nft_position_manager::PoolKey;

    // @notice Returns the address of a valid JediSwap V2 Pool
    // @param factory The contract address of the JediSwap V2 factory
    // @param pool_key The identifying key of the JediSwap V2 pool
    // @return The V2 pool contract address
    fn verify_callback_pool_key(factory: ContractAddress, pool_key: PoolKey) -> ContractAddress {
        let factory_dispatcher = IJediSwapV2FactoryDispatcher { contract_address: factory };
        let pool_address = factory_dispatcher
            .get_pool(pool_key.token0, pool_key.token1, pool_key.fee);
        assert(get_caller_address() == pool_address, 'Invalid callback');
        pool_address
    }

    // @notice Returns the address of a valid JediSwap V2 Pool
    // @param factory The contract address of the JediSwap V2 factory
    // @param token_a The contract address of either token0 or token1
    // @param token_b The contract address of the other token
    // @param fee The fee collected upon every swap in the pool, denominated in hundredths of a bip
    // @return The V2 pool contract address
    fn verify_callback(
        factory: ContractAddress, token_a: ContractAddress, token_b: ContractAddress, fee: u32
    ) -> ContractAddress {
        verify_callback_pool_key(factory, PoolKey { token0: token_a, token1: token_b, fee })
    }
}
