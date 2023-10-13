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
        uint8 liquidationPercent;
        bool isLiquidated;
        bool early;
    }

    struct UserStats {
        uint totalDeposited;
        uint totalLiquidated;
        uint totalEarly;
        uint otherLiquidationProfits;
    }
    //------------------------------------------------
    // State Variables
    //------------------------------------------------
    mapping(uint8 => bool) public acceptedReturns;
    mapping(uint posId => Position) public positions;
    mapping(address => uint[]) public userPositions;
    mapping(address => UserStats) public userStats;
    mapping(address => bool) public autoReinvest;

    IGrow public immutable grow;
    IERC20 public immutable usdt;
    address public devWallet;
    address public burnerWallet;

    uint public currentPositionToLiquidate;
    uint public queuePosition;

    uint public totalDeposits;
    uint public totalLiquidations;

    uint public liquidatorAmount = 1;
    uint public totalAmount = 5;

    uint public burnerAmount = 2 ether;

    uint public constant MIN_DEPOSIT = 10 ether;
    uint public constant INIT_MAX_DEPOSIT = 100 ether;
    uint public constant MAX_DEPOSIT_LIMIT = 1_000 ether;

    uint public constant EARLY_FEE = 4;
    uint public constant PERCENT = 100;
    uint private constant MAGNIFIER = 1 ether;

    //------------------------------------------------
    // Events
    //------------------------------------------------
    event Deposit(
        address indexed owner,
        uint indexed position,
        uint amount,
        uint helixBought
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
    event LiquidatedSelf(
        address indexed owner,
        uint indexed position,
        uint totalReceived
    );
    event LiquidatedOthers(
        address indexed liquidator,
        uint totalLiquidatorReceived,
        uint totalLiquidated
    );
    event SelfAutoReinvest(address indexed owner, bool autoReinvest);

    //------------------------------------------------
    // Constructor
    //------------------------------------------------
    constructor(address _grow, address _usdt, address _dev, address _burner) {
        currentPositionToLiquidate = 0;
        queuePosition = 0;
        grow = IGrow(_grow);
        usdt = IERC20(_usdt);
        acceptedReturns[4] = true;
        acceptedReturns[5] = true;
        acceptedReturns[6] = true;
        acceptedReturns[7] = true;
        acceptedReturns[8] = true;
        devWallet = _dev;
        usdt.approve(_grow, type(uint).max);
        burnerWallet = _burner;
    }

    //------------------------------------------------
    // External Functions
    //------------------------------------------------

    /**
     * @notice Deposit USDT to the contract and buy GROW
     * @param amount Amount of USDT to deposit
     * @param liqAmount Liquidation amount in percentage to profit
     */
    function deposit(
        uint amount,
        uint8 liqAmount,
        bool _autoReinvest
    ) external {
        if (amount % 10 ether != 0) revert NGR_GROW__InvalidDepositAmount();
        if (amount < MIN_DEPOSIT) revert NGR_GROW__InvalidMinDeposit();
        if (amount > INIT_MAX_DEPOSIT) {
            uint tcv = usdt.balanceOf(address(grow));
            if (tcv > MAX_DEPOSIT_LIMIT) {
                if (amount > tcv / 10) revert NGR_GROW__InvalidMaxDeposit();
            } else revert NGR_GROW__InvalidMaxDeposit();
        }
        if (!acceptedReturns[liqAmount]) {
            revert NGR_GROW__InvalidLiquidationAmount();
        }
        autoReinvest[msg.sender] = _autoReinvest;
        uint splits = amount / MIN_DEPOSIT;
        for (uint i = 0; i < splits; i++) {
            _deposit(msg.sender, msg.sender, MIN_DEPOSIT, liqAmount);
        }

        burnGrow();
        userStats[msg.sender].totalDeposited += amount;
        totalDeposits += amount;
    }

    function depositForUser(
        uint amount,
        uint8 liqAmount,
        address _receiver
    ) external {
        if (amount % 10 ether != 0) revert NGR_GROW__InvalidDepositAmount();
        if (amount < MIN_DEPOSIT) revert NGR_GROW__InvalidMinDeposit();
        if (amount > INIT_MAX_DEPOSIT) {
            uint tcv = usdt.balanceOf(address(grow));
            if (tcv > MAX_DEPOSIT_LIMIT) {
                if (amount > tcv / 10) revert NGR_GROW__InvalidMaxDeposit();
            } else revert NGR_GROW__InvalidMaxDeposit();
        }
        if (!acceptedReturns[liqAmount]) {
            revert NGR_GROW__InvalidLiquidationAmount();
        }
        uint splits = amount / MIN_DEPOSIT;
        for (uint i = 0; i < splits; i++) {
            _deposit(_receiver, msg.sender, MIN_DEPOSIT, liqAmount);
        }

        burnGrow();
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

    function liquidateSelf(uint position) external {
        Position storage liquidatedPos = positions[position];
        // Check that position is not already liquidated and caller is owner
        if (liquidatedPos.isLiquidated || liquidatedPos.owner != msg.sender)
            revert NGR_GROW__InvalidWithdraw();

        // Check that target price is reached
        uint currentPrice = grow.calculatePrice();
        if (currentPrice < liquidatedPos.liquidationPrice)
            revert NGR_GROW__LowPrice();

        liquidatedPos.isLiquidated = true;
        liquidatedPos.liqTime = block.timestamp;

        uint totalSell = grow.sell(
            address(this),
            liquidatedPos.growAmount,
            address(usdt)
        );
        uint maxLiq = (liquidatedPos.amountDeposited *
            liquidatedPos.liquidationPrice) / MAGNIFIER;

        uint liquidateUser = totalSell;
        if (totalSell > maxLiq) {
            uint diff = (totalSell - maxLiq) / 2;
            liquidateUser = totalSell - diff;
            usdt.transfer(devWallet, diff);
        }

        liquidatedPos.liquidatedAmount = liquidateUser;

        if (autoReinvest[msg.sender]) {
            uint extra = liquidateUser % MIN_DEPOSIT;
            liquidateUser -= extra;
            _deposit(
                msg.sender,
                address(this),
                liquidateUser,
                liquidatedPos.liquidationPercent
            );
            if (extra > 0) usdt.transfer(liquidatedPos.owner, extra);
        } else usdt.transfer(liquidatedPos.owner, liquidateUser);

        totalLiquidations += totalSell;
        emit LiquidatedSelf(msg.sender, position, totalSell);
    }

    function liquidateOthers(uint[] calldata _positions) external {
        uint rewardAccumulator = 0;
        uint accLiquidations = 0;
        for (uint i = 0; i < _positions.length; i++) {
            uint currentPrice = grow.calculatePrice();
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

            uint maxReturn = (liquidatedPos.amountDeposited *
                liquidatedPos.liquidationPrice) / MAGNIFIER;

            if (totalSell > maxReturn) {
                uint diff = maxReturn / PERCENT;
                diff +=
                    ((totalSell - maxReturn) * liquidatorAmount) /
                    totalAmount;
                totalSell -= diff;
                rewardAccumulator += diff;
            } else {
                uint diff = (totalSell * liquidatorAmount) / totalAmount;
                totalSell -= diff;
                rewardAccumulator += diff;
            }
            userStats[liquidatedPos.owner].totalLiquidated += totalSell;

            if (autoReinvest[liquidatedPos.owner])
                _deposit(
                    liquidatedPos.owner,
                    address(this),
                    totalSell,
                    liquidatedPos.liquidationPercent
                );
            else usdt.transfer(liquidatedPos.owner, totalSell);
            emit Liquidated(liquidatedPos.owner, _positions[i], totalSell);
        }
        totalLiquidations += accLiquidations;
        userStats[msg.sender].otherLiquidationProfits += rewardAccumulator;
        if (rewardAccumulator > 0) usdt.transfer(msg.sender, rewardAccumulator);
        emit LiquidatedOthers(msg.sender, rewardAccumulator, accLiquidations);
    }

    function setSelfAutoReinvest(bool _autoReinvest) external {
        autoReinvest[msg.sender] = _autoReinvest;
        emit SelfAutoReinvest(msg.sender, _autoReinvest);
    }

    function updateDevWallet(address _devWallet) external onlyOwner {
        devWallet = _devWallet;
    }

    function setBurnAmount(uint _burnerAmount) external onlyOwner {
        burnerAmount = _burnerAmount;
    }

    //------------------------------------------------
    // Private / Internal Functions
    //------------------------------------------------
    function _deposit(
        address user,
        address sender,
        uint amount,
        uint8 liqAmount
    ) private {
        userPositions[user].push(queuePosition);
        usdt.transferFrom(sender, address(grow), amount);
        uint boughtGrow = uint(
            grow.buyFor(address(this), amount, address(usdt))
        );
        uint liquidatedPrice = ((amount * (100 + liqAmount)) * MAGNIFIER) /
            (96 * boughtGrow);

        Position storage created = positions[queuePosition];
        created.depositTime = block.timestamp;
        created.owner = user;
        created.amountDeposited = amount;
        created.growAmount = boughtGrow;
        created.liquidationPrice = liquidatedPrice;
        created.liquidationPercent = liqAmount;
        emit Deposit(user, queuePosition, amount, boughtGrow);
        queuePosition++;
    }

    function burnGrow() private {
        // If not enough funds, return
        if (usdt.balanceOf(burnerWallet) < burnerAmount) return;

        usdt.transferFrom(burnerWallet, address(this), burnerAmount);
        grow.burnWithUnderlying(burnerAmount, address(usdt));
    }

    //------------------------------------------------
    // External View Functions
    //------------------------------------------------
    function getUserPositions(
        address _owner
    ) public view returns (uint[] memory) {
        return userPositions[_owner];
    }

    function getUserPositionsInfo(
        address _owner
    ) external view returns (Position[] memory) {
        uint[] memory userPosIds = getUserPositions(_owner);
        Position[] memory positionsInfo = new Position[](userPosIds.length);
        for (uint i = 0; i < userPosIds.length; i++) {
            positionsInfo[i] = positions[userPosIds[i]];
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
}
