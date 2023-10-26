//SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import "forge-std/Script.sol";
import "openzeppelin/token/ERC20/IERC20.sol";
import "../src/GROW.sol";
import "../src/NGR_Grow.sol";

contract DeployNGR2 is Script {
    GrowToken public grow;
    NGR_with_Grow public ngrGrow;

    function run() public {
        address[] memory stables = new address[](1);
        stables[0] = 0xb6D07D107FF8e26A21E497Bf64c3239101FED3Cf;
        address[] memory owners = new address[](3);
        owners[0] = 0x7Ff20b4E1Ad27C5266a929FC87b00F5cCB456374;
        owners[1] = 0x6b230Af9527AF9d253Fd0B503a9D451239a9e2cE;
        owners[2] = 0x79E441539a0760Eca6e08895E375F77AF2FBAa41;
        uint256[] memory shares = new uint256[](3);
        shares[0] = 45;
        shares[1] = 35;
        shares[2] = 20;
        vm.startBroadcast();
        grow = new GrowToken(stables, owners, shares, owners[0]);
        ngrGrow = new NGR_with_Grow(address(grow), stables[0], owners[1]);
        IERC20 USDT = IERC20(stables[0]);
        USDT.approve(address(ngrGrow), type(uint256).max);
        grow.setExecutorAddress(address(ngrGrow), true);
        USDT.transfer(address(grow), 1 ether);
        vm.stopBroadcast();
        console.log("GrowToken address: %s", address(grow));
        console.log("NGR_with_Grow address: %s", address(ngrGrow));
    }
}
