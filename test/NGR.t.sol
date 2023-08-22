// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import "openzeppelin/token/ERC20/presets/ERC20PresetFixedSupply.sol";
import "../src/NGR.sol";

contract CounterTest is Test {
    NGR public ngr;
    ERC20PresetFixedSupply public usdt;
    address owner1 = makeAddr("owner1");
    address owner2 = makeAddr("owner2");
    address owner3 = makeAddr("owner3");
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    address user3 = makeAddr("user3");
    address user4 = makeAddr("user4");
    address liq = makeAddr("liq");

    uint MIN_DEPOSIT = 5 ether;
    uint MAX_DEPOSIT = 1_000 ether;

    event Liquidate(address indexed user, uint amount);

    function setUp() public {
        usdt = new ERC20PresetFixedSupply(
            "USDT",
            "USDT",
            1_000_000 ether,
            address(this)
        );
        address[] memory owners = new address[](3);
        owners[0] = owner1;
        owners[1] = owner2;
        owners[2] = owner3;
        ngr = new NGR(address(usdt), liq, owners);
        owners = new address[](4);
        owners[0] = user1;
        owners[1] = user2;
        owners[2] = user3;
        owners[3] = user4;

        for (uint i = 0; i < owners.length; i++) {
            vm.deal(owners[i], 100 ether);
            usdt.transfer(owners[i], 10_000 ether);
            vm.prank(owners[i]);
            usdt.approve(address(ngr), 10_000 ether);
        }
    }

    function test_seed() public {
        usdt.approve(address(ngr), 10_000 ether);
        ngr.seed(1 ether);
        assertEq(ngr.currentSparks(), 0.97 ether);
        assertEq(usdt.balanceOf(address(ngr)), 0.994 ether);
        ngr.seed(1 ether);
        ngr.seed(1 ether);
        ngr.seed(1 ether);
        ngr.seed(1 ether);
        ngr.seed(1 ether);
        ngr.seed(1 ether);
        assertEq(ngr.totalPositions(), 0);
        assertEq(ngr.currentSparks(), 6.532838391539474389 ether);
    }

    modifier seed() {
        usdt.approve(address(ngr), 3_000 ether);
        ngr.seed(1 ether);
        ngr.seed(1 ether);
        ngr.seed(1 ether);
        ngr.seed(1 ether);
        ngr.seed(1 ether);
        ngr.seed(1 ether);
        ngr.seed(1 ether);
        _;
    }

    function test_deposit() public {
        vm.prank(user1);
        ngr.deposit(MIN_DEPOSIT, false);

        assertEq(ngr.totalPositions(), 1);
        (
            address user,
            uint initialDeposit,
            uint helixAmount,
            uint depositTime,
            uint liquidationPrice,
            uint liquidationCycle,
            bool redeposit,
            bool liquidated
        ) = ngr.positions(1);

        assertEq(liquidationCycle, 0);
        assertEq(redeposit, false);
        assertEq(liquidated, false);
        assertEq(user, user1);
        assertEq(initialDeposit, MIN_DEPOSIT);
        uint expectedHelix = uint(0.97 ether * MIN_DEPOSIT) /
            uint((1.1 ether * 909) / 1000);
        assertEq(helixAmount, expectedHelix);
        assertEq(depositTime, block.timestamp);
        assertEq(ngr.currentSparks(), 4.85 ether);
        uint theoreticalEndLiquidation = ((1.1 ether * 30 * 12) / 10000) +
            1.1 ether;
        theoreticalEndLiquidation =
            theoreticalEndLiquidation -
            ((theoreticalEndLiquidation * 6) / 10000);
        assertEq(liquidationPrice, theoreticalEndLiquidation);

        assertEq(usdt.balanceOf(address(ngr)), (MIN_DEPOSIT * 994) / 1000);
    }

    function test_liquidations() public seed {
        vm.startPrank(user1);
        ngr.deposit(898 ether, false);
        ngr.deposit(875 ether, false);
        ngr.deposit(530 ether, false);
        ngr.deposit(345 ether, false);
        vm.startPrank(user2);
        ngr.deposit(361 ether, false);
        ngr.deposit(900 ether, false);
        ngr.deposit(115 ether, false);
        ngr.deposit(604 ether, false);
        vm.startPrank(user3);
        ngr.deposit(739 ether, false);
        ngr.deposit(326 ether, false);
        ngr.deposit(682 ether, false);
        vm.stopPrank();
        vm.prank(user4);
        ngr.deposit(201 ether, false);

        (, , , , uint liqPrice, uint cycle, , ) = ngr.positions(1);
        console.log(
            "currentPrice: %s, cycle: %s",
            ngr.currentHelixPrice(),
            ngr.cycleCounter()
        );
        console.log("Liquidation Price: %s, cycle: %s", liqPrice, cycle);
        assertEq(ngr.canLiquidate(), true);

        vm.expectEmit();
        emit Liquidate(user1, 951.88 ether);
        ngr.liquidate();
        assertEq(ngr.canLiquidate(), true);
    }
}
