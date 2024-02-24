// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {UntrustedEscrow} from "../src/UntrustedEscrow.sol";
import {SanctionToken} from "../src/SanctionToken.sol";
import {GodToken} from "../src/GodToken.sol";
import {TokenTimelock} from "@openzeppelin/contracts/token/ERC20/utils/TokenTimelock.sol";

contract UntrustedEscrowTest is Test {
    event TimelockCreated(address indexed creator, address indexed token, address indexed beneficiary, uint256 amount);

    address private admin;
    address private bob;
    address private alice;
    UntrustedEscrow private escrow;
    SanctionToken private token1;
    GodToken private token2;

    function setUp() public {
        escrow = new UntrustedEscrow();
        admin = makeAddr("admin");
        bob = makeAddr("bob");
        alice = makeAddr("alice");
        token1 = new SanctionToken("S_Token", "SANC", admin);
        token2 = new GodToken("G_Token", "GOD", admin);
    }

    function test_Deposit() public {
        vm.startPrank(bob);
        token1.mint(bob, 10 ether);
        token1.approve(address(escrow), 2 ether);

        vm.expectEmit(address(escrow));
        emit TimelockCreated(bob, address(token1), alice, 2 ether);
        escrow.deposit(token1, alice, 2 ether);
    }

    function test_Withdraw() public {
        vm.startPrank(bob);
        token1.mint(bob, 10 ether);
        token1.approve(address(escrow), 2 ether);
        escrow.deposit(token1, alice, 2 ether);

        vm.warp(block.timestamp + 3 days);
        vm.startPrank(alice);
        TokenTimelock[] memory locks = escrow.getAllTimelocks();
        assertEq(locks.length, 1);

        assertEq(locks[0].beneficiary(), alice);
        escrow.withdraw(locks[0]);
        assertEq(token1.balanceOf(alice), 2 ether);
    }

    function test_WithdrawAll_AllWithdrawn() public {
        vm.startPrank(bob);
        token1.mint(bob, 10 ether);
        token1.approve(address(escrow), 2 ether);
        escrow.deposit(token1, alice, 2 ether);

        token2.mint(bob, 10 ether);
        token2.approve(address(escrow), 2 ether);
        escrow.deposit(token2, alice, 2 ether);

        vm.warp(block.timestamp + 4 days);
        vm.startPrank(alice);
        escrow.withdrawAll();

        assertEq(token1.balanceOf(alice), 2 ether);
        assertEq(token2.balanceOf(alice), 2 ether);
    }

    function test_GetAllTimeLocks() public {
        vm.startPrank(bob);
        token1.mint(bob, 10 ether);
        token1.approve(address(escrow), 2 ether);
        escrow.deposit(token1, alice, 2 ether);

        token2.mint(bob, 10 ether);
        token2.approve(address(escrow), 2 ether);
        escrow.deposit(token2, alice, 2 ether);

        vm.startPrank(alice);
        TokenTimelock[] memory locks = escrow.getAllTimelocks();
        assertEq(locks.length, 2);

        escrow.withdrawAll();
        locks = escrow.getAllTimelocks();
        assertEq(locks.length, 2);
    }

    function test_WithdrawAll_WithdrawInTwoSteps() public {
        vm.startPrank(bob);
        token1.mint(bob, 10 ether);
        token1.approve(address(escrow), 2 ether);
        escrow.deposit(token1, alice, 2 ether);

        token2.mint(bob, 10 ether);
        token2.approve(address(escrow), 3 ether);
        escrow.deposit(token2, alice, 3 ether);

        vm.warp(block.timestamp + 2 days);

        token2.approve(address(escrow), 2 ether);
        escrow.deposit(token2, alice, 2 ether);

        vm.warp(block.timestamp + 2 days);

        vm.startPrank(alice);
        escrow.withdrawAll();
        assertEq(token1.balanceOf(alice), 2 ether);
        assertEq(token2.balanceOf(alice), 3 ether);

        vm.warp(block.timestamp + 1 days);

        escrow.withdrawAll();
        assertEq(token1.balanceOf(alice), 2 ether);
        assertEq(token2.balanceOf(alice), 5 ether);
    }
}
