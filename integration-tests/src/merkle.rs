#![cfg(test)]

use crate::consensus_types::BeaconBlock;
use ssz_rs::prelude::*;
use serde_json::{ from_str, Value };
use std::fs;
use alloy::{
    sol,
    providers::ProviderBuilder,
    node_bindings::Anvil,
    network::EthereumWallet,
    signers::local::PrivateKeySigner,
    primitives::{
        U256,
        Address
    }
};

sol!(
    #[allow(missing_docs)]
    #[sol(rpc)]
    BeaconOracle,
    "../out/BeaconOracle.sol/BeaconOracle.json"
);

#[tokio::test(flavor = "multi_thread")]
async fn test_merkle_multi_proofs() {
    /*
    let anvil = Anvil::new().fork("https://eth.merkle.io@20107024").try_spawn().unwrap();

    let signer: PrivateKeySigner = anvil.keys()[0].clone().into();
    let wallet = EthereumWallet::from(signer);

    let rpc_url = anvil.endpoint().parse().unwrap();
    let provider =
        ProviderBuilder::new().with_recommended_fillers().wallet(wallet).on_http(rpc_url);
    */

    let file = fs::read_to_string("data/block.json").unwrap();
    let json: Value = from_str(file.as_str()).unwrap();

    let block: BeaconBlock = BeaconBlock::from_json(&json);
    let (proof, witness) = block.multi_prove(&[
        &["proposer_index".into()],
        &["body".into(), "execution_payload".into(), "fee_recipient".into()],
        &["body".into(), "execution_payload".into(), "transactions".into(), 0.into()]
    ]).unwrap();
    assert!(proof.verify(witness).is_ok());
    dbg!(&proof);

    /*
    let contract = BeaconOracle::deploy(&provider).await.unwrap();
    println!("Contract deployed at address: {}", contract.address());

    let builder = contract.verifyFeeRecipient(
        proof.indices.iter().map(|x| U256::from(*x)).collect(),
        proof.branch,
        U256::from(block.proposer_index),
        Address::from_slice(&block.body.execution_payload.fee_recipient),
        block.body.execution_payload.timestamp,
        1718573135 as u64
    );

    let res = builder.call().await.unwrap()._0;
    assert_eq!(res, true);*/
}
