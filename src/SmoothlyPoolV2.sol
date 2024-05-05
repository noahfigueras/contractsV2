// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import { ISmoothlyPoolV2 } from "./interfaces/ISmoothlyPoolV2.sol";
import { BeaconOracle } from "./BeaconOracle.sol";
import { Smooth } from "./Smooth.sol";
import { SSZ } from "./SSZ.sol";

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
  function register(uint64 validatorIndex, uint256 effectiveBalance) public {
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
  function withdraw(uint64 validatorIndex) public {
    (address withdrawal, uint256 value) = _calculateEth(validatorIndex);
    (bool sent, ) = withdrawal.call{ value: value }("");
    require(sent, "Failed to send ether");
  }

  /// @dev calculate share in 'eth' 
  function _calculateEth(uint64 validatorIndex) 
    internal returns (address withdrawal, uint256 eth) {
    Registrant memory registrant = registrants[validatorIndex];
    uint256 share = (registrant.claimable - lastRebalance) * registrant.effectiveBalance;
    eth = (share / smooth.totalSupply()) * address(this).balance; 
    withdrawal = registrant.withdrawal;
    registrant.claimable = block.timestamp;
    smooth.burn(share);
  }

  /// @dev calculate share of current rebalance period
  function _allocateSmooth(uint256 effectiveBalance, uint256 timestamp) 
    internal view returns (uint256 share) {
    return REBALANCE_PERIOD - (lastRebalance - timestamp) * effectiveBalance;
  }

  /// @dev restarts rebalance period
  function _rebalance() internal {
    totalEB *= REBALANCE_PERIOD; 
    lastRebalance = block.timestamp;
  }

}
