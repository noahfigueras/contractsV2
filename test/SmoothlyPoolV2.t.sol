// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { Vm } from "forge-std/Vm.sol";
import { console } from "forge-std/console.sol";

import { SmoothlyPoolV2 } from "../src/SmoothlyPoolV2.sol";
import { ISmoothlyPoolV2 } from "../src/interfaces/ISmoothlyPoolV2.sol";

import { SSZ } from "../src/SSZ.sol";

contract TestSmoothlyPoolV2 is Test, ISmoothlyPoolV2 {
  using stdJson for string;

  SmoothlyPoolV2 public pool;

  function setUp() public {
    pool = new SmoothlyPoolV2();
  }

  function test_registration() public {
    vm.startPrank(msg.sender);
    // Full share with 32 tokens
    uint256 share = 19353600 ether;
    address(pool).call{value: 1 ether}("");

    pool.register(400, 32 ether);

    uint256 tSupply = pool.smooths();
    SmoothlyPoolV2.Registrant memory r = pool.getRegistrant(400);
    vm.warp(8 days);
    pool.rebalance();
    (, uint256 eth, ) = pool.calculateEth(r);

    assertEq(share, tSupply);
    assertEq(eth, 1 ether);
    vm.stopPrank();
  }
}
