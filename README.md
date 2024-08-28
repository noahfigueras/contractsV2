# Permissionless MEV Smoothing Pool

I believe it is possible to create a Permissionless MEV Smoothing Pool contract
with the introduction of [eip-4788](https://eips.ethereum.org/EIPS/eip-4788).

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

## Steps 
1. User proofs that he's the owner of the validator. -> Registration 

2. Validator can claim rewards only when a block is proposed. The rewards will be 
calculated using a pro-rata share distribution using time and EB (staking power). 
Time starts from day of registration and resets every time validator claims rewards. 

3. Slashing of deactivation happens through a fraud proof, proving that a specific
validator has proposed a block with an incorrect `fee_recipient`. This gives x%
of the rewards to the observer submitting the fraud proof. The rest goes back to 
the pool. Or there's the option to add a bond on registration and use that as a 
reward for the observer. 
To proof this we need to submit and verify a merkle-multi-proof. Proving the: 
`fee_recipient, slot timestamp and validator index` of that specific slot. There's a time 
barrier regarding the verification of the block as the beacon block root contract
only gives around 1 day worth of the latest block roots. 

To remove that barrier we'll have to submit a multi-proof concatenating (beaconBlock with beaconState) to retrieve
a past root hash. beaconBlock -> beaconState -> historicalRoots[beaconBlockRootToProof]
The issue here is that it takes a while to retrieve the beaconState (2-3 min) to 
query. Also the proofs take a while as it's a lot of compute. 

Note: Not sure if we should add Missed Proposals into the slashing scenario. Every
second missed slot they lose rewards ?? 
* How do I actually prove that a validator missed a slot?
Exemple: Slot 9312424 was missed by Validator index 692834. 

To verify that a validator missed a slot  we'll need to compute [get_beacon_proposer_index()](https://github.com/ethereum/consensus-specs/blob/dev/specs/phase0/beacon-chain.md#get_beacon_proposer_index)
inside the contract. 

4. Validator exits pool. Gets rewards and bond back if there is.

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

valid and active. But how do we verify that the caller is the owner? 

1. We can do that through the withdrawals credentials. But then, the caller has
to have changed their withdrawals credentials to an eth1 address. 

2. For restaking users coming from eigen layer we could verify it by calling 
the withdrawal address(eigen  pod) and verify the owner of that contract with 
`EigenPodManager.sol::hasPodg.sender)`

## Slashing mechanism
Submitting fraud proofs is an idea for slashing someone that is missing slots or 
changing `fee_recipient`.

We can only verify a change of `fee_recipient` if the validator proposes a block
with the incorrect `fee_recipient` (one that is not the pool's address). This 
can be verified sending a proof. 



## Calculate rewards 

In order to calculate rewards using a pro-rata based distribution, we need to 
keep track of the time a user is been actively participating in the pool and 
allocate him rewards based on timestamp and the EB provided by his validator. 

For that, we define a constant `REBALANCE_PERIOD = 86400 * 7` (7 days) that specifies 
the duration of a rebalance period. We can calculate the rewards using 
the user claimable timestamp (updates after share is claimed) and EB against the 
`lastRebalance` period timestamp. 

In order to take into account other pool participants shares, we introduce two 
variables to keep track of the totalSupply: 
* `totalEB` keeps track of the total EB of the participants in the pool.
* `smooths` keeps track of the total share of participants in the pool to be distributed.

```
USER_SHARE = (lastRebalance - claimableTimestamp) * EB;
USER_ETH_SHARE = (SHARE / smooths) * TOTAL_POOL_BALANCE;
```

Let's look at the following example:
```
USER1 = {registrationTimestamp: 0, EB: 32 } // First day
USER2 = {registrationTimestamp: 86400 * 3, EB: 64 } // Third day
USER3 = {registrationTimestamp: 86400 * 6, EB: 32 } // Sixth day

// After 1 rebalance of 7 days, participants try to claim their share.
TOTAL_POOL_BALANCE = 1 ETH;
LAST_REBALANCE = 86400 * 7 // 7 DAYS;

SMOOTHS = (86400 * 7 * 32 + 86400 * 4 * 64 + 86400 * 32 ) // 44236800

USER1_SHARE = (604800 - 0) * 32;
USER1_ETH = (USER1_SHARE / SMOOTHS) * TOTAL_POOL_BALANCE; // 0.4375 ETH

USER2_SHARE = (604800 - 86400 * 3) * 64;
USER2_ETH = (USER1_SHARE / SMOOTHS) * TOTAL_POOL_BALANCE; // 0.5 ETH

USER3_SHARE = (604800 - 86400 * 6) * 32;
USER3_ETH = (USER1_SHARE / SMOOTHS) * TOTAL_POOL_BALANCE; // 0.0625 ETH
```

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


