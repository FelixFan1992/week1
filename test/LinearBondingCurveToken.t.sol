// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {LinearBondingCurveToken} from "../src/LinearBondingCurveToken.sol";

contract LinearBondingCurveTokenTest is Test {
    LinearBondingCurveToken private token;

    function setUp() public {
        token = new LinearBondingCurveToken("B_Token", "BOND", 50);
    }

    function test_Mint() public {
        address bob = makeAddr("bob");
        vm.expectRevert("not enough ether");
        token.mint(bob, 1 ether);

        token.mint{value: 0.25 ether}(bob, 1 ether);
        assertEq(token.balanceOf(bob), 1 ether);

        vm.expectRevert("not enough ether");
        token.mint{value: 0.25 ether}(bob, 1 ether);

        token.mint{value: 0.75 ether}(bob, 1 ether);
        assertEq(token.balanceOf(bob), 2 ether);
    }

    function test_Burn() public {
        address bob = makeAddr("bob");
        vm.deal(bob, 100 ether);

        vm.startPrank(bob);
        token.mint{value: 25 ether}(bob, 10 ether);
        assertEq(token.balanceOf(bob), 10 ether);

        vm.roll(block.number + 1);
        token.burn(10 ether);

        assertEq(token.balanceOf(bob), 0);
        assertEq(address(bob).balance, 100 ether);
    }

    function test_BurnFrom() public {
        address bob = makeAddr("bob");
        address alice = makeAddr("alice");
        vm.deal(bob, 100 ether);

        vm.startPrank(bob);
        token.mint{value: 25 ether}(bob, 10 ether);
        token.approve(alice, 5 ether);

        vm.startPrank(alice);
        vm.roll(block.number + 1);
        token.burnFrom(bob, 5 ether);

        assertEq(token.balanceOf(bob), 5 ether);
        // 75 + (10 * 10 - 5 * 5) / 4
        assertEq(address(bob).balance, 93.75 ether);
    }
}
