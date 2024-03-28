mod NFTDescriptor {
    use starknet::{ContractAddress, get_caller_address};
    use jediswap_v2_core::jediswap_v2_factory::{
        IJediSwapV2FactoryDispatcher, IJediSwapV2FactoryDispatcherTrait
    };
    use jediswap_v2_periphery::jediswap_v2_nft_position_manager::PoolKey;
    use jediswap_v2_core::libraries::math_utils::pow;


    // @notice Appends the string representation of a number to an array
    // @param content The array to append to
    // @param num_to_convert The number to convert
    // @param decimal Number of digits
    fn fee_to_string(ref content: Array<felt252>, mut num_to_convert: u256) {
        let mut decimal = 4;
        let before_decimal = num_to_convert / pow(10, decimal);
        let after_decimal = num_to_convert % pow(10, decimal);
        if (before_decimal > 0) {
            content.append(before_decimal.try_into().unwrap() + 48);
            loop {
                break true;
            };
        } else {
            content.append('0.')
        }
        num_to_convert = after_decimal;
        decimal -= 1;
        loop {
            if (decimal == 0 || num_to_convert == 0) {
                break true;
            }
            let q = num_to_convert / pow(10, decimal);
            let r = num_to_convert % pow(10, decimal);
            content.append(q.try_into().unwrap() + 48);
            num_to_convert = r;
            decimal -= 1;
        };
    }
}
