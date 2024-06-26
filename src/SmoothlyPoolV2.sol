// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import { ISmoothlyPoolV2 } from "./interfaces/ISmoothlyPoolV2.sol";
import { BeaconOracle } from "./BeaconOracle.sol";
import { SSZ } from "./SSZ.sol";
import { console } from "forge-std/console.sol";

contract SmoothlyPoolV2 is ISmoothlyPoolV2 {
  uint32 public constant REBALANCE_PERIOD = 7 days;
  uint32 public constant BPS = 10000;

  uint256 public lastRebalance; 
  uint256 public totalEB;
  uint256 public smooths;

  BeaconOracle public oracle;

  struct Registrant {
    uint256 claimable;
    uint64 effectiveBalance;
    address withdrawal;
    bool verified;
  }

  mapping(uint64 => Registrant) public registrants;

  constructor() {
    oracle = new BeaconOracle();
    lastRebalance = block.timestamp;
  }

  receive() external payable {
  }

  /// @dev register validator 
  function register(
    uint64 validatorIndex,
    bytes32[] calldata validatorProof,
    SSZ.Validator calldata validator,
    uint256 gIndex,
    uint64 ts
  ) external {
    uint256 time = block.timestamp;
    address withdrawal = msg.sender;

    oracle.verifyValidator(validatorProof, validator, gIndex, ts, withdrawal); // Should revert in case it's invalid

    registrants[validatorIndex].withdrawal = withdrawal; 
    registrants[validatorIndex].claimable = time; 
    registrants[validatorIndex].effectiveBalance = validator.effectiveBalance; 
    registrants[validatorIndex].verified = false; // This will disappear
    totalEB += validator.effectiveBalance;

    smooths += _allocateSmooth(uint256(validator.effectiveBalance), time);
    emit Registered(validatorIndex, validator.effectiveBalance, withdrawal);
  }

  /// @dev Only possible to withdraw up to 'lastRebalance'
  function withdraw(uint64 validatorIndex) external {
    Registrant memory registrant = registrants[validatorIndex];
    if(!registrant.verified) { revert Unverified(); }
    (address withdrawal, uint256 value, uint256 share) = calculateEth(registrant);
    (bool sent, ) = withdrawal.call{ value: value }("");
    require(sent, "Failed to send ether");
    smooths -= share;
    registrant.claimable = lastRebalance;
  }

  /// @dev gets registrant by validator index
  function getRegistrant(uint64 validatorIndex) external view returns (Registrant memory){
    return registrants[validatorIndex];
  }

  /// @dev calculate share in 'eth' 
  function calculateEth(Registrant memory registrant) 
    public view returns (address withdrawal, uint256 eth, uint256 share) {
    if(registrant.claimable > lastRebalance) { revert WithdrawalsDisabled(); }
    share = (lastRebalance - registrant.claimable) * registrant.effectiveBalance;
    eth = ((share * BPS / smooths) * address(this).balance) / BPS;
    withdrawal = registrant.withdrawal;
  }

  /// @dev restarts rebalance period
  function rebalance() public {
    uint256 t = block.timestamp;
    uint256 ellapsed = t - lastRebalance;
    if(ellapsed > REBALANCE_PERIOD) {
      uint256 extra = ellapsed - REBALANCE_PERIOD; 
      smooths += totalEB * extra;
      lastRebalance = t;
    } else {
      revert TimelockNotReached();
    }
  }

  /// @dev calculate share of current rebalance period
  function _allocateSmooth(uint256 effectiveBalance, uint256 timestamp) 
    internal returns (uint256 share) {
    uint256 ellapsed = timestamp - lastRebalance;
    if(ellapsed > REBALANCE_PERIOD) {
      ellapsed = ellapsed - REBALANCE_PERIOD;
      rebalance();
    }
    share = uint256(effectiveBalance) * uint64(REBALANCE_PERIOD - ellapsed);
  }

}
