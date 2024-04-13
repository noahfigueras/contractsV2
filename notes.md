
# Permissionless MEV Smoothing Pool

I believe we can successfully create a Permissionless MEV Smoothing Pool contract
with the introduction of [eip-4788](https://eips.ethereum.org/EIPS/eip-4788) and 
[eip4844](https://eips.ethereum.org/EIPS/eip-4844).

Eip-4788 allows us, to acess consensus information from the beacon chain through
the `beacon_block_root`. Thus, enabling us verification of the beacon state in the
EVM. We should be able to verify a validator, keep track of proposed blocks and 
the `fee_recipient`. Thus, enabling us verification of the beacon state in the
EVM. We should be able to verify a validator, keep track of proposed blocks and 
it's `fee_recipient`. 

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

We can do this by first querying the beacon API with: [getStateV2](https://ethereum.github.io/beacon-APIs/#/Debug/getStateV2).


## Registration
In order to verify a validator we can verify the beacon state through the `beacon_block_root`.
```python
def is_active_validator(validator: Validator, epoch: Epoch) -> bool:
    """
    Check if ``validator`` is active.
    """
    return validator.activation_epoch <= epoch < validator.exit_epoch
```

## Slashing mechanism
Submitting fraud proofs is an idea for slashing someone that is missing slots or 
changing `fee_recipient`.




