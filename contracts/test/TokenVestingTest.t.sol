// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "./config/BaseTest.t.sol";
import "../TokenVesting.sol";

contract TokenVestingTest is BaseTest {
    TokenVesting public tokenVesting;
    address alice = vm.addr(1);
    address bob = vm.addr(2);
    
    struct Vest {
        uint256 total;
        uint256 claimedAmount;
        bool isClaimed;
    }

    function setUp() public {
        tokenVesting = new TokenVesting();
    }

    function test_settingVestingAmounts() public {
        address[] memory addresses = new address[](2);
        addresses[0] = alice;
        addresses[1] = bob;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 700;
        amounts[1] = 300;

        vm.prank(tokenVesting.owner()); 
        tokenVesting.setVestingAmounts(1000, addresses, amounts);

        assertEq(tokenVesting.getVestingAmount(alice), 700);
        assertEq(tokenVesting.getVestingAmount(bob), 300);
    }

    function testFail_nonOwnerSettingVestingAmounts() public {
        address[] memory addresses = new address[](2);
        addresses[0] = alice;
        addresses[1] = bob;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 700;
        amounts[1] = 300;

        vm.prank(alice); 
        tokenVesting.setVestingAmounts(1000, addresses, amounts);
    }

    function testFail_totalClaimableSettingVestingAmounts() public {
        address[] memory addresses = new address[](2);
        addresses[0] = alice;
        addresses[1] = bob;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 700;
        amounts[1] = 300;

        vm.prank(tokenVesting.owner()); 
        tokenVesting.setVestingAmounts(900, addresses, amounts);
    }

    function test_start() public {
        vm.prank(tokenVesting.owner()); 
        tokenVesting.start();

        assertEq(tokenVesting.startTime(), block.timestamp);
    }

    function testFail_nonOwnerStart() public {
        vm.prank(alice); 
        tokenVesting.start();
    }

    function testFail_secondCallStart() public {
        vm.prank(tokenVesting.owner()); 
        tokenVesting.start();
        tokenVesting.start();
    }

    function test_claimableBeforeStart() public {
        tokenVesting.claimable(alice);
        address[] memory addresses = new address[](2);
        addresses[0] = alice;
        addresses[1] = bob;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 700;
        amounts[1] = 300;

        vm.prank(tokenVesting.owner()); 
        tokenVesting.setVestingAmounts(1000, addresses, amounts);

        assertEq(tokenVesting.getVestingAmount(alice), 700);
        assertEq(tokenVesting.getVestingAmount(bob), 300);

        assertEq(tokenVesting.claimable(alice), 0);
    }

    function test_claimableAfter1Day() public {
    	vm.startPrank(tokenVesting.owner()); 
    	address[] memory addresses = new address[](2);
        addresses[0] = alice;
        addresses[1] = bob;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 700;
        amounts[1] = 300;

        tokenVesting.setVestingAmounts(1000, addresses, amounts);
        tokenVesting.start();
        vm.stopPrank(); 

        vm.warp(86400);

        uint256 m = uint256(700)*90/100-uint256(700)*25/100;
        uint256 expectedAliceClaimableAmount = uint256(700)*25/100+m*1*86400/(90*86400);
        assertEq(tokenVesting.claimable(alice), expectedAliceClaimableAmount);
        uint256 mBob = uint256(300)*90/100-uint256(300)*25/100;
        uint256 expectedBobClaimableAmount = uint256(300)*25/100+mBob*1*86400/(90*86400);
        assertEq(tokenVesting.claimable(bob), expectedBobClaimableAmount);
    }

    function test_claimableAfter50Days() public {
    	vm.startPrank(tokenVesting.owner()); 
    	address[] memory addresses = new address[](2);
        addresses[0] = alice;
        addresses[1] = bob;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 700;
        amounts[1] = 300;

        tokenVesting.setVestingAmounts(1000, addresses, amounts);
        tokenVesting.start();
        vm.stopPrank(); 

        vm.warp(50*86400);

        uint256 m = uint256(700)*90/100-uint256(700)*25/100;
        uint256 expectedAliceClaimableAmount = uint256(700)*25/100+m*50*86400/(90*86400);
        assertEq(tokenVesting.claimable(alice), expectedAliceClaimableAmount);

        uint256 mBob = uint256(300)*90/100-uint256(300)*25/100;
        uint256 expectedBobClaimableAmount = uint256(300)*25/100+mBob*50*86400/(90*86400);
        assertEq(tokenVesting.claimable(bob), expectedBobClaimableAmount);
    }

    function test_claimableAfter90Days() public {
    	vm.startPrank(tokenVesting.owner()); 
    	address[] memory addresses = new address[](2);
        addresses[0] = alice;
        addresses[1] = bob;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 700;
        amounts[1] = 300;

        tokenVesting.setVestingAmounts(1000, addresses, amounts);
        tokenVesting.start();
        vm.stopPrank(); 

        vm.warp(10000000);

        uint256 expectedAliceClaimableAmount = 700;
        uint256 expectedBobClaimableAmount = 300;
        assertEq(tokenVesting.claimable(alice), expectedAliceClaimableAmount);
        assertEq(tokenVesting.claimable(bob), expectedBobClaimableAmount);
    }

    // TODO: Add tests for function claim()
}
