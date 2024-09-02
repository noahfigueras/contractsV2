// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import { ISmoothlyPoolV2 } from "./interfaces/ISmoothlyPoolV2.sol";
import { BeaconOracle } from "./BeaconOracle.sol";
import { SSZ } from "./libraries/SSZ.sol";
import "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import { console } from "forge-std/console.sol";

// TODO: Update EB + Voluntary Exits
// TODO: Slashings
// - Missed Proposal slash. All acumulated rewards go back to the pool.
// - Bad Fee Recipient proposal. All acumulated rewards go back to the pool + bond.
contract SmoothlyPoolV2 is ISmoothlyPoolV2, ReentrancyGuard {
  uint32 public constant REBALANCE_PERIOD = 7 days;
  uint32 public constant BPS = 10000;
  uint64 public constant BOND = 0.1 ether;

  uint256 public lastRebalance; 
  uint256 public totalEB;
  uint256 public totalBond;
  uint256 public smooths;

  BeaconOracle public oracle;

  struct Validator {
    uint64 effectiveBalance;
    address withdrawal;
    uint256 start;
    uint256 bond;
  }

  enum Slashes {
    FeeRecipient,
    Registration,
    VoluntaryExit 
  }

  mapping(uint256 => Validator) public validators;

  constructor() {
    oracle = new BeaconOracle();
    lastRebalance = block.timestamp;
  }

  receive() external payable {
    emit Received(msg.sender, msg.value);
  }

  /// @dev register validator 
  function register(
    uint64 validatorIndex,
    bytes32[] calldata validatorProof,
    SSZ.Validator calldata validator,
    uint256 gIndex,
    uint64 ts
  ) external payable {
    if(msg.value != BOND) { revert BondTooLow(); }
    if(validators[validatorIndex].start > 0) { revert AlreadyRegistered(); }
    uint256 time = block.timestamp;
    address withdrawal = msg.sender;

    oracle.verifyValidator(validatorProof, validator, gIndex, ts, withdrawal); // Should revert in case it's invalid

    // TODO: ValidatorIndex can be faked in this case as we are not really verifying it
    // Verify Inclusion
    validators[validatorIndex].withdrawal = withdrawal; 
    validators[validatorIndex].start = time; 
    validators[validatorIndex].effectiveBalance = validator.effectiveBalance; 
    validators[validatorIndex].bond = BOND; 

    totalBond += BOND;
    totalEB += validator.effectiveBalance;

    _allocateSmooths(uint256(validator.effectiveBalance), time);
    emit Registered(validatorIndex, validator.effectiveBalance, withdrawal);
  }

  /// @dev Only possible to withdraw up to 'lastRebalance'
  function withdraw(
    uint256[] calldata indices,
    bytes32[] calldata proof,
    uint256 validatorIndex,
    uint64 timestamp
  ) external nonReentrant {
    Validator memory validator = validators[validatorIndex];
    if(validator.start == 0) { revert Unregistered(); }
    if(timestamp < validator.start) { revert InvalidBlockTimestamp(); } 

    oracle.verifyFeeRecipient(
      indices, 
      proof, 
      validatorIndex, 
      address(this), 
      timestamp 
    );

    _withdraw(validator);
  }

  /// @dev updates Effective Balance 
  function updateValidator(
    uint256[] calldata indices,
    bytes32[] calldata proof,
    uint256 validatorIndex,
    uint64 timestamp
  ) external {
    Validator memory validator = validators[validatorIndex];
    if(validator.start == 0) { revert Unregistered(); }
   // TODO: Updates validator state
   // Updates Effective Balance if changed significally
   // Updates exit_epoch if user already perform voluntaryExit flag as inactive
     
  }

  /// @dev on Block Proposed with a bad fee_recipient, user loses stake + exits
  function slashBadFeeRecipient(
    uint256[] calldata indices,
    bytes32[] calldata proof,
    uint256 validatorIndex,
    address feeRecipient,
    uint64 timestamp
  ) external nonReentrant {
    Validator memory validator = validators[validatorIndex];
    if(validator.start == 0) { revert Unregistered(); }
    
    oracle.verifyFeeRecipient(
      indices, 
      proof, 
      validatorIndex, 
      feeRecipient, 
      timestamp 
    );

    if(feeRecipient == address(this)) { revert CorrectFeeRecipient(); }

    totalEB -= validator.effectiveBalance; 
    totalBond -= validator.bond;

    (bool sent, ) = payable(msg.sender).call{ value: validator.bond }("");
    require(sent, "Failed to send ether");

    _rebalance(block.timestamp);
    delete validators[validatorIndex];
  }

  /// @notice Exits Pool
  /// @dev Validator can exit any time but if he exits will lose accumulated
  /// rewards since last block proposed.
  function exit(uint256 validatorIndex) external nonReentrant {
    Validator memory validator = validators[validatorIndex];
    if(msg.sender != validator.withdrawal) { revert NotOwner(); }

    totalEB -= validator.effectiveBalance; 
    totalBond -= validator.bond;

    (bool sent, ) = validator.withdrawal.call{ value: validator.bond }("");
    require(sent, "Failed to send ether");

    _rebalance(block.timestamp);
    delete validators[validatorIndex];
  }

  /// @dev gets registrant by validator index
  function getValidator(uint64 validatorIndex) external view returns (Validator memory){
    return validators[validatorIndex];
  }

  /// @dev calculates registrant share 
  function calculateShare(Validator memory validator) 
    public view returns (uint256 eth, uint256 share) {
    if(validator.start > lastRebalance) { revert WithdrawalsDisabled(); }
    share = (lastRebalance - validator.start) * validator.effectiveBalance;
    eth = ((share * BPS / smooths) * totalETH()) / BPS;
  }

  /// @dev gets total amount of ETH in the pool 
  function totalETH() public view returns(uint256) {
    return address(this).balance - totalBond;
  }

  function _withdraw(Validator memory validator) internal {
    _rebalance(block.timestamp);

    (uint256 _eth, uint256 _smooths) = calculateShare(validator);
    _deallocateSmooths(_smooths);
    validator.start = lastRebalance;

    (bool sent, ) = validator.withdrawal.call{ value: _eth }("");
    require(sent, "Failed to send ether");
  }

  /// @dev Increase smooths tSupply accordingly
  function _rebalance(uint256 timestamp) internal returns(bool) {
    uint256 ellapsed = timestamp - lastRebalance;
    if(ellapsed > REBALANCE_PERIOD) {
      ellapsed = ellapsed - REBALANCE_PERIOD;
      smooths += totalEB * ellapsed;
      lastRebalance = timestamp;
      return true;
    }    
    return false;
  }

  /// @dev Increases smooths tSupply accordingly
  function _allocateSmooths(uint256 effectiveBalance, uint256 timestamp) internal {
    uint256 ellapsed = timestamp - lastRebalance;
    if(!_rebalance(timestamp)) {
      smooths += uint256(effectiveBalance) * uint64(REBALANCE_PERIOD - ellapsed);
    }   
  }

  /// @dev Decrease smooths tSupply accordingly
  function _deallocateSmooths(uint256 _smooths) internal {
    smooths -= _smooths;
  }


}
