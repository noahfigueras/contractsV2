Author: Noah Figueras 
github: github.com/noahfigueras

# A Permissionless MEV Smoothing Pool

## Introduction
Existing implementations of MEV Smoothing Pools often rely on external oracles 
to feed data into smart contracts. While these oracles are operated by trusted 
entities, this trust introduces vulnerabilities. If an oracle is compromised, 
it could lead to a breakdown in the system’s security, casting doubt on its 
reliability. Moreover, maintaining oracles requires significant infrastructure, 
which makes these systems expensive to operate. This, in turn, leads to user fees, 
increasing the overall cost of participation.

Until recently, this reliance on oracles was necessary because there was no way 
to monitor the beacon chain state directly on-chain. However, with the introduction 
of [EIP-4788](https://eips.ethereum.org/EIPS/eip-4788) as part of the Ethereum 
Dencun upgrade, this limitation has been addressed.

EIP-4788 enables access to consensus information from the beacon chain via the 
`beacon_block_root`, allowing smart contracts in the Ethereum Virtual Machine (EVM) 
to verify the beacon state through Merkle proofs. This advancement opens the door 
to a truly permissionless MEV Smoothing Pool.

I propose a permissionless MEV Smoothing Pool implemented as a smart contract on 
Ethereum, where the contract itself acts as the `fee_recipient` for all validators 
who choose to register. Once deployed, the smoothing pool is designed to operate entirely 
on its own, governed by transparent, on-chain logic without any centralized control.

The pooling of MEV rewards across multiple validators maximizes the potential 
returns by aggregating MEV opportunities that would otherwise be captured individually. 
By doing so, it creates a more predictable and stable revenue stream for participants. 
Validators who join the pool contribute their MEV rewards, and at regular intervals, 
the pool fairly distributes these rewards among participants based on a pro-rata 
share of their contributions.

This decentralized structure ensures that the distribution process is not only 
efficient but also fair, with no single entity having the ability to manipulate 
the rewards. All participants benefit equally based on their share of contributions, 
fostering a cooperative and trustless environment. Furthermore, by eliminating 
the costs associated with external infrastructure like oracles, this approach 
reduces overhead, making it a cost-effective solution that avoids unnecessary user fees.

## Design

In order to accomplish this, we need to be able to perform the following actions 
on-chain. 

1. Verification of an active validator on the beacon chain.
2. Verification of a block proposed by a validator and its `fee_recipient`.
3. Accounting for distribution of rewards based on active time and effective balance.
4. Slashing mechanism to punish bad actors, mostly due to changing their `fee_recipient`. 
5. Optionally there should be a mechanism to monitor missed proposals and punish
a node that is not active accordingly. But, this needs further research to be 
doable on-chain. Although this would make a better pool, it's not really necessary
to create a fair `smoothing pool`.

A proposed flow will be the following.

1. Validator changes his `fee_recipient` to the `smoothing pool` contract.
2. Validator registers to the protocol with a stake fee.
3. Validator proposes a block.
4. Validator can claim a withdrawal submitting a proof of the latest block proposed with
the `fee_recipient`.

Therefore a user that joins the pool, will have to propose a block with 
the `fee_recipient` set to the pool address in order to claim rewards.

Note that there's a `stake fee` to join the pool, this is set in place to penalize
a validator that proposes a block with the incorrect `fee_recipient`. Preventing 
users to trick the protocol. [See](##Slashing)

### Verify a validator
To register in the pool and start earning rewards, a user must prove on-chain 
ownership of a validator.

With EIP-4788, we can achieve this by submitting a Merkle proof of the validator’s 
inclusion in the `BeaconState`. The process involves:

1. **Validator Index Proof** – Confirming that the validator exists in the beacon state.

2. **Active Status Check** – Ensuring the validator is currently active.

3. **Ownership Verification** – Matching the validator’s `withdrawal_credentials` 
with `msg.sender`.

**Validator Structure**

```python
class Validator(Container):
    pubkey: BLSPubkey
    withdrawal_credentials: Bytes32  # Commitment to pubkey for withdrawals
    effective_balance: Gwei  # Balance at stake
    slashed: boolean
    # Status epochs
    activation_eligibility_epoch: Epoch  # When criteria for activation were met
    activation_epoch: Epoch
    exit_epoch: Epoch
    withdrawable_epoch: Epoch  # When validator can withdraw funds
```
```python
def is_active_validator(validator: Validator, epoch: Epoch) -> bool:
    """
    Check if ``validator`` is active.
    """
    return validator.activation_epoch <= epoch < validator.exit_epoch
```

**Ownership Verification**

A validator can register only if their `withdrawal_credentials` point to an 
Ethereum `Eth1` address. However, this does not necessarily ensure compatibility 
with restaking protocols.

For EigenLayer users, we could verify ownership by calling `EigenPodManager.sol::hasPod(msg.sender)`, 
confirming that `msg.sender` controls the `EigenPod`.

Alternatively, we could use `BLS` signature verification, where the validator 
signs a transaction with their BLS private key. On-chain verification would then 
check the signature against the validator’s `pubkey`, though this would require 
a secure and efficient on-chain BLS verification library in `solidity`.

**Proof Submission Path**

```
beacon_block_root → beacon_state_root → validators[validator_index] 
```

A validator proves their existence in the `BeaconState` by submitting a Merkle 
proof from the `beacon_block_root` to their `validator_index`.

### Verify validator blocks.
 **NOTE**: This current setup only works for vanilla validator blocks (i.e., 
 blocks built directly by the validator without `mev-boost`). Builders modify 
 the `fee_recipient` in the `BeaconBlockBody`, making verification more complex. 
 A standardized approach among builders is needed to ensure compatibility.
 [see](###Security Considerations)

Ensuring that a validator is consistently using the smoothing pool’s `fee_recipient`
address is crucial for maintaining a fair distribution of rewards. Since rewards from MEV 
and priority fees are routed through the `fee_recipient`, verifying that validators 
do not redirect funds elsewhere is key to preventing malicious behavior.

**Importance of Block Verification**

A validator could change its `fee_recipient` at any time, redirecting MEV rewards 
outside of the pool. On-chain verification ensures this does not happen without 
a penalty.

Users will only be able to claim their accrued rewards after their validator 
proposes a block. By enforcing this we could verify that the `fee_recipient` in 
that block is pointing to the pool address. This system mitigates attacks where a 
validator tries to extract MEV unfairly. Validators must submit a Merkle proof 
of their latest `BeaconBlock` to verify their `fee_recipient` in order to 
claim rewards.

**Proof Submission Path**

To verify the `fee_recipient`, two possible proof paths exist:

1. **Short-Term Proofs (~24 Hours Validity)**
```
beacon_block_root → body_root → execution_payload → fee_recipient 
```
This approach relies on `EIP-4788`, which only stores `beacon_block_root` history 
for one day. Proofs must be submitted within 24 hours, making it less flexible.

2. **Long-Term Proofs (~26,131 Years Validity)**
```
beacon_block_root → beacon_state_root → historical_roots[slot_index] → body_root → execution_payload → fee_recipient 
 
```
This path utilizes `historical_roots`, storing a much longer proof history. 
However, generating these proofs may be computationally challenging.


### Reward Distribution
Rewards are distributed based on a **pro-rata share model**, which considers both 
a validator's **effective balance (EB)** and the **time actively contributing** 
to the pool. This ensures that validators who contribute longer and with a higher 
stake receive a fairer share of the rewards.

#### Tracking Contributions
Each validator's rewards are calculated based on:

1. **Time in the pool**: Starts from the validator's registration time and resets 
upon claiming rewards.

2. **Effective Balance (EB)**: The validator's stake to account for `MAX_EB`.

3. **Total Pool Participation**: The sum of all active validators' contributions over 
time.

To fairly distribute rewards, we define a **Rebalancing Period**:

* `REBALANCE_PERIOD = 21 days (1,814,400 seconds)` (This could be changed)
* At the end of each period, the accumulated rewards are distributed proportionally.

To account for the total pool participation, we maintain:

* `totalEB`: The total **effective balance** of all participating validators.
* `smooths`: A cumulative metric that tracks **weighted participation over time**.


#### Reward Calculation Example (21-Day Rebalance Period)

#### Formula
The rewards are calculated based on **Effective Balance (EB)** and **Time Contributed (TC)** within the 21-day period.

```
USER_SHARE = (lastRebalanceTimestamp - userTimeContributed) * EB
smooths = SUM(USER_SHARE for all users)
USER_ETH_SHARE = (USER_SHARE / smooths) * TOTAL_POOL_BALANCE
```

Where:
- `USER_SHARE` = Contribution based on time and EB.
- `USER_ETH_SHARE` = User's proportional ETH rewards.
- `smooths` = Sum of all `USER_SHARE` values across validators.
- `TOTAL_POOL_BALANCE` = The total ETH rewards collected for that period.


---

#### Example Calculation
- **Rebalance period**: **21 days** (604800 * 3 = 1814400 seconds)
- **Total Pool Rewards**: **1 ETH**
- **Users and their registration timestamps:**

| User  | Registration Day | EB  | Time Contributed (sec) | User Share  | ETH Share |
|-------|-----------------|----|---------------------|------------|----------|
| **U1** | Day 1          | 32 | 1,814,400          | $\( 1,814,400 \times 32 \)$ | **0.3889 ETH** |
| **U2** | Day 5          | 64 | 1,468,800          | $\( 1,468,800 \times 64 \)$ | **0.4630 ETH** |
| **U3** | Day 10         | 32 | 1,209,600          | $\( 1,209,600 \times 32 \)$ | **0.1915 ETH** |
| **U4** | Day 15         | 32 | 950,400            | $\( 950,400 \times 32 \)$  | **0.1505 ETH** |
| **U5** | Day 18         | 64 | 691,200            | $\( 691,200 \times 64 \)$  | **0.3028 ETH** |

#### Total Smooths Calculation
$\text{smooths} = (1814400 \times 32) + (1468800 \times 64) + (1209600 \times 32) + (950400 \times 32) + (691200 \times 64)$
$\text{smooths} = 58,060,800 + 94,003,200 + 38,707,200 + 30,412,800 + 44,236,800 = 265,420,800$

---

Proposing a block will enable a validator to claim their accrued rewards. On 
whithdrawal, their contribution is removed from smooths to maintain accurate 
distribution.

#### Key Takeaways 
- **Users who join earlier receive a higher share of rewards** since their **Time Contributed (TC)** is higher.
- **Higher EB (Effective Balance) validators** receive more rewards since they contribute more security.
- **Rebalance period impacts reward distribution**—longer periods favor early joiners.

---

### Slashing

To maintain a **permissionless** and **trust-minimized** staking system, validators 
must stake **collateral ETH** to ensure honest participation. This stake serves 
as an **economic deterrent** against malicious actions.

A proposed stake amount is **0.3 ETH**, which should be greater than the average 
MEV reward per block. This ensures that dishonest behavior is penalized.

#### Conditions for Slashing
A validator can be penalized under the following condition:

**Fee Recipient Manipulation (Critical Misbehavior)**
* Each validator must set their `fee_recipient` address to the **pool contract 
address** to ensure fair distribution of rewards.

* If a validator **modifies their** `fee_recipient` **to any other address**, before
exiting the pool, they will be **immediately penalized**, losing their **entire 0.3 ETH 
stake** and **exiting the pool**.

* This prevents validators from **stealing MEV and priority fees** meant for the 
pool participants.

#### Missed Proposals (Future Consideration)
Ideally, validators who **miss their block proposals** should also be **penalized**
to prevent inactivity that harms the pool. However, there is currently **no easy 
on-chain mechanism** to track missed proposals **without additional infrastructure**. 
This remains an area for **future research**.


#### On-Chain Fraud Proofs
To ensure **trustless enforcement**, slashing must be provable on-chain via fraud 
proofs.

* Any user can submit a **Merkle proof** of a **block proposed** by a validator 
with `validator_index = x`, showing that the `fee_recipient` was **set to an 
unauthorized address**.

* This proof serves as **verifiable evidence** that the validator **violated the 
protocol**, triggering automatic slashing.

**Slasher Incentives**   
To encourage participation in fraud-proof submission, a **Slasher Role** is 
introduced:

1. **Slasher Reward**: The **slasher receives a percentage** of the slashed 
validator’s stake as a **bounty** for submitting proof.

2. **Pool Reimbursement**: The **remaining stake is redistributed** to the pool 
to **compensate affected participants**.


### Security Considerations
The current implementation only supports **vanilla blocks**. This is because 
**MEV-Boost builders** follow **different methods** for distributing MEV rewards 
to the `fee_recipient`, making it more complex to verify blocks produced via 
**external builders**.

**Potential Risk: MEV-Boost Incompatibility**
* If a **builder adopts a new standard** for passing MEV rewards to the `fee_recipient`, 
and the pool contract **does not properly account for this behavior**, validators 
using that builder **may be incorrectly slashed**.

* Malicious `SLASHERS` could exploit this inconsistency to **submit fraudulent 
fraud proofs**, unjustly slashing honest validators and **stealing their stake**.

**Mitigation Strategies**
To prevent wrongful slashing and improve security:

1. **Standardized MEV Distribution**: Encourage builders to follow a **transparent 
and verifiable** standard for MEV payouts, ensuring compatibility.

2. **Appeal Mechanism**: Introduce a **grace period** or **appeal system** where validators 
can dispute incorrect slashing claims before penalties are enforced.

### Things that still need some research

An important area to focus on is to propose a standard for the builders to pass 
the `fee_recipient`. As `mev-boost` is beneficial to increase the chance of higher
mev for produced blocks. Idea: Universal contract that realays payments.

The verification and generation of `multi_proofs` for some scnearios need to be 
researched and improved. There's some real time limits in some cases, where proofs
are too big or take too long to submit. 

Research verification of missed slots on chain, is that possible??

Monitor for missed slots would be ideal but as far as my knowledge goes it is
not really doable to proof that on-chain. Because in order to compute the `validator_index`
at slot `x` from the beacon state we'll have to pass the full validator array. 
See here: [compute_proposer_index()](`https://github.com/ethereum/consensus-specs/blob/dev/specs/phase0/beacon-chain.md#compute_proposer_index)

Further research is required for missed slot verification on-chain and improved 
multi-proof generation techniques. Contributions are welcome at [https://github.com/noahfigueras/contractsV2](https://github.com/noahfigueras/contractsV2).


