// SPDX-License-Identifier: MIT
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

// -------------------------------------------------------
// Error Codes
// -------------------------------------------------------
error NGR_InvalidAmount();
error NGR__CannotLiquidate();

contract NGR_v2 {
    // -------------------------------------------------------
    // Type Definitions
    // -------------------------------------------------------
    struct PositionInfo {
        address owner;
        uint depositAmount;
        uint depositTime;
        uint liquidationTime;
    }
    struct CorpPosition {
        address owner;
        uint depositAmount;
        uint depositTime;
        uint liquidationTime;
        uint liquidationPosition;
    }
    struct UserStats {
        uint totalDeposited;
        uint totalLiquidated;
        uint totalWithdrawn;
        uint totalPositions;
        uint totalPositionsLiquidated;
        uint totalPositionsWithdrawn;
        uint lastLiquidatedPosition;
    }
    // -------------------------------------------------------
    // State Variables
    // -------------------------------------------------------
    IERC20 public immutable USDT;
    mapping(uint => PositionInfo) public positions;
    mapping(address => UserStats) public userStats;
    mapping(address => uint[]) public userPositions;
    CorpPosition public corpPosition3;
    CorpPosition public corpPosition4;

    uint public constant MIN_DEPOSIT = 100 ether;
    uint public constant MAX_DEPOSIT = 100 ether;
    uint private constant BASE_PROPORTION = 100;
    uint private constant MAX_PRICE = 1.2 ether;
    uint private constant LIQUIDATION_PROFIT = 106;
    uint private constant FULL_LIQUIDATION = 10662;
    uint private constant FULL_BASE_PROPORTION = 10000;

    address[] public owners;

    address public liqOutWallet;
    address public corpWallet;

    uint public totalDeposits;
    uint public totalLiquidations;

    uint private corpLiqs;
    uint private depositFee = 3;
    uint private helixCreated = 98;
    uint private devProportion = 15;

    uint public totalSupply;
    // userToLiquidate: starts at one meaning the first position to liquidate
    uint public userToLiquidate = 1;
    uint public positionsCounter;
    uint public depositCounter;
    uint public liquidationsCounter;
    uint public cycleCounter;

    bool private firstLiquidation = true;

    // -------------------------------------------------------
    // Events
    // -------------------------------------------------------
    event Deposit(address indexed user, uint256 amount, uint256 indexPosition);
    event Liquidate(address indexed user, uint amount, uint position);

    // -------------------------------------------------------
    // Constructor
    // -------------------------------------------------------
    constructor(
        address _token,
        address _liqOut,
        address _seed,
        address[] memory _owners
    ) {
        USDT = IERC20(_token);
        owners = _owners;
        liqOutWallet = _liqOut;
        corpWallet = _seed;
        totalSupply = 1 ether;
    }

    // -------------------------------------------------------
    // External Functions
    // -------------------------------------------------------

    /**
     * @notice Function to deposit USDT into the protocol
     * @param amount The amount of USDT to be deposited
     */
    function deposit(uint amount) external {
        _deposit(msg.sender, msg.sender, amount);
        _autoLiquidate(5, false);
    }

    function depositForUser(uint amount, address receiver) external {
        _deposit(receiver, msg.sender, amount);
        _autoLiquidate(5, false);
    }

    function liquidate() external {
        _autoLiquidate(10, true);
    }

    // -------------------------------------------------------
    // Internal & Private Functions
    // -------------------------------------------------------
    /**
     * @notice Function to distribute USDT to owners
     * @param amount The amount of USDT to be distributed amongst owners
     */
    function distributeToOwners(uint amount) private {
        uint amountPerOwner = amount / owners.length;
        for (uint i = 0; i < owners.length; i++) {
            USDT.transfer(owners[i], amountPerOwner);
        }
    }

    /**
     * @notice Function to deposit USDT into the protocol for any user by any caller
     * @param _user User who will receive the deposit
     * @param _caller User who will pay the USDT
     * @param amount Amount of USDT to be deposited
     */
    function _deposit(address _user, address _caller, uint amount) private {
        // if (amount < MIN_DEPOSIT && amount > MAX_DEPOSIT)
        if (amount != MIN_DEPOSIT) revert NGR_InvalidAmount();
        totalDeposits += amount;
        uint devFee = (amount * depositFee) / BASE_PROPORTION;

        uint realAmount = amount - devFee;
        devFee = (devFee * devProportion) / BASE_PROPORTION;
        realAmount = _helixCreate(realAmount);

        totalSupply += realAmount;
        depositCounter++;
        positionsCounter++;
        positions[positionsCounter] = PositionInfo({
            owner: _user,
            depositAmount: amount,
            depositTime: block.timestamp,
            liquidationTime: 0
        });
        userPositions[_user].push(positionsCounter);
        emit Deposit(_user, amount, positionsCounter);
        USDT.transferFrom(_caller, address(this), amount);
        UserStats storage stats = userStats[_user];
        stats.totalDeposited += amount;
        stats.totalPositions++;

        distributeToOwners(devFee);
        adjustPrice();
    }

    /**
     * @notice Function to adjust the price of HELIX back to 1$
     */
    function adjustPrice() private {
        uint currentPrice = helixPrice();
        if (currentPrice > MAX_PRICE) {
            cycleCounter++;
            totalSupply = USDT.balanceOf(address(this));
        }
    }

    function _liquidate() private {
        if (firstLiquidation) firstLiquidation = false;
        PositionInfo storage position = positions[userToLiquidate];

        if (position.liquidationTime != 0) {
            userToLiquidate++;
            return _liquidate();
        }
        position.liquidationTime = block.timestamp;
        uint liquidationAmount = (position.depositAmount * LIQUIDATION_PROFIT) /
            BASE_PROPORTION;
        uint totalTokens = (position.depositAmount * FULL_LIQUIDATION) /
            FULL_BASE_PROPORTION;

        uint mktAmount = totalTokens - liquidationAmount;

        totalTokens =
            (totalSupply * totalTokens) /
            USDT.balanceOf(address(this));
        totalSupply -= totalTokens;

        UserStats storage stats = userStats[position.owner];
        stats.totalLiquidated += liquidationAmount;
        stats.totalPositionsLiquidated++;
        stats.lastLiquidatedPosition = userToLiquidate;
        totalLiquidations += liquidationAmount;
        liquidationsCounter++;

        USDT.transfer(position.owner, liquidationAmount);
        USDT.transfer(liqOutWallet, mktAmount);
        emit Liquidate(position.owner, liquidationAmount, userToLiquidate);
        userToLiquidate++;
        adjustPrice();
    }

    function _autoLiquidate(uint cycleAmount, bool shouldRevert) internal {
        bool canAdvance = canLiquidate();
        if (!canAdvance) {
            if (shouldRevert) revert NGR__CannotLiquidate();
            else return;
        }
        uint upkeepLiquidations = 0;
        do {
            // liquidate next position
            _liquidate();
            canAdvance = canLiquidate();
            upkeepLiquidations++;
        } while (canAdvance && upkeepLiquidations < cycleAmount);
    }

    // -------------------------------------------------------
    // External & Public VIEW Functions
    // -------------------------------------------------------

    /**
     * @notice Function to get the price of HELIX
     * @return The price of 1 HELIX
     */
    function helixPrice() public view returns (uint) {
        uint balance = USDT.balanceOf(address(this));
        uint supply = totalSupply;
        if (supply == 0 && balance == 0) return 1 ether;
        return (balance * 1 ether) / totalSupply;
    }

    function canLiquidate() public view returns (bool) {
        uint currentTCV = USDT.balanceOf(address(this));
        uint gaps = depositCounter - liquidationsCounter;
        bool regular1 = currentTCV / (gaps + 1) > (MIN_DEPOSIT * 8) / 10;
        bool regular2 = currentTCV > MAX_DEPOSIT * 10;
        bool extra1 = currentTCV > 5 * MAX_DEPOSIT;
        bool extra2 = gaps > 19;
        return (regular1 && regular2) || (extra1 && extra2);
    }

    function getUserPositions(
        address user
    ) external view returns (uint[] memory) {
        return userPositions[user];
    }

    // -------------------------------------------------------
    // Internal Private VIEW Functions
    // -------------------------------------------------------

    /**
     * @notice Function to calculate the amount of HELIX to mint
     * @param amount The amount of USDT that will be converted to HELIX
     * @return The amount of HELIX to mint
     */
    function _helixCreate(uint amount) private view returns (uint) {
        uint balance = USDT.balanceOf(address(this));
        uint supply = totalSupply;
        if (supply == 0) supply = 1;
        if (balance == 0) balance = 1;
        // gets the reverse price of the token to calculate the amount of HELIX to mint
        amount = (supply * amount) / balance;
        return (amount * helixCreated) / BASE_PROPORTION;
    }
}
