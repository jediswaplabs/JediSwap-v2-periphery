// @title NFT positions
// @notice Wraps JediSwap V2 positions in the ERC721 non-fungible token interface

use starknet::{ContractAddress, ClassHash};
use jediswap_v2_core::libraries::signed_integers::{i32::i32};
use jediswap_v2_periphery::jediswap_v2_nft_position_manager::PoolKey;

// @notice details about the JediSwap V2 position
#[derive(Copy, Drop, Serde, starknet::Store)]
struct PositionDetail {
    // @notice The address that is approved for spending this token
    operator: ContractAddress,
    // @notice The ID of the pool with which this token is connected
    pool_id: u64,
    // @notice The lower tick of the position
    tick_lower: i32,
    // @notice The upper tick of the position
    tick_upper: i32,
    // @notice The liquidity of the position
    liquidity: u128,
    // @notice The fee growth of the aggregate position as of the last action on the individual position, for token0
    fee_growth_inside_0_last_X128: u256,
    // @notice The fee growth of the aggregate position as of the last action on the individual position, for token1
    fee_growth_inside_1_last_X128: u256,
    // @notice Uncollected token0 owed to the position, as of the last computation
    tokens_owed_0: u128,
    // @notice Uncollected token1 owed to the position, as of the last computation
    tokens_owed_1: u128
}

#[derive(Copy, Drop, Serde)]
struct MintParams {
    token0: ContractAddress,
    token1: ContractAddress,
    fee: u32,
    tick_lower: i32,
    tick_upper: i32,
    amount0_desired: u256,
    amount1_desired: u256,
    amount0_min: u256,
    amount1_min: u256,
    recipient: ContractAddress,
    deadline: u64
}

#[derive(Copy, Drop, Serde)]
struct AddLiquidityParams {
    token0: ContractAddress,
    token1: ContractAddress,
    fee: u32,
    recipient: ContractAddress,
    tick_lower: i32,
    tick_upper: i32,
    amount0_desired: u256,
    amount1_desired: u256,
    amount0_min: u256,
    amount1_min: u256
}

#[derive(Copy, Drop, Serde)]
struct IncreaseLiquidityParams {
    token_id: u256,
    amount0_desired: u256,
    amount1_desired: u256,
    amount0_min: u256,
    amount1_min: u256,
    deadline: u64
}

#[derive(Copy, Drop, Serde)]
struct DecreaseLiquidityParams {
    token_id: u256,
    liquidity: u128,
    amount0_min: u256,
    amount1_min: u256,
    deadline: u64
}

#[derive(Copy, Drop, Serde)]
struct CollectParams {
    token_id: u256,
    recipient: ContractAddress,
    amount0_max: u128,
    amount1_max: u128
}

#[derive(Copy, Drop, Serde)]
struct MintCallbackData {
    pool_key: PoolKey,
    payer: ContractAddress
}


#[starknet::interface]
trait IERC721Metadata<TContractState> {
    fn name(self: @TContractState) -> ByteArray;
    fn symbol(self: @TContractState) -> ByteArray;
    fn token_uri(self: @TContractState, token_id: u256) -> ByteArray;
}

#[starknet::interface]
trait IERC721CamelMetadata<TContractState> {
    fn tokenURI(self: @TContractState, token_id: u256) -> ByteArray;
}

#[starknet::interface]
trait IJediSwapV2NFTPositionManagerV2<TContractState> {
    fn get_factory_v2(self: @TContractState) -> ContractAddress;
    fn get_position(self: @TContractState, token_id: u256) -> (PositionDetail, PoolKey);
    fn mint(ref self: TContractState, params: MintParams) -> (u256, u128, u256, u256);
    fn increase_liquidity(
        ref self: TContractState, params: IncreaseLiquidityParams
    ) -> (u128, u256, u256);
    fn decrease_liquidity(
        ref self: TContractState, params: DecreaseLiquidityParams
    ) -> (u256, u256);
    fn collect(ref self: TContractState, params: CollectParams) -> (u128, u128);
    fn burn(ref self: TContractState, token_id: u256);
    fn create_and_initialize_pool(
        ref self: TContractState,
        token0: ContractAddress,
        token1: ContractAddress,
        fee: u32,
        sqrt_price_X96: u256
    ) -> ContractAddress;
    fn jediswap_v2_mint_callback(
        ref self: TContractState,
        amount0_owed: u256,
        amount1_owed: u256,
        callback_data_span: Span<felt252>
    );
    fn upgrade(ref self: TContractState, new_class_hash: ClassHash);
}

