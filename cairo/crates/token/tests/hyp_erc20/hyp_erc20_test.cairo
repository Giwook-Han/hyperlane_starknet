use alexandria_bytes::BytesTrait;
use contracts::hooks::libs::standard_hook_metadata::standard_hook_metadata::VARIANT;
use mocks::test_interchain_gas_payment::ITestInterchainGasPaymentDispatcherTrait;
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use snforge_std::{
    CheatSpan, ContractClass, ContractClassTrait, DeclareResultTrait, cheat_caller_address,
};
use super::common::{
    ALICE, BOB, DECIMALS, E18, GAS_LIMIT, IHypERC20TestDispatcherTrait, ORIGIN, REQUIRED_VALUE,
    TOTAL_SUPPLY, TRANSFER_AMT, enroll_local_router, enroll_remote_router, perform_remote_transfer,
    perform_remote_transfer_and_gas, set_custom_gas_config, setup,
    test_transfer_with_hook_specified,
};

#[test]
fn test_erc20_total_supply() {
    let setup = setup();
    let erc20_token = setup.local_token;
    let total_supply = erc20_token.total_supply();
    assert_eq!(total_supply, TOTAL_SUPPLY);
}

#[test]
fn test_erc20_decimals() {
    let setup = setup();
    let erc20_token = setup.local_token;
    let decimals = erc20_token.decimals();
    assert_eq!(decimals, DECIMALS);
}

#[test]
fn test_erc20_local_transfer() {
    let setup = setup();
    let erc20_token = setup.local_token;
    let alice = erc20_token.balance_of(ALICE());
    let bob = erc20_token.balance_of(BOB());
    assert_eq!(alice, 1000 * E18);
    assert_eq!(bob, 0);

    cheat_caller_address((setup).local_token.contract_address, ALICE(), CheatSpan::TargetCalls(1));

    erc20_token.transfer(BOB(), 100 * E18);

    let alice = erc20_token.balance_of(ALICE());
    let bob = erc20_token.balance_of(BOB());
    assert_eq!(alice, 900 * E18);
    assert_eq!(bob, 100 * E18);
}

#[test]
fn test_erc20_remote_transfer() {
    let setup = setup();
    let erc20_token = setup.local_token;
    enroll_remote_router(@setup);
    enroll_local_router(@setup);

    let local_token_address: felt252 = setup.local_token.contract_address.into();
    setup.remote_token.enroll_remote_router(ORIGIN, local_token_address.into());

    let balance_before = erc20_token.balance_of(ALICE());
    perform_remote_transfer_and_gas(@setup, REQUIRED_VALUE, TRANSFER_AMT, 0);
    let balance_after = erc20_token.balance_of(ALICE());
    assert_eq!(balance_after, balance_before - TRANSFER_AMT);
}

#[test]
#[should_panic]
fn test_erc20_remote_transfer_invalid_amount() {
    let setup = setup();

    perform_remote_transfer(@setup, REQUIRED_VALUE, TRANSFER_AMT * 11);
}

#[test]
fn test_erc20_remote_transfer_with_custom_gas_config() {
    let setup = setup();
    let erc20_token = setup.local_token;
    enroll_remote_router(@setup);
    enroll_local_router(@setup);

    let local_token_address: felt252 = setup.local_token.contract_address.into();
    setup.remote_token.enroll_remote_router(ORIGIN, local_token_address.into());

    set_custom_gas_config(@setup);

    let gas_price = setup.igp.gas_price();
    let balance_before = erc20_token.balance_of(ALICE());
    perform_remote_transfer_and_gas(@setup, REQUIRED_VALUE, TRANSFER_AMT, GAS_LIMIT * gas_price);
    let balance_after = erc20_token.balance_of(ALICE());
    assert_eq!(balance_after, balance_before - TRANSFER_AMT);
    let eth_dispatcher = IERC20Dispatcher { contract_address: setup.eth_token.contract_address };
    assert_eq!(
        eth_dispatcher.balance_of(setup.igp.contract_address),
        GAS_LIMIT * gas_price,
        "Gas fee didnt transferred",
    );
}

#[test]
#[fuzzer]
fn test_fuzz_erc20_remote_transfer_with_hook_specified(mut fee: u256, metadata: u256) {
    let fee = fee % (TRANSFER_AMT / 10);
    let mut metadata_bytes = BytesTrait::new_empty();
    metadata_bytes.append_u16(VARIANT);
    metadata_bytes.append_u256(metadata);
    let setup = setup();
    let erc20_token = setup.local_token;
    enroll_remote_router(@setup);
    enroll_local_router(@setup);

    let local_token_address: felt252 = setup.local_token.contract_address.into();
    setup.remote_token.enroll_remote_router(ORIGIN, local_token_address.into());

    let balance_before = erc20_token.balance_of(ALICE());
    test_transfer_with_hook_specified(@setup, fee, metadata_bytes);
    let balance_after = erc20_token.balance_of(ALICE());
    assert_eq!(balance_after, balance_before - TRANSFER_AMT);
}
