// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { Vm } from "forge-std/Vm.sol";
import { console } from "forge-std/console.sol";

import { Merkle } from "../src/libraries/Merkle.sol";
import { Arrays } from "../src/libraries/Arrays.sol";

contract TestMerkle is Test {
  using Arrays for uint256[];

  function test_MultiMerkleRoot() public {
   // TODO 
  }

  function test_HelperIndices() public {
    uint256[] memory helperIndices = new uint256[](2);
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

  function test_Arrays() public {
    uint256[] memory test = new uint256[](1);
    uint256[] memory cmp = new uint256[](2);
    cmp[0] = 1;
    cmp[1] = 2;
    test[0] = cmp[0];
    assertEq(cmp, test.push(2));
    assertEq(cmp.pop(), test);

    uint256[] memory test2 = new uint256[](2);
    uint256[] memory add = new uint256[](2);
    uint256[] memory cmp2 = new uint256[](4);
    cmp2[0] = 1;
    cmp2[1] = 2;
    cmp2[2] = 3;
    cmp2[3] = 4;
    test2[0] = 1;
    test2[1] = 2;
    add[0] = 3;
    add[1] = 4;
    assertEq(cmp2, test2.concat(add));
  }
}
