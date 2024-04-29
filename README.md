
# Permissionless MEV Smoothing Pool

I believe it is possible to create a Permissionless MEV Smoothing Pool contract
with the introduction of [eip-4788](https://eips.ethereum.org/EIPS/eip-4788) and 
[eip4844](https://eips.ethereum.org/EIPS/eip-4844).

Eip-4788 allows us, to acess consensus information from the beacon chain through
the `beacon_block_root`. Thus, enabling us verification of the beacon state in the
EVM. We should be able to verify a validator, keep track of proposed blocks and 
the `fee_recipient`.  

There are still some challenges to keep up to date with relay registrations to 
build a fair system. Users can cheat the system if they change the `fee_recipient`.
Therefore, we should penalized them for it. The only problem is that we can only 
monitor that through the off-chan relay registrations API. One solution to that 
might be to add some relay registration data in the blobspace and verify it somehow
with the `beacon_block_root`.

Something else to have into consideration is the introduction of `MAX_EFFECTIVE_BALANCE` 
in [eip-7251](https://eips.ethereum.org/EIPS/eip-7251). This allows to have a validator
with more power having more than `32 ETH`. Therefore a validator with `64 ETH` 
should get a bigger share of rewards than a validator with `32 ETH`. Also, we are 
going to introduce a **pro-rata share distribution** in this system. 

## Requirements 
In order to verify some beacon state, we have to  submit a proof of the beacon 
state with the information we need to verify. 

1. We can do this by first querying the beacon API with: [getStateV2](https://ethereum.github.io/beacon-APIs/#/Debug/getStateV2).

2. Create a proof for the state of the validator against the block by concatenating
Gindices.

3. Verify proof on contract side using [eip-4788](https://eips.ethereum.org/EIPS/eip-4788)
precompile contract. The contract stores the `parent_beacon_block_root` at timestamp.
It is stored at `timestamp % HISTORY_BUFFER_LENGTH + HISTORY_BUFFER_LENGTH`.

Examples with timestamp `1713380903` at slot `8879740`.
```
// Getting the storage slot directly
curl -X POST --data '{"jsonrpc":"2.0", "method": "eth_getStorageAt", "params": ["0x000F3df6D732807Ef1319fB7B8bB8522d0Beac02", "0x0000000000000000000000000000000000000000000000000000000000002f40", "latest"], "id": 1}' $MAINNET_FORK
// Using call method
curl -X POST --data '{"jsonrpc":"2.0","method":"eth_call","params":[{"to": "0x000F3df6D732807Ef1319fB7B8bB8522d0Beac02", "input": "0x000000000000000000000000000000000000000000000000000000006620cf4b"}],"id":1}' $MAINNET_FORK
```

## Registration
In order to verify a validator we can verify the beacon state through the `beacon_block_root`.
```python
def is_active_validator(validator: Validator, epoch: Epoch) -> bool:
    """
    Check if ``validator`` is active.
    """
    return validator.activation_epoch <= epoch < validator.exit_epoch
```

Problem 1 **->** Someone can pass a proof of the state of a validator that is
valid and active. But how do we verify that the caller is the owner? 

1. We can do that through the withdrawals credentials. But then, the caller has
to have changed their withdrawals credentials to an eth1 address. 

2. For restaking users coming from eigen layer we could verify it by calling 
the withdrawal address(eigen  pod) and verify the owner of that contract with 
`EigenPodManager.sol::hasPod(msg.sender)`


## Slashing mechanism
Submitting fraud proofs is an idea for slashing someone that is missing slots or 
changing `fee_recipient`.

TODO

## Calculate rewards 
How to calculate rewards using a pro-rata based distribution and also take into 
account any misbehaviour of the validator. Ex: `fee_recipient` swap.

TODO 

## Generalized indices and Merkle Proofs

If we need to proof some information stored in the beacon block body. It's easy.
We just need to download the specific beacon block and get a proof for the value 
we want to prove. If we need to prove a value that is inside the beacon state, 
we need to submit a proof of that value in the beacon state against the beacon 
block. In order to do this we need to concatenate proof branches and find the correct
concatenated generalized index. 

### Generalized Merkle tree index 
In a binary Merkle tree, we define a "generalized index" of a node as 2 ** depth + index.
```
    1
 2     3
4 5   6 7
   ...
```
Note that the generalized index has the convenient property that the two children 
of node k are 2k and 2k+1.


