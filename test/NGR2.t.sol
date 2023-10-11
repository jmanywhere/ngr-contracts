// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import "openzeppelin/token/ERC20/presets/ERC20PresetFixedSupply.sol";
import "../src/prevNGR/NGR_2.sol";

contract TestNGR2 is Test {
    NGR_v2 public ngr;
    ERC20PresetFixedSupply public usdt;

    address owner1 = makeAddr("owner1");
    address owner2 = makeAddr("owner2");
    address owner3 = makeAddr("owner3");

    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    address user3 = makeAddr("user3");

    address liqout = makeAddr("liqout");
    address seeder = makeAddr("seeder");

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
        ngr = new NGR_v2(address(usdt), liqout, seeder, owners);

        owners[0] = user1;
        owners[1] = user2;
        owners[2] = user3;

        usdt.transfer(address(ngr), 1 ether);

        usdt.transfer(seeder, 10_000 ether);
        vm.prank(seeder);
        usdt.approve(address(ngr), type(uint).max);

        for (uint i = 0; i < owners.length; i++) {
            vm.deal(owners[i], 100 ether);
            usdt.transfer(owners[i], 10_000 ether);
            vm.prank(owners[i]);
            usdt.approve(address(ngr), type(uint).max);
        }
    }

    function test_deposit() public {
        vm.prank(user1);
        ngr.deposit(100 ether);

        assertEq(usdt.balanceOf(address(ngr)), 1096.05 ether);
        assertGt(ngr.totalSupply(), 400 ether);
        console.log(
            "Total Helix: %s, price: %s",
            ngr.totalSupply(),
            ngr.helixPrice()
        );
    }

    function test_liquidation() public {
        uint userBalance = usdt.balanceOf(user1);
        vm.startPrank(user1);
        ngr.deposit(500 ether);
        ngr.deposit(500 ether);
        ngr.deposit(500 ether);
        ngr.deposit(500 ether);
        vm.stopPrank();
        userBalance -= 2000 ether;
        (address owner, uint depositAmount, , uint liquidationTime) = ngr
            .positions(1);
        assertEq(owner, user1);
        assertEq(depositAmount, 500 ether);
        assertEq(liquidationTime, block.timestamp);

        (owner, depositAmount, , liquidationTime) = ngr.positions(2);
        assertEq(owner, user1);
        assertEq(depositAmount, 500 ether);
        assertEq(liquidationTime, block.timestamp);

        assertEq(usdt.balanceOf(user1), userBalance + 1060 ether);
    }
}
