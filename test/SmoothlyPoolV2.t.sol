// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { Vm } from "forge-std/Vm.sol";
import { console } from "forge-std/console.sol";

import { SmoothlyPoolV2 } from "../src/SmoothlyPoolV2.sol";
import { ISmoothlyPoolV2 } from "../src/interfaces/ISmoothlyPoolV2.sol";

import { SSZ } from "../src/libraries/SSZ.sol";

contract TestSmoothlyPoolV2 is Test, ISmoothlyPoolV2 {
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
  }

  function test_registration() public {
    vm.selectFork(fork);
    vm.rollFork(19688741); // One over 19683121 (verifying block)
    pool = new SmoothlyPoolV2();
    // Full share with 32 tokens
    uint256 share = 19353600000000000;
    (bool success,) = address(pool).call{value: 1 ether}("");
    require(success);

    uint64 vIndex = 465789;
    vm.prank(address(0xbe2C1805CcD7f4Ae97457A6C90dfDD5542364A09));
    pool.register{value: 0.1 ether}(
      vIndex, 
      registrationProof.validatorProof,
      registrationProof.validator,
      registrationProof.gIndex,
      registrationProof.timestamp
    );

    uint256 tSupply = pool.smooths();
    SmoothlyPoolV2.Registrant memory r = pool.getRegistrant(vIndex);
    assertEq(share, tSupply);

    vm.warp(block.timestamp + 8 days);
    pool.rebalance();
    (uint256 eth, ) = pool.calculateEth(r);

    assertEq(eth, 1 ether);
    assertEq(address(pool).balance, 1.1 ether);
    vm.stopPrank();
  }

}
