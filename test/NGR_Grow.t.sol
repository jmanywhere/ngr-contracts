// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import "forge-std/Test.sol";
import "openzeppelin/token/ERC20/presets/ERC20PresetFixedSupply.sol";
import "../src/GROW.sol";
import "../src/NGR_Grow.sol";

contract NGR_w_Grow is Test {
    ERC20PresetFixedSupply usdt;
    GrowToken grow;
    NGR_with_Grow ngr;

    address devWallet = makeAddr("devWallet");
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    address user3 = makeAddr("user3");
    address burner = makeAddr("burner");

    address owner1 = makeAddr("owner1");
    address owner2 = makeAddr("owner2");
    address owner3 = makeAddr("owner3");

    // ------------------------------------------------
    // Events
    // ------------------------------------------------
    event Deposit(
        address indexed owner,
        uint indexed position,
        uint amount,
        uint helixBought
    );

    function setUp() public {
        usdt = new ERC20PresetFixedSupply(
            "USDT",
            "USDT",
            1_000_000 ether,
            address(this)
        );
        address[] memory stables = new address[](1);
        stables[0] = address(usdt);
        address[] memory owners = new address[](3);
        owners[0] = owner1;
        owners[1] = owner2;
        owners[2] = owner3;
        uint[] memory shares = new uint[](3);
        shares[0] = 45;
        shares[1] = 35;
        shares[2] = 20;

        usdt.transfer(user1, 1_000 ether);
        usdt.transfer(user2, 1_000 ether);
        usdt.transfer(user3, 1_000 ether);

        grow = new GrowToken(stables, owners, shares, devWallet);
        usdt.transfer(address(grow), 1 ether);
        usdt.transfer(burner, 10_000 ether);

        ngr = new NGR_with_Grow(
            address(grow),
            address(usdt),
            devWallet,
            burner
        );
        usdt.approve(address(ngr), type(uint).max);
        vm.prank(burner);
        usdt.approve(address(ngr), type(uint).max);

        grow.setExecutorAddress(address(ngr), true);

        vm.prank(user1);
        usdt.approve(address(ngr), type(uint).max);
        vm.prank(user2);
        usdt.approve(address(ngr), type(uint).max);
        vm.prank(user3);
        usdt.approve(address(ngr), type(uint).max);
    }

    function test_deposit() public {
        vm.expectEmit();
        emit Deposit(user1, 0, 10 ether, 9.6 ether);
        vm.prank(user1);
        ngr.deposit(10 ether, false);

        (
            address owner,
            uint depositTime,
            uint liqTime,
            uint amountDeposited,
            uint helix,
            uint liqPrice,
            uint liquidatedAmount,
            bool isLiq,
            bool early
        ) = ngr.positions(0);
        assertEq(owner, user1);
        assertEq(depositTime, block.timestamp);
        assertEq(liqTime, 0);
        assertEq(liquidatedAmount, 0);
        assertEq(amountDeposited, 10 ether);
        assertEq(helix, 9.6 ether);
        assertEq(liqPrice, 1_128472222222222222);
        assertEq(isLiq, false);
        assertEq(early, false);

        assertGt(grow.balanceOf(owner1), (10 ether * 45) / 100_00);
        assertGt(grow.balanceOf(owner2), (10 ether * 35) / 100_00);
        assertGt(grow.balanceOf(owner3), (10 ether * 20) / 100_00);

        uint totalDeposits = ngr.totalDeposits();
        assertEq(totalDeposits, 10 ether);
        uint totalLiquidations = ngr.totalLiquidations();
        assertEq(totalLiquidations, 0);
        assertEq(usdt.balanceOf(address(grow)), 13 ether);
    }

    function test_early_exit() public {
        vm.startPrank(user1);
        ngr.deposit(10 ether, false);

        uint u1Balance = usdt.balanceOf(user1);

        vm.expectRevert(NGR_GROW__InvalidWithdraw.selector);
        ngr.earlyExit(1);

        skip(1 days);

        ngr.earlyExit(0);

        (, , uint liqTime, , , , , bool isLiq, bool early) = ngr.positions(0);
        assertEq(liqTime, block.timestamp);
        assertEq(isLiq, true);
        assertEq(early, true);

        assertEq(usdt.balanceOf(user1), u1Balance + 9.2 ether);
        assertGt(usdt.balanceOf(devWallet), 0);
    }

    function test_self_liquidate() public {
        vm.startPrank(user1);
        ngr.deposit(10 ether, false);

        uint u1Balance = usdt.balanceOf(user1);

        vm.expectRevert(NGR_GROW__InvalidWithdraw.selector);
        // ngr.liquidateSelf(1);

        skip(1 days);

        vm.startPrank(user2);
        for (uint i = 0; i < 3; i++) {
            ngr.deposit(10 ether, false);
        }
        vm.stopPrank();

        vm.prank(user1);
        // ngr.liquidateSelf(0);

        (, , uint liqTime, , , , , bool isLiq, bool early) = ngr.positions(0);
        assertEq(liqTime, block.timestamp);
        assertEq(isLiq, true);
        assertEq(early, false);

        assertGt(usdt.balanceOf(user1), u1Balance + 10.6 ether);
        // console.log("user1 Liquidated: %s", usdt.balanceOf(user1));
    }

    function test_others_liquidate() public {
        vm.startPrank(user1);
        ngr.deposit(10 ether, false);

        vm.expectRevert(NGR_GROW__InvalidWithdraw.selector);
        // ngr.liquidateSelf(1);

        skip(1 days);

        vm.startPrank(user2);
        for (uint i = 0; i < 3; i++) {
            ngr.deposit(10 ether, false);
        }
        vm.stopPrank();
        uint u3Balance = usdt.balanceOf(devWallet);

        uint[] memory toLiquidate = new uint[](1);
        toLiquidate[0] = 0;
        vm.prank(devWallet);
        ngr.liquidatePositions(toLiquidate);

        assertGt(usdt.balanceOf(devWallet), u3Balance);
        console.log("dif: %s", usdt.balanceOf(devWallet) - u3Balance);
    }

    function test_price_rise() public {
        uint prv = vm.snapshot();
        vm.startPrank(user1);
        for (uint i = 0; i < 50; i++) {
            ngr.deposit(10 ether, false);
            (, , , , , uint liqPrice, , , ) = ngr.positions(i);
            console.log(grow.calculatePrice(), i, liqPrice);
        }

        vm.revertTo(prv);
        for (uint i = 0; i < 10; i++) {
            ngr.deposit(100 ether, false);
            (, , , , , uint liqPrice, , , ) = ngr.positions(i);
            console.log(grow.calculatePrice(), i, liqPrice);
        }
    }
}
