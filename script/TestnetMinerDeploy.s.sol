//SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import "../src/GrowMiner.sol";
import "../src/GROW.sol";
import "forge-std/Script.sol";

contract MinerDeploy is Script {
    address[] owners;
    uint[] shares;
    IERC20 usdt = IERC20(0xb6D07D107FF8e26A21E497Bf64c3239101FED3Cf);
    address owner1 = 0xD43f17A3103a07d35215E1b19676f4FbFb6db682;
    address owner2 = 0x7Ff20b4E1Ad27C5266a929FC87b00F5cCB456374;

    function run() public {
        owners.push(owner1);
        owners.push(owner2);
        shares.push(225);
        shares.push(225);
        address[] memory addrs = new address[](1);
        addrs[0] = address(usdt);

        vm.startBroadcast();
        GrowToken grow = new GrowToken(addrs, owners, shares, msg.sender);
        usdt.transfer(address(grow), 1 ether);

        GrowMiner miner = new GrowMiner(address(grow), address(usdt), owners);

        console.log("Grow address: %s", address(grow));
        console.log("Miner address: %s", address(miner));
        grow.setExecutorAddress(address(miner), true);
        vm.stopBroadcast();
    }
}