#[starknet::contract]
mod JediSwapV2NFTPositionManagerV2 {
    use super::{
        PoolKey, PositionDetail, MintParams, AddLiquidityParams, IncreaseLiquidityParams,
        DecreaseLiquidityParams, CollectParams, MintCallbackData
    };
    use starknet::{
        ContractAddress, ClassHash, get_contract_address, contract_address_const,
        get_caller_address, get_block_timestamp, contract_address_to_felt252
    };
    use integer::{u256_from_felt252};

    use openzeppelin::token::erc20::interface::{
        IERC20MetadataDispatcher, IERC20MetadataDispatcherTrait
    };
    use openzeppelin::access::ownable::interface::{IOwnableDispatcher, IOwnableDispatcherTrait};
    use jediswap_v2_core::libraries::sqrt_price_math::SqrtPriceMath::Q128;
    use jediswap_v2_core::libraries::position::{PositionKey};
    use jediswap_v2_core::libraries::tick_math::TickMath::get_sqrt_ratio_at_tick;
    use jediswap_v2_core::libraries::math_utils::mod_subtraction;
    use jediswap_v2_periphery::libraries::liquidity_amounts::LiquidityAmounts::get_liquidity_for_amounts;
    use jediswap_v2_periphery::libraries::callback_validation::CallbackValidation::verify_callback_pool_key;
    use jediswap_v2_periphery::libraries::nft_descriptor::NFTDescriptor::fee_to_string;
    use jediswap_v2_periphery::libraries::periphery_payments::PeripheryPayments::pay;

    use jediswap_v2_core::jediswap_v2_pool::{
        IJediSwapV2PoolDispatcher, IJediSwapV2PoolDispatcherTrait
    };
    use jediswap_v2_core::jediswap_v2_factory::{
        IJediSwapV2FactoryDispatcher, IJediSwapV2FactoryDispatcherTrait
    };

    use jediswap_v2_core::libraries::signed_integers::{i32::i32, integer_trait::IntegerTrait};
    use jediswap_v2_core::libraries::full_math::mul_div;
    use jediswap_v2_core::libraries::math_utils::pow;

    use openzeppelin::upgrades::upgradeable::UpgradeableComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc721::ERC721Component;
    component!(path: ERC721Component, storage: erc721_storage, event: ERC721Event);
    component!(path: SRC5Component, storage: src5_storage, event: SRC5Event);
    component!(path: UpgradeableComponent, storage: upgradeable_storage, event: UpgradeableEvent);

