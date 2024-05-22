use core::to_byte_array::FormatAsByteArray;
use jediswap_v2_periphery::libraries::nft_descriptor::NFTDescriptor::{fee_to_string, symbol_to_string, get_token_uri};

#[test]
fn test_fee_to_string_for_100() {
    let fee: u32 = 100;
    let fee_string = fee_to_string(fee.into());
    println!("fee_string {}", fee_string);
    assert(fee_string == "0.01", 'Not 0.01');
}

#[test]
fn test_fee_to_string_for_500() {
    let fee: u32 = 500;
    let fee_string = fee_to_string(fee.into());
    println!("fee_string {}", fee_string);
    assert(fee_string == "0.05", 'Not 0.05');
}

#[test]
fn test_fee_to_string_for_3000() {
    let fee: u32 = 3000;
    let fee_string = fee_to_string(fee.into());
    println!("fee_string {}", fee_string);
    assert(fee_string == "0.3", 'Not 0.3');
}

#[test]
fn test_fee_to_string_for_10000() {
    let fee: u32 = 10000;
    let fee_string = fee_to_string(fee.into());
    println!("fee_string {}", fee_string);
    assert(fee_string == "1", 'Not 1');
}

#[test]
fn test_symbol_to_string_for_ETH() {
    let symbol = 'ETH';
    let symbol_string = symbol_to_string(symbol);
    println!("symbol_string {}", symbol_string);
    assert(symbol_string == "ETH", 'Not ETH');
}

#[test]
fn test_symbol_to_string_for_LORDS() {
    let symbol = 'LORDS';
    let symbol_string = symbol_to_string(symbol);
    println!("symbol_string {}", symbol_string);
    assert(symbol_string == "LORDS", 'Not LORDS');
}

#[test]
fn test_symbol_to_string_for_SymbolWithLower() {
    let symbol = 'SymbolWithLower';
    let symbol_string = symbol_to_string(symbol);
    println!("symbol_string {}", symbol_string);
    assert(symbol_string == "SymbolWithLower", 'Not SymbolWithLower');
}

#[test]
fn test_symbol_to_string_for_Symb0lW1thNumbers() {
    let symbol = 'Symb0lW1thNumbers';
    let symbol_string = symbol_to_string(symbol);
    println!("symbol_string {}", symbol_string);
    assert(symbol_string == "Symb0lW1thNumbers", 'Not Symb0lW1thNumbers');
}

#[test]
fn test_get_token_uri() {
    let token_uri = get_token_uri('TOKEN1', 'TOK2', 100);
    println!("token_uri {}", token_uri);
}
