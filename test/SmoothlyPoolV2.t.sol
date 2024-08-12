// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { Vm } from "forge-std/Vm.sol";
import { console } from "forge-std/console.sol";

import { SmoothlyPoolV2 } from "../src/SmoothlyPoolV2.sol";
import { ISmoothlyPoolV2 } from "../src/interfaces/ISmoothlyPoolV2.sol";

import { SSZ } from "../src/libraries/SSZ.sol";

contract TestSmoothlyPoolV2 is Test, ISmoothlyPoolV2, SmoothlyPoolV2 {
  using stdJson for string;

  string FORK_URL = vm.envString("MAINNET_FORK");
  uint256 fork;

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
  }

  function test_register() public {
    //vm.rollFork(19688741); // One over 19683121 (verifying block)
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

  function test_withdraw() public {
    vm.rollFork(19688741); // One over 19683121 (verifying block)
    uint64 vIndex = 465789;
    vm.warp(0);
    pool = new SmoothlyPoolV2();
    vm.prank(address(0xbe2C1805CcD7f4Ae97457A6C90dfDD5542364A09));
    pool.register{value: 0.1 ether}(
      vIndex, 
      registrationProof.validatorProof,
      registrationProof.validator,
      registrationProof.gIndex,
      registrationProof.timestamp
    );

    vm.rollFork(18994311);
    vm.warp(8 days);
    // Actual fee_recipient field of mainnet_slot
    // Make also address of pool for testing verification
    address payable mockFeeRecipient = payable(0x95222290DD7278Aa3Ddd389Cc1E1d165CC4BAfe5);
    vm.etch(mockFeeRecipient, address(pool).code);
    pool = SmoothlyPoolV2(mockFeeRecipient);
    vm.deal(address(pool), 0);
    (bool success,) = address(pool).call{value: 1.1 ether}("");
    require(success);


    /*
    vm.warp(block.timestamp + 8 days);
    pool.withdraw(new uint256[](1), new bytes32[](1), vIndex, 0, 0);
    assertEq(pool.totalETH(), 0 ether);
    assertEq(address(pool).balance, 0.1 ether);
   */
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
