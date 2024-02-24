// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {SanctionToken} from "../src/SanctionToken.sol";

contract SanctionTokenTest is Test {
    event AdminUpdated(address newAdmin);
    event Sanctioned(address);
    event SanctionLifted(address);

    SanctionToken private token;
    address private admin;

    function setUp() public {
        admin = makeAddr("admin");
        token = new SanctionToken("S_Token", "SANC", admin);
    }

    function test_UpdateAdmin() public {
        address bob = makeAddr("bob");
        vm.prank(token.owner());
        vm.expectEmit(address(token));
        emit AdminUpdated(bob);
        token.updateAdmin(bob);
    }

    function test_Mint_AnyoneCanMint() public {
        address bob = makeAddr("bob");
        vm.prank(bob);

        token.mint(bob, 1 ether);

        assertEq(token.balanceOf(bob), 1 ether);
    }

    function test_Sanction_AdminCanSanction() public {
        address bob = makeAddr("bob");
        address alice = makeAddr("alice");
        token.mint(bob, 1 ether);

        vm.prank(admin);
        vm.expectEmit(address(token));
        emit Sanctioned(bob);
        token.sanction(bob);

        // cannot send
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(SanctionToken.SanctionedSender.selector, bob));
        token.transfer(alice, 0.5 ether);

        // cannot receive (mint)
        vm.expectRevert(abi.encodeWithSelector(SanctionToken.SanctionedReceiver.selector, bob));
        token.mint(bob, 1 ether);
    }

    function test_Sanction_AdminCanLiftSanction() public {
        address bob = makeAddr("bob");
        address alice = makeAddr("alice");
        token.mint(bob, 1 ether);

        vm.prank(admin);
        token.sanction(bob);

        vm.expectEmit(address(token));
        emit SanctionLifted(bob);
        vm.prank(admin);
        token.unsanction(bob);

        // can send
        vm.prank(bob);
        token.transfer(alice, 0.5 ether);
        assertEq(token.balanceOf(alice), 0.5 ether);
        assertEq(token.balanceOf(bob), 0.5 ether);

        // can receive (mint)
        token.mint(bob, 1 ether);
        assertEq(token.balanceOf(bob), 1.5 ether);
    }
}
