// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { Vm } from "forge-std/Vm.sol";
import { console } from "forge-std/console.sol";

import { SmoothlyPoolV2 } from "../src/SmoothlyPoolV2.sol";
import { ProofHelper } from "./ProofHelper.t.sol";

contract TestSmoothlyPoolV2Internal is Test, ProofHelper, SmoothlyPoolV2 {
  function testRebalance() public {
    uint256 r = block.timestamp;
    totalEB = 32 gwei;

    _rebalance(block.timestamp);
    assertEq(lastRebalance, r);
    assertEq(smooths, 0);

    _rebalance(block.timestamp + REBALANCE_PERIOD + 1 days);
    assertEq(lastRebalance, block.timestamp + REBALANCE_PERIOD + 1 days);
    assertEq(smooths, (lastRebalance - block.timestamp) * 32 gwei);
  }

  function testWithdrawal_WithdrawalsDisabled() public {
    Validator memory validator = Validator ({
      effectiveBalance: 32 gwei,
      withdrawal: address(1),
      start: block.timestamp,
      bond: BOND,
      smooths: 0
    });
    
    smooths = 32 gwei;
    uint256 eth = _withdraw(validator);
    assertEq(eth,0);
  }

  function testCalculateShare_SingleValidator() public {
    lastRebalance = block.timestamp;
    Validator memory validator = Validator ({
      effectiveBalance: 32 gwei,
      withdrawal: address(1),
      start: block.timestamp,
      bond: BOND,
      smooths: 0
    });

    totalEB += validator.effectiveBalance;

    vm.warp(block.timestamp + REBALANCE_PERIOD + 1 days);
    _rebalance(block.timestamp);
    
    uint256 eth = _withdraw(validator);
    assertEq(address(this).balance, 0);
    assertEq(address(1).balance, eth);
    assertEq(smooths, 0);
  }

  function testCalculateShare_MultiValidator() public {
    lastRebalance = block.timestamp;
    Validator[] memory validators = new Validator[](20);
    for(uint i = 0; i < validators.length; i++) {
      Validator memory validator = Validator ({
        effectiveBalance: 32 gwei,
        withdrawal: address(1),
        start: block.timestamp,
        bond: BOND,
        smooths: 0
      });
      validators[i] = validator;
      totalEB += validator.effectiveBalance;
    }

    vm.deal(address(this), 10000 ether);
    vm.warp(block.timestamp + REBALANCE_PERIOD + 1 days);
    _rebalance(block.timestamp);
    
    uint256 ethPerShare = address(this).balance / validators.length;
    for(uint i = 0; i < validators.length; i++) {
      uint256 eth = _withdraw(validators[i]);
      int256 precission = int256(ethPerShare) - int256(eth);
      if(precission < 0) { precission *= -1; }
      assertTrue(precission <= 1 gwei);
    }
  }

  function testCalculateShare_MultiValidator_multiPeriod() public {
    lastRebalance = block.timestamp;
    Validator memory validator1 = Validator ({
      effectiveBalance: 32 gwei,
      withdrawal: address(1),
      start: block.timestamp,
      bond: BOND,
      smooths: 0
    });
    _allocateSmooths(validator1.effectiveBalance, block.timestamp);

    vm.warp(block.timestamp + REBALANCE_PERIOD + 1 days);
    _rebalance(block.timestamp);

    Validator memory validator2 = Validator ({
      effectiveBalance: 32 gwei,
      withdrawal: address(1),
      start: block.timestamp,
      bond: BOND,
      smooths: 0
    });
    _allocateSmooths(validator2.effectiveBalance, block.timestamp);

    vm.warp(block.timestamp + REBALANCE_PERIOD + 1 days);
    _rebalance(block.timestamp);

    vm.deal(address(this), 10 ether);

    uint256 _eth = _withdraw(validator1);
    uint256 _eth2 = _withdraw(validator2);

    assertEq(_eth + _eth2, 10 ether);
    assertEq(totalETH(), 0);
    assertEq(0, smooths);

  }

  function testCalculateShare_MultiValidator_multiPeriod2() public {
    lastRebalance = block.timestamp;
    Validator[] memory validators = new Validator[](20);
    for(uint i = 0; i < validators.length; i++) {
      Validator memory validator = Validator ({
        effectiveBalance: 32 gwei,
        withdrawal: address(1),
        start: block.timestamp,
        bond: BOND,
        smooths: 0
      });
      validators[i] = validator;
      _allocateSmooths(validator.effectiveBalance, block.timestamp);
      if(i % 5 == 0 ) {
        vm.warp(block.timestamp + REBALANCE_PERIOD + 1 days); 
        _rebalance(block.timestamp);
      }
    }

    vm.warp(block.timestamp + REBALANCE_PERIOD + 1 days); 
    _rebalance(block.timestamp);
    vm.deal(address(this), 56 ether);
    uint256 totalRewarded = 0;

    for(uint i = 0; i < validators.length; i++) {
      uint256 _eth = _withdraw(validators[i]);
      totalRewarded += _eth;
    }

    assertEq(totalETH(), 0 ether);
    assertEq(smooths, 0);
  }

  function testCalculateShare_MultiValidatorEB_samePeriod() public {
    lastRebalance = block.timestamp;
    Validator[] memory validators = new Validator[](6);
    uint64 EB = 32 gwei;
    for(uint i = 0; i < validators.length; i++) {
      Validator memory validator = Validator ({
        effectiveBalance: EB,
        withdrawal: address(1),
        start: block.timestamp,
        bond: BOND,
        smooths: 0
      });
      validators[i] = validator;
      _allocateSmooths(validator.effectiveBalance, block.timestamp);
      EB += 10 gwei;
    }

    vm.warp(block.timestamp + REBALANCE_PERIOD + 1 days); 
    _rebalance(block.timestamp);

    vm.deal(address(this), 10 ether);
    uint256 totalRewarded = 0;
    
    for(uint i = validators.length - 1; i > 0; i-=2) {
      uint256 _eth1 = _withdraw(validators[i]);
      uint256 _eth2 = _withdraw(validators[i - 1]);
      totalRewarded += _eth1 + _eth2;
      assertTrue(_eth1 > _eth2);
      if(i < 2) {
        break;
      }
    }

    assertEq(totalRewarded, 10 ether);
    assertEq(totalETH(), 0 ether);
    assertEq(smooths, 0);
  }

  function testCalculateShare_MultiValidatorTimestamp_samePeriod() public {
    lastRebalance = block.timestamp;
    Validator[] memory validators = new Validator[](6);
    uint256 timestamp = block.timestamp;
    for(uint i = 0; i < validators.length; i++) {
      Validator memory validator = Validator ({
        effectiveBalance: 32 gwei,
        withdrawal: address(1),
        start: timestamp,
        bond: BOND,
        smooths: 0
      });
      validators[i] = validator;
      _allocateSmooths(validator.effectiveBalance, timestamp);
      timestamp += 1 days;
    }

    vm.warp(block.timestamp + REBALANCE_PERIOD + 1 days); 
    _rebalance(block.timestamp);
    vm.deal(address(this), 10 ether);
    uint256 totalRewarded = 0;
    
    for(uint i = 0; i < validators.length - 1; i+=2) {
      if(i >= validators.length) {
        break;
      }
      uint256 _eth1 = _withdraw(validators[i]);
      uint256 _eth2 = _withdraw(validators[i + 1]);
      totalRewarded += _eth1 + _eth2;
      assertTrue(_eth1 > _eth2);
    }

    assertEq(totalRewarded, 10 ether);
    assertEq(totalETH(), 0 ether);
    assertEq(smooths, 0);
  }

  function testCalculateShare_MultiValidatorEBRandom_samePeriod() public {
    lastRebalance = block.timestamp;
    Validator[] memory validators = new Validator[](20);
    for(uint i = 0; i < validators.length; i++) {
      uint randomHash = uint(keccak256(abi.encodePacked(
          block.timestamp,
          block.prevrandao,
          msg.sender,
          i 
      )));
      uint64 randomEB = uint64((randomHash % (2048 - 32 + 1)) + 32) * 1 gwei;
      Validator memory validator = Validator ({
        effectiveBalance: randomEB,
        withdrawal: address(1),
        start: block.timestamp,
        bond: BOND,
        smooths: 0
      });
      validators[i] = validator;
      _allocateSmooths(uint256(validator.effectiveBalance), validator.start);
    }

    vm.warp(block.timestamp + REBALANCE_PERIOD + 1 days); 
    _rebalance(block.timestamp);
    vm.deal(address(this), 100 ether);

    uint256 totalRewarded = 0;
    for(uint i = 0; i < validators.length; i++) {
      uint256 _eth = _withdraw(validators[i]);
      totalRewarded += _eth;
    }

    assertEq(totalRewarded, 100 ether);
    assertEq(totalETH(), 0 ether);
    assertEq(smooths, 0);
  }
}
