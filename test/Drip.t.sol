// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import "openzeppelin/token/ERC20/IERC20.sol";
import "../src/GrowDrip.sol";
import "../src/GROW.sol";

contract Test_Drip is Test {
    GrowToken grow;
    GrowDrip drip;
    IERC20 USDT;

    // Binance Hot wallet of USDT
    address usdtWhale = 0xF977814e90dA44bFA03b6295A0616a897441aceC;
    address mainOwner = 0xF38d66f68b7B9570d196DAEF5C5c1a58BA5597e8;
    address owner1 = makeAddr("owner1");
    address owner2 = makeAddr("owner2");
    address owner3 = makeAddr("owner3");

    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    address user3 = makeAddr("user3");

    //-----------------------------------------------------------------------------------
    // Events to test
    //-----------------------------------------------------------------------------------
    event Deposit(
        address indexed from,
        uint depositAmount,
        uint growAmount,
        uint timestamp
    );
    event Claim(
        address indexed from,
        uint growUsed,
        uint totalClaim,
        uint timestamp
    );

    function setUp() public {
        grow = GrowToken(0xA72f53ea4f3Cf19f1F6359E87E58221Bd0a7068b);
        USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
        address[] memory _owners = new address[](3);
        _owners[0] = owner1;
        _owners[1] = owner2;
        _owners[2] = owner3;

        uint[] memory shares = new uint[](3);
        shares[0] = 225;
        shares[1] = 225;
        shares[2] = 50;

        vm.startPrank(usdtWhale);
        USDT.transfer(user1, 1_000 ether);
        USDT.transfer(user2, 1_000 ether);
        USDT.transfer(user3, 1_000 ether);
        vm.stopPrank();

        drip = new GrowDrip(address(USDT), address(grow), _owners, shares);
        //  Need to make drip an executor AND make it fee exempt so it can handle the fees itself
        vm.startPrank(mainOwner);
        grow.setExecutorAddress(address(drip), true);
        grow.setFeeExemption(address(drip), true);
        vm.stopPrank();
        // Make user have an approved balance of USDT
        vm.prank(user1);
        USDT.approve(address(drip), 1_000 ether);
        vm.prank(user2);
        USDT.approve(address(drip), 1_000 ether);
        vm.prank(user3);
        USDT.approve(address(drip), 1_000 ether);
    }

    function test_deposit() public {
        uint growAmount = grow.calculatePrice();
        growAmount = ((90 ether) * 1 ether) / growAmount;
        growAmount -= 100;
        uint ownerTax = (growAmount * 5) / 90;
        uint taxUsed = (ownerTax * 225) / 500;
        taxUsed += (ownerTax * 225) / 500;
        taxUsed += (ownerTax * 50) / 500;

        growAmount -= taxUsed;
        vm.prank(user1);
        vm.expectEmit(true, false, false, false);
        emit Deposit(user1, 100 ether, growAmount, block.timestamp);
        drip.deposit(100 ether);

        //  Assertions
        (
            uint deposits,
            uint _grow,
            uint timestamp,
            uint totalClaim,
            uint pos
        ) = drip.users(user1);
        assertEq(deposits, 100 ether);
        assertLt(growAmount - _grow, 1_000);
        assertEq(timestamp, block.timestamp);
        assertEq(totalClaim, 0);
        assertEq(pos, 0);

        vm.prank(user2);
        drip.deposit(120 ether);

        (deposits, , timestamp, totalClaim, pos) = drip.users(user2);
        assertEq(deposits, 120 ether);
        assertEq(timestamp, block.timestamp);
        assertEq(totalClaim, 0);
        assertEq(pos, 1);
    }

    function test_deposit_quit() public {
        vm.prank(user1);
        drip.deposit(100 ether);

        vm.prank(user1);
        drip.quit();

        (uint deposits, , , , ) = drip.users(user1);
        assertEq(deposits, 0);

        vm.prank(user1);
        vm.expectRevert(GrowDrip__InvalidOperation.selector);
        drip.quit();
    }

    function test_claimable() public {
        vm.prank(user1);
        drip.deposit(100 ether);

        uint snap = vm.snapshot();
        uint claimable = 0;
        skip(25 hours);

        (claimable, , ) = drip.claimable(user1);
        assertEq(claimable, 0.5 ether);

        vm.revertTo(snap);

        skip(12 hours);
        (claimable, , ) = drip.claimable(user1);
        // assertEq(claimable, 0.25 ether);
        skip(52 weeks);
        (claimable, , ) = drip.claimable(user1);
        assertEq(claimable, 0.5 ether);
    }

    function test_self_claim() public {
        vm.prank(user1);
        drip.deposit(100 ether);

        (, uint growAmount, , , ) = drip.users(user1);

        skip(25 hours);

        vm.prank(user1);
        drip.claim();

        (, uint nextGrowAmount, , uint totalClaim, ) = drip.users(user1);
        assertLt(nextGrowAmount, growAmount);
        totalClaim = 0.5 ether - totalClaim;
        assertLt(totalClaim, 1000);
    }

    function test_liquidations() public {
        vm.prank(user1);
        drip.deposit(100 ether);

        skip(5 hours);

        vm.prank(user2);
        drip.deposit(100 ether);

        skip(20 hours);

        (address[] memory pendingusers, uint[] memory rewards) = drip
            .usersPendingLiquidation();

        // assertEq(pendingusers.length, 1);
        assertEq(pendingusers[0], user1);
        uint approxReward = 0.1 ether - rewards[0];
        assertLt(approxReward, 10000);

        vm.prank(user2);
        drip.liquidateUsers(pendingusers);

        (, , , uint totalClaim, ) = drip.users(user1);
        assertLt(totalClaim, 0.4 ether);
        assertGt(drip.liquidatorEarnings(user2), 0);
        assertGt(USDT.balanceOf(user2), 900 ether);
    }
}
