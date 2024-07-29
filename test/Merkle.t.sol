// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { Vm } from "forge-std/Vm.sol";
import { console } from "forge-std/console.sol";

import { Merkle } from "../src/libraries/Merkle.sol";

contract TestMerkle is Test {

  function test_MultiMerkleRoot() public {
   // TODO 
  }

  function test_HelperIndices() public {
    uint256[] memory helperIndices = new uint256[](64);
    uint256[] memory indices = new uint256[](3);
    indices[0] = 4;
    indices[1] = 10;
    indices[2] = 6;
    helperIndices[0] = 11;
    helperIndices[1] = 7;
    assertEq(helperIndices, Merkle.getHelperIndices(indices));
  }

  function test_BranchIndices() public {
    Merkle.getBranchIndices(10);
  }
}
