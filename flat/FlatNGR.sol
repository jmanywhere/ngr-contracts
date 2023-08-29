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
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

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
    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);

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
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
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

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

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
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
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

// OpenZeppelin Contracts (last updated v4.9.0) (security/ReentrancyGuard.sol)

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be _NOT_ENTERED
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == _ENTERED;
    }
}

contract AutomationBase {
    error OnlySimulatedBackend();

    /**
     * @notice method that allows it to be simulated via eth_call by checking that
     * the sender is the zero address.
     */
    function preventExecution() internal view {
        if (tx.origin != address(0)) {
            revert OnlySimulatedBackend();
        }
    }

    /**
     * @notice modifier that allows it to be simulated via eth_call by checking
     * that the sender is the zero address.
     */
    modifier cannotExecute() {
        preventExecution();
        _;
    }
}

interface AutomationCompatibleInterface {
    /**
     * @notice method that is simulated by the keepers to see if any work actually
     * needs to be performed. This method does does not actually need to be
     * executable, and since it is only ever simulated it can consume lots of gas.
     * @dev To ensure that it is never called, you may want to add the
     * cannotExecute modifier from KeeperBase to your implementation of this
     * method.
     * @param checkData specified in the upkeep registration so it is always the
     * same for a registered upkeep. This can easily be broken down into specific
     * arguments using `abi.decode`, so multiple upkeeps can be registered on the
     * same contract and easily differentiated by the contract.
     * @return upkeepNeeded boolean to indicate whether the keeper should call
     * performUpkeep or not.
     * @return performData bytes that the keeper should call performUpkeep with, if
     * upkeep is needed. If you would like to encode data to decode later, try
     * `abi.encode`.
     */
    function checkUpkeep(
        bytes calldata checkData
    ) external returns (bool upkeepNeeded, bytes memory performData);

    /**
     * @notice method that is actually executed by the keepers, via the registry.
     * The data returned by the checkUpkeep simulation will be passed into
     * this method to actually be executed.
     * @dev The input to this method should not be trusted, and the caller of the
     * method should not even be restricted to any single registry. Anyone should
     * be able call it, and the input should be validated, there is no guarantee
     * that the data passed in is the performData returned from checkUpkeep. This
     * could happen due to malicious keepers, racing keepers, or simply a state
     * change while the performUpkeep transaction is waiting for confirmation.
     * Always validate the data passed in.
     * @param performData is the data which was passed back from the checkData
     * simulation. If it is encoded, it can easily be decoded into other types by
     * calling `abi.decode`. This data should not be trusted, and should be
     * validated against the contract's current state.
     */
    function performUpkeep(bytes calldata performData) external;
}

abstract contract AutomationCompatible is
    AutomationBase,
    AutomationCompatibleInterface
{}

/**
 * @title Interface for NGR protocol
 * @author Semi Invader
 * @notice This protocol is of type ROI, meant to deliver a user a specific ROI on their investment.
 *          The ROI is of a fixed 6% to end user and of 6.36% total.
 *          The protocol is meant to be used with Stablecoins, but can be adapted to any token
 *          A user is able to do the following:
 *            - Deposit Stablecoin
 *            - Withdraw Investment at a 6% loss maximum
 *            - Withdraw Investment at a 6% gain maximum
 *            - Liquidate users who are eligible for liquidation
 *
 * @dev Notes on implementation:
 *       - A user can only enter once and can only exit once. Once they exit, their position is closed and can enter again.
 *       - No user can be liquidated unless Differential Sparks (DS) is equal to zero(0)
 *       - Users are liquidated on a FIFO basis
 *       - Internally we're tracking 1 balance per User called GROW and 2 global balances called DS and Cumulative Sparks (CS)
 *       - On liquidation or withdrawal, the user's GROW amount is deducted from the DS and CS amounts
 *       - The proposal on deposits is to have a 3% fee on entry distributed as follows:
 *          - 2.4% as collateral for rewards
 *          - 0.6% as a development fee distributed 3 ways amongst owners
 *          e.g. If user deposits 100 USDT, they will receive 97 USDT worth of GROW
 *       - The proposal on withdrawals is to have a 6% total loss for the user on early exit and distributed as follows:
 *          - 2.4% as collateral for rewards
 *          - 0.6% as a development fee distributed 3 ways amongst owners
 *          e.g. If user deposits 100 USDT and withdraws early, they will receive 94 USDT.
 *       - We need to know the current Total Contract Value(TCV) held at any given time. Basically `balanceOf(self)`.
 *       - Deposits are capped depending on TCV distributed on 4 tiers and can be edited as needed:
 *          - 0 - 9,999 TCV: 500 USDT
 *          - 10,000 - 50,000 TCV: 1,000 USDT
 *          - 50,000 - 100,000 TCV: 2,000,000 USDT
 *          - 100,000+ TCV: 3% of TCV
 *        - PRICE of GROW is calculated as follows:
 *            TCV / (DS + CS)
 *        - Cycles represent the RESET of GROW price back to zero. This is done to prevent the GROW price from getting too high.
 *        - Cycles are set to happen once price reaches 1.2$ and back to 1.00$
 *        - Once price reaches 1.2$, the contract will automatically reset the price to 1.00$ and increment the cycle counter, then we create DS to adjust the price back to 1.00$
 *        - If DS exists, on new deposits, CS is incremented and DS is decremented.
 */

interface INGR {
    struct PositionInfo {
        address user; // Address of the user holding the position
        uint initialDeposit;
        uint helixAmount;
        uint sparks;
        uint depositTime;
        uint liquidationPrice;
        uint liquidationCycle;
        uint liquidated;
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

