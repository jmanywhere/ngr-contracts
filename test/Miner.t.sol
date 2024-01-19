//SPDX-License-Identifier: MIT
pragma solidity 0.8.19;
import "forge-std/Test.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
// ---- Contracts to Test ----
import "../src/GrowMiner.sol";
import "../src/GROW.sol";

contract MinerTest is Test {
    GrowMiner miner;
    GrowToken grow;
    IERC20 usdt;

    address owner1 = makeAddr("owner1");
    address owner2 = makeAddr("owner2");

    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");

    address growOwner;

    function setUp() public {
        grow = GrowToken(0xA72f53ea4f3Cf19f1F6359E87E58221Bd0a7068b);
        usdt = IERC20(0x55d398326f99059fF775485246999027B3197955);

        growOwner = grow.owner();

        address[] memory _owners = new address[](2);
        _owners[0] = owner1;
        _owners[1] = owner2;

        vm.startPrank(0x8894E0a0c962CB723c1976a4421c95949bE2D4E3);
        usdt.transfer(user1, 1_000 ether);
        usdt.transfer(user2, 1_000 ether);
        vm.stopPrank();

        vm.deal(user1, 1 ether);
        vm.deal(user2, 1 ether);

        vm.startPrank(growOwner);
        miner = new GrowMiner(address(grow), address(usdt), _owners);

        grow.setExecutorAddress(address(miner), true);
        vm.stopPrank();

        vm.prank(user1);
        usdt.approve(address(miner), 1000 ether);
        vm.prank(user2);
        usdt.approve(address(miner), 1000 ether);
    }

    function test_pre_initialize() public {
        vm.expectRevert(GrowMiner__NotInitialized.selector);
        vm.prank(user1);
        miner.depositIntoMine(100 ether, address(0));
    }

    modifier initialized() {
        vm.prank(growOwner);
        miner.initializeMiner();
        _;
    }

    function test_deposit() public initialized {
        vm.prank(user1);
        miner.depositIntoMine(100 ether, user2);

        (
            uint miners,
            uint invested,
            uint redeemed,
            uint refEg,
            uint locked,
            uint last,
            address _ref
        ) = miner.user(user1);

        assertGt(miners, 0);
        assertGt(invested, 30 ether);
        assertEq(redeemed, 0);
        assertEq(refEg, 0);
        assertEq(locked, 0);
        assertEq(last, block.timestamp);
        // since user2 is not deposited, it doesn't count
        assertEq(_ref, address(0));
    }

    function test_claim() public initialized {
        vm.startPrank(user1);
        miner.depositIntoMine(100 ether, user2);

        skip(12 hours);

        uint eggs = miner.getEggsSinceLastHatch(user1);
        uint market = miner.marketEggs();
        assertEq(eggs, 10_000 * 12 hours);
        uint growBalance = grow.balanceOf(address(miner));
        uint growToUse = (eggs * growBalance) / (market + eggs);
        miner.claimFromMine();

        assertEq(grow.balanceOf(address(miner)), growBalance - growToUse);
        vm.stopPrank();
    }

    function test_referral() public initialized {
        vm.prank(user1);
        miner.depositIntoMine(100 ether, user2);

        vm.prank(user2);
        miner.depositIntoMine(100 ether, user1);

        (uint miners1, , , uint ref, , , ) = miner.user(user1);
        (uint miners2, , , , , , ) = miner.user(user2);

        assertGt(ref, 0);
        assertGt(miners1, miners2);
    }

    function test_liquidations() public initialized {
        vm.prank(user1);
        miner.depositIntoMine(100 ether, address(0));

        skip(6 hours);

        vm.prank(user2);
        miner.depositIntoMine(100 ether, address(0));

        skip(20 hours);

        address[] memory liquidatable;
        uint[] memory amounts;
        (liquidatable, amounts) = miner.getLiquidatableUsers();
        assertEq(liquidatable.length, 1);
        assertEq(liquidatable[0], user1);

        uint eggsUsed = miner.getEggs(user1);
        // Make sure 24 hour truncation happens
        assertEq(eggsUsed, 10_000 * 24 hours);

        uint growBalance = grow.balanceOf(address(miner));
        uint growUsed = (eggsUsed * growBalance) /
            (eggsUsed + miner.marketEggs());

        vm.prank(owner1);
        miner.liquidateUsers(liquidatable);
        uint newBal = grow.balanceOf(address(miner));
        assertEq(newBal, growBalance - growUsed);

        // Make sure that a user can't be liquidated twice
        // and user claiming immediately after liquidation makes no difference
        vm.expectRevert(GrowMiner__NoEggs.selector);
        vm.prank(user1);
        miner.claimFromMine();
        // Cant liquidate if under threshold
        skip(12 hours);
        vm.expectRevert(GrowMiner__NothingToLiquidate.selector);
        vm.prank(owner1);
        miner.liquidateUsers(liquidatable);

        assertEq(grow.balanceOf(address(miner)), newBal);
    }
}
