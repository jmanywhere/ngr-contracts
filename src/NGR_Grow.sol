//SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IGrow} from "./interfaces/IGrow.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";

error NGR_GROW__InvalidLiquidationAmount();
error NGR_GROW__InvalidWithdraw();
error NGR_GROW__LowPrice();
error NGR_GROW__InvalidMinDeposit();
error NGR_GROW__InvalidMaxDeposit();
error NGR_GROW__InvalidDepositAmount();
error NGR_GROW__LiquidatorMinDepositNotReached();

contract NGR_with_Grow is Ownable {
    //------------------------------------------------
    // Type Declarations
    //------------------------------------------------
    struct Position {
        address owner;
        uint depositTime;
        uint liqTime;
        uint amountDeposited;
        uint growAmount;
        uint liquidationPrice;
        uint liquidatedAmount;
        bool isLiquidated;
        bool early;
    }

    struct UserStats {
        uint totalDeposited;
        uint totalLiquidated;
        uint totalEarly;
        uint otherLiquidationProfits;
    }
    struct UserPositions {
        uint mainDeposit;
        uint liquidationStartPrice;
        uint positionId;
    }
    //------------------------------------------------
    // State Variables
    //------------------------------------------------
    mapping(uint => Position) public positions;
    mapping(address => UserStats) public userStats;
    mapping(address => bool) public autoReinvest;
    mapping(address => bool) public isLiquidator;
    mapping(address => UserPositions[]) public userMainDeposits;

    IGrow public immutable grow;
    IERC20 public immutable usdt;
    address public devWallet;

    uint public currentPositionToLiquidate;
    uint public queuePosition;

    uint public totalDeposits;
    uint public totalLiquidations;
    uint public totalPaidToLiquidators;

    uint public liquidatorAmount = 1;
    uint public totalAmount = 5;

    uint public minLiquidatorThreshold = 50 ether;

    uint public constant MIN_DEPOSIT = 10 ether;
    uint public constant TCV_DEPOSIT_LIMIT_1 = 500 ether;
    uint public constant TCV_DEPOSIT_LIMIT_2 = 1_000 ether;
    uint public constant DEPOSIT_LIMIT_2 = 25 ether;
    uint public constant DEPOSIT_LIMIT_1 = 50 ether;

    uint public constant MAX_DEPOSIT_LIMIT = 25 ether;
    uint public constant TARGET_PROFIT = 6;
    uint public constant MIN_PROFIT = 5;
    uint private constant FULL_MIN_PROFIT = 105;
    uint private constant FULL_TARGET_PROFIT = 106;
    uint private constant GROW_SELL_TOTAL_RCV = 94;

    uint public constant PERCENT = 100;
    uint private constant MAGNIFIER = 1 ether;

    //------------------------------------------------
    // Events
    //------------------------------------------------
    event Deposit(
        address indexed owner,
        uint indexed position,
        uint amount,
        uint growAmount
    );
    event EarlyExit(
        address indexed owner,
        uint indexed position,
        uint totalReceived
    );
    event Liquidated(
        address indexed owner,
        uint indexed position,
        uint totalReceived
    );
    event LiquidatorAction(
        address indexed liquidator,
        uint totalLiquidatorReceived,
        uint totalLiquidated
    );
    event SetSelfAutoReinvest(address indexed user, bool autoReinvest);

    //------------------------------------------------
    // Modifiers
    //------------------------------------------------
    modifier checkAmount(uint amount) {
        // Can only deposit FULL token amounts
        if (amount % 1 ether != 0) revert NGR_GROW__InvalidDepositAmount();
        // Minimum Deposit of 10$ (10 USDT)
        if (amount < MIN_DEPOSIT) revert NGR_GROW__InvalidMinDeposit();
        if (amount > MAX_DEPOSIT_LIMIT) revert NGR_GROW__InvalidMaxDeposit();
        _;
    }

    //------------------------------------------------
    // Constructor
    //------------------------------------------------
    constructor(address _grow, address _usdt, address _dev) {
        currentPositionToLiquidate = 0;
        queuePosition = 0;
        grow = IGrow(_grow);
        usdt = IERC20(_usdt);
        devWallet = _dev;
        usdt.approve(_grow, type(uint).max);
        usdt.approve(address(this), type(uint).max);
        isLiquidator[devWallet] = true;
    }

    //------------------------------------------------
    // External Functions
    //------------------------------------------------

    /**
     * @notice Deposit USDT to the contract and buy GROW
     * @param amount Amount of USDT to deposit
     * @param _autoReinvest Whether to auto reinvest or not
     */
    function deposit(
        uint amount,
        bool _autoReinvest
    ) external checkAmount(amount) {
        autoReinvest[msg.sender] = _autoReinvest;

        uint currentQueuePos = queuePosition;
        UserPositions[] storage userMain = userMainDeposits[msg.sender];
        // First liquidation is stored in the main positions array
        userMain.push(
            UserPositions({
                mainDeposit: amount,
                liquidationStartPrice: _deposit(msg.sender, msg.sender, amount),
                positionId: currentQueuePos
            })
        );

        userStats[msg.sender].totalDeposited += amount;
        totalDeposits += amount;

        if (
            !isLiquidator[msg.sender] &&
            userStats[msg.sender].totalDeposited >= minLiquidatorThreshold
        ) {
            isLiquidator[msg.sender] = true;
        }
    }

    function depositForUser(
        uint amount,
        address _receiver
    ) external checkAmount(amount) {
        uint currentQueuePos = queuePosition;
        UserPositions[] storage userMain = userMainDeposits[_receiver];
        // First liquidation is stored in the main positions array
        userMain.push(
            UserPositions({
                mainDeposit: amount,
                liquidationStartPrice: _deposit(_receiver, msg.sender, amount),
                positionId: currentQueuePos
            })
        );
        userStats[msg.sender].totalDeposited += amount;
        totalDeposits += amount;
    }

    function changeAutoReinvest(bool _autoReinvest) external {
        autoReinvest[msg.sender] = _autoReinvest;
    }

    function earlyExit(uint position) external {
        Position storage exitPos = positions[position];

        if (exitPos.isLiquidated || exitPos.owner != msg.sender)
            revert NGR_GROW__InvalidWithdraw();

        exitPos.isLiquidated = true;
        exitPos.early = true;
        exitPos.liqTime = block.timestamp;
        uint totalSell = grow.sell(exitPos.growAmount, address(usdt));
        uint minSent = (exitPos.amountDeposited * 92) / 100;

        uint min = totalSell < minSent ? totalSell : minSent;
        uint remaining = totalSell - min;
        // Transfer out the minimum
        exitPos.liquidatedAmount = min;
        usdt.transfer(exitPos.owner, min);
        // If there's any remaning, that's the fee
        if (remaining > 0) usdt.transfer(devWallet, remaining);
        userStats[msg.sender].totalEarly += min;

        emit EarlyExit(msg.sender, position, min);
        totalLiquidations += totalSell;
    }

    function liquidatePositions(uint[] calldata _positions) external {
        if (!isLiquidator[msg.sender])
            revert NGR_GROW__LiquidatorMinDepositNotReached();
        uint rewardAccumulator = 0;
        uint accLiquidations = 0;
        uint accDevProportion = 0;
        uint positionLiquidated = currentPositionToLiquidate;
        for (uint i = 0; i < _positions.length; i++) {
            uint currentPrice = grow.calculatePrice();
            if (positionLiquidated < _positions[i])
                positionLiquidated = _positions[i];
            Position storage liquidatedPos = positions[_positions[i]];
            //If position has laready been liquidated or not reached, then skip.
            // We can't assure that all _positions are in order, so skipping is necessary
            // instead of reverting
            if (
                currentPrice < liquidatedPos.liquidationPrice ||
                liquidatedPos.isLiquidated
            ) continue;

            liquidatedPos.isLiquidated = true;
            liquidatedPos.liqTime = block.timestamp;
            uint totalSell = grow.sell(
                address(this),
                liquidatedPos.growAmount,
                address(usdt)
            );
            accLiquidations += totalSell;

            // GET USERS PROFIT
            uint userProfit = calculateMinProfitAmount(
                liquidatedPos.amountDeposited
            );

            uint liquidatorProfit = totalSell - userProfit;
            uint devProportion = (liquidatorProfit * 6) / 10;
            liquidatorProfit -= devProportion;

            rewardAccumulator += liquidatorProfit;
            accDevProportion += devProportion;
            userStats[liquidatedPos.owner].totalLiquidated += userProfit;
            liquidatedPos.liquidatedAmount = userProfit;

            if (autoReinvest[liquidatedPos.owner]) {
                // Cant re invest more than max
                if (userProfit > MAX_DEPOSIT_LIMIT) {
                    usdt.transfer(
                        liquidatedPos.owner,
                        userProfit - MAX_DEPOSIT_LIMIT
                    );
                    userProfit = MAX_DEPOSIT_LIMIT;
                }
                uint currentQueuePos = queuePosition;
                UserPositions[] storage userMain = userMainDeposits[
                    liquidatedPos.owner
                ];
                // First liquidation is stored in the main positions array
                userMain.push(
                    UserPositions({
                        mainDeposit: userProfit,
                        liquidationStartPrice: _deposit(
                            liquidatedPos.owner,
                            address(this),
                            userProfit
                        ),
                        positionId: currentQueuePos
                    })
                );
            } else usdt.transfer(liquidatedPos.owner, userProfit);
            emit Liquidated(liquidatedPos.owner, _positions[i], totalSell);
        }
        currentPositionToLiquidate = positionLiquidated;
        totalPaidToLiquidators += rewardAccumulator;
        totalLiquidations += accLiquidations;
        userStats[msg.sender].otherLiquidationProfits += rewardAccumulator;
        if (rewardAccumulator > 0) usdt.transfer(msg.sender, rewardAccumulator);
        if (accDevProportion > 0) usdt.transfer(devWallet, accDevProportion);
        emit LiquidatorAction(msg.sender, rewardAccumulator, accLiquidations);
    }

    function setSelfAutoReinvest(bool _autoReinvest) external {
        autoReinvest[msg.sender] = _autoReinvest;
        emit SetSelfAutoReinvest(msg.sender, _autoReinvest);
    }

    function updateDevWallet(address _devWallet) external onlyOwner {
        devWallet = _devWallet;
    }

    function setLiquidatorThreshold(uint _thresholdAmount) external onlyOwner {
        minLiquidatorThreshold = _thresholdAmount;
    }

    function setLiquidator(address[] calldata _liquidators) external onlyOwner {
        for (uint i = 0; i < _liquidators.length; i++) {
            isLiquidator[_liquidators[i]] = true;
        }
    }

    //------------------------------------------------
    // Private / Internal Functions
    //------------------------------------------------
    function _deposit(
        address user,
        address sender,
        uint amount
    ) private returns (uint liqPrice) {
        usdt.transferFrom(sender, address(grow), amount);
        uint boughtGrow = uint(
            grow.buyFor(address(this), amount, address(usdt))
        );
        liqPrice = calculateLiquidationPrice(amount, boughtGrow);
        Position storage created = positions[queuePosition];
        created.depositTime = block.timestamp;
        created.owner = user;
        created.amountDeposited = amount;
        created.growAmount = boughtGrow;
        created.liquidationPrice = liqPrice;
        emit Deposit(user, queuePosition, amount, boughtGrow);
        queuePosition++;
    }

    //------------------------------------------------
    // External View Functions
    //------------------------------------------------
    function getUserPositions(
        address _owner
    ) public view returns (uint[] memory) {
        uint length = userMainDeposits[_owner].length;
        uint[] memory allPositions = new uint[](length);
        for (uint i = 0; i < length; i++) {
            allPositions[i] = userMainDeposits[_owner][i].positionId;
        }
        return allPositions;
    }

    function getUserPositionsInfo(
        address _owner
    ) external view returns (Position[] memory) {
        uint length = userMainDeposits[_owner].length;
        Position[] memory positionsInfo = new Position[](length);
        for (uint i = 0; i < length; i++) {
            positionsInfo[i] = positions[
                userMainDeposits[_owner][i].positionId
            ];
        }
        return positionsInfo;
    }

    function getPositions(
        uint startPosition,
        uint positionAmount
    ) external view returns (Position[] memory) {
        Position[] memory positionsInfo = new Position[](positionAmount);
        for (uint i = 0; i < positionAmount; i++) {
            positionsInfo[i] = positions[startPosition + i];
        }
        return positionsInfo;
    }

    function getUserMainPositions(
        address _owner
    ) external view returns (UserPositions[] memory) {
        return userMainDeposits[_owner];
    }

    //------------------------------------------------
    // Private View PURE Functions
    //------------------------------------------------
    function calculateLiquidationPrice(
        uint depositAmount,
        uint growAmount
    ) private pure returns (uint) {
        return
            (depositAmount * FULL_TARGET_PROFIT * MAGNIFIER) /
            (growAmount * GROW_SELL_TOTAL_RCV);
    }

    function calculateMinProfitAmount(uint amount) private pure returns (uint) {
        return (amount * FULL_MIN_PROFIT) / PERCENT;
    }
}