    event Deposit(address indexed user, uint256 amount, uint256 indexPosition);
    event Withdraw(address indexed user, uint256 amount, uint position);
    event Liquidate(address indexed user, uint256 amount, uint position);
    event Seed(uint amount);
    event EarlyWithdrawal(
        address indexed user,
        uint initialDeposit,
        uint earlyFeeTaken,
        uint totalWithdrawn
    );
    event UpdateOwners(address[] owners);
    event UpdateLiquidationWallet(address indexed _old, address indexed _new);

    /**
     * @notice Deposit Stablecoin into the protocol to wait for ROI to be delivered
     * @param amount The amount of stable coins to receive.
     * @dev This function calculates the CS to be added to the pool and the DS to be removed. Also calculates GROW to be received by user.
     */
    function deposit(uint256 amount) external;

    /**
     * Seed the current NGR contract so it's easy to view
     * @param amount The amount of USDT used to SEED the initial deposits
     */
    function seed(uint amount) external;

    /**
     * @notice Make a deposit and immediately withdraw without doing anything.
     * @param amount The amount of USDT used to SEED the initial deposits
     */
    function seedAndQuit(uint amount) external;

    /**
     * @notice Withdraw from the protocol, without any profits and with a penalty to principal
     * @dev only the last position of the user can be withdrawn
     */
    function earlyWithdraw() external;

    function liquidate() external;

    function getDS() external view returns (int256);

    function TCV() external view returns (uint256);

    function currentHelixPrice() external view returns (uint256);

    /**
     * @return The index of the next user to be liquidated
     */
    function currentUserPendingLiquidation() external view returns (uint256);

    function userLiquidationStatus(
        address user,
        uint256 indexPosition
    ) external view returns (bool indexEnabled, bool envLiquidationStatus);

    function calculateSparksOnDeposit(
        uint256 amount
    ) external view returns (uint256);
}

error NGR__InvalidAmount(uint256 amount);
error NGR__CannotLiquidate();
error NGR__AlreadyLiquidated();

contract NGR is INGR, Ownable, ReentrancyGuard, AutomationCompatible {
    mapping(uint position => PositionInfo) public positions;
    mapping(address user => uint[] positions) public userPositions;
    mapping(address user => UserStats) public userStats;

    address[] public owners;
    address public liquidationOutWallet;
    IERC20 public usdt;
    uint public totalHelix;
    uint public cycleCounter;
    uint private liquidationUser = 1;
    uint public totalPositions;
    uint public totalLiquidations;
    uint public totalDeposits;

    uint private depositFee = 3;
    // Keep track of the current Gap counter;
    uint public depositCounter = 0;
    uint public liquidationCounter = 0;

    uint private devProportion = 20;
    uint private tcvProportion = 80;

    uint private cumulativeSparks;
    int private deltaSparks;
    uint private lastSparkBeforeUpdate;

    uint public constant MAX_DEPOSIT = 500 ether;
    uint public constant MAX_PRICE = 1.2 ether;
    uint public constant BASE_PRICE = 1 ether;
    uint public constant MIN_DEPOSIT = 100 ether;
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

    constructor(address _usdt, address liqOutWallet, address[] memory _owners) {
        liquidationOutWallet = liqOutWallet;
        usdt = IERC20(_usdt);
        owners = _owners;
    }

    //---------------------------
    //  External functions
    //---------------------------
    function deposit(uint amount) external nonReentrant {
        uint devFee = _deposit(msg.sender, amount, false);
        usdt.transferFrom(msg.sender, address(this), amount);
        if (devFee > 0) distributeToOwners(devFee);
        reAdjustPrice();
        _autoLiquidate(5, false);
    }

    function depositForUser(address user, uint amount) external nonReentrant {
        uint devFee = _deposit(user, amount, false);
        usdt.transferFrom(msg.sender, address(this), amount);
        if (devFee > 0) distributeToOwners(devFee);
        reAdjustPrice();
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
        uint devFee = _deposit(msg.sender, amount, true);
        usdt.transferFrom(msg.sender, address(this), amount);
        if (devFee > 0) distributeToOwners(devFee);
    }

    function seedAndQuit(uint amount) external nonReentrant {
        usdt.transferFrom(msg.sender, address(this), amount);
        uint devFee = _deposit(msg.sender, amount, false);
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

    function _deposit(
        address user,
        uint amount,
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
        UserStats storage stats = userStats[user];
        // setup user
        if (!isSeed) {
            totalDeposits += amount;
            totalPositions++;
            userPositions[user].push(totalPositions);
            stats.totalDeposited += amount;
            stats.totalPositions++;
        }

        PositionInfo storage position = positions[totalPositions];
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
        if (isSeed) {
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
    }

    function _liquidate() internal {
        PositionInfo storage toLiquidate = positions[liquidationUser];
        // If the position is already liquidated, skip it
        if (toLiquidate.liquidated > 0) {
            liquidationUser++;
            return _liquidate();
        }
        UserStats storage stats = userStats[toLiquidate.user];
        stats.lastLiquidatedPosition = liquidationUser;
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
        liquidationUser++;
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
        // If the position is already liquidated, skip it
        if (toWithdraw.liquidated > 0) {
            revert NGR__AlreadyLiquidated();
        }
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
            toWithdraw.initialDeposit - earlyLiquidationAmount
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
        if (gap > 20) return true;
        bool tcvCanLiquidate = tcv > MAX_DEPOSIT * 5;
        bool gapCanLiquidate = gap > 3;
        // Check gaps and TCV
        return tcvCanLiquidate && gapCanLiquidate;
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
