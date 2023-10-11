//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IGrow} from "./interfaces/IGrow.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";

error NGR_GROW__InvalidLiquidationAmount();
error NGR_GROW__InvalidWithdraw();
error NGR_GROW__LowPrice();
error NGR_GROW__InvalidMinDeposit();
error NGR_GROW__InvalidMaxDeposit();

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
        bool isLiquidated;
        bool early;
    }

    //------------------------------------------------
    // State Variables
    //------------------------------------------------
    mapping(uint8 => bool) public acceptedReturns;
    mapping(uint posId => Position) public positions;
    mapping(address => uint[]) public userPositions;

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

    uint public minSplitAmount = 20 ether;
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
    function deposit(uint amount, uint8 liqAmount) external {
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
        if (amount > minSplitAmount) {
            uint depositSplit = amount / 2;
            _deposit(msg.sender, msg.sender, depositSplit, liqAmount);
            _deposit(msg.sender, msg.sender, amount - depositSplit, liqAmount);
        } else _deposit(msg.sender, msg.sender, amount, liqAmount);

        burnGrow();
        totalDeposits += amount;
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
        usdt.transfer(exitPos.owner, min);
        // If there's any remaning, that's the fee
        if (remaining > 0) usdt.transfer(devWallet, remaining);

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
            liquidatedPos.owner,
            liquidatedPos.growAmount,
            address(usdt)
        );

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
            uint reward = (totalSell * liquidatorAmount) / totalAmount;
            rewardAccumulator += reward;
            reward = totalSell - reward;
            usdt.transfer(liquidatedPos.owner, reward);
            emit Liquidated(liquidatedPos.owner, _positions[i], reward);
        }
        totalLiquidations += accLiquidations;
        if (rewardAccumulator > 0) usdt.transfer(msg.sender, rewardAccumulator);
        emit LiquidatedOthers(msg.sender, rewardAccumulator, accLiquidations);
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
        created.owner = msg.sender;
        created.amountDeposited = amount;
        created.growAmount = boughtGrow;
        created.liquidationPrice = liquidatedPrice;
        emit Deposit(msg.sender, queuePosition, amount, boughtGrow);
        queuePosition++;
    }

    function burnGrow() private {
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
