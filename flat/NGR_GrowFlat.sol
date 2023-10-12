//SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/IERC20.sol)

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

interface IGrow is IERC20 {
    function burn(uint256 amount) external;

    function sell(
        uint256 amount,
        address stable
    ) external returns (uint stableReceived);

    function sell(
        address recipient,
        uint256 amount,
        address stable
    ) external returns (uint stableReceived);

    function sellAll(address _stable) external;

    // These functions are used to buy CLIMB with STABLE, STABLE will need to be approved for transfer in for this contract.
    function buy(uint256 numTokens, address stable) external returns (uint256);

    function buy(
        address recipient,
        uint256 numTokens,
        address stable
    ) external returns (uint256);

    /// @notice although this function has the same parameters as the BUY functions, only Matrix contracts can call this function
    /// @dev the Matrix contract MUST send STABLE tokens to this contract before calling this function. Without this function, the Matrix contract would have to receive STABLE tokens from the user, then approve STABLE tokens to the contract to buy CLIMB token and then CLIMB would need to transfer STABLE back to themselves. This function saves gas and time.
    function buyFor(
        address recipient,
        uint256 numTokens,
        address stable
    ) external returns (uint256);

    function eraseHoldings(uint256 nHoldings) external;

    function volumeFor(address wallet) external view returns (uint256);

    function calculatePrice() external view returns (uint256);

    function burnWithUnderlying(
        uint256 underlyingAmount,
        address _stable
    ) external;

    function stables(
        address _stable
    )
        external
        view
        returns (
            uint balance,
            uint8 index,
            uint8 decimals,
            bool accepted,
            bool setup
        );

    function allStables() external view returns (address[] memory);

    ///@notice this function is called by OWNER only and is used to exchange the complete balance in STABLE1 for STABLE2
    function exchangeTokens(
        address stable1,
        address stable2,
        address _router
    ) external;

    // owner functions
    function setExecutorAddress(address executor, bool exempt) external;

    ///////////////////////////////////
    //////        EVENTS        ///////
    ///////////////////////////////////

    event UpdateShares(uint256 updatedDevShare, uint256 updatedLiquidityShare);
    event UpdateFees(
        uint256 updatedSellFee,
        uint256 updatedMintFee,
        uint256 updatedTransferFee
    );
    event UpdateDevAddress(address updatedDev);
    event SetExecutor(address executor, bool isExecutor);
    event PriceChange(
        uint256 previousPrice,
        uint256 currentPrice,
        uint256 totalSupply
    );
    event ErasedHoldings(address who, uint256 amountTokensErased);
    event GarbageCollected(uint256 amountTokensErased);
    event UpdateTokenSlippage(uint256 newSlippage);
    event TransferOwnership(address newOwner);
    event TokenStaked(uint256 assetsReceived, address recipient);
    event SetFeeExemption(address Contract, bool exempt);
    event TokenActivated(uint256 totalSupply, uint256 price, uint256 timestamp);
    event TokenSold(
        uint256 amountCLIMB,
        uint256 assetsRedeemed,
        address recipient
    );
    event TokenPurchased(uint256 assetsReceived, address recipient);
    event SetStableToken(address stable, bool exempt);
    event ExchangeToken(
        address _from,
        address _to,
        uint256 amountFROM,
        uint256 amountTO
    );
}

interface IOwnableGrow is IGrow {
    function owner() external returns (address);
}

// OpenZeppelin Contracts (last updated v4.9.0) (access/Ownable.sol)

// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

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

    uint public splitAmounts = 20 ether;
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
        uint splits = amount / splitAmounts;
        for (uint i = 0; i < splits; i++) {
            _deposit(msg.sender, msg.sender, splitAmounts, liqAmount);
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
        uint splits = amount / splitAmounts;
        for (uint i = 0; i < splits; i++) {
            _deposit(_receiver, msg.sender, splitAmounts, liqAmount);
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
            uint extra = liquidateUser % splitAmounts;
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
