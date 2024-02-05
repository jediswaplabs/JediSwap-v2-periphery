// @title JediSwap V2 Swap Router
// @notice Router for stateless execution of swaps against JediSwap V2

use starknet::ContractAddress;
use yas_core::numbers::signed_integer::{i256::i256};

#[derive(Copy, Drop, Serde)]
struct ExactInputSingleParams {
    token_in: ContractAddress,
    token_out: ContractAddress,
    fee: u32,
    recipient: ContractAddress,
    deadline: u64,
    amount_in: u256,
    amount_out_minimum: u256,
    sqrt_price_limit_X96: u256
}

#[derive(Drop, Serde)]
struct ExactInputParams {
    path: Array<felt252>,
    recipient: ContractAddress,
    deadline: u64,
    amount_in: u256,
    amount_out_minimum: u256
}

#[derive(Copy, Drop, Serde)]
struct ExactOutputSingleParams {
    token_in: ContractAddress,
    token_out: ContractAddress,
    fee: u32,
    recipient: ContractAddress,
    deadline: u64,
    amount_out: u256,
    amount_in_maximum: u256,
    sqrt_price_limit_X96: u256
}

#[derive(Drop, Serde)]
struct ExactOutputParams {
    path: Array::<felt252>,
    recipient: ContractAddress,
    deadline: u64,
    amount_out: u256,
    amount_in_maximum: u256
}

#[derive(Copy, Drop, Serde)]
struct PathData {
    token_in: ContractAddress,
    token_out: ContractAddress,
    fee: u32
}

#[derive(Copy, Drop, Serde)]
struct SwapCallbackData {
    path: Span<felt252>,
    payer: ContractAddress
}


#[starknet::interface]
trait IJediSwapV2SwapRouter<TContractState> {
    fn get_factory(self: @TContractState) -> ContractAddress;
    fn exact_input_single(ref self: TContractState, params: ExactInputSingleParams) -> u256;
    fn exact_input(ref self: TContractState, params: ExactInputParams) -> u256;
    fn exact_output_single(ref self: TContractState, params: ExactOutputSingleParams) -> u256;
    fn exact_output(ref self: TContractState, params: ExactOutputParams) -> u256;
    fn jediswap_v2_swap_callback(ref self: TContractState, amount0_delta: i256, amount1_delta: i256, callback_data_span: Span<felt252>);
}

#[starknet::contract]
mod JediSwapV2SwapRouter {
    use super::{ExactInputSingleParams, ExactInputParams, ExactOutputSingleParams, ExactOutputParams, PathData, SwapCallbackData};
    use starknet::{ContractAddress, get_contract_address, get_caller_address, get_block_timestamp, contract_address_to_felt252};
    use integer::{u256_from_felt252, BoundedInt};

    use jediswap_v2_core::libraries::tick_math::TickMath::{get_sqrt_ratio_at_tick, MIN_TICK, MAX_TICK};
    use jediswap_v2_periphery::libraries::callback_validation::CallbackValidation::verify_callback;
    use jediswap_v2_periphery::libraries::periphery_payments::PeripheryPayments::pay;

    use jediswap_v2_core::jediswap_v2_pool::{IJediSwapV2PoolDispatcher, IJediSwapV2PoolDispatcherTrait};
    use jediswap_v2_core::jediswap_v2_factory::{IJediSwapV2FactoryDispatcher, IJediSwapV2FactoryDispatcherTrait};
    
    use yas_core::numbers::signed_integer::{i256::i256, integer_trait::IntegerTrait};
    use yas_core::utils::math_utils::FullMath::mul_div;

    #[storage]
    struct Storage {
        factory: ContractAddress,
        amount_in_cached: u256
    }

    #[constructor]
    fn constructor(ref self: ContractState, factory: ContractAddress) {
        self.factory.write(factory);
        self.amount_in_cached.write(BoundedInt::max());
    }

    #[external(v0)]
    impl JediSwapV2SwapRouterImpl of super::IJediSwapV2SwapRouter<ContractState> {
        
        fn get_factory(self: @ContractState) -> ContractAddress {
            self.factory.read()
        }

        // @notice Swaps `amount_in` of one token for as much as possible of another token
        // @param params The parameters necessary for the swap, encoded as `ExactInputSingleParams` in calldata
        // @return The amount of the received token
        fn exact_input_single(ref self: ContractState, params: ExactInputSingleParams) -> u256 {
            _check_deadline(params.deadline);
            let mut path_data: Array<felt252> = ArrayTrait::new();
            let path_data_struct = PathData{token_in: params.token_in, token_out: params.token_out, fee: params.fee};
            Serde::<PathData>::serialize(@path_data_struct, ref path_data);
            let swap_callback_data_struct = SwapCallbackData {path: path_data.span(), payer: get_caller_address()};
            let amount_out = self._exact_input_internal(params.amount_in, params.recipient, params.sqrt_price_limit_X96, swap_callback_data_struct);
            assert(amount_out >= params.amount_out_minimum, 'Too little received');
            amount_out
        }

