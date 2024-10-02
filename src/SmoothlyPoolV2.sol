// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import { ISmoothlyPoolV2 } from "./interfaces/ISmoothlyPoolV2.sol";
import { BeaconOracle } from "./BeaconOracle.sol";
import "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import { console } from "forge-std/console.sol";

contract SmoothlyPoolV2 is BeaconOracle, ReentrancyGuard, ISmoothlyPoolV2 {
  // @dev Time required to execute the next pool rebalance.
  uint32 public constant REBALANCE_PERIOD = 21 days;
  // @dev Required BOND to join the pool, allows slashes in case of misbehaviours. 
  uint64 public constant BOND = 0.1 ether;
  // @dev Used for precise calculations. 
  uint256 public constant BPS = 1e18;

  // @dev gIndex of validator 0 in beacon chain, proofs proposer_index inclusion.
  uint64 public ZERO_VALIDATOR_INDEX = 798245441765376;
  // @dev timestamp of last rebalance period.
  uint256 public lastRebalance; 
  // @dev total amount of Effective Balance.
  uint256 public totalEB;
  // @dev total amount of Bond.
  uint256 public totalBond;
  // @dev Units to be rewarded for participating in the pool weighted by EB.
  uint256 public smooths;
  // @dev total amount of Effective Balance.
  uint256 public pendingEB;
  // @dev pending units to be rewarded for participating in the pool weighted by EB.
  uint256 public pendingSmooths;

  struct Validator {
    // @dev Beacon chain validator's effective balance.
    uint64 effectiveBalance;
    // @dev Beacon chain validator's withdrawal address. 
    address withdrawal;
    // @dev Bond submitted in registration as ETH. 
    uint256 bond;
    // @dev Starting point for claiming rewards as timestamp.
    uint256 start;
    // @dev Keeps track of unclaimed smooths for validator updates.
    uint256 smooths;
  }

  // @dev Maps all validators registered in the pool. 
  mapping(uint256 => Validator) public validators;

  // @notice Allocates new smooths for last REBALANCE_PERIOD.
  modifier needsRebalance() {
    _rebalance(block.timestamp);
    _;
  }

  constructor() {
    lastRebalance = block.timestamp;
  }

  // @notice Receives ETH. 
  receive() external payable {
    emit Received(msg.sender, msg.value);
  }

  // @notice Receives ETH as donation. Used to differentiate donations from
  // ETH coming to the pool
  function donateETH() external payable {
    emit Donated(msg.sender, msg.value);
  }

  // @notice Registers validator into the pool.
  // @dev Verifies validatorIndex is included and active in the beacon chain. 
  // @dev eip-4788 reverts if timestamp is older than 1 day.
  // @dev Sets withdrawal address as recipient of the rewards. Rejects BLS 
  // withdrawal addresses.
  function register(
    uint64 validatorIndex,
    bytes32[] calldata validatorProof,
    BeaconChainValidator calldata validator,
    uint64 ts
  ) external payable needsRebalance {
    if(msg.value != BOND) { revert BondNotSatisfied(); }
    if(validators[validatorIndex].start > 0) { revert AlreadyRegistered(); }
    uint256 time = block.timestamp;
    uint256 gIndex = ZERO_VALIDATOR_INDEX + validatorIndex;
    address _withdrawal = withdrawalToAddress(validator.withdrawalCredentials);

    if(!isActiveValidator(validator)) revert InactiveValidator();
    verifyValidator(validatorProof, validator, gIndex, ts);

    validators[validatorIndex].effectiveBalance = validator.effectiveBalance; 
    validators[validatorIndex].withdrawal = _withdrawal; 
    validators[validatorIndex].bond = BOND; 
    validators[validatorIndex].start = time; 

    totalBond += BOND;
    _allocateSmooths(uint256(validator.effectiveBalance), time);

    emit Registered(validatorIndex, validator.effectiveBalance, _withdrawal);
  }

  // @notice Process withdrawal of share in ETH to withdrawal address.
  // @dev Submits a proof with this address as the fee_recipient.
  // @dev Only Possible to withdraw after a validator has proposed a block with 
  // this address as the fee_recipient.
  // @dev Only possible to withdraw up to 'lastRebalance'
  // @dev eip-4788 reverts if timestamp is older than 1 day.
  function withdraw(
    uint256[] calldata indices,
    bytes32[] calldata proof,
    uint256 validatorIndex,
    uint64 timestamp
  ) external needsRebalance {
    Validator memory validator = validators[validatorIndex];
    if(validator.start == 0) { revert Unregistered(); }
    if(timestamp < validator.start) { revert InvalidBlockTimestamp(); } 
    if(totalETH() == 0) { revert EmptyPool(); }

    verifyFeeRecipient(
      indices, 
      proof, 
      validatorIndex, 
      address(this), 
      timestamp 
    );

    uint256 eth = _withdraw(validator);
    validators[validatorIndex].start = lastRebalance;
    validators[validatorIndex].smooths = 0;
    emit Withdrawal(validatorIndex, eth, validator.withdrawal);
  }

  // @notice Updates Validator EB if still active, otherwise exits validator. 
  // @dev Verifies recent validator state in the beacon_chain, eip-4788 reverts
  // if timestamp is older than 1 day.
  // @dev Anyone can update a validator. If a validator exits the beacon_chain
  // anyone should be able to stop them accumulating rewards.
  function updateValidator(
    uint64 validatorIndex,
    bytes32[] calldata validatorProof,
    BeaconChainValidator calldata validator,
    uint64 ts
  ) external needsRebalance {
    Validator storage _validator = validators[validatorIndex];
    if(_validator.start == 0) { revert Unregistered(); }

    uint256 gIndex = ZERO_VALIDATOR_INDEX + validatorIndex;
    verifyValidator(validatorProof, validator, gIndex, ts);

    if(isActiveValidator(validator)) {
      if(_validator.start >= lastRebalance) { revert UpdateNotAvailable(); }
      uint256 time = block.timestamp;
      uint256 share = (time - _validator.start) * _validator.effectiveBalance;

      totalEB -= _validator.effectiveBalance;

      _validator.smooths += share;
      _validator.start = time;
      _validator.effectiveBalance = validator.effectiveBalance;

      _allocateSmooths(validator.effectiveBalance, time);
    } else {
      _exit(validatorIndex, _validator.withdrawal);
      emit Exit(validatorIndex, "INVALIDED");
    }
  }

  // @notice Slashes a validatorIndex due to proposing a block with a different
  // fee_recipient.
  // @dev validatorIndex should be exited due to slashing, losing all accumulated
  // rewards and bond. 
  // @dev Anyone should be able to call this and get validatorIndex bond as reward.
  function slashBadFeeRecipient(
    uint256[] calldata indices,
    bytes32[] calldata proof,
    uint256 validatorIndex,
    address feeRecipient,
    uint64 timestamp
  ) external needsRebalance {
    Validator memory validator = validators[validatorIndex];
    if(validator.start == 0) { revert Unregistered(); }
    
    verifyFeeRecipient(
      indices, 
      proof, 
      validatorIndex, 
      feeRecipient, 
      timestamp 
    );

    if(feeRecipient == address(this)) { revert CorrectFeeRecipient(); }

    _exit(validatorIndex, msg.sender);
    emit Exit(validatorIndex, "SLASHED");
  }

  /// @notice Exits Pool
  /// @dev Validator can exit any time but if he exits will lose accumulated
  /// rewards since last block proposed.
  function exit(uint256 validatorIndex) external needsRebalance {
    Validator memory validator = validators[validatorIndex];
    // EigenPod owners can't call this directly.
    // Maybe consider a signature here.
    if(msg.sender != validator.withdrawal) { revert NotOwner(); }
    _exit(validatorIndex, validator.withdrawal);
    emit Exit(validatorIndex, "VOLUNTARY_EXIT");
  }

  // @notice Distributes shares among participants in the pool.
  // @dev Only smooth shares up to lastRebalance should be distributed.
  function rebalance() external {
    _rebalance(block.timestamp);
  }

  // @notice Returns total amount of ETH to be distributed in the pool.
  function totalETH() public view returns(uint256) {
    return address(this).balance - totalBond;
  }

  // @notice Exits Pool
  // @dev Validator can exit any time but if he exits will lose accumulated
  // rewards since last block proposed.
  function _exit(uint256 validatorIndex, address recipient) internal nonReentrant {
    Validator memory validator = validators[validatorIndex];

    if(validator.start >= lastRebalance) {
      pendingEB -= validator.effectiveBalance;
      pendingSmooths -= validator.effectiveBalance * (REBALANCE_PERIOD - (validator.start - lastRebalance));
      smooths -= validator.smooths;
    } else {
      totalEB -= validator.effectiveBalance; 
      smooths -= _getShares(validator);
    }

    totalBond -= validator.bond;

    (bool sent, ) = recipient.call{ value: validator.bond }("");
    require(sent, "Failed to send ether");

    delete validators[validatorIndex];
  }

  // @notice Withdraws validator share in eth to withdrawal addr.
  // @dev Validator should only be able to process a withdrawal if it has been 
  // active at least for 1 epoch.
  function _withdraw(Validator memory validator) internal nonReentrant returns(uint256 eth) {
    if(smooths == 0) { revert WithdrawalsDisabled(); }

    uint256 share = (validator.start >= lastRebalance) ? validator.smooths : _getShares(validator);
    eth = ((share * BPS / smooths) * totalETH()) / BPS;
    smooths -= share;

    (bool sent, ) = validator.withdrawal.call{ value: eth }("");
    require(sent, "Failed to send ether");
  }

  // @dev Updates all validatorIndex shares after REBALANCE_PERIOD timelock is 
  // meet. 
  function _rebalance(uint256 timestamp) internal {
    uint256 ellapsed = timestamp - lastRebalance;
    if(ellapsed > REBALANCE_PERIOD) {
      smooths += (totalEB * ellapsed) + (pendingEB * (ellapsed - REBALANCE_PERIOD)) + pendingSmooths;
      totalEB += pendingEB;
      lastRebalance = timestamp;
      pendingSmooths = 0;
      pendingEB = 0;
    }    
  }

  // @dev Keeps track of new registrations smooths and EB after lastRebalance. 
  // It is used to properly update smooths on _rebalance.
  function _allocateSmooths(uint256 effectiveBalance, uint256 timestamp) internal {
    uint256 ellapsed = timestamp - lastRebalance;
    pendingEB += effectiveBalance;
    pendingSmooths += effectiveBalance * (REBALANCE_PERIOD - ellapsed);
  }

  // @dev Calculates smooths shares by active time and effective balance.
  function _getShares(Validator memory validator) internal view returns(uint256 share) {
    share = (lastRebalance - validator.start) * validator.effectiveBalance;
    share += validator.smooths;
  }
}
