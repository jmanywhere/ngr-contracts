// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "openzeppelin/token/ERC20/IERC20.sol";
import "openzeppelin/access/Ownable.sol";
import "openzeppelin/security/ReentrancyGuard.sol";
import "./INGR.sol";

import "forge-std/console2.sol";

contract NGR is INGR, Ownable, ReentrancyGuard {
    mapping(uint position => UserInfo) public positions;
    mapping(address user => uint[] positions) public userPositions;

    address[] public owners;
    address public liquidationOutWallet;
    IERC20 public usdt;

    uint private liquidationUser = 1;
    uint public totalPositions;

    uint public depositFee = 3;
    // Keep track of the current Gap counter;
    uint public depositCounter = 0;
    uint public liquidationCounter = 0;

    uint private devProportion = 20;
    uint private tcvProportion = 80;

    uint private cumulativeSparks;
    int private deltaSparks;
    uint private lastSparkBeforeUpdate;

    uint public MAX_DEPOSIT = 1_000 ether;
    uint public MAX_Price = 1.2 ether;
    uint public BASE_PRICE = 1 ether;
    uint private constant GOLDEN_RANGE_START = 1.05 ether - 1;
    uint private constant GOLDEN_RANGE_END = 1.1 ether + 1;
    uint private constant GOLDEN_RANGE_ADJUSTMENT = 0.1 ether;
    uint private constant LIQ_BEGIN = 110;
    uint private constant BASE_PROPORTION = 100;

    uint private constant HELIX_ADJUST = 909;
    uint private constant BASE_THOUSANDTH = 1000;

    uint private constant LIQ_EVENTS = 30;
    uint private constant LIQ_PROFIT = 12;
    uint private constant LIQ_TAX_ADJUST = 6;
    uint private constant DOUBLE_BASE_PROPORTION = 100_00;

    uint private constant LIQ_OUT_TOTAL = 106_62;
    uint private constant LIQ_OUT_USER = 106_00;

    constructor(address _usdt, address liqOutWallet, address[] memory _owners) {
        liquidationOutWallet = liqOutWallet;
        usdt = IERC20(_usdt);
        owners = _owners;
    }

    //---------------------------
    //  External functions
    //---------------------------
    function deposit(uint amount, uint redeposit) external nonReentrant {
        if (amount == 0 || amount > MAX_DEPOSIT)
            revert NGR__InvalidAmount(amount);

        uint helixAmount = currentHelixPrice();

        usdt.transferFrom(msg.sender, address(this), amount);
        // get fee for DEV and TCV
        uint fee = (amount * depositFee) / BASE_PROPORTION;
        // distribute Fees
        uint devFee = (fee * devProportion) / BASE_PROPORTION;
        if (devFee > 0) distributeToOwners(devFee);
        // setup user
        totalPositions++;
        userPositions[msg.sender].push(totalPositions);

        UserInfo storage position = positions[totalPositions];
        position.user = msg.sender;
        position.initialDeposit = amount;
        position.depositTime = block.timestamp;
        amount -= fee;
        uint createdSparks = (amount * BASE_PRICE) / helixAmount;
        cumulativeSparks += createdSparks;

        if (deltaSparks > 0) deltaSparks -= int(createdSparks);

        // GOLDEN RANGE Price Adjustment
        if (helixAmount > GOLDEN_RANGE_START && helixAmount < GOLDEN_RANGE_END)
            helixAmount += 0.1 ether;
        // devFee = liquidationPrice
        devFee = (helixAmount * LIQ_BEGIN) / BASE_PROPORTION;
        if (devFee > MAX_Price) devFee = devFee - MAX_Price + 1 ether;
        position.liquidationPrice = getFinalLiquidationPrice(devFee);
        position.helixAmount =
            (amount * BASE_PRICE) /
            ((devFee * HELIX_ADJUST) / BASE_THOUSANDTH);
        position.redeposit = redeposit;

        console2.log("Delta", deltaSparks);
        console2.log("Cumulative", cumulativeSparks);
        console2.log("HELIX AMOUNT", position.helixAmount);
        reAdjustPrice();
        depositCounter++;
        emit Deposit(msg.sender, position.initialDeposit, totalPositions);
    }

    function earlyWithdraw() external {
        revert("Not implemented");
    }

    function liquidate() external {
        if (!canLiquidate()) revert NGR__CannotLiquidate();

        UserInfo storage toLiquidate = positions[liquidationUser];

        cumulativeSparks -= toLiquidate.helixAmount;

        uint liquidationAmount = (toLiquidate.initialDeposit * LIQ_OUT_TOTAL) /
            DOUBLE_BASE_PROPORTION;
        uint liquidationUserAmount = (liquidationAmount * LIQ_OUT_USER) /
            DOUBLE_BASE_PROPORTION;

        liquidationAmount = liquidationAmount - liquidationUserAmount;

        liquidationUser++;
        liquidationCounter++;

        usdt.transfer(toLiquidate.user, liquidationUserAmount);
        usdt.transfer(liquidationOutWallet, liquidationAmount);

        reAdjustPrice();
        emit Liquidate(toLiquidate.user, liquidationUserAmount);
    }

    function seed(uint amount, bool inAndOut) external {
        revert("Not implemented");
    }

    //---------------------------
    //  Internal functions
    //---------------------------
    function distributeToOwners(uint amount) internal {
        uint amountPerOwner = amount / owners.length;
        for (uint i = 0; i < owners.length; i++) {
            usdt.transfer(owners[i], amountPerOwner);
        }
    }

    function reAdjustPrice() internal {
        uint currentPrice = currentHelixPrice();
        if (currentPrice > MAX_Price) {
            do {
                currentPrice = (currentPrice % MAX_Price) + BASE_PRICE;
            } while (currentPrice > MAX_Price);

            uint extraSparks = (cumulativeSparks * BASE_PRICE) / currentPrice;
            deltaSparks += int(extraSparks);
        }
    }

    //---------------------------
    //  External VIEW functions
    //---------------------------

    function devDistributions()
        external
        view
        returns (uint fullFee, uint devPortion, uint tcvPortion)
    {
        return (depositFee, devProportion, tcvProportion);
    }

    function canLiquidate() public view returns (bool) {
        if (depositCounter - liquidationCounter > 20) return true;
        uint tcv = TCV();
        bool tcvCanLiquidate = tcv > MAX_DEPOSIT * 3;
        bool tcvCanOverLiquidate = tcv > MAX_DEPOSIT * 12;
        return (tcvCanLiquidate) || (tcvCanOverLiquidate);
    }

    //---------------------------
    //  Internal VIEW & PURE functions
    //---------------------------
    function getFinalLiquidationPrice(
        uint ogLiquidation
    ) internal pure returns (uint) {
        uint allEvents = (LIQ_EVENTS * LIQ_PROFIT * ogLiquidation) /
            DOUBLE_BASE_PROPORTION;
        allEvents += ogLiquidation;
        uint tax = (allEvents * LIQ_TAX_ADJUST) / DOUBLE_BASE_PROPORTION;
        return allEvents - tax;
    }

    //---------------------------
    //  Public VIEW functions
    //---------------------------
    function currentHelixPrice() public view returns (uint) {
        uint delta;
        if (deltaSparks < 0) delta = cumulativeSparks - uint(-deltaSparks);
        else delta = cumulativeSparks + uint(deltaSparks);

        if (delta == 0) return BASE_PRICE;

        return (usdt.balanceOf(address(this)) * BASE_PRICE) / delta;
    }

    function getDS() external view returns (int256) {
        return deltaSparks;
    }

    function TCV() public view returns (uint256) {
        return usdt.balanceOf(address(this));
    }

    function currentUserPendingLiquidation() external view returns (uint256) {
        return liquidationUser;
    }

    function userLiquidationStatus(
        address user
    ) external view returns (bool indexEnabled, bool pastCycle, bool dsZero) {
        return (false, false, false);
    }

    function currentSparks() external view returns (uint256) {
        return cumulativeSparks;
    }

    function calculateSparksOnDeposit(
        uint256 amount
    ) external view returns (uint256) {
        uint helixAmount = currentHelixPrice();
        uint createdSparks = helixAmount / amount;
        return createdSparks;
    }
}