        // @notice Swaps `amount_in` of one token for as much as possible of another along the specified path
        // @param params The parameters necessary for the multi-hop swap, encoded as `ExactInputParams` in calldata
        // @return The amount of the received token
        fn exact_input(ref self: ContractState, params: ExactInputParams) -> u256 {
            _check_deadline(params.deadline);
            let mut payer = get_caller_address();
            let mut path_data_span = params.path.span();
            let mut amount_in = params.amount_in;
            let mut amount_out = 0;
            loop {
                let path_data_len = path_data_span.len();

                let has_multiple_pools = path_data_len > 3;
                let swap_callback_data_struct = SwapCallbackData {path: path_data_span.slice(0, 3), payer: payer};  // only the first pool in the path is necessary

                // the outputs of prior swaps become the inputs to subsequent ones
                amount_in = self._exact_input_internal(
                    amount_in, 
                    if (has_multiple_pools) {   // for intermediate swaps, this contract custodies
                        get_contract_address() 
                        } else { 
                            params.recipient 
                            },
                    0, 
                    swap_callback_data_struct);
                
                // decide whether to continue or terminate
                if (has_multiple_pools) {
                    payer = get_contract_address(); // at this point, the caller has paid
                    path_data_span = path_data_span.slice(3, path_data_len - 3);
                } else {
                    amount_out = amount_in;
                    break true;
                }
            };

            assert(amount_out >= params.amount_out_minimum, 'Too little received');
            amount_out
        }

        // @notice Swaps as little as possible of one token for `amount_out` of another token
        // @param params The parameters necessary for the swap, encoded as `ExactOutputSingleParams` in calldata
        // @return The amount of the input token
        fn exact_output_single(ref self: ContractState, params: ExactOutputSingleParams) -> u256 {
            _check_deadline(params.deadline);
            let mut path_data: Array<felt252> = ArrayTrait::new();
            let path_data_struct = PathData{token_in: params.token_out, token_out: params.token_in, fee: params.fee};
            Serde::<PathData>::serialize(@path_data_struct, ref path_data);
            // let mut swap_callback_data: Array<felt252> = ArrayTrait::new();
            let swap_callback_data_struct = SwapCallbackData {path: path_data.span(), payer: get_caller_address()};
            // Serde::<SwapCallbackData>::serialize(@swap_callback_data_struct, ref swap_callback_data);
            let amount_in = self._exact_output_internal(params.amount_out, params.recipient, params.sqrt_price_limit_X96, swap_callback_data_struct);
            assert(amount_in <= params.amount_in_maximum, 'Too much requested');
            // has to be reset even though we don't use it in the single hop case
            self.amount_in_cached.write(BoundedInt::max());
            amount_in
        }

        // @notice Swaps as little as possible of one token for `amount_out` of another along the specified path (reversed)
        // @dev path array will be in format [token_out, token_in, fee] if used for single hop (recommend using exact_output_single)
        // @dev for multihop going from token_in to token_out via token_mid, path will be [token_out, token_mid, fee_out_mid, token_mid, token_in, fee_mid_in]
        // @param params The parameters necessary for the multi-hop swap, encoded as `ExactOutputParams` in calldata
        // @return The amount of the input token
        fn exact_output(ref self: ContractState, params: ExactOutputParams) -> u256 {
            _check_deadline(params.deadline);
            let path_data_span = params.path.span();

            // it's okay that the payer is fixed to caller here, as they're only paying for the "final" exact output
            // swap, which happens first, and subsequent swaps are paid for within nested callback frames
            let swap_callback_data_struct = SwapCallbackData {path: path_data_span, payer: get_caller_address()};
            self._exact_output_internal(params.amount_out, params.recipient, 0, swap_callback_data_struct);

            let amount_in = self.amount_in_cached.read();
            assert(amount_in <= params.amount_in_maximum, 'Too much requested');
            self.amount_in_cached.write(BoundedInt::max());
            amount_in
        }
        
