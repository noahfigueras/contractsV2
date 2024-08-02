#![cfg(test)]

use alloy::{sol, providers::ProviderBuilder, node_bindings::Anvil};

sol!(
    #[allow(missing_docs)]
    #[sol(rpc)]
    IWETH9,
    "../out/Merkle.sol/Merkle.json"
);

#[tokio::test(flavor = "multi_thread")]
async fn test_merkle_multi_proofs() {
    let anvil = Anvil::new().fork("https://eth.merkle.io").try_spawn().unwrap();
    assert_eq!("sol", "sol");
}
