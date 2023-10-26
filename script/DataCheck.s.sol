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
        grow = GrowToken(0xF38c9E79463DFebECA756aB4026E5298dbB88147);
        ngrGrow = NGR_with_Grow(0x6e9FE75AB684C2D6F9BA2529A94cc0b928a5d634);
    }
}