        fn jediswap_v2_swap_callback(ref self: ContractState, amount0_delta: i256, amount1_delta: i256, mut callback_data_span: Span<felt252>) {
            assert(amount0_delta > IntegerTrait::<i256>::new(0, false) || amount1_delta > IntegerTrait::<i256>::new(0, false), 'not supported');
            let caller = get_caller_address();
            
            let decoded_data = Serde::<SwapCallbackData>::deserialize(ref callback_data_span).unwrap();

            let mut path_span = decoded_data.path.slice(0, 3);
            let path = Serde::<PathData>::deserialize(ref path_span).unwrap();
            let (token_in, token_out, fee) = (path.token_in, path.token_out, path.fee);

            verify_callback(self.factory.read(), token_in, token_out, fee);

            let (is_exact_input, amount_to_pay) = if (amount0_delta > IntegerTrait::<i256>::new(0, false)) {
                (u256_from_felt252(contract_address_to_felt252(token_in)) < u256_from_felt252(contract_address_to_felt252(token_out)), amount0_delta.mag)
            } else {
                (u256_from_felt252(contract_address_to_felt252(token_out)) < u256_from_felt252(contract_address_to_felt252(token_in)), amount1_delta.mag)
            };

            if (is_exact_input) {
                pay(token_in, decoded_data.payer, caller, amount_to_pay);
            } else {
                // either initiate the next swap or pay
                if (decoded_data.path.len() > 3) {
                    let swap_callback_data_struct = SwapCallbackData {path: decoded_data.path.slice(3, decoded_data.path.len() - 3), payer: decoded_data.payer};
                    self._exact_output_internal(amount_to_pay, caller, 0, swap_callback_data_struct);
                } else {
                    self.amount_in_cached.write(amount_to_pay);
                    pay(token_out, decoded_data.payer, caller, amount_to_pay);  // swap in/out because exact output swaps are reversed
                }
            }
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {

        // @dev Performs a single exact input swap
        fn _exact_input_internal(ref self: ContractState, amount_in: u256, mut recipient: ContractAddress, sqrt_price_limit_X96: u256, swap_callback_data_struct: SwapCallbackData) -> u256 {
            // allow swapping to the router address with address 0
            if (recipient.is_zero()) {
                recipient = get_contract_address();
            }
            
            let mut path_span = swap_callback_data_struct.path;

            let path = Serde::<PathData>::deserialize(ref path_span).unwrap();

            let zero_for_one = u256_from_felt252(contract_address_to_felt252(path.token_in)) < u256_from_felt252(contract_address_to_felt252(path.token_out));

            let factory_dispatcher = IJediSwapV2FactoryDispatcher {contract_address: self.factory.read()};
            let mut pool_address = factory_dispatcher.get_pool(path.token_in, path.token_out, path.fee);
            let pool_dispatcher = IJediSwapV2PoolDispatcher {contract_address: pool_address};
            let mut swap_callback_data: Array<felt252> = ArrayTrait::new();
            Serde::<SwapCallbackData>::serialize(@swap_callback_data_struct, ref swap_callback_data);
            let (amount0, amount1) = pool_dispatcher.swap(
                recipient, 
                zero_for_one, 
                amount_in.into(), 
                if (sqrt_price_limit_X96 == 0) {
                    if (zero_for_one) {
                        get_sqrt_ratio_at_tick(MIN_TICK()) + 1
                    } else {
                        get_sqrt_ratio_at_tick(MAX_TICK()) - 1
                    }
                } else {
                    sqrt_price_limit_X96
                },
                swap_callback_data
            );
            if (zero_for_one) {
                return amount1.mag;
            } else {
                return amount0.mag;
            }
        }

        // @dev Performs a single exact output swap
        fn _exact_output_internal(ref self: ContractState, amount_out: u256, mut recipient: ContractAddress, sqrt_price_limit_X96: u256, swap_callback_data_struct: SwapCallbackData) -> u256 {
            // allow swapping to the router address with address 0
            if (recipient.is_zero()) {
                recipient = get_contract_address();
            }
            
            let mut path_span = swap_callback_data_struct.path.slice(0, 3);

            let path = Serde::<PathData>::deserialize(ref path_span).unwrap();

            let token_out = path.token_in;
            let token_in = path.token_out;
            let fee = path.fee;

            let zero_for_one = u256_from_felt252(contract_address_to_felt252(token_in)) < u256_from_felt252(contract_address_to_felt252(token_out));

            let factory_dispatcher = IJediSwapV2FactoryDispatcher {contract_address: self.factory.read()};
            let mut pool_address = factory_dispatcher.get_pool(token_in, token_out, fee);
            let pool_dispatcher = IJediSwapV2PoolDispatcher {contract_address: pool_address};
            let mut swap_callback_data: Array<felt252> = ArrayTrait::new();
            Serde::<SwapCallbackData>::serialize(@swap_callback_data_struct, ref swap_callback_data);
            let (amount0_delta, amount1_delta) = pool_dispatcher.swap(
                recipient, 
                zero_for_one, 
                -amount_out.into(), 
                if (sqrt_price_limit_X96 == 0) {
                    if (zero_for_one) {
                        get_sqrt_ratio_at_tick(MIN_TICK()) + 1
                    } else {
                        get_sqrt_ratio_at_tick(MAX_TICK()) - 1
                    }
                } else {
                    sqrt_price_limit_X96
                },
                swap_callback_data
            );
            let (amount_in, amount_out_received) = if (zero_for_one) { 
                (amount0_delta.mag, amount1_delta.mag)
                } else {
                    (amount1_delta.mag, amount0_delta.mag)
                    };
            // it's technically possible to not receive the full output amount,
            // so if no price limit has been specified, require this possibility away
            if (sqrt_price_limit_X96 == 0) {
                assert(amount_out_received == amount_out, 'not full amount');
            }

            amount_in
        }
    }

    fn _check_deadline(deadline: u64) {
            let block_timestamp = get_block_timestamp();
            assert(deadline >= block_timestamp, 'Transaction too old');
    }
}