mod PeripheryPayments {

    use starknet::{ContractAddress, get_contract_address};
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};

    // @notice Returns the address of a valid JediSwap V2 Pool
    // @param factory The contract address of the JediSwap V2 factory
    // @param token_a The contract address of either token0 or token1
    // @param token_b The contract address of the other token
    // @param fee The fee collected upon every swap in the pool, denominated in hundredths of a bip
    // @return The V2 pool contract address
    fn pay(token: ContractAddress, payer: ContractAddress, recipient: ContractAddress, value: u256) {
        let token_dispatcher = IERC20Dispatcher { contract_address: token };
        if (payer == get_contract_address()) {
            // pay with tokens already in the contract (for the exact input multihop case)
            token_dispatcher.transfer(recipient, value);
        } else {
            // pull payment
            token_dispatcher.transfer_from(payer, recipient, value); // TODO which transfer_from
        }
    }
}