    #[abi(embed_v0)]
    impl ERC721Impl = ERC721Component::ERC721Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC721CamelOnlyImpl = ERC721Component::ERC721CamelOnlyImpl<ContractState>;
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;
    #[abi(embed_v0)]
    impl SRC5CamelImpl = SRC5Component::SRC5CamelImpl<ContractState>;

    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        IncreaseLiquidity: IncreaseLiquidity,
        DecreaseLiquidity: DecreaseLiquidity,
        Collect: Collect,
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event
    }

    // @notice Emitted when liquidity is increased for a position NFT
    // @dev Also emitted when a token is minted
    // @param token_id The ID of the token for which liquidity was increased
    // @param liquidity The amount by which liquidity for the NFT position was increased
    // @param amount0 The amount of token0 that was paid for the increase in liquidity
    // @param amount1 The amount of token1 that was paid for the increase in liquidity
    #[derive(Drop, starknet::Event)]
    struct IncreaseLiquidity {
        token_id: u256,
        liquidity: u128,
        amount0: u256,
        amount1: u256
    }

    // @notice Emitted when liquidity is decreased for a position NFT
    // @param token_id The ID of the token for which liquidity was decreased
    // @param liquidity The amount by which liquidity for the NFT position was decreased
    // @param amount0 The amount of token0 that was accounted for the decrease in liquidity
    // @param amount1 The amount of token1 that was accounted for the decrease in liquidity
    #[derive(Drop, starknet::Event)]
    struct DecreaseLiquidity {
        token_id: u256,
        liquidity: u128,
        amount0: u256,
        amount1: u256
    }

    // @notice Emitted when tokens are collected for a position NFT
    // @dev The amounts reported may not be exactly equivalent to the amounts transferred, due to rounding behavior
    // @param token_id The ID of the token for which underlying tokens were collected
    // @param recipient The address of the account that received the collected tokens
    // @param amount0 The amount of token0 owed to the position that was collected
    // @param amount1 The amount of token1 owed to the position that was collected
    #[derive(Drop, starknet::Event)]
    struct Collect {
        token_id: u256,
        recipient: ContractAddress,
        amount0_collect: u128,
        amount1_collect: u128
    }

    #[storage]
    struct Storage {
        factory: ContractAddress,
        pool_ids: LegacyMap<ContractAddress, u64>,
        pool_id_to_pool_key: LegacyMap<u64, PoolKey>,
        positions: LegacyMap<u256, PositionDetail>,
        next_id: u256,
        next_pool_id: u64,
        #[substorage(v0)]
        erc721_storage: ERC721Component::Storage,
        #[substorage(v0)]
        src5_storage: SRC5Component::Storage,
        #[substorage(v0)]
        upgradeable_storage: UpgradeableComponent::Storage
    }

    #[constructor]
    fn constructor(ref self: ContractState, factory: ContractAddress) {
        self.erc721_storage.initializer("JediSwap V2 Positions NFT", "JEDI-V2-POS", "");

        self.factory.write(factory);
        self.next_id.write(1);
        self.next_pool_id.write(1);
    }

    #[abi(embed_v0)]
    impl ERC721MetadataImpl of super::IERC721Metadata<ContractState> {
        fn name(self: @ContractState) -> ByteArray {
            self.erc721_storage.ERC721_name.read()
        }

        fn symbol(self: @ContractState) -> ByteArray {
            self.erc721_storage.ERC721_symbol.read()
        }

        fn token_uri(self: @ContractState, token_id: u256) -> ByteArray {
            assert(self.erc721_storage._exists(token_id), 'ERC721: invalid token ID');
            self._token_uri(token_id)
        }
    }

    #[abi(embed_v0)]
    impl ERC721CamelMetadataImpl of super::IERC721CamelMetadata<ContractState> {
        fn tokenURI(self: @ContractState, token_id: u256) -> ByteArray {
            self.token_uri(token_id)
        }
    }

    #[abi(embed_v0)]
    impl JediSwapV2NFTPositionManagerV2Impl of super::IJediSwapV2NFTPositionManagerV2<ContractState> {
        //TODO docs
        fn get_factory_v2(self: @ContractState) -> ContractAddress {
            self.factory.read()
        }

        // @notice Returns the position information associated with a given token ID.
        // @dev Throws if the token ID is not valid.
        // @param tokenId The ID of the token that represents the position
        // @return All the detailed info of the position
        // @return The identifying key of the pool
        fn get_position(self: @ContractState, token_id: u256) -> (PositionDetail, PoolKey) {
            let position = self.positions.read(token_id);
            assert(position.pool_id != 0, 'Invalid token ID');
            let pool_key = self.pool_id_to_pool_key.read(position.pool_id);
            (position, pool_key)
        }

        // @notice Creates a new position wrapped in a NFT
        // @dev Call this when the pool does exist and is initialized. Note that if the pool is created but not initialized
        // a method does not exist, i.e. the pool is assumed to be initialized.
        // @param params The params necessary to mint a position, encoded as `MintParams` in calldata
        // @return The ID of the token that represents the minted position
        // @return The amount of liquidity for this position
        // @return The amount of token0
        // @return The amount of token1
        fn mint(ref self: ContractState, params: MintParams) -> (u256, u128, u256, u256) {
            _check_deadline(params.deadline);
            let (liquidity, amount0, amount1, pool_dispatcher) = self
                ._add_liquidity(
                    AddLiquidityParams {
                        token0: params.token0,
                        token1: params.token1,
                        fee: params.fee,
                        recipient: get_contract_address(),
                        tick_lower: params.tick_lower,
                        tick_upper: params.tick_upper,
                        amount0_desired: params.amount0_desired,
                        amount1_desired: params.amount1_desired,
                        amount0_min: params.amount0_min,
                        amount1_min: params.amount1_min
                    }
                );

            let token_id = self.next_id.read();
            self.next_id.write(token_id + 1);
            self.erc721_storage._mint(params.recipient, token_id);

            let position_info = pool_dispatcher
                .get_position_info(
                    PositionKey {
                        owner: get_contract_address(),
                        tick_lower: params.tick_lower,
                        tick_upper: params.tick_upper
                    }
                );

            // idempotent set
            let pool_id = self
                ._cache_pool_key(
                    pool_dispatcher.contract_address,
                    PoolKey { token0: params.token0, token1: params.token1, fee: params.fee }
                );

            self
                .positions
                .write(
                    token_id,
                    PositionDetail {
                        operator: contract_address_const::<0>(),
                        pool_id: pool_id,
                        tick_lower: params.tick_lower,
                        tick_upper: params.tick_upper,
                        liquidity: liquidity,
                        fee_growth_inside_0_last_X128: position_info.fee_growth_inside_0_last_X128,
                        fee_growth_inside_1_last_X128: position_info.fee_growth_inside_1_last_X128,
                        tokens_owed_0: 0,
                        tokens_owed_1: 0
                    }
                );

            self.emit(IncreaseLiquidity { token_id, liquidity, amount0, amount1 });
            (token_id, liquidity, amount0, amount1)
        }

        // @notice Increases the amount of liquidity in a position, with tokens paid by the caller
        // @param params The params necessary to increase liquidity of a position, encoded as `IncreaseLiquidityParams` in calldata
        // @return The new liquidity amount as a result of the increase
        // @return The amount of token0 to achieve resulting liquidity
        // @return The amount of token1 to achieve resulting liquidity
        fn increase_liquidity(
            ref self: ContractState, params: IncreaseLiquidityParams
        ) -> (u128, u256, u256) {
            _check_deadline(params.deadline);

            let mut position = self.positions.read(params.token_id);
            let pool_key = self.pool_id_to_pool_key.read(position.pool_id);

            let (liquidity, amount0, amount1, pool_dispatcher) = self
                ._add_liquidity(
                    AddLiquidityParams {
                        token0: pool_key.token0,
                        token1: pool_key.token1,
                        fee: pool_key.fee,
                        tick_lower: position.tick_lower,
                        tick_upper: position.tick_upper,
                        amount0_desired: params.amount0_desired,
                        amount1_desired: params.amount1_desired,
                        amount0_min: params.amount0_min,
                        amount1_min: params.amount1_min,
                        recipient: get_contract_address()
                    }
                );

            // this is now updated to the current transaction
            let position_info = pool_dispatcher
                .get_position_info(
                    PositionKey {
                        owner: get_contract_address(),
                        tick_lower: position.tick_lower,
                        tick_upper: position.tick_upper
                    }
                );

            position
                .tokens_owed_0 +=
                    mul_div(
                        mod_subtraction(position_info.fee_growth_inside_0_last_X128, position.fee_growth_inside_0_last_X128),
                        position.liquidity.into(),
                        Q128
                    )
                .try_into()
                .unwrap();

            position
                .tokens_owed_1 +=
                    mul_div(
                        mod_subtraction(position_info.fee_growth_inside_1_last_X128, position.fee_growth_inside_1_last_X128),
                        position.liquidity.into(),
                        Q128
                    )
                .try_into()
                .unwrap();

            position.fee_growth_inside_0_last_X128 = position_info.fee_growth_inside_0_last_X128;
            position.fee_growth_inside_1_last_X128 = position_info.fee_growth_inside_1_last_X128;
            position.liquidity += liquidity;

            self.positions.write(params.token_id, position);

            self.emit(IncreaseLiquidity { token_id: params.token_id, liquidity, amount0, amount1 });
            (liquidity, amount0, amount1)
        }

        // @notice Decreases the amount of liquidity in a position and accounts it to the position
        // @param params The params necessary to decrease liquidity of a position, encoded as `DecreaseLiquidityParams` in calldata
        // @return The amount of token0 accounted to the position's tokens owed
        // @return The amount of token1 accounted to the position's tokens owed
        fn decrease_liquidity(
            ref self: ContractState, params: DecreaseLiquidityParams
        ) -> (u256, u256) {
            self._is_authorized_for_token(params.token_id);
            _check_deadline(params.deadline);
            assert(params.liquidity > 0, '0 liquidity');

            let mut position = self.positions.read(params.token_id);

            let position_liquidity = position.liquidity;
            assert(position_liquidity >= params.liquidity, 'not enough liquidity');

            let pool_key = self.pool_id_to_pool_key.read(position.pool_id);
            let factory_dispatcher = IJediSwapV2FactoryDispatcher {
                contract_address: self.factory.read()
            };
            let pool_address = factory_dispatcher
                .get_pool(pool_key.token0, pool_key.token1, pool_key.fee);
            let pool_dispatcher = IJediSwapV2PoolDispatcher { contract_address: pool_address };
            let (amount0, amount1) = pool_dispatcher
                .burn(position.tick_lower, position.tick_upper, params.liquidity);

            // this is now updated to the current transaction
            let position_info = pool_dispatcher
                .get_position_info(
                    PositionKey {
                        owner: get_contract_address(),
                        tick_lower: position.tick_lower,
                        tick_upper: position.tick_upper
                    }
                );

            position
                .tokens_owed_0 +=
                    (amount0
                        + mul_div(
                            position_info.fee_growth_inside_0_last_X128
                                - position.fee_growth_inside_0_last_X128,
                            position.liquidity.into(),
                            Q128
                        ))
                .try_into()
                .unwrap();

            position
                .tokens_owed_1 +=
                    (amount1
                        + mul_div(
                            position_info.fee_growth_inside_1_last_X128
                                - position.fee_growth_inside_1_last_X128,
                            position.liquidity.into(),
                            Q128
                        ))
                .try_into()
                .unwrap();

            position.fee_growth_inside_0_last_X128 = position_info.fee_growth_inside_0_last_X128;
            position.fee_growth_inside_1_last_X128 = position_info.fee_growth_inside_1_last_X128;
            // subtraction is safe because we checked position_liquidity is gte params.liquidity
            position.liquidity = position_liquidity - params.liquidity;

            self.positions.write(params.token_id, position);

            self
                .emit(
                    DecreaseLiquidity {
                        token_id: params.token_id, liquidity: params.liquidity, amount0, amount1
                    }
                );
            (amount0, amount1)
        }

        // @notice Collects up to a maximum amount of fees owed to a specific position to the recipient
        // @param params The params necessary to collect fees of a position, encoded as `CollectParams` in calldata
        // @return The amount of fees collected in token0
        // @return The amount of fees collected in token1
        fn collect(ref self: ContractState, params: CollectParams) -> (u128, u128) {
            self._is_authorized_for_token(params.token_id);
            assert(params.amount0_max > 0 || params.amount1_max > 0, 'nothing to collect');

            let recipient = if (params.recipient.is_zero()) {
                get_contract_address()
            } else {
                params.recipient
            };

            let mut position = self.positions.read(params.token_id);

            let pool_key = self.pool_id_to_pool_key.read(position.pool_id);
            let factory_dispatcher = IJediSwapV2FactoryDispatcher {
                contract_address: self.factory.read()
            };
            let pool_address = factory_dispatcher
                .get_pool(pool_key.token0, pool_key.token1, pool_key.fee);
            let pool_dispatcher = IJediSwapV2PoolDispatcher { contract_address: pool_address };

            let mut tokens_owed_0 = position.tokens_owed_0;
            let mut tokens_owed_1 = position.tokens_owed_1;

            // trigger an update of the position fees owed and fee growth snapshots if it has any liquidity
            if (position.liquidity > 0) {
                pool_dispatcher.burn(position.tick_lower, position.tick_upper, 0);
                let position_info = pool_dispatcher
                    .get_position_info(
                        PositionKey {
                            owner: get_contract_address(),
                            tick_lower: position.tick_lower,
                            tick_upper: position.tick_upper
                        }
                    );

                tokens_owed_0 +=
                    mul_div(
                        position_info.fee_growth_inside_0_last_X128
                            - position.fee_growth_inside_0_last_X128,
                        position.liquidity.into(),
                        Q128
                    )
                    .try_into()
                    .unwrap();
                tokens_owed_1 +=
                    mul_div(
                        position_info.fee_growth_inside_1_last_X128
                            - position.fee_growth_inside_1_last_X128,
                        position.liquidity.into(),
                        Q128
                    )
                    .try_into()
                    .unwrap();

                position
                    .fee_growth_inside_0_last_X128 = position_info
                    .fee_growth_inside_0_last_X128;
                position
                    .fee_growth_inside_1_last_X128 = position_info
                    .fee_growth_inside_1_last_X128;
            }

            // compute the arguments to give to the pool#collect method
            let amount0_collect = if (params.amount0_max > tokens_owed_0) {
                tokens_owed_0
            } else {
                params.amount0_max
            };
            let amount1_collect = if (params.amount1_max > tokens_owed_1) {
                tokens_owed_1
            } else {
                params.amount1_max
            };

            // the actual amounts collected are returned
            let (amount0, amount1) = pool_dispatcher
                .collect(
                    recipient,
                    position.tick_lower,
                    position.tick_upper,
                    amount0_collect,
                    amount1_collect
                );

            // sometimes there will be a few less wei than expected due to rounding down in core, but we just subtract the full amount expected
            // instead of the actual amount so we can burn the token
            position.tokens_owed_0 = tokens_owed_0 - amount0_collect;
            position.tokens_owed_1 = tokens_owed_1 - amount1_collect;

            self.positions.write(params.token_id, position);

            self
                .emit(
                    Collect {
                        token_id: params.token_id, recipient, amount0_collect, amount1_collect
                    }
                );
            (amount0, amount1)
        }

        // @notice Burns a token ID, which deletes it from the NFT contract. The token must have 0 liquidity and all tokens
        // must be collected first.
        // @param token_id The ID of the token that is being burned
        fn burn(ref self: ContractState, token_id: u256) {
            self._is_authorized_for_token(token_id);
            let mut position = self.positions.read(token_id);
            assert(
                position.liquidity == 0
                    && position.tokens_owed_0 == 0
                    && position.tokens_owed_1 == 0,
                'Not cleared'
            );
            self
                .positions
                .write(
                    token_id,
                    PositionDetail {
                        operator: contract_address_const::<0>(),
                        pool_id: 0,
                        tick_lower: IntegerTrait::<i32>::new(0, false),
                        tick_upper: IntegerTrait::<i32>::new(0, false),
                        liquidity: 0,
                        fee_growth_inside_0_last_X128: 0,
                        fee_growth_inside_1_last_X128: 0,
                        tokens_owed_0: 0,
                        tokens_owed_1: 0
                    }
                );
            self.erc721_storage._burn(token_id);
        }

        // @notice Creates a new pool if it does not exist, then initializes if not initialized
        // @dev This method can be bundled with others via multicall for the first action (e.g. mint) performed against a pool
        // @param token0 The contract address of token0 of the pool
        // @param token1 The contract address of token1 of the pool
        // @param fee The fee amount of the v2 pool for the specified token pair
        // @param sqrt_price_X96 The initial square root price of the pool as a Q64.96 value
        // @return Returns the pool address based on the pair of tokens and fee, will return the newly created pool address if necessary
        fn create_and_initialize_pool(
            ref self: ContractState,
            token0: ContractAddress,
            token1: ContractAddress,
            fee: u32,
            sqrt_price_X96: u256
        ) -> ContractAddress {
            assert(
                u256_from_felt252(
                    contract_address_to_felt252(token0)
                ) < u256_from_felt252(contract_address_to_felt252(token1)),
                'Tokens not sorted'
            );
            let factory_dispatcher = IJediSwapV2FactoryDispatcher {
                contract_address: self.factory.read()
            };
            let mut pool_address = factory_dispatcher.get_pool(token0, token1, fee);

            if (pool_address.is_zero()) {
                pool_address = factory_dispatcher.create_pool(token0, token1, fee);
                let pool_dispatcher = IJediSwapV2PoolDispatcher { contract_address: pool_address };
                pool_dispatcher.initialize(sqrt_price_X96);
            } else {
                let pool_dispatcher = IJediSwapV2PoolDispatcher { contract_address: pool_address };
                let sqrt_price_X96_existing = pool_dispatcher.get_sqrt_price_X96();
                if (sqrt_price_X96_existing == 0) {
                    pool_dispatcher.initialize(sqrt_price_X96);
                }
            }
            pool_address
        }

        fn jediswap_v2_mint_callback(
            ref self: ContractState,
            amount0_owed: u256,
            amount1_owed: u256,
            mut callback_data_span: Span<felt252>
        ) {
            let caller = get_caller_address();

            let decoded_data = Serde::<MintCallbackData>::deserialize(ref callback_data_span)
                .unwrap();

            verify_callback_pool_key(self.factory.read(), decoded_data.pool_key);

            if (amount0_owed > 0) {
                pay(decoded_data.pool_key.token0, decoded_data.payer, caller, amount0_owed);
            }
            if (amount1_owed > 0) {
                pay(decoded_data.pool_key.token1, decoded_data.payer, caller, amount1_owed);
            }
        }

        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            let caller = get_caller_address();
            let ownable_dispatcher = IOwnableDispatcher { contract_address: self.factory.read() };
            assert(ownable_dispatcher.owner() == caller, 'Invalid caller');
            self.upgradeable_storage._upgrade(new_class_hash);
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        // @dev Caches a pool key
        fn _cache_pool_key(
            ref self: ContractState, pool: ContractAddress, pool_key: PoolKey
        ) -> u64 {
            let mut pool_id = self.pool_ids.read(pool);
            if (pool_id == 0) {
                pool_id = self.next_pool_id.read();
                self.next_pool_id.write(pool_id + 1);
                self.pool_ids.write(pool, pool_id);
                self.pool_id_to_pool_key.write(pool_id, pool_key);
            }
            pool_id
        }

        // @notice Add liquidity to an initialized pool
        fn _add_liquidity(
            self: @ContractState, params: AddLiquidityParams
        ) -> (u128, u256, u256, IJediSwapV2PoolDispatcher) {
            let pool_key = PoolKey {
                token0: params.token0, token1: params.token1, fee: params.fee
            };

            let factory_dispatcher = IJediSwapV2FactoryDispatcher {
                contract_address: self.factory.read()
            };
            let pool_address = factory_dispatcher
                .get_pool(params.token0, params.token1, params.fee);

            assert(pool_address.into() != 0, 'pool not created');

            let pool_dispatcher = IJediSwapV2PoolDispatcher { contract_address: pool_address };

            // compute the liquidity amount
            let sqrt_price_X96 = pool_dispatcher.get_sqrt_price_X96();
            let sqrt_ratio_a_X96 = get_sqrt_ratio_at_tick(params.tick_lower);
            let sqrt_ratio_b_X96 = get_sqrt_ratio_at_tick(params.tick_upper);

            let liquidity = get_liquidity_for_amounts(
                sqrt_price_X96,
                sqrt_ratio_a_X96,
                sqrt_ratio_b_X96,
                params.amount0_desired,
                params.amount1_desired
            );

            let mut mint_callback_data: Array<felt252> = ArrayTrait::new();
            let mint_callback_data_struct = MintCallbackData {
                pool_key, payer: get_caller_address()
            };
            Serde::<
                MintCallbackData
            >::serialize(@mint_callback_data_struct, ref mint_callback_data);
            let (amount0, amount1) = pool_dispatcher
                .mint(
                    params.recipient,
                    params.tick_lower,
                    params.tick_upper,
                    liquidity,
                    mint_callback_data
                );

            assert(
                amount0 >= params.amount0_min && amount1 >= params.amount1_min,
                'Price slippage check'
            );
            (liquidity, amount0, amount1, pool_dispatcher)
        }

        fn _is_authorized_for_token(ref self: ContractState, token_id: u256) {
            let caller = get_caller_address();
            assert(self.erc721_storage._is_approved_or_owner(caller, token_id), 'Not approved');
        }

        fn _token_uri(self: @ContractState, token_id: u256) -> ByteArray {
            let mut content: ByteArray = "";
            let (_, pool_key) = self.get_position(token_id);

            let token_0_dispatcher = IERC20MetadataDispatcher { contract_address: pool_key.token0 };
            let token_1_dispatcher = IERC20MetadataDispatcher { contract_address: pool_key.token1 };

            // Name & Description
            content.append_word('data:application/json;utf8,', 27);
            content.append_word('{"name":"JediSwap V2 Position",', 28);
            content.append_word('"description":"This NFT ', 24);
            content.append_word('represents liquidity position ', 30);
            content.append_word('in a JediSwap V2 ', 17);
            content.append(@token_0_dispatcher.symbol());
            content.append_word('-', 1);
            content.append(@token_1_dispatcher.symbol());
            content.append_word(' ', 1);
            // fee_to_string(ref content, pool_key.fee.into());
            content.append_word('% ', 2);
            content.append_word(' pool. The owner of this NFT ', 29);
            content.append_word('can modify or redeem the ', 25);
            content.append_word('position."', 10);
            // // Image
            content.append_word(',"image":"', 10);
            content.append_word('https://static.jediswap.', 23);
            content.append_word('xyz/V2NFT.png"}', 15);
            // content.append('position. Deposit Amounts: ');
            // content.append('~0 ETH & ~0.000002 USDC"');

            // // Image
            // content.append(',"image":"');
            // content.append('data:image/svg+xml;utf8,<svg%20');
            // content.append('width=\\"100%\\"%20height=\\"100%\\');
            // content.append('"%20viewBox=\\"0%200%2020000%202');
            // content.append('0000\\"%20xmlns=\\"http://www.w3.');
            // content.append('org/2000/svg\\"><style>svg{backg');
            // content.append('round-image:url(');
            // content.append('data:image/png;base64,');

            // // Golden Token Base64 Encoded PNG
            // content.append('iVBORw0KGgoAAAANSUhEUgAAAUAAAAF');
            // content.append('ABAMAAAA/vriZAAAAD1BMVEUAAAD4+A');
            // content.append('CJSQL/pAD///806TM9AAACgUlEQVR4A');
            // content.append('WKgGAjiBUqoANDOHdzGDcRQAK3BLaSF');
            // content.append('tJD+awriQwh8zDd2srlQfjxJGGr4xhf');
            // content.append('Csuj3ywEC7gcCAgKeCD9bVC8gICAg4H');
            // content.append('cDVtGvP/G5MKIXvKF8MhAQEBAQMFifo');
            // content.append('rmK+Iho8uh8zwMCAgICAk65aouaEVM9');
            // content.append('WL3zAQICAgJuBqYtth7brEZHC2CcMI6');
            // content.append('Z1FQCAgICAm4GTnZsGL8WRaW4inPVV3');
            // content.append('eAgICAgI8CVls0uIr+WnnR7wABAQEBF');
            // content.append('wAvbBn3ytrvuhIQEBAQcCvwa8IbygCm');
            // content.append('DRAQEBBwK7DbTt8A/OdWl7ZUAgICAgL');
            // content.append('uAp5slXD1+i2BzQYICAgIuBsYtigyf8');
            // content.append('2Z+GjRkhMYNQABAQEBdwFfsVXgRLd1Y');
            // content.append('Dl/yAEBAQEB9wDrO7OoOQtRvdpeGKec');
            // content.append('AAQEBATcCsxWd7qNwh1YItG15EYgICA');
            // content.append('gIOAopyudHp6FuApgTRlgKbkTCAgICA');
            // content.append('g4jhAl8NCz/u31W2+na4GAgICAgHFVh');
            // content.append('+ZPtkmJvEiuNeYMa4CAgICAgPlxWSxP');
            // content.append('nERhS0zE4XDR78rAyw4gICAgIGASYte');
            // content.append('UN1soJyV+CGOL7QEBAQEBnwTs20yl+t');
            // content.append('VZvFGLhTpUsxAICAgICJjKfORvvD06O');
            // content.append('cAL2zogICAgIODJFg+fvknL25vR+7nd');
            // content.append('CQQEBAQELMrYIeQ/XoxJvrItBAICAgI');
            // content.append('CpvK0w2l8pUak3Nn2AwEBAQEB6z+sj/');
            // content.append('1jin/yTlsFdT8QEBAQELAro1PF/lEpI');
            // content.append('lJGHgthAwQEBATcD8wI5dxOzRr1C7PO');
            // content.append('AgQEBAR8GjA7X1SqyjqxP0/cAJYDAQE');
            // content.append('BAQGDGt46cJ/JyQIEBAQEfD7w0nsl2g');
            // content.append('8EBAQEBPwNOZbOIEJQph0AAAAASUVOR');
            // content.append('K5CYII=');

            // content.append(');background-repeat:no-repeat;b');
            // content.append('ackground-size:contain;backgrou');
            // content.append('nd-position:center;image-render');
            // content.append('ing:-webkit-optimize-contrast;-');
            // content.append('ms-interpolation-mode:nearest-n');
            // content.append('eighbor;image-rendering:-moz-cr');
            // content.append('isp-edges;image-rendering:pixel');
            // content.append('ated;}</style></svg>"}');

            content
        }
    }

    fn _check_deadline(deadline: u64) {
        let block_timestamp = get_block_timestamp();
        assert(deadline >= block_timestamp, 'Transaction too old');
    }
}
