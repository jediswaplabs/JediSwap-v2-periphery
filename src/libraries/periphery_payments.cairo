mod PeripheryPayments {
    use starknet::{ContractAddress, get_contract_address};
    use openzeppelin::token::erc20::interface::{
        IERC20Dispatcher, IERC20DispatcherTrait, IERC20CamelDispatcher, IERC20CamelDispatcherTrait
    };

    // @param token The token to pay
    // @param payer The entity that must pay
    // @param recipient The entity that will receive payment
    // @param value The amount to pay
    fn pay(
        token: ContractAddress, payer: ContractAddress, recipient: ContractAddress, value: u256
    ) {
        let token_dispatcher = IERC20Dispatcher { contract_address: token };
        let token_camel_dispatcher = IERC20CamelDispatcher { contract_address: token };
        if (payer == get_contract_address()) {
            // pay with tokens already in the contract (for the exact input multihop case)
            token_dispatcher.transfer(recipient, value);
        } else {
            // pull payment
            // token_dispatcher.transfer_from(payer, recipient, value); // TODO which transfer_from/transferFrom
            token_camel_dispatcher.transferFrom(payer, recipient, value);
        }
    }
}
