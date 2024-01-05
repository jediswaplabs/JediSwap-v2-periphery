use jediswap_v2_periphery::libraries::liquidity_amounts::LiquidityAmounts::{get_liquidity_for_amounts, get_amounts_for_liquidity};
use yas_core::utils::math_utils::{pow};
use snforge_std::PrintTrait;


// def encode_price_sqrt(a, b): 
//      return int(math.sqrt(a/b) * (2**96))

#[test]
fn test_get_liquidity_for_amounts_for_price_inside() {
    let sqrt_price_X96 = 79228162514264337593543950336; //  encode_price_sqrt(1, 1)
    let sqrt_price_a_X96 = 75541088972021055470308425728; //  encode_price_sqrt(100, 110)
    let sqrt_price_b_X96 = 83095197869223164535776477184; //  encode_price_sqrt(110, 100)

    let liquidity = get_liquidity_for_amounts(sqrt_price_X96, sqrt_price_a_X96, sqrt_price_b_X96, 100, 200);

    assert(liquidity == 2148, 'incorrect liquidity');
}

#[test]
fn test_get_liquidity_for_amounts_for_price_below() {
    let sqrt_price_X96 = 75162434512514376853788557312; //  encode_price_sqrt(99, 110)
    let sqrt_price_a_X96 = 75541088972021055470308425728; //  encode_price_sqrt(100, 110)
    let sqrt_price_b_X96 = 83095197869223164535776477184; //  encode_price_sqrt(110, 100)

    let liquidity = get_liquidity_for_amounts(sqrt_price_X96, sqrt_price_a_X96, sqrt_price_b_X96, 100, 200);

    assert(liquidity == 1048, 'incorrect liquidity');
}

#[test]
fn test_get_liquidity_for_amounts_for_price_above() {
    let sqrt_price_X96 = 83472048772503571108888313856; //  encode_price_sqrt(111, 100)
    let sqrt_price_a_X96 = 75541088972021055470308425728; //  encode_price_sqrt(100, 110)
    let sqrt_price_b_X96 = 83095197869223164535776477184; //  encode_price_sqrt(110, 100)

    let liquidity = get_liquidity_for_amounts(sqrt_price_X96, sqrt_price_a_X96, sqrt_price_b_X96, 100, 200);

    assert(liquidity == 2097, 'incorrect liquidity');
}

#[test]
fn test_get_liquidity_for_amounts_for_price_equal_to_lower_boundary() {
    let sqrt_price_X96 = 75541088972021055470308425728; //  encode_price_sqrt(100, 110)
    let sqrt_price_a_X96 = 75541088972021055470308425728; //  encode_price_sqrt(100, 110)
    let sqrt_price_b_X96 = 83095197869223164535776477184; //  encode_price_sqrt(110, 100)

    let liquidity = get_liquidity_for_amounts(sqrt_price_X96, sqrt_price_a_X96, sqrt_price_b_X96, 100, 200);

    assert(liquidity == 1048, 'incorrect liquidity');
}

#[test]
fn test_get_liquidity_for_amounts_for_price_equal_to_upper_boundary() {
    let sqrt_price_X96 = 83095197869223164535776477184; //  encode_price_sqrt(110, 100)
    let sqrt_price_a_X96 = 75541088972021055470308425728; //  encode_price_sqrt(100, 110)
    let sqrt_price_b_X96 = 83095197869223164535776477184; //  encode_price_sqrt(110, 100)

    let liquidity = get_liquidity_for_amounts(sqrt_price_X96, sqrt_price_a_X96, sqrt_price_b_X96, 100, 200);

    assert(liquidity == 2097, 'incorrect liquidity');
}

#[test]
fn test_get_amounts_for_liquidity_for_price_inside() {
    let sqrt_price_X96 = 79228162514264337593543950336; //  encode_price_sqrt(1, 1)
    let sqrt_price_a_X96 = 75541088972021055470308425728; //  encode_price_sqrt(100, 110)
    let sqrt_price_b_X96 = 83095197869223164535776477184; //  encode_price_sqrt(110, 100)

    let (amount0, amount1) = get_amounts_for_liquidity(sqrt_price_X96, sqrt_price_a_X96, sqrt_price_b_X96, 2148);

    assert(amount0 == 99, 'incorrect amount0');
    assert(amount1 == 99, 'incorrect amount1');
}

