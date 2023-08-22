// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "openzeppelin/token/ERC20/IERC20.sol";
import "openzeppelin/access/Ownable.sol";
import "openzeppelin/security/ReentrancyGuard.sol";
import "chainlink/automation/AutomationCompatible.sol";
import "./INGR.sol";

contract NGR is INGR, Ownable, ReentrancyGuard, AutomationCompatible {
    mapping(uint position => PositionInfo) public positions;
    mapping(address user => uint[] positions) public userPositions;

    address[] public owners;
    address public liquidationOutWallet;
    IERC20 public usdt;

    uint public cycleCounter;
    uint private liquidationUser = 1;
    uint public totalPositions;

    uint private depositFee = 3;
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
    uint public MIN_DEPOSIT = 5 ether;
    uint private constant GOLDEN_RANGE_START = 1.05 ether - 1;
    uint private constant GOLDEN_RANGE_END = 1.1 ether + 1;
    uint private constant GOLDEN_RANGE_ADJUSTMENT = 0.1 ether;
    uint private constant LIQ_BEGIN = 110;
    uint private constant LIQ_EARLY = 6;
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
    function deposit(uint amount, bool redeposit) external nonReentrant {
        uint devFee = _deposit(msg.sender, amount, redeposit, false);
        usdt.transferFrom(msg.sender, address(this), amount);
        if (devFee > 0) distributeToOwners(devFee);
    }

    function depositForUser(
        address user,
        uint amount,
        bool redeposit
    ) external nonReentrant {
        uint devFee = _deposit(user, amount, redeposit, false);
        usdt.transferFrom(msg.sender, address(this), amount);
        if (devFee > 0) distributeToOwners(devFee);
    }

    function earlyWithdraw(uint userIndex) external nonReentrant {
        _earlyWithdraw(msg.sender, userIndex);
    }

    function liquidate() public nonReentrant {
        if (!canLiquidate()) revert NGR__CannotLiquidate();
        _liquidate();
    }

    function seed(uint amount) external nonReentrant {
        uint devFee = _deposit(msg.sender, amount, false, true);
        usdt.transferFrom(msg.sender, address(this), amount);
        if (devFee > 0) distributeToOwners(devFee);
    }

    function seedAndQuit(uint amount) external nonReentrant {
        usdt.transferFrom(msg.sender, address(this), amount);
        uint devFee = _deposit(msg.sender, amount, false, false);
        if (devFee > 0) distributeToOwners(devFee);
        uint index = userPositions[msg.sender].length - 1;
        index = userPositions[msg.sender][index];
        _earlyWithdraw(msg.sender, index);
    }

    function performUpkeep(bytes calldata) external nonReentrant {
        bool canAdvance = canLiquidate();
        if (!canAdvance) revert NGR__CannotLiquidate();
        do {
            // liquidate next position
            _liquidate();
            canAdvance = canLiquidate();
        } while (canAdvance);
    }

    //---------------------------
    //  Internal functions
    //---------------------------

    function _deposit(
        address user,
        uint amount,
        bool redeposit,
        bool isSeed
    ) internal returns (uint devProp) {
        if (!isSeed && (amount < MIN_DEPOSIT || amount > MAX_DEPOSIT))
            revert NGR__InvalidAmount(amount);

        uint helixPrice = currentHelixPrice();
        // get fee for DEV and TCV
        uint fee = (amount * depositFee) / BASE_PROPORTION;
        // distribute Fees
        uint devFee = (fee * devProportion) / BASE_PROPORTION;
        devProp = devFee;
        // setup user
        if (!isSeed) {
            totalPositions++;
            userPositions[user].push(totalPositions);
        }

        PositionInfo storage position = positions[totalPositions];
        position.user = user;
        position.initialDeposit = amount;
        position.depositTime = block.timestamp;
        amount -= fee;
        uint createdSparks = (amount * BASE_PRICE) / helixPrice;
        cumulativeSparks += createdSparks;

        if (deltaSparks > 0) deltaSparks -= int(createdSparks);
        uint helixAmount = helixPrice;
        // GOLDEN RANGE Price Adjustment
        if (helixPrice > GOLDEN_RANGE_START && helixPrice < GOLDEN_RANGE_END)
            helixAmount += 0.1 ether;
        // devFee = liquidationPrice
        devFee = (helixAmount * LIQ_BEGIN) / BASE_PROPORTION;
        position.liquidationCycle = cycleCounter;
        if (devFee > MAX_Price) devFee = devFee - MAX_Price + 1 ether;
        position.liquidationPrice = getFinalLiquidationPrice(devFee);
        // If next liquidation price is lower than current price, increase cycle to avoid premature liquidation
        if (position.liquidationPrice < helixPrice) position.liquidationCycle++;

        position.helixAmount =
            (amount * BASE_PRICE) /
            ((devFee * HELIX_ADJUST) / BASE_THOUSANDTH);
        position.redeposit = redeposit;

        // If it's a seed, reset the current position made.
        if (isSeed) {
            positions[totalPositions] = PositionInfo({
                user: address(0),
                initialDeposit: 0,
                depositTime: 0,
                liquidationPrice: 0,
                helixAmount: 0,
                liquidationCycle: 0,
                redeposit: false,
                liquidated: false
            });
            emit Seed(amount);
        } else {
            depositCounter++;
            emit Deposit(user, position.initialDeposit, totalPositions);
        }

        reAdjustPrice();
    }

    function _liquidate() internal {
        PositionInfo storage toLiquidate = positions[liquidationUser];
        // If the position is already liquidated, skip it
        if (toLiquidate.liquidated) {
            liquidationUser++;
            return liquidate();
        }
        // Set the liquidation flag
        toLiquidate.liquidated = true;
        // Remove Sparks/Helix from existence
        cumulativeSparks -= toLiquidate.helixAmount;

        // Calculate the amount of USDT to be distributed
        uint liquidationAmount = (toLiquidate.initialDeposit * LIQ_OUT_TOTAL) /
            DOUBLE_BASE_PROPORTION;
        // Amount to actually give the user
        uint liquidationUserAmount = (toLiquidate.initialDeposit *
            LIQ_OUT_USER) / DOUBLE_BASE_PROPORTION;
        // Amount to give to the liquidation wallet
        liquidationAmount = liquidationAmount - liquidationUserAmount;

        // Next position to liquidate
        liquidationUser++;
        // Increase Counter for gap difference
        liquidationCounter++;
        // If user will redeposit, redeposit Amount (up to MAX_DEPOSIT)
        emit Liquidate(toLiquidate.user, liquidationUserAmount);
        if (toLiquidate.redeposit) {
            uint devAmount;
            if (liquidationUserAmount > MAX_DEPOSIT) {
                liquidationUserAmount -= MAX_DEPOSIT;
                devAmount = _deposit(
                    toLiquidate.user,
                    MAX_DEPOSIT,
                    true,
                    false
                );
                usdt.transfer(toLiquidate.user, liquidationUserAmount);
            } else {
                devAmount = _deposit(
                    toLiquidate.user,
                    liquidationUserAmount,
                    true,
                    false
                );
            }
            if (devAmount > 0) distributeToOwners(devAmount);
        }
        // Else, transfer USDT to user
        else usdt.transfer(toLiquidate.user, liquidationUserAmount);

        // Transfer to Liquidation Wallet
        usdt.transfer(liquidationOutWallet, liquidationAmount);
        // Readjust price
        reAdjustPrice();
    }

    function _earlyWithdraw(address user, uint index) internal {
        index = userPositions[user][index];
        // Index is only of user so there's no monkey business
        PositionInfo storage toWithdraw = positions[index];
        // If the position is already liquidated, skip it
        if (toWithdraw.liquidated) {
            revert NGR__AlreadyLiquidated();
        }
        toWithdraw.liquidated = true;
        liquidationCounter++;
        // Remove Sparks/Helix from existence
        cumulativeSparks -= toWithdraw.helixAmount;
        // Calculate the amount of USDT to be distributed
        uint earlyLiquidationAmount = (toWithdraw.initialDeposit * LIQ_EARLY) /
            BASE_PROPORTION;
        emit EarlyWithdrawal(
            user,
            toWithdraw.initialDeposit,
            earlyLiquidationAmount
        );
        // Transfer USDT to user
        earlyLiquidationAmount =
            toWithdraw.initialDeposit -
            earlyLiquidationAmount;
        usdt.transfer(user, earlyLiquidationAmount);
        reAdjustPrice();
    }

    /**
     * @notice Function to distribute USDT to owners
     * @param amount The amount of USDT to be distributed amongst owners
     */
    function distributeToOwners(uint amount) internal {
        uint amountPerOwner = amount / owners.length;
        for (uint i = 0; i < owners.length; i++) {
            usdt.transfer(owners[i], amountPerOwner);
        }
    }

    /**
     * @notice Function to adjust price so it is always in Range
     */
    function reAdjustPrice() internal {
        uint currentPrice = currentHelixPrice();
        if (currentPrice > MAX_Price) {
            do {
                currentPrice = (currentPrice % MAX_Price) + BASE_PRICE;
            } while (currentPrice > MAX_Price);
            cycleCounter++;
            uint extraSparks = (cumulativeSparks * BASE_PRICE) / currentPrice;
            deltaSparks += int(extraSparks);
        }
    }

    //---------------------------
    //  External VIEW functions
    //---------------------------

    /**
     * @notice Returns the helix dev Distribution percentages
     * @return fullFee -> depositFee
     * @return devPortion -> proportion of depositFee that goes to dev
     * @return tcvPortion -> proportion of depositFee that goes to TCV
     */
    function devDistributions()
        external
        view
        returns (uint fullFee, uint devPortion, uint tcvPortion)
    {
        return (depositFee, devProportion, tcvProportion);
    }

    /**
     * @notice Determines wether the system is ready for a liquidation
     * @return bool -> can liquidate or not
     */
    function canLiquidate() public view returns (bool) {
        uint positionToLiquidate = liquidationUser;
        PositionInfo storage toLiquidate = positions[positionToLiquidate];

        while (toLiquidate.liquidated) {
            positionToLiquidate++;
            toLiquidate = positions[positionToLiquidate];
        }

        uint currentPrice = currentHelixPrice();
        // Check current price and cycle
        if (
            (cycleCounter == toLiquidate.liquidationCycle &&
                currentPrice >= toLiquidate.liquidationPrice) ||
            cycleCounter > toLiquidate.liquidationCycle
        ) {
            uint gap = depositCounter - liquidationCounter;
            uint tcv = TCV();
            // Check gaps
            if (gap > 20) return true;
            bool tcvCanLiquidate = tcv > MAX_DEPOSIT * 5;
            bool gapCanLiquidate = gap > 3;
            // Check gaps and TCV
            return tcvCanLiquidate && gapCanLiquidate;
        }
        return false;
    }

    /**
     * @return upkeepNeeded -> can liquidate or not
     * @return performData -> unused
     */
    function checkUpkeep(
        bytes calldata
    )
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        upkeepNeeded = canLiquidate();
        performData = bytes("");
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

    /**
     * @notice Returns wether the user and position index can be liquidated
     * @param user The user to check
     * @param positionIndex Of all the user's positions, which one to check based on index
     */
    function userLiquidationStatus(
        address user,
        uint positionIndex
    ) external view returns (bool indexEnabled, bool envAllows) {
        uint positionId = userPositions[user][positionIndex];
        return (liquidationCounter == positionId, canLiquidate());
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
