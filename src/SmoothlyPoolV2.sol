// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import { ISmoothlyPoolV2 } from "./interfaces/ISmoothlyPoolV2.sol";
import { BeaconOracle } from "./BeaconOracle.sol";
import { Smooth } from "./Smooth.sol";
import { SSZ } from "./SSZ.sol";
import { console } from "forge-std/console.sol";

contract SmoothlyPoolV2 is ISmoothlyPoolV2 {
  uint32 public constant REBALANCE_PERIOD = 7 days;

  uint256 public lastRebalance; 
  uint256 public totalEB;

  BeaconOracle public oracle;
  Smooth public smooth;

  struct Registrant {
    uint256 claimable;
    uint256 effectiveBalance;
    address withdrawal;
    bool verified;
  }

  mapping(uint64 => Registrant) public registrants;

  constructor() {
    oracle = new BeaconOracle();
    smooth = new Smooth();
    lastRebalance = block.timestamp;
  }

  receive() external payable {
  }

  /// @dev register validator 
  function register(uint64 validatorIndex, uint256 effectiveBalance) external {
    uint256 time = block.timestamp;
    address withdrawal = msg.sender;

    registrants[validatorIndex].withdrawal = withdrawal; 
    registrants[validatorIndex].claimable = time; 
    registrants[validatorIndex].effectiveBalance = effectiveBalance; 
    registrants[validatorIndex].verified = false; 
    totalEB += effectiveBalance;

    smooth.mint(_allocateSmooth(effectiveBalance, time));
    emit Registered(validatorIndex, effectiveBalance, withdrawal);
  }

  /// @dev Only possible to withdraw up to 'lastRebalance'
  function withdraw(uint64 validatorIndex) external {
    Registrant memory registrant = registrants[validatorIndex];
    if(!registrant.verified) { revert Unverified(); }
    (address withdrawal, uint256 value, uint256 share) = calculateEth(registrant);
    (bool sent, ) = withdrawal.call{ value: value }("");
    require(sent, "Failed to send ether");
    smooth.burn(share);
  }

  /// @dev calculate share in 'eth' 
  function calculateEth(Registrant memory registrant) 
    public returns (address withdrawal, uint256 eth, uint256 share) {
    if(registrant.claimable > lastRebalance) { revert WithdrawalsDisabled(); }
    share = (lastRebalance - registrant.claimable) * registrant.effectiveBalance;
    eth = (share / smooth.totalSupply()) * address(this).balance; 
    withdrawal = registrant.withdrawal;
    registrant.claimable = block.timestamp;
  }

  /// @dev gets registrant by validator index
  function getRegistrant(uint64 validatorIndex) public view returns (Registrant memory){
    return registrants[validatorIndex];
  }

  /// @dev calculate share of current rebalance period
  function _allocateSmooth(uint256 effectiveBalance, uint256 timestamp) 
    internal returns (uint256 share) {
    uint256 ellapsed = timestamp - lastRebalance;
    if(ellapsed > REBALANCE_PERIOD) {
      ellapsed = ellapsed - REBALANCE_PERIOD;
      rebalance();
    }
    return (REBALANCE_PERIOD - ellapsed) * effectiveBalance;
  }

  /// @dev restarts rebalance period
  function rebalance() public {
    totalEB *= REBALANCE_PERIOD;
    lastRebalance = block.timestamp;
  }

}
