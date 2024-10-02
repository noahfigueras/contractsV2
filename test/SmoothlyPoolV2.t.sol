// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { Vm } from "forge-std/Vm.sol";
import { console } from "forge-std/console.sol";

import { SmoothlyPoolV2 } from "../src/SmoothlyPoolV2.sol";
import { ProofHelper } from "./ProofHelper.t.sol";

contract TestSmoothlyPoolV2 is Test, ProofHelper, SmoothlyPoolV2 {

  SmoothlyPoolV2 public pool;

  function setUp() public {
    deployBeaconBlockRootPrecompile();
  }

  function testRegistration_InvalidBond() public {
    pool = new SmoothlyPoolV2();
    RegistrationProof memory _proof = loadRegistrationData();
    setBeaconBlockRoot(_proof.blockRoot);

    vm.expectRevert(BondNotSatisfied.selector);
    pool.register(
      _proof.validatorIndex, 
      _proof.proof,
      _proof.validator,
      uint64(block.timestamp)
    );
  }

  function testRegistration_AlreadyRegistered() public {
    pool = new SmoothlyPoolV2();
    RegistrationProof memory _proof = loadRegistrationData();
    setBeaconBlockRoot(_proof.blockRoot);

    pool.register{value: 0.1 ether}(
      _proof.validatorIndex, 
      _proof.proof,
      _proof.validator,
      uint64(block.timestamp)
    );

    vm.expectRevert(AlreadyRegistered.selector);
    pool.register{value: 0.1 ether}(
      _proof.validatorIndex, 
      _proof.proof,
      _proof.validator,
      uint64(block.timestamp)
    );
  }

  function testRegistration_InvalidWithdrawals() public {
    pool = new SmoothlyPoolV2();
    RegistrationProof memory _proof = loadRegistrationData();
    _proof.validator.withdrawalCredentials = bytes32(0x000000000000000000000000be2c1805ccd7f4ae97457a6c90dfdd5542364a09);
    setBeaconBlockRoot(_proof.blockRoot);

    vm.expectRevert(InvalidWithdrawalAddr.selector);
    pool.register{value: 0.1 ether}(
      _proof.validatorIndex, 
      _proof.proof,
      _proof.validator,
      uint64(block.timestamp)
    );
  }

  function testRegistration_InactiveValidator() public {
    pool = new SmoothlyPoolV2();
    RegistrationProof memory _proof = loadRegistrationData();
    _proof.validator.exitEpoch = uint64(getEpoch(block.timestamp));
    setBeaconBlockRoot(_proof.blockRoot);

    vm.expectRevert(InactiveValidator.selector);
    pool.register{value: 0.1 ether}(
      _proof.validatorIndex, 
      _proof.proof,
      _proof.validator,
      uint64(block.timestamp)
    );
  }

  function testRegistration_InvalidProof() public {
    pool = new SmoothlyPoolV2();
    RegistrationProof memory _proof = loadRegistrationData();
    _proof.validator.withdrawalCredentials = bytes32(0x010000000000000000000000fe2c1805ccd7f4ae97457a6c90dfdd5542364a09);
    setBeaconBlockRoot(_proof.blockRoot);

    vm.expectRevert(InvalidProof.selector);
    pool.register{value: 0.1 ether}(
      _proof.validatorIndex, 
      _proof.proof,
      _proof.validator,
      uint64(block.timestamp)
    );
  }

  function testRegistration() public {
    pool = new SmoothlyPoolV2();
    RegistrationProof memory _proof = loadRegistrationData();
    setBeaconBlockRoot(_proof.blockRoot);

    vm.deal(address(pool), 1 ether);
    pool.register{value: 0.1 ether}(
      _proof.validatorIndex, 
      _proof.proof,
      _proof.validator,
      uint64(block.timestamp)
    );

    (
      uint64 EB, 
      address withdrawal, 
      uint256 bond,
      uint256 start,
      uint256 _smooths
    ) = pool.validators(_proof.validatorIndex);

    assertEq(EB, 32 gwei);
    assertEq(withdrawal, withdrawalToAddress(_proof.validator.withdrawalCredentials));
    assertEq(start, block.timestamp);
    assertEq(bond, BOND);
    assertEq(_smooths, 0);
    assertEq(pool.totalBond(), BOND);
    assertEq(pool.pendingEB(), EB);
    assertEq(pool.pendingSmooths(), EB * REBALANCE_PERIOD);
    assertEq(pool.totalETH(), 1 ether);
    assertEq(address(pool).balance, 1.1 ether);
  }

  function testWithdrawal_Unregistered() public {
    uint256 validatorIndex = 696862;
    pool = new SmoothlyPoolV2();
    vm.expectRevert(Unregistered.selector);
    pool.withdraw(new uint256[](0), new bytes32[](0), validatorIndex, 0);
  }

  function testWithdrawal_InvalidBlockTimestamp() public {
    pool = new SmoothlyPoolV2();
    RegistrationProof memory _proof = loadRegistrationData();
    setBeaconBlockRoot(_proof.blockRoot);

    pool.register{value: 0.1 ether}(
      _proof.validatorIndex, 
      _proof.proof,
      _proof.validator,
      uint64(block.timestamp)
    );

    vm.expectRevert(InvalidBlockTimestamp.selector);
    pool.withdraw(new uint256[](0), new bytes32[](0), _proof.validatorIndex, 0);
  }

  function testWithdrawal_EmptyPool() public {
    pool = new SmoothlyPoolV2();
    RegistrationProof memory _proof = loadRegistrationData();
    setBeaconBlockRoot(_proof.blockRoot);

    pool.register{value: 0.1 ether}(
      _proof.validatorIndex, 
      _proof.proof,
      _proof.validator,
      uint64(block.timestamp)
    );

    vm.warp(block.timestamp + REBALANCE_PERIOD + 1 days);

    WithdrawalProof memory _proof2 = loadWithdrawalData();
    // ROOT modified to match fee_recipient as contract address
    setBeaconBlockRoot(bytes32(0xffb9279e026dbfb8a370183b1ad6f540fd1e7ded7e21f55dac4fe27458f54440));
    vm.expectRevert(EmptyPool.selector);
    pool.withdraw(_proof2.indices, _proof2.branches, _proof.validatorIndex, uint64(block.timestamp));
  }

  function testWithdrawal_InvalidProof() public {
    pool = new SmoothlyPoolV2();
    RegistrationProof memory _proof = loadRegistrationData();
    setBeaconBlockRoot(_proof.blockRoot);

    pool.register{value: 0.1 ether}(
      _proof.validatorIndex, 
      _proof.proof,
      _proof.validator,
      uint64(block.timestamp)
    );

    WithdrawalProof memory _proof2 = loadWithdrawalData();
    setBeaconBlockRoot(_proof.blockRoot);
    vm.deal(address(pool), 1 ether);
    vm.expectRevert(InvalidProof.selector);
    pool.withdraw(_proof2.indices, _proof2.branches, _proof.validatorIndex, uint64(block.timestamp));
  }

  function testWithdrawals() public {
    pool = new SmoothlyPoolV2();
    RegistrationProof memory _proof = loadRegistrationData();
    setBeaconBlockRoot(_proof.blockRoot);

    vm.deal(address(pool), 1 ether);
    pool.register{value: 0.1 ether}(
      _proof.validatorIndex, 
      _proof.proof,
      _proof.validator,
      uint64(block.timestamp)
    );

    vm.warp(block.timestamp + REBALANCE_PERIOD + 1 days);

    WithdrawalProof memory _proof2 = loadWithdrawalData();
    // ROOT modified to match fee_recipient as contract address
    setBeaconBlockRoot(bytes32(0xffb9279e026dbfb8a370183b1ad6f540fd1e7ded7e21f55dac4fe27458f54440));
    address recipient = withdrawalToAddress(_proof.validator.withdrawalCredentials);
    vm.deal(recipient, 0);

    pool.withdraw(_proof2.indices, _proof2.branches, _proof.validatorIndex, uint64(block.timestamp));

    assertEq(recipient.balance, 1 ether);
    assertEq(pool.totalETH(), 0);
    assertEq(address(pool).balance, 0.1 ether);
  }

  function testUpdateValidator_Unregistered() public {
    pool = new SmoothlyPoolV2();
    RegistrationProof memory _proof = loadRegistrationData();
    setBeaconBlockRoot(_proof.blockRoot);

    vm.expectRevert(Unregistered.selector);
    pool.updateValidator(
      _proof.validatorIndex,
      _proof.proof,
      _proof.validator,
      uint64(block.timestamp)
    );
  }

  function testUpdateValidator_UpdateNotAvailable() public {
    pool = new SmoothlyPoolV2();
    RegistrationProof memory _proof = loadRegistrationData();
    setBeaconBlockRoot(_proof.blockRoot);

    pool.register{value: 0.1 ether}(
      _proof.validatorIndex, 
      _proof.proof,
      _proof.validator,
      uint64(block.timestamp)
    );

    vm.expectRevert(UpdateNotAvailable.selector);
    pool.updateValidator(
      _proof.validatorIndex,
      _proof.proof,
      _proof.validator,
      uint64(block.timestamp)
    );
  }

  function testUpdateValidator_Active() public {
    pool = new SmoothlyPoolV2();
    RegistrationProof memory _proof = loadRegistrationData();
    setBeaconBlockRoot(_proof.blockRoot);

    pool.register{value: 0.1 ether}(
      _proof.validatorIndex, 
      _proof.proof,
      _proof.validator,
      uint64(block.timestamp)
    );

    vm.warp(block.timestamp + REBALANCE_PERIOD + 1 days); 
    vm.deal(address(pool), 10 ether);

    _proof.validator.effectiveBalance = 40 gwei;
    setBeaconBlockRoot(0xfbba209b35daefd1b5a3c2bf4d67fe96133dd74da600932600459e0621bd740c);
    pool.updateValidator(
      _proof.validatorIndex,
      _proof.proof,
      _proof.validator,
      uint64(block.timestamp)
    );

    (uint256 EB, , ,uint256 start, uint256 _smooths ) = pool.validators(_proof.validatorIndex);
    assertEq(EB, _proof.validator.effectiveBalance);
    assertEq(pool.smooths(), _smooths);
    assertEq(block.timestamp, start);
    assertEq(pool.totalEB(), 0);
    assertEq(pool.pendingEB(), 40 gwei);
    assertEq(pool.pendingSmooths(), 21 days * 40 gwei);
    assertEq(pool.totalBond(), 0.1 ether);
  }

  function testUpdateValidator_ExitBeforeRebalance() public {
    pool = new SmoothlyPoolV2();
    RegistrationProof memory _proof = loadRegistrationData();
    setBeaconBlockRoot(_proof.blockRoot);

    pool.register{value: 0.1 ether}(
      _proof.validatorIndex, 
      _proof.proof,
      _proof.validator,
      uint64(block.timestamp)
    );

    vm.warp(block.timestamp + 7 days); 
    vm.deal(address(pool), 10 ether);

    _proof.validator.exitEpoch = uint64(getEpoch(block.timestamp));
    setBeaconBlockRoot(0x5e9882629aef5b1b763a2132a06b47ebe045d319de51dab8ffe821aaff0a79e1);
    address recipient = withdrawalToAddress(_proof.validator.withdrawalCredentials);
    vm.deal(recipient, 0);
    pool.updateValidator(
      _proof.validatorIndex,
      _proof.proof,
      _proof.validator,
      uint64(block.timestamp)
    );

    (uint256 EB, , ,uint256 start, uint256 _smooths ) = pool.validators(_proof.validatorIndex);
    assertEq(EB, 0);
    assertEq(start, 0);
    assertEq(_smooths, 0);
    assertEq(pool.totalEB(), 0);
    assertEq(pool.pendingEB(), 0);
    assertEq(pool.pendingSmooths(), 0);
    assertEq(pool.totalBond(), 0 ether);
    assertEq(pool.smooths(), 0);
    assertEq(recipient.balance, 0.1 ether);
  }

  function testUpdateValidator_ExitAfterRebalance() public {
    pool = new SmoothlyPoolV2();
    RegistrationProof memory _proof = loadRegistrationData();
    setBeaconBlockRoot(_proof.blockRoot);

    pool.register{value: 0.1 ether}(
      _proof.validatorIndex, 
      _proof.proof,
      _proof.validator,
      uint64(block.timestamp)
    );

    vm.warp(block.timestamp + REBALANCE_PERIOD + 1 days); 
    vm.deal(address(pool), 10 ether);

    _proof.validator.exitEpoch = uint64(getEpoch(block.timestamp));
    setBeaconBlockRoot(0x30feddf3516019321c4d509fa28d0177f902c27e84587e6c8f795af5655123bb);
    address recipient = withdrawalToAddress(_proof.validator.withdrawalCredentials);
    vm.deal(recipient, 0);
    pool.updateValidator(
      _proof.validatorIndex,
      _proof.proof,
      _proof.validator,
      uint64(block.timestamp)
    );

    (uint256 EB, , ,uint256 start, uint256 _smooths ) = pool.validators(_proof.validatorIndex);
    assertEq(EB, 0);
    assertEq(start, 0);
    assertEq(_smooths, 0);
    assertEq(pool.totalEB(), 0);
    assertEq(pool.pendingEB(), 0);
    assertEq(pool.pendingSmooths(), 0);
    assertEq(pool.totalBond(), 0 ether);
    assertEq(pool.smooths(), 0);
    assertEq(recipient.balance, 0.1 ether);
  }

  function testSlashBadFeeRecipient_InvalidProof() public {
    pool = new SmoothlyPoolV2();
    RegistrationProof memory _proof = loadRegistrationData();
    setBeaconBlockRoot(_proof.blockRoot);

    pool.register{value: 0.1 ether}(
      _proof.validatorIndex, 
      _proof.proof,
      _proof.validator,
      uint64(block.timestamp)
    );

    vm.warp(block.timestamp + REBALANCE_PERIOD + 1 days); 
    vm.deal(address(pool), 10 ether);

    WithdrawalProof memory _proof2 = loadWithdrawalData();
    setBeaconBlockRoot(_proof2.blockRoot);
    vm.deal(address(1), 0);
    vm.prank(address(1));
    vm.expectRevert(InvalidProof.selector);
    pool.slashBadFeeRecipient(
      _proof2.indices,
      _proof2.branches,
      _proof2.validatorIndex,
      address(0),
      uint64(block.timestamp)
    );
  }

  function testSlashBadFeeRecipient_CorrectFeeRecipient() public {
    pool = new SmoothlyPoolV2();
    RegistrationProof memory _proof = loadRegistrationData();
    setBeaconBlockRoot(_proof.blockRoot);

    pool.register{value: 0.1 ether}(
      _proof.validatorIndex, 
      _proof.proof,
      _proof.validator,
      uint64(block.timestamp)
    );

    vm.warp(block.timestamp + REBALANCE_PERIOD + 1 days); 
    vm.deal(address(pool), 10 ether);

    WithdrawalProof memory _proof2 = loadWithdrawalData();
    // ROOT modified to match fee_recipient as contract address
    setBeaconBlockRoot(bytes32(0xffb9279e026dbfb8a370183b1ad6f540fd1e7ded7e21f55dac4fe27458f54440));
    vm.expectRevert(CorrectFeeRecipient.selector);
    pool.slashBadFeeRecipient(
      _proof2.indices,
      _proof2.branches,
      _proof2.validatorIndex,
      address(pool),
      uint64(block.timestamp)
    );
  }

  function testSlashBadFeeRecipient() public {
    pool = new SmoothlyPoolV2();
    RegistrationProof memory _proof = loadRegistrationData();
    setBeaconBlockRoot(_proof.blockRoot);

    pool.register{value: 0.1 ether}(
      _proof.validatorIndex, 
      _proof.proof,
      _proof.validator,
      uint64(block.timestamp)
    );

    vm.warp(block.timestamp + REBALANCE_PERIOD + 1 days); 
    vm.deal(address(pool), 10 ether);

    WithdrawalProof memory _proof2 = loadWithdrawalData();
    setBeaconBlockRoot(_proof2.blockRoot);
    vm.deal(address(1), 0);
    vm.prank(address(1));
    pool.slashBadFeeRecipient(
      _proof2.indices,
      _proof2.branches,
      _proof2.validatorIndex,
      address(0x1f9090aaE28b8a3dCeaDf281B0F12828e676c326),
      uint64(block.timestamp)
    );

    (uint256 EB, , ,uint256 start, uint256 _smooths ) = pool.validators(_proof.validatorIndex);
    assertEq(EB, 0);
    assertEq(start, 0);
    assertEq(_smooths, 0);
    assertEq(pool.totalEB(), 0);
    assertEq(pool.pendingEB(), 0);
    assertEq(pool.pendingSmooths(), 0);
    assertEq(pool.totalBond(), 0 ether);
    assertEq(pool.smooths(), 0);
    assertEq(address(1).balance, 0.1 ether);
  }

  function testExit_NotOwner() public {
    pool = new SmoothlyPoolV2();
    RegistrationProof memory _proof = loadRegistrationData();
    setBeaconBlockRoot(_proof.blockRoot);

    pool.register{value: 0.1 ether}(
      _proof.validatorIndex, 
      _proof.proof,
      _proof.validator,
      uint64(block.timestamp)
    );

    vm.warp(block.timestamp + REBALANCE_PERIOD + 1 days); 
    vm.deal(address(pool), 10 ether);

    vm.prank(address(1));
    vm.expectRevert(NotOwner.selector);
    pool.exit(_proof.validatorIndex);
  }

  function testExit() public {
    pool = new SmoothlyPoolV2();
    RegistrationProof memory _proof = loadRegistrationData();
    setBeaconBlockRoot(_proof.blockRoot);

    pool.register{value: 0.1 ether}(
      _proof.validatorIndex, 
      _proof.proof,
      _proof.validator,
      uint64(block.timestamp)
    );

    vm.warp(block.timestamp + REBALANCE_PERIOD + 1 days); 
    vm.deal(address(pool), 10 ether);

    vm.prank(withdrawalToAddress(_proof.validator.withdrawalCredentials));
    pool.exit(_proof.validatorIndex);

    (uint256 EB, , ,uint256 start, uint256 _smooths ) = pool.validators(_proof.validatorIndex);
    assertEq(EB, 0);
    assertEq(start, 0);
    assertEq(_smooths, 0);
    assertEq(pool.totalEB(), 0);
    assertEq(pool.pendingEB(), 0);
    assertEq(pool.pendingSmooths(), 0);
    assertEq(pool.totalBond(), 0 ether);
    assertEq(pool.smooths(), 0);
    assertEq(withdrawalToAddress(_proof.validator.withdrawalCredentials).balance, 0.1 ether);
  }
}

