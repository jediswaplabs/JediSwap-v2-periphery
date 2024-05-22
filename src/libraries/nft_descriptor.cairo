mod NFTDescriptor {
    use starknet::{ContractAddress, get_caller_address};
    use jediswap_v2_core::jediswap_v2_factory::{
        IJediSwapV2FactoryDispatcher, IJediSwapV2FactoryDispatcherTrait
    };
    use jediswap_v2_periphery::jediswap_v2_nft_position_manager::PoolKey;
    use jediswap_v2_core::libraries::math_utils::pow;
    use integer::{u256_safe_div_rem};


    // @notice Appends the string representation of a number to an array
    // @param num_to_convert The number to convert
    // @param decimal Number of digits
    // @returns fee string
    fn fee_to_string(mut num_to_convert: u256) -> ByteArray{
        let mut fee_string: ByteArray = "";
        let mut decimal = 4;
        let before_decimal = num_to_convert / pow(10, decimal);
        let after_decimal = num_to_convert % pow(10, decimal);
        if (before_decimal > 0) {
            fee_string.append_byte(before_decimal.try_into().unwrap() + 48);
            loop {
                break true;
            };
        } else {
            fee_string.append_word('0.', 2)
        }
        num_to_convert = after_decimal;
        decimal -= 1;
        loop {
            if (decimal == 0 || num_to_convert == 0) {
                break true;
            }
            let q = num_to_convert / pow(10, decimal);
            let r = num_to_convert % pow(10, decimal);
            fee_string.append_byte(q.try_into().unwrap() + 48);
            num_to_convert = r;
            decimal -= 1;
        };
        fee_string
    }

    fn symbol_to_string(symbol: felt252) -> ByteArray {
        let mut temp_value: u256 = symbol.into();
        let mut index: u8 = 0;
        let mut symbol_string = "";
        loop {
            if (temp_value == 0) {
                break;
            }
            if (index >= 32) {
                break;
            }

            let (q, r) = u256_safe_div_rem(temp_value, 256);
            symbol_string.append_byte(r.low.try_into().unwrap());
            temp_value = q.low.into();
            index = index + 1;
        };
        symbol_string.rev()
    }

    // @notice Appends the string representation of a number to an array
    // @param content The array to append to
    // @param num_to_convert The number to convert
    // @param decimal Number of digits
    fn get_token_uri(token_0_symbol: felt252, token_1_symbol: felt252, pool_fee: u32) -> ByteArray {
        let name: ByteArray = "JediSwap V2 Position";
        let description: ByteArray = format!("This NFT represents liquidity position in a JediSwap V2 {}-{} {}% pool. The owner of this NFT can modify or redeem the position.", symbol_to_string(token_0_symbol), symbol_to_string(token_1_symbol), fee_to_string(pool_fee.into()));
        let image: ByteArray = "https://static.jediswap.xyz/V2NFT.png";
        let token_uri: ByteArray = format!("data:application/json;utf8,{{\"name\": \"{}\", \"description\": \"{}\", \"image\": \"{}\"}}", name, description, image);
        token_uri
        // content.append(' Deposit Amounts: ');
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
    }
}
