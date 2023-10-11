// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "openzeppelin/token/ERC20/IERC20.sol";
import "openzeppelin/access/Ownable.sol";
import "openzeppelin/security/ReentrancyGuard.sol";
import "chainlink/automation/AutomationCompatible.sol";
import "./INGR.sol";
import "forge-std/console.sol";

contract NGR is INGR, Ownable, ReentrancyGuard, AutomationCompatible {
    mapping(uint position => PositionInfo) public positions;
    mapping(address user => uint[] positions) public userPositions;
    mapping(address user => UserStats) public userStats;
    PositionInfo private consistentPosition3;
    PositionInfo private consistentPosition4;

    address[] public owners;
    address public liquidationOutWallet;
    address private seedWallet;
    IERC20 public usdt;
    uint public totalHelix;
    uint public cycleCounter;
    uint private liquidationUser = 1;
    uint public totalPositions;
    uint public totalLiquidations;
    uint public totalDeposits;
    uint private consistentPositionId;
    uint private consistentPositionId2;

    uint private depositFee = 3;
    // Keep track of the current Gap counter;
    uint public depositCounter = 0;
    uint public liquidationCounter = 0;

    uint private devProportion = 15;
    uint private tcvProportion = 85;

    uint private cumulativeSparks;
    int private deltaSparks;
    uint private lastSparkBeforeUpdate;

    uint public constant MIN_DEPOSIT = 50 ether;
    uint public constant MAX_DEPOSIT = 500 ether;
    uint public constant MAX_PRICE = 1.2 ether;
    uint public constant BASE_PRICE = 1 ether;
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
    bool private liqConditionCheck = true;

    constructor(
        address _usdt,
        address liqOutWallet,
        address reseedWallet,
        address[] memory _owners
    ) {
        liquidationOutWallet = liqOutWallet;
        usdt = IERC20(_usdt);
        owners = _owners;
        seedWallet = reseedWallet;
    }

    //---------------------------
    //  External functions
    //---------------------------
    function deposit(uint amount) external nonReentrant {
        _depositEnv(msg.sender, msg.sender, amount);
    }

    function depositForUser(address user, uint amount) external nonReentrant {
        _depositEnv(user, msg.sender, amount);
    }

    function earlyWithdraw() external nonReentrant {
        uint userIndex = userPositions[msg.sender].length - 1;
        _earlyWithdraw(msg.sender, userIndex);
    }

    function liquidate() public nonReentrant {
        if (!canLiquidate()) revert NGR__CannotLiquidate();
        if (liqConditionCheck) liqConditionCheck = false;
        _liquidate();
    }

    function seed(uint amount) external nonReentrant {
        uint devFee = _deposit(msg.sender, amount, true, 0);
        usdt.transferFrom(msg.sender, address(this), amount);
        if (devFee > 0) distributeToOwners(devFee);
    }

    function seedAndQuit(uint amount) external nonReentrant {
        usdt.transferFrom(msg.sender, address(this), amount);
        uint devFee = _deposit(msg.sender, amount, false, 0);
        if (devFee > 0) distributeToOwners(devFee);
        uint index = userPositions[msg.sender].length - 1;
        index = userPositions[msg.sender][index];
        _earlyWithdraw(msg.sender, index);
    }

    function performUpkeep(bytes calldata) external nonReentrant {
        _autoLiquidate(10, true);
    }

    function updateOwners(address[] memory _owners) external onlyOwner {
        require(_owners.length > 0, "NGR: Invalid owners");
        owners = _owners;
        emit UpdateOwners(_owners);
    }

    function updateLiquidationOutWallet(address _wallet) external onlyOwner {
        require(_wallet != address(0), "NGR: Invalid wallet");
        emit UpdateLiquidationWallet(liquidationOutWallet, _wallet);
        liquidationOutWallet = _wallet;
    }

    //---------------------------
    //  Internal functions
    //---------------------------

    function _depositEnv(address _user, address caller, uint amount) private {
        uint devFee = _deposit(_user, amount, false, 0);
        usdt.transferFrom(caller, address(this), amount);
        if (devFee > 0) distributeToOwners(devFee);
        reAdjustPrice();

        if (
            consistentPosition3.initialDeposit == 0 ||
            (consistentPosition3.liquidated > 0)
        ) {
            devFee = _deposit(seedWallet, MAX_DEPOSIT, false, 1);
            usdt.transferFrom(seedWallet, address(this), MAX_DEPOSIT);
            if (devFee > 0) distributeToOwners(devFee);
            reAdjustPrice();
        }
        if (
            consistentPosition4.initialDeposit == 0 ||
            (consistentPosition4.liquidated > 0)
        ) {
            devFee = _deposit(seedWallet, MAX_DEPOSIT, false, 2);
            usdt.transferFrom(seedWallet, address(this), MAX_DEPOSIT);
            if (devFee > 0) distributeToOwners(devFee);
            reAdjustPrice();
        }
        autoSeed();
        _autoLiquidate(5, false);
    }

    function _deposit(
        address user,
        uint amount,
        bool isSeed,
        uint8 consistent
    ) internal returns (uint devProp) {
        if (!isSeed && (amount < MIN_DEPOSIT || amount > MAX_DEPOSIT))
            revert NGR__InvalidAmount(amount);

        uint helixPrice = currentHelixPrice();
        // get fee for DEV and TCV
        uint fee = (amount * depositFee) / BASE_PROPORTION;
        // distribute Fees
        uint devFee = (fee * devProportion) / BASE_PROPORTION;
        devProp = devFee;
        UserStats storage stats = userStats[user];
        // setup user
        totalPositions++;
        if (!isSeed) {
            totalDeposits += amount;
            stats.totalPositions++;
            stats.totalDeposited += amount;
            if (consistent == 0) {
                userPositions[user].push(totalPositions);
            }
        }

        PositionInfo storage position;
        if (consistent > 0) {
            if (consistent == 1) {
                position = consistentPosition3;
                consistentPositionId = liquidationUser + 2;
            } else {
                position = consistentPosition4;
                consistentPositionId2 = liquidationUser + 3;
            }
            position.liquidated = 0;
        } else position = positions[totalPositions];

        position.user = user;
        position.initialDeposit = amount;
        position.depositTime = block.timestamp;
        amount -= fee;
        uint createdSparks = (amount * BASE_PRICE) / helixPrice;
        cumulativeSparks += createdSparks;
        position.sparks = createdSparks;

        if (deltaSparks > 0) {
            deltaSparks -= int(createdSparks);
        }
        // delta sparks cant drop below 0 on a deposit
        if (deltaSparks < 0) deltaSparks = 0;
        uint helixAmount = helixPrice;
        // GOLDEN RANGE Price Adjustment
        if (helixPrice > GOLDEN_RANGE_START && helixPrice < GOLDEN_RANGE_END)
            helixAmount += 0.1 ether;
        // devFee = liquidationPrice
        devFee = (helixAmount * LIQ_BEGIN) / BASE_PROPORTION;
        position.liquidationCycle = cycleCounter;
        if (devFee > MAX_PRICE) devFee = devFee - MAX_PRICE + 1 ether;
        position.liquidationPrice = getFinalLiquidationPrice(devFee);
        // If next liquidation price is lower than current price, increase cycle to avoid premature liquidation
        if (position.liquidationPrice < helixPrice) position.liquidationCycle++;

        position.helixAmount =
            (amount * BASE_PRICE * BASE_THOUSANDTH) /
            (devFee * HELIX_ADJUST);
        totalHelix += position.helixAmount;

        // If it's a seed, reset the current position made.
        if (isSeed && consistent == 0) {
            positions[totalPositions] = PositionInfo({
                user: address(0),
                initialDeposit: 0,
                depositTime: 0,
                liquidationPrice: 0,
                helixAmount: 0,
                sparks: 0,
                liquidationCycle: 0,
                liquidated: 0
            });
            emit Seed(amount);
        } else {
            depositCounter++;
            emit Deposit(user, position.initialDeposit, totalPositions);
        }
        if (isSeed || consistent > 0) totalPositions--;
    }

    function _liquidate() internal {
        uint currentLiquidationUser = liquidationUser;

        PositionInfo storage toLiquidate;
        bool consistent = false;
        if (
            currentLiquidationUser == consistentPositionId &&
            consistentPosition3.liquidated == 0
        ) {
            toLiquidate = consistentPosition3;
            consistent = true;
        } else if (
            currentLiquidationUser == consistentPositionId2 &&
            consistentPosition4.liquidated == 0
        ) {
            toLiquidate = consistentPosition4;
            consistent = true;
        } else toLiquidate = positions[currentLiquidationUser];
        // If the position is already liquidated, skip it
        if (toLiquidate.liquidated > 0) {
            liquidationUser++;
            return _liquidate();
        }
        UserStats storage stats = userStats[toLiquidate.user];
        stats.lastLiquidatedPosition = currentLiquidationUser;
        stats.totalPositionsLiquidated++;
        // Set the liquidation flag
        toLiquidate.liquidated = block.timestamp;
        // Remove Sparks/Helix from existence
        cumulativeSparks -= toLiquidate.helixAmount;
        totalHelix -= toLiquidate.helixAmount;
        if (deltaSparks < 0) deltaSparks = 0;
        else {
            deltaSparks -= (int(toLiquidate.helixAmount) * 2) / 10;
        }
        // Calculate the amount of USDT to be distributed
        uint liquidationAmount = (toLiquidate.initialDeposit * LIQ_OUT_TOTAL) /
            DOUBLE_BASE_PROPORTION;
        // Amount to actually give the user
        uint liquidationUserAmount = (toLiquidate.initialDeposit *
            LIQ_OUT_USER) / DOUBLE_BASE_PROPORTION;
        totalLiquidations += liquidationUserAmount;
        // Amount to give to the liquidation wallet
        liquidationAmount = liquidationAmount - liquidationUserAmount;

        // Next position to liquidate
        if (!consistent) liquidationUser++;
        // Increase Counter for gap difference
        liquidationCounter++;
        // If user will redeposit, redeposit Amount (up to MAX_DEPOSIT)
        emit Liquidate(
            toLiquidate.user,
            liquidationUserAmount,
            liquidationUser - 1
        );
        stats.totalLiquidated += liquidationUserAmount;
        usdt.transfer(toLiquidate.user, liquidationUserAmount);

        // Transfer to Liquidation Wallet
        usdt.transfer(liquidationOutWallet, liquidationAmount);
        // Readjust price
        reAdjustPrice();
    }

    function _earlyWithdraw(address user, uint index) internal {
        index = userPositions[user][index];
        // Index is only of user so there's no monkey business
        PositionInfo storage toWithdraw = positions[index];
        // If TCV not enough, liquidate
        if (TCV() < 4 * MAX_DEPOSIT)
            revert NGR__CannotExit(TCV(), 4 * MAX_DEPOSIT);
        // If the position is already liquidated, skip it
        if (toWithdraw.liquidated > 0) revert NGR__AlreadyLiquidated();

        toWithdraw.liquidated = 1; // liquidated == 1 means it's an early withdraw
        liquidationCounter++;
        // Remove Sparks/Helix from existence

        cumulativeSparks -= toWithdraw.sparks;
        totalHelix -= toWithdraw.helixAmount;
        // Calculate the amount of USDT to be distributed
        uint earlyLiquidationAmount = (toWithdraw.initialDeposit * LIQ_EARLY) /
            BASE_PROPORTION;
        emit EarlyWithdrawal(
            user,
            toWithdraw.initialDeposit,
            earlyLiquidationAmount,
            toWithdraw.initialDeposit - earlyLiquidationAmount,
            index
        );
        // Transfer USDT to user
        earlyLiquidationAmount =
            toWithdraw.initialDeposit -
            earlyLiquidationAmount;
        totalLiquidations += earlyLiquidationAmount;
        userStats[user].totalPositionsWithdrawn++;
        userStats[user].totalWithdrawn += earlyLiquidationAmount;
        usdt.transfer(user, earlyLiquidationAmount);
        reAdjustPrice();
    }

    function _autoLiquidate(uint cycleAmount, bool shouldRevert) internal {
        bool canAdvance = canLiquidate();
        if (!canAdvance) {
            if (shouldRevert) revert NGR__CannotLiquidate();
            else return;
        }
        if (liqConditionCheck) liqConditionCheck = false;
        uint upkeepLiquidations = 0;
        do {
            // liquidate next position
            _liquidate();
            canAdvance = canLiquidate();
            upkeepLiquidations++;
        } while (canAdvance && upkeepLiquidations < cycleAmount);
    }

    function autoSeed() private {
        uint gaps = depositCounter - liquidationCounter;

        if (gaps < 25) return;
        uint halfTCV = TCV() / 2;
        uint allowance = usdt.allowance(seedWallet, address(this));
        uint balance = usdt.balanceOf(seedWallet);

        if (allowance < halfTCV || balance == 0) {
            emit NotEnoughAllowanceOrBalance(seedWallet, allowance, balance);
            return;
        }
        if (balance < halfTCV && balance > 0) halfTCV = balance;
        usdt.transferFrom(seedWallet, address(this), halfTCV);
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
        if (currentPrice > MAX_PRICE) {
            while (currentPrice > MAX_PRICE) {
                currentPrice = (currentPrice % MAX_PRICE) + BASE_PRICE;
            }
            cycleCounter++;
            uint sparkAdjustment = (BASE_PRICE * TCV()) / currentPrice;
            sparkAdjustment -= cumulativeSparks;

            if (deltaSparks < 0) deltaSparks = int(sparkAdjustment);
            else deltaSparks += int(sparkAdjustment);
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

        while (toLiquidate.liquidated > 0) {
            positionToLiquidate++;
            toLiquidate = positions[positionToLiquidate];
        }

        if (liqConditionCheck) {
            uint currentPrice = currentHelixPrice();
            // Check current price and cycle
            if (
                (cycleCounter == toLiquidate.liquidationCycle &&
                    currentPrice >= toLiquidate.liquidationPrice) ||
                cycleCounter > toLiquidate.liquidationCycle
            ) {
                return gapCheck();
            }
            return false;
        }
        return gapCheck();
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

    function gapCheck() internal view returns (bool) {
        uint gap = depositCounter - liquidationCounter;
        uint tcv = TCV();
        // Check gaps
        bool normalTCVCheck = tcv / gap > MIN_DEPOSIT * 2;
        bool normalTCVCheck2 = tcv > MAX_DEPOSIT * 5;
        bool superGapCheck = gap > 25;
        bool superTCVCheck = tcv > MAX_DEPOSIT * 7;
        // Check gaps and TCV
        return
            (normalTCVCheck && normalTCVCheck2) ||
            (superGapCheck && superTCVCheck);
    }

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
    function currentHelixPrice() public view override returns (uint) {
        uint delta = cumulativeSparks;
        if (deltaSparks < 0) delta -= uint(-deltaSparks);
        else delta += uint(deltaSparks);

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

    function getUserPositions(
        address user
    ) external view returns (uint[] memory) {
        return userPositions[user];
    }
}
