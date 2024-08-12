// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import { ISmoothlyPoolV2 } from "./interfaces/ISmoothlyPoolV2.sol";
import { BeaconOracle } from "./BeaconOracle.sol";
import { SSZ } from "./libraries/SSZ.sol";
import { console } from "forge-std/console.sol";

contract SmoothlyPoolV2 is ISmoothlyPoolV2 {
  uint32 public constant REBALANCE_PERIOD = 7 days;
  uint32 public constant BPS = 10000;
  uint64 public constant BOND = 0.1 ether;

  uint256 public lastRebalance; 
  uint256 public totalEB;
  uint256 public totalBond;
  uint256 public smooths;

  BeaconOracle public oracle;

  struct Registrant {
    uint256 claimable;
    uint64 effectiveBalance;
    address withdrawal;
    uint256 bond;
  }

  mapping(uint256 => Registrant) public registrants;

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
    uint256 time = block.timestamp;
    address withdrawal = msg.sender;

    oracle.verifyValidator(validatorProof, validator, gIndex, ts, withdrawal); // Should revert in case it's invalid

    registrants[validatorIndex].withdrawal = withdrawal; 
    registrants[validatorIndex].claimable = time; 
    registrants[validatorIndex].effectiveBalance = validator.effectiveBalance; 
    registrants[validatorIndex].bond = BOND; 

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
    uint64 timestamp,
    uint64 parentTs
  ) external {
    Registrant memory registrant = registrants[validatorIndex];
    if(registrant.claimable == 0) { revert Unregistered(); }
    if(timestamp < registrant.claimable) { revert InvalidBlockTimestamp(); } 

    oracle.verifyFeeRecipient(
      indices, 
      proof, 
      validatorIndex, 
      address(this), 
      timestamp, 
      parentTs
    );

    _rebalance(block.timestamp);
    (uint256 _eth, uint256 _smooths) = calculateShare(registrant);
    _deallocateSmooths(_smooths);
    registrant.claimable = lastRebalance;

    // TODO: Test for reentrancy
    (bool sent, ) = registrant.withdrawal.call{ value: _eth }("");
    require(sent, "Failed to send ether");
  }

  /// @dev gets registrant by validator index
  function getRegistrant(uint64 validatorIndex) external view returns (Registrant memory){
    return registrants[validatorIndex];
  }

  /// @dev calculates registrant share 
  function calculateShare(Registrant memory registrant) 
    public view returns (uint256 eth, uint256 share) {
    if(registrant.claimable > lastRebalance) { revert WithdrawalsDisabled(); }
    share = (lastRebalance - registrant.claimable) * registrant.effectiveBalance;
    eth = ((share * BPS / smooths) * totalETH()) / BPS;
  }

  /// @dev gets total amount of ETH in the pool 
  function totalETH() public view returns(uint256) {
    return address(this).balance - totalBond;
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
