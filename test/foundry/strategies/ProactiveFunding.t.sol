// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import "forge-std/Test.sol";

import {ProactiveFunding} from "../../../contracts/strategies/proactive-funding/ProactiveFunding.sol";
import {ProactiveFundingVoucher} from "../../../contracts/strategies/proactive-funding/ProactiveFundingVoucher.sol";
import {Errors} from "../../../contracts/core/libraries/Errors.sol";
import {Native} from "../../../contracts/core/libraries/Native.sol";
import {Metadata} from "../../../contracts/core/libraries/Metadata.sol";

import {AlloSetup} from "../shared/AlloSetup.sol";
import {RegistrySetupFull} from "../shared/RegistrySetup.sol";
import {EventSetup} from "../shared/EventSetup.sol";
import {MockERC20} from "../../utils/MockERC20.sol";

contract ProactiveFundingTest is Test, AlloSetup, RegistrySetupFull, EventSetup, Native, Errors {
    ProactiveFunding internal strategy;
    ProactiveFundingVoucher internal voucher;
    MockERC20 internal mockERC20;
    uint256 internal poolId;
    Metadata internal poolMetadata;

    event DirectAllocated(
        bytes32 indexed profileId, address profileOwner, uint256 amount, address token, address sender
    );
    event VoucherClaimed(uint256 indexed tokenId, address indexed recipient);

    function setUp() public {
        __RegistrySetupFull();
        __AlloSetup(address(registry()));

        strategy = ProactiveFunding(_deployStrategy());
        mockERC20 = new MockERC20();
        mockERC20.mint(address(this), 1_000_000 * 1e18);
        mockERC20.mint(address(strategy), 1_000_000 * 1e18);
        poolMetadata = Metadata({protocol: 1, pointer: "PoolMetadata"});

        vm.prank(pool_admin());
        poolId = allo().createPoolWithCustomStrategy(
            poolProfile_id(),
            address(strategy),
            bytes("0"),
            address(mockERC20),
            0,
            poolMetadata,
            pool_managers()
        );

        // Get the voucher contract address after initialization
        voucher = ProactiveFundingVoucher(strategy.voucher());
    }

    function _deployStrategy() internal virtual returns (address payable) {
        return payable(address(new ProactiveFunding(address(allo()), "ProactiveFundingStrategy")));
    }

    function test_initialize() public {
        assertEq(strategy.getPoolId(), poolId);
        assertTrue(address(strategy.voucher()) != address(0));
    }
    function test_allocate() public {
        console.log("Starting test_allocate");
        
        uint256 amount = strategy.HOURLY_RATE() * strategy.HOURS_PER_VOUCHER();
        console.log("Calculated amount:", amount);
        
        mockERC20.approve(address(strategy), amount);
        console.log("Approved strategy to spend amount");

        bytes memory data = abi.encode(address(this), address(mockERC20), 1);
        console.log("Encoded allocation data");
        
        uint256 voucherCountBefore = voucher.totalSupply();
        console.log("Initial voucher count:", voucherCountBefore);
        
        uint256 balanceBefore = mockERC20.balanceOf(address(this));
        console.log("Initial balance:", balanceBefore);

        console.log("Calling allocate on Allo contract");
        allo().allocate(poolId, data);
        console.log("Allocation complete");

        uint256 voucherCountAfter = voucher.totalSupply();
        console.log("Final voucher count:", voucherCountAfter);
        
        uint256 balanceAfter = mockERC20.balanceOf(address(this));
        console.log("Final balance:", balanceAfter);

        console.log("Checking assertions...");
        assertEq(voucherCountAfter, voucherCountBefore + 1);
        assertEq(balanceAfter, balanceBefore + amount);
        assertTrue(voucher.ownerOf(1) == address(strategy));
        console.log("All assertions passed");
    }

    function test_claimVoucher() public {
        console.log("Starting test_claimVoucher");

        address worker = makeAddr("worker");
        console.log("Created worker address:", worker);

        // First allocate to create a voucher
        uint256 amount = strategy.HOURLY_RATE() * strategy.HOURS_PER_VOUCHER();
        console.log("Calculated amount:", amount);

        mockERC20.approve(address(strategy), amount);
        console.log("Approved strategy to spend amount");

        bytes memory data = abi.encode(worker, address(mockERC20), 1);
        console.log("Encoded allocation data");

        console.log("Calling allocate to create voucher");
        allo().allocate(poolId, data);
        console.log("Allocation complete");

        uint256 tokenId = 1; // First voucher ID
        console.log("Using tokenId:", tokenId);
        
        console.log("Current voucher owner:", voucher.ownerOf(tokenId));
        console.log("Worker for token:", voucher.tokenToWorker(tokenId));
        console.log("Attempting to claim as:", worker);
        
        vm.expectEmit(true, true, true, true);
        emit VoucherClaimed(tokenId, worker);
        
        vm.prank(worker);
        console.log("Claiming voucher");
        strategy.claimVoucher(tokenId);
        console.log("Claim complete");
        
        address newOwner = voucher.ownerOf(tokenId);
        console.log("New voucher owner:", newOwner);
        
        assertEq(newOwner, worker);
        console.log("Test complete");
    }

    function test_claimVoucher_revert_InvalidVoucher() public {
        vm.expectRevert(ProactiveFunding.InvalidVoucher.selector);
        strategy.claimVoucher(999); // Non-existent voucher
    }

    function test_claimVoucher_revert_UnauthorizedClaim() public {
        // First allocate to create a voucher
        uint256 amount = strategy.HOURLY_RATE() * strategy.HOURS_PER_VOUCHER();
        mockERC20.approve(address(strategy), amount);
        bytes memory data = abi.encode(address(this), address(mockERC20), 1);
        allo().allocate(poolId, data);

        uint256 tokenId = 1;
        
        // Try to claim with different address
        vm.prank(address(0xdead));
        vm.expectRevert(ProactiveFunding.UnauthorizedClaim.selector);
        strategy.claimVoucher(tokenId);
    }

    function test_withdraw() public {
        uint256 amount = 1000;
        mockERC20.transfer(address(strategy), amount);

        uint256 balanceBefore = mockERC20.balanceOf(pool_admin());

        vm.prank(pool_admin());
        strategy.withdraw(address(mockERC20), pool_admin());

        uint256 balanceAfter = mockERC20.balanceOf(pool_admin());

        assertEq(balanceAfter, balanceBefore + amount+ 1_000_000 * 1e18);
        assertEq(mockERC20.balanceOf(address(strategy)), 0);
    }

    function test_withdraw_revert_UNAUTHORIZED() public {
        mockERC20.transfer(address(strategy), 1000);

        vm.expectRevert(UNAUTHORIZED.selector);
        strategy.withdraw(address(mockERC20), pool_admin());
    }
} 