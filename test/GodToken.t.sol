// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {GodToken} from "../src/GodToken.sol";

contract GodTokenTest is Test {
    event AdminUpdated(address newAdmin);

    GodToken private token;
    address private admin;

    function setUp() public {
        admin = makeAddr("admin");
        token = new GodToken("G_Token", "GOD", admin);
    }

    function test_UpdateAdmin() public {
        address bob = makeAddr("bob");
        vm.prank(token.owner());
        vm.expectEmit(address(token));
        emit AdminUpdated(bob);
        token.updateAdmin(bob);
    }

    function test_Transfer_AdminDoesNotNeedAllowance() public {
        address bob = makeAddr("bob");
        token.mint(bob, 2 ether);

        vm.prank(admin);
        token.transferFrom(bob, admin, 1 ether);

        assertEq(token.balanceOf(bob), 1 ether);
        assertEq(token.balanceOf(admin), 1 ether);
    }

    function test_Transfer_RegularOperatorNeedAllowance() public {
        address bob = makeAddr("bob");
        address alice = makeAddr("alice");
        token.mint(bob, 2 ether);

        vm.prank(alice);
        vm.expectRevert("ERC20: insufficient allowance");
        token.transferFrom(bob, admin, 1 ether);

        vm.prank(bob);
        token.approve(alice, 1 ether);
        vm.prank(alice);
        token.transferFrom(bob, admin, 1 ether);
        assertEq(token.balanceOf(bob), 1 ether);
        assertEq(token.balanceOf(admin), 1 ether);
    }
}
