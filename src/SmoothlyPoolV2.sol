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

    _allocateSmooth(uint256(validator.effectiveBalance), time);
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

    rebalance();

    oracle.verifyFeeRecipient(
      indices, 
      proof, 
      validatorIndex, 
      address(this), 
      timestamp, 
      parentTs
    );

    (uint256 value, uint256 share) = calculateEth(registrant);
    smooths -= share;
    registrant.claimable = lastRebalance;

    (bool sent, ) = registrant.withdrawal.call{ value: value }("");
    require(sent, "Failed to send ether");
  }

  /// @dev gets registrant by validator index
  function getRegistrant(uint64 validatorIndex) external view returns (Registrant memory){
    return registrants[validatorIndex];
  }

  /// @dev calculate share in 'eth' 
  function calculateEth(Registrant memory registrant) 
    public view returns (uint256 eth, uint256 share) {
    if(registrant.claimable > lastRebalance) { revert WithdrawalsDisabled(); }
    share = (lastRebalance - registrant.claimable) * registrant.effectiveBalance;
    eth = ((share * BPS / smooths) * totalETH()) / BPS;
  }

  /// @dev gets total amount of ETH in the pool 
  function totalETH() internal view returns(uint256) {
    return address(this).balance - totalBond;
  }

  /// @dev restarts rebalance period
  function rebalance() public {
    uint256 t = block.timestamp;
    uint256 ellapsed = t - lastRebalance;
    if(ellapsed > REBALANCE_PERIOD) {
      uint256 extra = ellapsed - REBALANCE_PERIOD; 
      smooths += totalEB * extra;
      lastRebalance = t;
    }  
  }

  /// @dev calculate share of current rebalance period
  function _allocateSmooth(uint256 effectiveBalance, uint256 timestamp) internal {
    uint256 ellapsed = timestamp - lastRebalance;
    if(ellapsed > REBALANCE_PERIOD) {
      ellapsed = ellapsed - REBALANCE_PERIOD;
      rebalance();
    } else {
      smooths += uint256(effectiveBalance) * uint64(REBALANCE_PERIOD - ellapsed);
    }
  }

}