#[test]
fn test_get_amounts_for_liquidity_for_price_below() {
    let sqrt_price_X96 = 75162434512514376853788557312; //  encode_price_sqrt(99, 110)
    let sqrt_price_a_X96 = 75541088972021055470308425728; //  encode_price_sqrt(100, 110)
    let sqrt_price_b_X96 = 83095197869223164535776477184; //  encode_price_sqrt(110, 100)

    let (amount0, amount1) = get_amounts_for_liquidity(sqrt_price_X96, sqrt_price_a_X96, sqrt_price_b_X96, 1048);

    assert(amount0 == 99, 'incorrect amount0');
    assert(amount1 == 0, 'incorrect amount1');
}

#[test]
fn test_get_amounts_for_liquidity_for_price_above() {
    let sqrt_price_X96 = 83472048772503571108888313856; //  encode_price_sqrt(111, 100)
    let sqrt_price_a_X96 = 75541088972021055470308425728; //  encode_price_sqrt(100, 110)
    let sqrt_price_b_X96 = 83095197869223164535776477184; //  encode_price_sqrt(110, 100)

    let (amount0, amount1) = get_amounts_for_liquidity(sqrt_price_X96, sqrt_price_a_X96, sqrt_price_b_X96, 2097);

    assert(amount0 == 0, 'incorrect amount0');
    assert(amount1 == 199, 'incorrect amount1');
}

#[test]
fn test_get_amounts_for_liquidity_for_price_equal_to_lower_boundary() {
    let sqrt_price_X96 = 75541088972021055470308425728; //  encode_price_sqrt(100, 110)
    let sqrt_price_a_X96 = 75541088972021055470308425728; //  encode_price_sqrt(100, 110)
    let sqrt_price_b_X96 = 83095197869223164535776477184; //  encode_price_sqrt(110, 100)

    let (amount0, amount1) = get_amounts_for_liquidity(sqrt_price_X96, sqrt_price_a_X96, sqrt_price_b_X96, 1048);

    assert(amount0 == 99, 'incorrect amount0');
    assert(amount1 == 0, 'incorrect amount1');
}

#[test]
fn test_get_amounts_for_liquidity_for_price_equal_to_upper_boundary() {
    let sqrt_price_X96 = 83095197869223164535776477184; //  encode_price_sqrt(110, 100)
    let sqrt_price_a_X96 = 75541088972021055470308425728; //  encode_price_sqrt(100, 110)
    let sqrt_price_b_X96 = 83095197869223164535776477184; //  encode_price_sqrt(110, 100)

    let (amount0, amount1) = get_amounts_for_liquidity(sqrt_price_X96, sqrt_price_a_X96, sqrt_price_b_X96, 2097);

    assert(amount0 == 0, 'incorrect amount0');
    assert(amount1 == 199, 'incorrect amount1');
}

// #[test]
// fn test_string() {
//     let mut content = array![];
//     let fee_u: u32 = 100000;
//     let mut to_convert_to_string = fee_u.into();
//     let mut decimal = 4;
//     content.append('Hello ');
//     let before_decimal = to_convert_to_string / pow(10, decimal);
//     let after_decimal = to_convert_to_string % pow(10, decimal);
//     if (before_decimal > 0) {
//         Serde::serialize(@before_decimal.low, ref content);
//         loop {
//             break true;
//         };
//     } else {
//         content.append('0.')
//     }
//     to_convert_to_string = after_decimal;
//     decimal -= 1;
//     loop {
//         if (decimal == 0 || to_convert_to_string == 0) {
//             break true;
//         }
//         let q = to_convert_to_string / pow(10, decimal);
//         let r = to_convert_to_string % pow(10, decimal);
//         Serde::serialize(@q.low, ref content);
//         to_convert_to_string = r;
//         decimal -= 1;
//     };
//     content.print();
//     assert(false, 'false');
// }