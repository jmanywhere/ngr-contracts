// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IGrow, IERC20} from "./interfaces/IGrow.sol";
import {ReentrancyGuard} from "openzeppelin/security/ReentrancyGuard.sol";

error GrowDrip__OnlyOwner();
error GrowDrip__InvalidLiquidator();
error GrowDrip__InvalidAddress();
error GrowDrip__InvalidOperation();
error GrowDrip__ZeroLiquidation();
error GrowDrip__MinInitDepositNotMet();

contract GrowDrip is ReentrancyGuard {
    //-------------------------------------------------------------------------
    // Type Definitions
    //-------------------------------------------------------------------------
    struct User {
        uint totalDeposited;
        uint currentGrowAmount;
        uint lastClaimed;
        uint totalClaimed;
        uint position;
    }
    //-------------------------------------------------------------------------
    // State Variables
    //-------------------------------------------------------------------------
    mapping(address => User) public users;
    mapping(address => uint) public liquidatorEarnings;
    mapping(address => bool) public feeExemption;
    address[] private allUsers;
    address[] private owners;
    uint[] private shares;
    IGrow public immutable GROW;
    IERC20 public immutable USDT;
    address public owner;
    uint private totalShares;
    uint public totalClaimed;
    uint public totalDeposits;
    uint public activeDeposits;
    uint public MAX_CLAIMABLE = 5; // 0.5%
    uint public OWNER_FEES = 5; // 5%
    uint public constant LIQUIDATOR_FEES = 190;
    uint public constant PERCENTAGE = 100_0;
    uint public constant SHARE_BASE_PERCENTAGE = 90;
    uint public constant MAX_CLAIM_TIME = 24 hours;
    uint private constant MIN_INIT_DEPOSIT = 100 ether;
    uint private constant MIN_AMOUNT = 1 ether;
    uint public liquidationThresholdHours;
    //-------------------------------------------------------------------------
    // Events
    //-------------------------------------------------------------------------
    //------------------------------DRIP---------------------------------------
    event Deposit(
        address indexed user,
        uint usdtAmount,
        uint growAmount,
        uint timestamp
    );
    event Claim(
        address indexed user,
        uint grow_amount_sold,
        uint usdt_amount_received,
        uint timestamp
    );
    event Liquidated(
        address indexed liquidator,
        uint users_liquidated,
        uint grow_received_from_users,
        uint usdt_amount_for_liquidator,
        uint timestamp
    );
    event PriceAfterBurn(uint price, uint timestamp);
    event Quit(address indexed user, uint timestamp);
    //---------------------------OWNERSHIP-------------------------------------
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );
    event OwnershipRenounced(address indexed previousOwner);
    event SetLiquidationThreshold(
        uint previousLiquidationThreshold,
        uint newLiquidationThreshold
    );
    //-------------------------------------------------------------------------
    // Modifiers
    //-------------------------------------------------------------------------
    modifier onlyOwner() {
        if (msg.sender == owner) _;
        else revert GrowDrip__OnlyOwner();
    }

    //-------------------------------------------------------------------------
    // Constructor
    //-------------------------------------------------------------------------
    /**
     * Create the GrowDrip contract
     * @param _usdt USDT token address
     * @param _grow GROW token address
     * @param _owners Dev team wallets
     * @param _shares Shares per wallet
     */
    constructor(
        address _usdt,
        address _grow,
        address[] memory _owners,
        uint[] memory _shares
    ) {
        if (_usdt == address(0) || _grow == address(0)) {
            revert GrowDrip__InvalidAddress();
        }
        USDT = IERC20(_usdt);
        GROW = IGrow(_grow);
        owner = msg.sender;
        liquidationThresholdHours = 25 hours;
        USDT.approve(_grow, type(uint).max);
        feeExemption[_owners[0]] = true;
        for (uint i = 0; i < _owners.length; i++) {
            owners.push(_owners[i]);
            shares.push(_shares[i]);
            totalShares += _shares[i];
        }
    }

    //-------------------------------------------------------------------------
    // EXTERNAL / PUBLIC FUNCTIONS
    //-------------------------------------------------------------------------

    /**
     * @notice Deposit USDT to the contract to start the DRIP
     * @param amount Amount of USDT to deposit
     * @dev If there is a pending claim, it'll claim it first.
     */
    function deposit(uint amount) external nonReentrant {
        _claim(msg.sender, false);
        User storage user = users[msg.sender];

        if (user.totalDeposited == 0) {
            if (amount < MIN_INIT_DEPOSIT)
                revert GrowDrip__MinInitDepositNotMet();
            user.position = allUsers.length;
            allUsers.push(msg.sender);
        }
        user.totalDeposited += amount;
        user.lastClaimed = block.timestamp;
        totalDeposits += amount;
        activeDeposits += amount;

        // Deposits creates Grow tokens
        uint growBuy = 0;
        if (feeExemption[msg.sender]) growBuy = (amount * 95) / 100;
        else growBuy = (amount * 9) / 10;

        uint taxAmount = amount - growBuy;
        // 15% tax here
        // buy with 90% of USDT taxless
        USDT.transferFrom(msg.sender, address(GROW), growBuy);
        USDT.transferFrom(msg.sender, address(this), taxAmount);

        uint growBought = GROW.buyFor(address(this), growBuy, address(USDT));
        // 10% burn after buy
        GROW.burnWithUnderlying(taxAmount, address(USDT));
        emit PriceAfterBurn(GROW.calculatePrice(), block.timestamp);
        // 5/90 of GROW to team
        if (!feeExemption[msg.sender])
            growBought = _distributeSharesFromFullValue(growBought);
        user.currentGrowAmount += growBought;
        emit Deposit(msg.sender, amount, growBought, block.timestamp);
    }

    /**
     * @notice Claim drip USDT from the contract
     * @dev This will only claim the caller's pending drip
     */
    function claim() external nonReentrant {
        _claim(msg.sender, false);
    }

    /**
     * @notice Liquidate users that have not claimed for 25 hours
     * @param usersToLiquidate List of users to liquidate
     * @dev If a user tries to liquidate a user who doesn't have a pending claim, it'll claim whatever is pending
     */
    function liquidateUsers(
        address[] calldata usersToLiquidate
    ) external nonReentrant {
        // Make sure it's a valid liquidator
        if (users[msg.sender].totalDeposited == 0)
            revert GrowDrip__InvalidLiquidator();
        // Liquidators can liquidate users that have not claimed for 25 hours
        uint liquidatorAmount;
        uint burnAmount;
        for (uint i = 0; i < usersToLiquidate.length; i++) {
            (uint liq, uint burn) = _claim(usersToLiquidate[i], true);
            liquidatorAmount += liq;
            burnAmount += burn;
        }
        if (liquidatorAmount == 0) revert GrowDrip__ZeroLiquidation();
        uint soldAmount = GROW.sell(liquidatorAmount, address(USDT));
        // Liquidators take 0.1% of the liquidated amount of each user
        // sell the GROW liquidatorAmount and transfer the USDT to them.
        USDT.transfer(msg.sender, soldAmount);
        liquidatorEarnings[msg.sender] += soldAmount;
        if (burnAmount > 0) {
            GROW.burnWithUnderlying(burnAmount, address(USDT));
            emit PriceAfterBurn(GROW.calculatePrice(), block.timestamp);
        }
        emit Liquidated(
            msg.sender,
            usersToLiquidate.length,
            liquidatorAmount,
            soldAmount,
            block.timestamp
        );
    }

    function quit() external nonReentrant {
        User storage user = users[msg.sender];
        if (user.totalDeposited == 0 || user.currentGrowAmount == 0)
            revert GrowDrip__InvalidOperation();

        // get taxed amount
        uint growAmount = user.currentGrowAmount;
        uint devAmount = growAmount / 10; // 10% fee for quitting
        uint burnTax = (growAmount * 5) / 100; // 5% sell tax

        growAmount -= devAmount;
        growAmount -= burnTax;

        uint usdtAmount = GROW.sell(growAmount, address(USDT));
        // reset USER
        activeDeposits -= user.totalDeposited;
        users[msg.sender] = User(0, 0, 0, user.totalClaimed + usdtAmount, 0);
        // remove user from list of active users
        allUsers[user.position] = allUsers[allUsers.length - 1];
        allUsers.pop();

        USDT.transfer(msg.sender, usdtAmount);
        GROW.burn(burnTax);
        emit PriceAfterBurn(GROW.calculatePrice(), block.timestamp);

        uint ownerShare = devAmount / 2;
        devAmount -= ownerShare;
        GROW.transfer(owners[0], ownerShare);
        GROW.transfer(owners[1], devAmount);
        emit Quit(msg.sender, block.timestamp);
    }

    function setLiquidationThreshold(uint _hours) external onlyOwner {
        if (_hours < 24 hours) revert GrowDrip__InvalidOperation();
        emit SetLiquidationThreshold(liquidationThresholdHours, _hours);
        liquidationThresholdHours = _hours;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
        if (newOwner == address(0)) {
            emit OwnershipRenounced(owner);
        }
    }

    function setFeeExemptStatus(address _who, bool _status) external onlyOwner {
        feeExemption[_who] = _status;
    }

    //-------------------------------------------------------------------------
    // PRIVATE/ INTERNAL FUNCTIONS
    //-------------------------------------------------------------------------

    function _claim(
        address _who,
        bool liquidator
    ) private returns (uint _liquidatorAmount, uint _burnAmount) {
        // do the entire liquidation sequence here
        // Do checks for _who
        User storage user = users[_who];
        if (user.totalDeposited == 0 || user.currentGrowAmount == 0)
            return (0, 0);
        // goal amount and growamount
        (, uint tokenAmount, uint growAmount) = claimable(_who);
        if (tokenAmount == 0) return (0, 0);
        // Liquidator Checks
        if (liquidator) {
            if (block.timestamp - user.lastClaimed < liquidationThresholdHours)
                return (0, 0);
        }

        // Do checks for liquidator
        // if user requires more than amount held, user is reset
        if (growAmount >= user.currentGrowAmount) {
            growAmount = user.currentGrowAmount;
            users[_who] = User(0, 0, 0, user.totalClaimed, 0);
            //remove user from list of active users
            allUsers[user.position] = allUsers[allUsers.length - 1];
            allUsers.pop();
            users[_who] = User(0, 0, 0, user.totalClaimed, 0);
        } else user.currentGrowAmount -= growAmount;
        // liquidator Maths
        if (liquidator) {
            // get 1/5th of the goalAmount to liquidator
            _liquidatorAmount = (growAmount * LIQUIDATOR_FEES) / PERCENTAGE;
            growAmount -= _liquidatorAmount;
        }
        uint trackGrow = growAmount;
        // sell all claimed amount
        tokenAmount = GROW.sell(growAmount, address(USDT));
        if (liquidator) {
            growAmount = (tokenAmount * 5) / 81; // 5% sell tax
            // Accumulate the 5% for a single massive burn
            _burnAmount = growAmount;
        } else {
            // burn 5% of the sell amount
            growAmount = (tokenAmount * 5) / 100; // 5% sell tax
            GROW.burnWithUnderlying(growAmount, address(USDT));
            emit PriceAfterBurn(GROW.calculatePrice(), block.timestamp);
        }
        tokenAmount -= growAmount;
        totalClaimed += tokenAmount;
        user.lastClaimed = block.timestamp;
        user.totalClaimed += tokenAmount;
        USDT.transfer(_who, tokenAmount);
        emit Claim(_who, trackGrow, tokenAmount, block.timestamp);
    }

    function _distributeSharesFromFullValue(
        uint _amount
    ) private returns (uint) {
        // Distribute the shares to the owners
        uint allShares = _ownerShares(_amount);
        for (uint i = 0; i < owners.length; i++) {
            uint share = (allShares * shares[i]) / totalShares;
            _amount -= share;
            GROW.transfer(owners[i], share);
        }
        return _amount;
    }

    //-------------------------------------------------------------------------
    // EXTERNAL / PUBLIC VIEW FUNCTIONS
    //-------------------------------------------------------------------------

    function claimable(
        address _who
    )
        public
        view
        returns (uint maxClaimableAmount, uint tokensToReceive, uint growToBurn)
    {
        User storage user = users[_who];
        // if not a current user, return 0
        if (user.totalDeposited == 0 || user.currentGrowAmount == 0)
            return (0, 0, 0);
        // Returns the amount of USDT that are claimable based on last action
        uint timeDiff = block.timestamp - user.lastClaimed;
        if (timeDiff > MAX_CLAIM_TIME) {
            timeDiff = MAX_CLAIM_TIME;
        }
        // This is capped at 0.5% of the deposited amount
        maxClaimableAmount = (user.totalDeposited * 5) / 100_0; // 0.5% of total deposited
        maxClaimableAmount = (timeDiff * maxClaimableAmount) / MAX_CLAIM_TIME;
        tokensToReceive = (maxClaimableAmount * 100) / 95;
        uint growPrice = GROW.calculatePrice();
        growToBurn = (tokensToReceive * 1 ether) / growPrice;
        if (growToBurn > user.currentGrowAmount) {
            growToBurn = user.currentGrowAmount;
        }
        tokensToReceive = (growToBurn * growPrice) / 1 ether;
    }

    /**
     * This function is intended for FRONTEND use only
     * @return pendingLiquidation List of all users that need to be liquidated
     * @return rewardAmounts
     */
    function usersPendingLiquidation()
        external
        view
        returns (
            address[] memory pendingLiquidation,
            uint[] memory rewardAmounts
        )
    {
        // Returns the list of users that are pending liquidation
        uint count;
        uint[] memory indexes = new uint[](allUsers.length);
        for (uint i = 0; i < allUsers.length; i++) {
            if (
                block.timestamp - users[allUsers[i]].lastClaimed >=
                liquidationThresholdHours * 1 hours
            ) {
                indexes[count] = i;
                count++;
            }
        }
        pendingLiquidation = new address[](count);
        rewardAmounts = new uint[](count);
        // Returns the amount of USDT that the liquidator will receive for liquidating each user
        for (uint j = 0; j < count; j++) {
            address pendingUser = allUsers[indexes[j]];
            pendingLiquidation[j] = pendingUser;
            (, uint actual, ) = claimable(pendingUser);
            rewardAmounts[j] = (actual * LIQUIDATOR_FEES) / PERCENTAGE;
        }
    }

    //-------------------------------------------------------------------------
    // PRIVATE / INTERNAL VIEW FUNCTIONS
    //-------------------------------------------------------------------------

    function _ownerShares(
        uint totalAmount
    ) private view returns (uint allShares) {
        allShares = (totalAmount * OWNER_FEES) / SHARE_BASE_PERCENTAGE;
    }

    function _maxClaimable(uint amount) private view returns (uint) {
        return (amount * MAX_CLAIMABLE) / PERCENTAGE;
    }
}
