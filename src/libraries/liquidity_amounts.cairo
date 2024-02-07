mod LiquidityAmounts {
    use yas_core::utils::math_utils::FullMath::mul_div;
    use yas_core::utils::math_utils::BitShift::BitShiftTrait;
    use jediswap_v2_core::libraries::sqrt_price_math::SqrtPriceMath::{Q96, R96};

    // @notice Computes the amount of liquidity received for a given amount of token0 and price range
    // @dev Calculates amount0 * (sqrt(upper) * sqrt(lower)) / (sqrt(upper) - sqrt(lower))
    // @param sqrt_ratio_a_X96 A sqrt price representing the first tick boundary
    // @param sqrt_ratio_b_X96 A sqrt price representing the second tick boundary
    // @param amount0 The amount0 being sent in
    // @return liquidity The amount of returned liquidity
    fn get_liquidity_for_amount0(
        sqrt_ratio_a_X96: u256, sqrt_ratio_b_X96: u256, amount0: u256
    ) -> u128 {
        let (sqrt_ratio_a_X96, sqrt_ratio_b_X96) = if (sqrt_ratio_a_X96 > sqrt_ratio_b_X96) {
            (sqrt_ratio_b_X96, sqrt_ratio_a_X96)
        } else {
            (sqrt_ratio_a_X96, sqrt_ratio_b_X96)
        };
        let intermediate = mul_div(sqrt_ratio_a_X96, sqrt_ratio_b_X96, Q96);
        mul_div(amount0, intermediate, sqrt_ratio_b_X96 - sqrt_ratio_a_X96).try_into().unwrap()
    }

    // @notice Computes the amount of liquidity received for a given amount of token1 and price range
    // @dev Calculates amount1 / (sqrt(upper) - sqrt(lower)).
    // @param sqrt_ratio_a_X96 A sqrt price representing the first tick boundary
    // @param sqrt_ratio_b_X96 A sqrt price representing the second tick boundary
    // @param amount1 The amount1 being sent in
    // @return liquidity The amount of returned liquidity
    fn get_liquidity_for_amount1(
        sqrt_ratio_a_X96: u256, sqrt_ratio_b_X96: u256, amount1: u256
    ) -> u128 {
        let (sqrt_ratio_a_X96, sqrt_ratio_b_X96) = if (sqrt_ratio_a_X96 > sqrt_ratio_b_X96) {
            (sqrt_ratio_b_X96, sqrt_ratio_a_X96)
        } else {
            (sqrt_ratio_a_X96, sqrt_ratio_b_X96)
        };
        mul_div(amount1, Q96, (sqrt_ratio_b_X96 - sqrt_ratio_a_X96)).try_into().unwrap()
    }

    // @notice Computes the maximum amount of liquidity received for a given amount of token0, token1, the current
    // pool prices and the prices at the tick boundaries
    // @param sqrt_ratio_X96 A sqrt price representing the current pool prices
    // @param sqrt_ratio_a_X96 A sqrt price representing the first tick boundary
    // @param sqrt_ratio_b_X96 A sqrt price representing the second tick boundary
    // @param amount0 The amount of token0 being sent in
    // @param amount1 The amount of token1 being sent in
    // @return liquidity The maximum amount of liquidity received
    fn get_liquidity_for_amounts(
        sqrt_ratio_X96: u256,
        sqrt_ratio_a_X96: u256,
        sqrt_ratio_b_X96: u256,
        amount0: u256,
        amount1: u256
    ) -> u128 {
        let (sqrt_ratio_a_X96, sqrt_ratio_b_X96) = if (sqrt_ratio_a_X96 > sqrt_ratio_b_X96) {
            (sqrt_ratio_b_X96, sqrt_ratio_a_X96)
        } else {
            (sqrt_ratio_a_X96, sqrt_ratio_b_X96)
        };

        if (sqrt_ratio_X96 <= sqrt_ratio_a_X96) {
            get_liquidity_for_amount0(sqrt_ratio_a_X96, sqrt_ratio_b_X96, amount0)
        } else if (sqrt_ratio_X96 < sqrt_ratio_b_X96) {
            let liquidity0 = get_liquidity_for_amount0(sqrt_ratio_X96, sqrt_ratio_b_X96, amount0);
            let liquidity1 = get_liquidity_for_amount1(sqrt_ratio_a_X96, sqrt_ratio_X96, amount1);
            if (liquidity0 < liquidity1) {
                liquidity0
            } else {
                liquidity1
            }
        } else {
            get_liquidity_for_amount1(sqrt_ratio_a_X96, sqrt_ratio_b_X96, amount1)
        }
    }

    // @notice Computes the amount of token0 for a given amount of liquidity and a price range
    // @param sqrt_ratio_a_X96 A sqrt price representing the first tick boundary
    // @param sqrt_ratio_b_X96 A sqrt price representing the second tick boundary
    // @param liquidity The liquidity being valued
    // @return The amount of token0
    fn get_amount0_for_liquidity(
        sqrt_ratio_a_X96: u256, sqrt_ratio_b_X96: u256, liquidity: u128
    ) -> u256 {
        let (sqrt_ratio_a_X96, sqrt_ratio_b_X96) = if (sqrt_ratio_a_X96 > sqrt_ratio_b_X96) {
            (sqrt_ratio_b_X96, sqrt_ratio_a_X96)
        } else {
            (sqrt_ratio_a_X96, sqrt_ratio_b_X96)
        };
        mul_div(liquidity.into().shl(R96), sqrt_ratio_b_X96 - sqrt_ratio_a_X96, sqrt_ratio_b_X96)
            / sqrt_ratio_a_X96
    }

    // @notice Computes the amount of token1 for a given amount of liquidity and a price range
    // @param sqrt_ratio_a_X96 A sqrt price representing the first tick boundary
    // @param sqrt_ratio_b_X96 A sqrt price representing the second tick boundary
    // @param liquidity The liquidity being valued
    // @return The amount of token1
    fn get_amount1_for_liquidity(
        sqrt_ratio_a_X96: u256, sqrt_ratio_b_X96: u256, liquidity: u128
    ) -> u256 {
        let (sqrt_ratio_a_X96, sqrt_ratio_b_X96) = if (sqrt_ratio_a_X96 > sqrt_ratio_b_X96) {
            (sqrt_ratio_b_X96, sqrt_ratio_a_X96)
        } else {
            (sqrt_ratio_a_X96, sqrt_ratio_b_X96)
        };
        let liquidity_u256: u256 = liquidity.into();
        mul_div(liquidity.into(), sqrt_ratio_b_X96 - sqrt_ratio_a_X96, Q96)
    }

    fn get_amounts_for_liquidity(
        sqrt_ratio_X96: u256, sqrt_ratio_a_X96: u256, sqrt_ratio_b_X96: u256, liquidity: u128
    ) -> (u256, u256) {
        let (sqrt_ratio_a_X96, sqrt_ratio_b_X96) = if (sqrt_ratio_a_X96 > sqrt_ratio_b_X96) {
            (sqrt_ratio_b_X96, sqrt_ratio_a_X96)
        } else {
            (sqrt_ratio_a_X96, sqrt_ratio_b_X96)
        };

        let mut amount0: u256 = 0;
        let mut amount1: u256 = 0;

        if (sqrt_ratio_X96 <= sqrt_ratio_a_X96) {
            amount0 = get_amount0_for_liquidity(sqrt_ratio_a_X96, sqrt_ratio_b_X96, liquidity);
        } else if (sqrt_ratio_X96 < sqrt_ratio_b_X96) {
            amount0 = get_amount0_for_liquidity(sqrt_ratio_X96, sqrt_ratio_b_X96, liquidity);
            amount1 = get_amount1_for_liquidity(sqrt_ratio_a_X96, sqrt_ratio_X96, liquidity);
        } else {
            amount1 = get_amount1_for_liquidity(sqrt_ratio_a_X96, sqrt_ratio_b_X96, liquidity);
        }

        (amount0, amount1)
    }
}
