use jediswap_v2_periphery::libraries::nft_descriptor::NFTDescriptor::fee_to_string;
use snforge_std::PrintTrait;

#[test]
fn test_fee_to_string_for_100() {
    let mut content = array![];
    let fee: u32 = 100;
    fee_to_string(ref content, fee.into());
    content.print();
    assert(content == array!['0.', '0', '1'], 'Not 0.01');
}

#[test]
fn test_fee_to_string_for_500() {
    let mut content = array![];
    let fee: u32 = 500;
    fee_to_string(ref content, fee.into());
    content.print();
    assert(content == array!['0.', '0', '5'], 'Not 0.05');
}

#[test]
fn test_fee_to_string_for_3000() {
    let mut content = array![];
    let fee: u32 = 3000;
    fee_to_string(ref content, fee.into());
    content.print();
    assert(content == array!['0.', '3'], 'Not 0.3');
}

#[test]
fn test_fee_to_string_for_10000() {
    let mut content = array![];
    let fee: u32 = 10000;
    fee_to_string(ref content, fee.into());
    content.print();
    assert(content == array!['1'], 'Not 1');
}
