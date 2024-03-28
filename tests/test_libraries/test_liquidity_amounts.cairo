use jediswap_v2_periphery::libraries::liquidity_amounts::LiquidityAmounts::{
    get_liquidity_for_amounts, get_amounts_for_liquidity
};
use jediswap_v2_core::libraries::math_utils::pow;


// def encode_price_sqrt(a, b): 
//      return int(math.sqrt(a/b) * (2**96))

#[test]
fn test_get_liquidity_for_amounts_for_price_inside() {
    let sqrt_price_X96 = 79228162514264337593543950336; //  encode_price_sqrt(1, 1)
    let sqrt_price_a_X96 = 75541088972021055470308425728; //  encode_price_sqrt(100, 110)
    let sqrt_price_b_X96 = 83095197869223164535776477184; //  encode_price_sqrt(110, 100)

    let liquidity = get_liquidity_for_amounts(
        sqrt_price_X96, sqrt_price_a_X96, sqrt_price_b_X96, 100, 200
    );

    assert(liquidity == 2148, 'incorrect liquidity');
}

#[test]
fn test_get_liquidity_for_amounts_for_price_below() {
    let sqrt_price_X96 = 75162434512514376853788557312; //  encode_price_sqrt(99, 110)
    let sqrt_price_a_X96 = 75541088972021055470308425728; //  encode_price_sqrt(100, 110)
    let sqrt_price_b_X96 = 83095197869223164535776477184; //  encode_price_sqrt(110, 100)

    let liquidity = get_liquidity_for_amounts(
        sqrt_price_X96, sqrt_price_a_X96, sqrt_price_b_X96, 100, 200
    );

    assert(liquidity == 1048, 'incorrect liquidity');
}

#[test]
fn test_get_liquidity_for_amounts_for_price_above() {
    let sqrt_price_X96 = 83472048772503571108888313856; //  encode_price_sqrt(111, 100)
    let sqrt_price_a_X96 = 75541088972021055470308425728; //  encode_price_sqrt(100, 110)
    let sqrt_price_b_X96 = 83095197869223164535776477184; //  encode_price_sqrt(110, 100)

    let liquidity = get_liquidity_for_amounts(
        sqrt_price_X96, sqrt_price_a_X96, sqrt_price_b_X96, 100, 200
    );

    assert(liquidity == 2097, 'incorrect liquidity');
}

#[test]
fn test_get_liquidity_for_amounts_for_price_equal_to_lower_boundary() {
    let sqrt_price_X96 = 75541088972021055470308425728; //  encode_price_sqrt(100, 110)
    let sqrt_price_a_X96 = 75541088972021055470308425728; //  encode_price_sqrt(100, 110)
    let sqrt_price_b_X96 = 83095197869223164535776477184; //  encode_price_sqrt(110, 100)

    let liquidity = get_liquidity_for_amounts(
        sqrt_price_X96, sqrt_price_a_X96, sqrt_price_b_X96, 100, 200
    );

    assert(liquidity == 1048, 'incorrect liquidity');
}

#[test]
fn test_get_liquidity_for_amounts_for_price_equal_to_upper_boundary() {
    let sqrt_price_X96 = 83095197869223164535776477184; //  encode_price_sqrt(110, 100)
    let sqrt_price_a_X96 = 75541088972021055470308425728; //  encode_price_sqrt(100, 110)
    let sqrt_price_b_X96 = 83095197869223164535776477184; //  encode_price_sqrt(110, 100)

    let liquidity = get_liquidity_for_amounts(
        sqrt_price_X96, sqrt_price_a_X96, sqrt_price_b_X96, 100, 200
    );

    assert(liquidity == 2097, 'incorrect liquidity');
}

#[test]
fn test_get_amounts_for_liquidity_for_price_inside() {
    let sqrt_price_X96 = 79228162514264337593543950336; //  encode_price_sqrt(1, 1)
    let sqrt_price_a_X96 = 75541088972021055470308425728; //  encode_price_sqrt(100, 110)
    let sqrt_price_b_X96 = 83095197869223164535776477184; //  encode_price_sqrt(110, 100)

    let (amount0, amount1) = get_amounts_for_liquidity(
        sqrt_price_X96, sqrt_price_a_X96, sqrt_price_b_X96, 2148
    );

    assert(amount0 == 99, 'incorrect amount0');
    assert(amount1 == 99, 'incorrect amount1');
}

#[test]
fn test_get_amounts_for_liquidity_for_price_below() {
    let sqrt_price_X96 = 75162434512514376853788557312; //  encode_price_sqrt(99, 110)
    let sqrt_price_a_X96 = 75541088972021055470308425728; //  encode_price_sqrt(100, 110)
    let sqrt_price_b_X96 = 83095197869223164535776477184; //  encode_price_sqrt(110, 100)

    let (amount0, amount1) = get_amounts_for_liquidity(
        sqrt_price_X96, sqrt_price_a_X96, sqrt_price_b_X96, 1048
    );

    assert(amount0 == 99, 'incorrect amount0');
    assert(amount1 == 0, 'incorrect amount1');
}

#[test]
fn test_get_amounts_for_liquidity_for_price_above() {
    let sqrt_price_X96 = 83472048772503571108888313856; //  encode_price_sqrt(111, 100)
    let sqrt_price_a_X96 = 75541088972021055470308425728; //  encode_price_sqrt(100, 110)
    let sqrt_price_b_X96 = 83095197869223164535776477184; //  encode_price_sqrt(110, 100)

    let (amount0, amount1) = get_amounts_for_liquidity(
        sqrt_price_X96, sqrt_price_a_X96, sqrt_price_b_X96, 2097
    );

    assert(amount0 == 0, 'incorrect amount0');
    assert(amount1 == 199, 'incorrect amount1');
}

#[test]
fn test_get_amounts_for_liquidity_for_price_equal_to_lower_boundary() {
    let sqrt_price_X96 = 75541088972021055470308425728; //  encode_price_sqrt(100, 110)
    let sqrt_price_a_X96 = 75541088972021055470308425728; //  encode_price_sqrt(100, 110)
    let sqrt_price_b_X96 = 83095197869223164535776477184; //  encode_price_sqrt(110, 100)

    let (amount0, amount1) = get_amounts_for_liquidity(
        sqrt_price_X96, sqrt_price_a_X96, sqrt_price_b_X96, 1048
    );

    assert(amount0 == 99, 'incorrect amount0');
    assert(amount1 == 0, 'incorrect amount1');
}

#[test]
fn test_get_amounts_for_liquidity_for_price_equal_to_upper_boundary() {
    let sqrt_price_X96 = 83095197869223164535776477184; //  encode_price_sqrt(110, 100)
    let sqrt_price_a_X96 = 75541088972021055470308425728; //  encode_price_sqrt(100, 110)
    let sqrt_price_b_X96 = 83095197869223164535776477184; //  encode_price_sqrt(110, 100)

    let (amount0, amount1) = get_amounts_for_liquidity(
        sqrt_price_X96, sqrt_price_a_X96, sqrt_price_b_X96, 2097
    );

    assert(amount0 == 0, 'incorrect amount0');
    assert(amount1 == 199, 'incorrect amount1');
}
