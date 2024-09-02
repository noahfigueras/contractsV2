// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { Vm } from "forge-std/Vm.sol";
import { console } from "forge-std/console.sol";

import { SmoothlyPoolV2 } from "../src/SmoothlyPoolV2.sol";
import { BeaconOracle } from "../src/BeaconOracle.sol";
import { ISmoothlyPoolV2 } from "../src/interfaces/ISmoothlyPoolV2.sol";
import { IBeaconOracle } from "../src/interfaces/IBeaconOracle.sol";

import { SSZ } from "../src/libraries/SSZ.sol";

contract TestSmoothlyPoolV2 is Test, ISmoothlyPoolV2, SmoothlyPoolV2, IBeaconOracle {
  using stdJson for string;

  string FORK_URL = vm.envString("MAINNET_FORK");
  uint256 fork;

  bytes32[] public proof;
  uint256[] public indices;

  struct registrationProofJSON {
    bytes32[] validatorProof;
    SSZ.Validator validator;
    uint64 validatorIndex;
    bytes32 blockRoot;
    uint256 gIndex;
    uint64 timestamp;
  }

  registrationProofJSON public registrationProof;

  SmoothlyPoolV2 public pool;

  function setUp() public {
    string memory root = vm.projectRoot();
    string memory path = string.concat(root, "/test/fixtures/validator_registration.json");
    string memory json = vm.readFile(path);
    bytes memory data = json.parseRaw("$");
    registrationProof = abi.decode(data, (registrationProofJSON));
    fork = vm.createSelectFork(FORK_URL);
    vm.selectFork(fork);
    oracle = new BeaconOracle();
  }

  function test_register() public {
    pool = new SmoothlyPoolV2();
    setBeaconBlockRoot(
      0x564f8fec0e94f43397efad2c55313a9325922e3cc9b26ed9049d9d1b1c43da4a,
      block.timestamp
    );
    // Full share with 32 tokens
    uint256 share = 19353600000000000;
    (bool success,) = address(pool).call{value: 1 ether}("");
    require(success);

    uint64 vIndex = 465789;
    vm.prank(address(0xbe2C1805CcD7f4Ae97457A6C90dfDD5542364A09));
    vm.deal(address(0xbe2C1805CcD7f4Ae97457A6C90dfDD5542364A09), 1 ether);
    pool.register{value: 0.1 ether}(
      vIndex, 
      registrationProof.validatorProof,
      registrationProof.validator,
      registrationProof.gIndex,
      uint64(block.timestamp)
    );

    uint256 tSupply = pool.smooths();
    assertEq(share, tSupply);
    assertEq(address(pool).balance, 1.1 ether);
    assertEq(pool.totalETH(), 1 ether);

    vm.stopPrank();
  }

  function test_withdrawUnregistered() public {
    uint256 validatorIndex = 696862;
    pool = new SmoothlyPoolV2();
    vm.expectRevert(Unregistered.selector);
    pool.withdraw(new uint256[](0), new bytes32[](0), validatorIndex, 0);
  }

  function test_withdrawWithInvalidBlock() public {
    uint256 validatorIndex = 696862;
    uint64 timestamp = 1718573135; // Parent Root Block Timestamp
    Validator memory validator = validators[validatorIndex];
    validator.start = timestamp + 1 days;
    vm.expectRevert(InvalidBlockTimestamp.selector);
    if(validator.start == 0) { revert Unregistered(); }
    if(timestamp < validator.start) { revert InvalidBlockTimestamp(); } 
  }

  function test_withdrawTooEarly() public {
    uint256 validatorIndex = 696862;
    uint64 timestamp = 1718573135; // parent root block timestamp

    Validator memory validator = validators[validatorIndex];
    validator.start = timestamp - 3 days;
    validator.effectiveBalance = 32 gwei;

    vm.warp(timestamp + 2 days);
    vm.deal(address(this), 1.1 ether);
    vm.expectRevert(WithdrawalsDisabled.selector);

    lastRebalance = timestamp - 4 days;
    totalBond = BOND;
    totalEB = validator.effectiveBalance;

    _allocateSmooths(uint256(validator.effectiveBalance), timestamp - 3 days);

    if(validator.start == 0) { revert Unregistered(); }
    if(timestamp < validator.start) { revert InvalidBlockTimestamp(); } 
    /*
    oracle.verifyFeeRecipient(
      indices, 
      proof, 
      validatorIndex, 
      feeRecipient, 
      timestamp
    );*/

    _withdraw(validator);
  }

  function test_withdrawInvalidProof() public {
    uint256 validatorIndex = 696862;
    address feeRecipient = 0x95222290DD7278Aa3Ddd389Cc1E1d165CC4BAfe5; // Pool Address Mock
    proof = [
     bytes32(hex'552f83bef2164ede6e62b9f1c53cde415f057afcafecdd0a69abc6d47a2f4f71'),
     bytes32(hex'82eab58be968f51f0e05a6e2506361146e17fad78cdddda1e7ccb1ede1f8ecfd'),
     bytes32(hex'91eea28200b4f7e7f39e195e9bfa4406c388b038e7b1d793466f30c783a468d0'),
     bytes32(hex'c5a65260030c71839a5e56a6666a702ae163c4ee1bd1e90fffeee86e76dfa23d'),
     bytes32(hex'5842e447dc6a52c921c292f1c06fbf98fc39e123d0ea592b9fd98759eb01f28f'),
     bytes32(hex'71a6d6c6e7661c2db605750a399568a4cd7d224bada2f90e4139add65329445f'),
     bytes32(hex'b46f0c01805fe212e15907981b757e6c496b0cb06664224655613dcec82505bb'),
     bytes32(hex'db56114e00fdd4c1f85c892bf35ac9a89289aaecb1ebd0a96cde606a748b5d71'),
     bytes32(hex'5adf3630e082725d52ef90c24257302c20fbfb3c686b9dc9d89fd9eff8d0e345'),
     bytes32(hex'0000000000000000000000000000000000000000000000000000000000000000'),
     bytes32(hex'a9188e0000000000000000000000000000000000000000000000000000000000'),
     bytes32(hex'f5a5fd42d16a20302798ef6ed309979b43003d2320d9f0e8ea9831a92759fb4b'),
     bytes32(hex'ecaf4123f2be7f1f7b7eacf63997326dbed3ef925959daaaf9ae2c1d911c88ec')
    ];
    indices = [9, 6433];
    
    setBeaconBlockRoot(
      0x435835bed4c54a00490293e9935bccec7b248f5db7f9fe2fbfa34481fe80c916,
      block.timestamp 
    );

    vm.expectRevert(InvalidProof.selector);
    oracle.verifyFeeRecipient(
      indices, 
      proof, 
      validatorIndex, 
      feeRecipient, 
      uint64(block.timestamp) 
    );
  }

  function test_withdrawal() public {
    address feeRecipient = 0x95222290DD7278Aa3Ddd389Cc1E1d165CC4BAfe5; 
    uint256 validatorIndex = 696862;
    proof = [
     bytes32(hex'552f83bef2164ede6e62b9f1c53cde415f057afcafecdd0a69abc6d47a2f4f71'),
     bytes32(hex'82eab58be968f51f0e05a6e2506361146e17fad78cdddda1e7ccb1ede1f8ecfd'),
     bytes32(hex'91eea28200b4f7e7f39e195e9bfa4406c388b038e7b1d793466f30c783a468d0'),
     bytes32(hex'c5a65260030c71839a5e56a6666a702ae163c4ee1bd1e90fffeee86e76dfa23d'),
     bytes32(hex'5842e447dc6a52c921c292f1c06fbf98fc39e123d0ea592b9fd98759eb01f28f'),
     bytes32(hex'71a6d6c6e7661c2db605750a399568a4cd7d224bada2f90e4139add65329445f'),
     bytes32(hex'b46f0c01805fe212e15907981b757e6c496b0cb06664224655613dcec82505bb'),
     bytes32(hex'db56114e00fdd4c1f85c892bf35ac9a89289aaecb1ebd0a96cde606a748b5d71'),
     bytes32(hex'5adf3630e082725d52ef90c24257302c20fbfb3c686b9dc9d89fd9eff8d0e345'),
     bytes32(hex'0000000000000000000000000000000000000000000000000000000000000000'),
     bytes32(hex'a9188e0000000000000000000000000000000000000000000000000000000000'),
     bytes32(hex'f5a5fd42d16a20302798ef6ed309979b43003d2320d9f0e8ea9831a92759fb4b'),
     bytes32(hex'ecaf4123f2be7f1f7b7eacf63997326dbed3ef925959daaaf9ae2c1d911c88ec')
    ];
    indices = [9, 6433];
    setBeaconBlockRoot(
      0xab5835bed4c54a00490293e9935bccec7b248f5db7f9fe2fbfa34481fe80c916,
      block.timestamp 
    );

    Validator memory validator = validators[validatorIndex];
    validator.start = block.timestamp - 30 days;
    validator.withdrawal = address(1);
    validator.effectiveBalance = 32 gwei;
    validator.bond = 0.1 ether;

    totalBond += BOND;
    totalEB += validator.effectiveBalance;

    _allocateSmooths(uint256(validator.effectiveBalance), block.timestamp - 30 days);

    vm.deal(address(this), 1.1 ether);
    vm.deal(validator.withdrawal, 0);

    // Correct Withdrawal 
    if(validator.start == 0) { revert Unregistered(); }
    if(block.timestamp < validator.start) { revert InvalidBlockTimestamp(); } 
    oracle.verifyFeeRecipient(
      indices, 
      proof, 
      validatorIndex, 
      feeRecipient, 
      uint64(block.timestamp)
    );

    _withdraw(validator);

    assertEq(lastRebalance, block.timestamp);
    //assertEq(address(this).balance, 0.1 ether);
    //assertEq(validator.withdrawal.balance, 1 ether);
    assertEq(totalEB * (30 - 7), smooths);
    //console.log(smooths);
  }

  function setBeaconBlockRoot(bytes32 root, uint256 timestamp) public {
    address BEACON_ROOTS = 0x000F3df6D732807Ef1319fB7B8bB8522d0Beac02;
    uint256 HISTORY_BUFFER_LENGTH = 8191;
    bytes32 slot = bytes32(uint256(timestamp % HISTORY_BUFFER_LENGTH + HISTORY_BUFFER_LENGTH));
    vm.store(
      BEACON_ROOTS, 
      slot,
      root
    ); 
  }
}

