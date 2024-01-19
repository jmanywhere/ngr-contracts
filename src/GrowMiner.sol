// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Ownable} from "openzeppelin/access/Ownable.sol";
import {ReentrancyGuard} from "openzeppelin/security/ReentrancyGuard.sol";
import {IGrow, IERC20} from "./interfaces/IGrow.sol";
error GrowMiner__NotInitialized();
error GrowMiner__InvalidAmount();
error GrowMiner__NotDeposited();
error GrowMiner__NoEggs();
error GrowMiner__OnlyIntegers();
error GrowMiner__NothingToLiquidate();

/**
 * @title GrowMiner
 * @author TheThinker @ NextGenROI
 * @notice This is a miner, it's very risky, and pretty scammy. It's very high risk and you should not add money here if you have no idea
 * what you're doing. It's a ponzi scheme, and it's not sustainable. It's a game, and it's meant to be fun.
 * If you consider gambling fun...
 * Please consider using our other products like the Fixed Deposit or Drip.
 * DISCLAIMER: The only reason we added this contract is because the community asked for it, we do not endorse this contract, and we do not
 * approve of users being scammed. We are not responsible for any losses you may incur.
 * https://nextgenroi.com/invest
 */
contract GrowMiner is Ownable, ReentrancyGuard {
    struct Mining {
        uint256 miners;
        uint256 totalInvested; // This is in GROW
        uint256 totalRedeemed; // This is in Stable
        uint256 refEggs; // eggs used for referral rewards, these can either be compounded or claimed
        uint256 lockedEggs; // only used for creating miners, not claimable
        uint256 lastInteraction;
        address referrer;
    }
    mapping(address => Mining) public user;
    address[] private owners;
    address[] private participants; // this value is only used for the UI

    uint256 public constant EGGS_TO_HATCH_1MINERS = 2592000;
    uint256 public constant MAX_VAULT_TIME = 24 hours;
    uint256 public constant PERCENT_BASE = 100;

    uint256 public marketEggs;
    uint256 public devFee = 5;
    uint256 public growFee = 5;
    uint256 public liquidatorFee = 15;
    uint256 public totalLiquidated = 0;

    address public grow;

    IGrow public immutable GROW;
    IERC20 public immutable STABLE;
    bool public initialized = false;

    //------------------------
    //  EVENTS
    //------------------------
    event Initialize(uint256 timeStamp);
    event Deposit(
        address indexed _user,
        address indexed _ref,
        uint256 _growAmount
    );
    event PriceAfterBurn(uint256 _price, uint256 _timestamp);
    event Redeem(address indexed _user, uint256 _growAmount);
    event Reinvest(address indexed _user, uint256 _growAmount);
    event Liquidation(
        address indexed _liquidator,
        address[] _users,
        uint256 _liquidationReward
    );

    //------------------------
    //  Modifiers
    //------------------------
    modifier onlyInitialized() {
        if (!initialized) revert GrowMiner__NotInitialized();
        _;
    }

    //------------------------
    //  Constructor
    //------------------------
    /**
     *
     * @param _growToken The address of the GROW tokens, this is immutable since the GROW token will never change
     * @param _stable This is the address of the STABLE token that will be used to buy GROW tokens
     * @param _owners List of owners that'll receive the devFees
     */
    constructor(address _growToken, address _stable, address[] memory _owners) {
        GROW = IGrow(_growToken);
        STABLE = IERC20(_stable);
        STABLE.approve(_growToken, type(uint256).max);
        owners = _owners;
    }

    //--------------------------------
    //  External / Public Functions
    //--------------------------------
    /**
     * @notice Deposit STABLE tokens into the miner to create miners and start the "game"
     * @param amount The amount of STABLE tokens to deposit
     * @param referrer The user who referred this user
     */
    function depositIntoMine(
        uint256 amount,
        address referrer
    ) external onlyInitialized nonReentrant {
        if (amount == 0) revert GrowMiner__InvalidAmount();
        if (amount % 1 ether != 0) revert GrowMiner__OnlyIntegers();
        uint256 currentGrow = GROW.balanceOf(address(this));
        uint growFeeAmount = (amount * growFee) / PERCENT_BASE;
        uint stableAmount = amount - growFeeAmount;
        // Create Grow
        STABLE.transferFrom(msg.sender, address(GROW), stableAmount);
        STABLE.transferFrom(msg.sender, address(this), growFeeAmount);
        uint256 boughtGrow = GROW.buyFor(
            address(this),
            stableAmount,
            address(STABLE)
        );
        if (growFeeAmount > 0) {
            GROW.burnWithUnderlying(growFeeAmount, address(STABLE));
            emit PriceAfterBurn(GROW.calculatePrice(), block.timestamp);
        }
        // Send GROW created to owners
        boughtGrow = ownerDistribution(boughtGrow, true);

        uint eggsBought = calculateEggBuy(boughtGrow, currentGrow);
        Mining storage miner = user[msg.sender];

        eggsBought += miner.lockedEggs;

        _checkAndSetRef(referrer, miner);
        // Referrals will only get 2% of the total eggs bought
        _sendRefAmount(miner.referrer, eggsBought / 50);

        uint newMiners = eggsBought / EGGS_TO_HATCH_1MINERS;
        uint leftOver = eggsBought % EGGS_TO_HATCH_1MINERS;
        if (miner.miners == 0) {
            participants.push(msg.sender);
            if (newMiners == 0) {
                newMiners++;
            }
        }
        miner.miners += newMiners;
        miner.refEggs = 0;
        miner.lockedEggs += leftOver;
        miner.totalInvested += boughtGrow;
        miner.lastInteraction = block.timestamp;
        // 20% of eggs bought are added to market to nerf miners hoarding
        marketEggs += eggsBought / 5;

        emit Deposit(msg.sender, user[msg.sender].referrer, boughtGrow);
    }

    /**
     * @notice this function compounds any accumulated eggs into the user's miners
     * @dev Any eggs not used by the user to create a miner will be locked and added to the user's lockedEggs amount
     */
    function compoundResources() external onlyInitialized nonReentrant {
        Mining storage miner = user[msg.sender];
        if (miner.miners == 0) revert GrowMiner__NotDeposited();
        uint256 eggsUsed = getEggs(msg.sender) + miner.lockedEggs;
        if (eggsUsed == 0) revert GrowMiner__NoEggs();
        // reset the locked and ref eggs
        miner.lockedEggs = 0;
        miner.refEggs = 0;
        // This is a calculation based on the amount of eggs that could've turned into GROW tokens, it doens't really
        // mean the GROW was bought so be weary of this value
        uint256 eggsValue = calculateEggSell(eggsUsed);
        uint256 newMiners = eggsUsed / EGGS_TO_HATCH_1MINERS;
        uint256 leftOver = eggsUsed % EGGS_TO_HATCH_1MINERS;

        // boost market to nerf miners hoarding
        eggsUsed /= 5; // 20% of total eggs
        marketEggs += eggsUsed;
        miner.lockedEggs += leftOver;
        miner.miners += newMiners;
        miner.totalInvested += eggsValue;
        miner.lastInteraction = block.timestamp;

        // boost market to nerf miners hoarding
        // Actual eggs value reinvested
        emit Reinvest(msg.sender, eggsValue);
    }

    /**
     * @notice this function allows the user to claim the value of their eggs, whatever that may be
     * @dev This function will sell the user's eggs for the respective GROW amount, and then sell the GROW for STABLE tokens
     */
    function claimFromMine() public onlyInitialized nonReentrant {
        Mining storage miner = user[msg.sender];
        if (miner.miners == 0) revert GrowMiner__NotDeposited();
        uint256 hasEggs = getEggs(msg.sender);
        if (hasEggs == 0) revert GrowMiner__NoEggs();
        uint256 eggsValue = calculateEggSell(hasEggs);
        miner.refEggs = 0;
        miner.lastInteraction = block.timestamp;
        marketEggs += hasEggs;
        eggsValue = _sellEggs(eggsValue, msg.sender, true);
        miner.totalRedeemed += eggsValue;
        emit Redeem(msg.sender, eggsValue);
    }

    /**
     * @notice starts the miner, this is a one time function that can only be called once
     */
    function initializeMiner() external onlyOwner {
        require(marketEggs == 0, "Market eggs not zero");
        initialized = true;
        marketEggs = 25920000000;
        emit Initialize(block.timestamp);
    }

    /**
     * @notice This function allows users to liquidate other users who have gone 1 hour above the MAX_VAULT_TIME and claims for them.
     * @dev The liquidator (caller) will receive 15% of the total GROW tokens liquidated, the rest will be sent to the main user.
     * @param toLiquidate The list of users to liquidate
     */
    function liquidateUsers(
        address[] calldata toLiquidate
    ) external onlyInitialized nonReentrant {
        uint256 totalUsers = toLiquidate.length;
        uint256 currentLiquidator = 0;
        for (uint256 i = 0; i < totalUsers; i++) {
            Mining storage miner = user[toLiquidate[i]];
            if (
                block.timestamp - miner.lastInteraction >
                MAX_VAULT_TIME + 1 hours
            ) {
                uint256 eggs = getEggs(toLiquidate[i]);
                if (eggs == 0) continue;
                uint256 eggsValue = calculateEggSell(eggs);
                miner.refEggs = 0;
                miner.lastInteraction = block.timestamp;
                marketEggs += eggs;
                eggsValue = _sellEggs(eggsValue, msg.sender, false);
                uint liquidatorAmount = (eggsValue * liquidatorFee) /
                    PERCENT_BASE;
                eggsValue -= liquidatorAmount;
                currentLiquidator += liquidatorAmount;
                miner.totalRedeemed += eggsValue;
                marketEggs += eggs;
                STABLE.transfer(toLiquidate[i], eggsValue);
                emit Redeem(toLiquidate[i], eggsValue);
            }
        }
        if (currentLiquidator == 0) revert GrowMiner__NothingToLiquidate();
        totalLiquidated += currentLiquidator;
        if (currentLiquidator > 0) {
            STABLE.transfer(msg.sender, currentLiquidator);
            emit Liquidation(msg.sender, toLiquidate, currentLiquidator);
        }
    }

    //--------------------------------
    //  Internal/Private Functions
    //--------------------------------
    /**
     * @notice this function adds the provided referrer to the user's miner
     * @param _ref The address to add as referrer
     * @param miner The miner struct of the user
     * @dev A user can't be a referrer if the referrer is already set, or the referrer is the user itself, or the referrer has never participated in the miner
     */
    function _checkAndSetRef(address _ref, Mining storage miner) private {
        if (_ref == msg.sender) {
            _ref = address(0);
        }
        if (
            miner.referrer == address(0) &&
            _ref != address(0) &&
            user[_ref].miners > 0
        ) {
            miner.referrer = _ref;
        }
    }

    /**
     * @notice this function sends the referral amount to the referrer
     * @param _ref The address of the referrer
     * @param amount The amount of eggs to send to the referrer
     */
    function _sendRefAmount(address _ref, uint amount) private {
        if (_ref != address(0)) {
            user[_ref].refEggs += amount;
        }
    }

    /**
     * @notice this function distributes the devFee to the owners
     * @param amount The amount of GROW tokens to distribute
     * @param onBuy if it's a buy, base percentage is different
     */
    function ownerDistribution(
        uint amount,
        bool onBuy
    ) private returns (uint amountAfterFee) {
        uint256 base = onBuy ? PERCENT_BASE - growFee : PERCENT_BASE;
        uint256 fee = (amount * devFee) / base;
        fee = fee / owners.length;
        for (uint8 i = 0; i < owners.length; i++) {
            amountAfterFee += fee;
            GROW.transfer(owners[i], fee);
        }
        return amount - amountAfterFee;
    }

    /**
     *
     * @param growSold The amount of GROW tokens that are being sold
     * @param recipient The recipient of the STABLE tokens
     */
    function _sellEggs(
        uint growSold,
        address recipient,
        bool doTransfer
    ) private returns (uint valueOfSell) {
        // send share to dev
        growSold = ownerDistribution(growSold, false);
        uint growFeeAmount = (growSold * growFee) / (PERCENT_BASE - devFee);
        growSold -= growFeeAmount;

        valueOfSell = GROW.sell(growSold, address(STABLE));
        //BURN happens after claiming
        if (growFeeAmount > 0) {
            GROW.burn(growFeeAmount);
        }

        if (doTransfer) STABLE.transfer(recipient, valueOfSell);
    }

    //---------------------------------------
    //  External/Public VIEW/PURE Functions
    //---------------------------------------

    /**
     * @notice This is the trading calculation function, it's taken from bnb.miner AS IS and simplified, to warn users how scammy this is
     * @param rt This is the amount that will be added to the pool
     * @param rs this is the current pool
     * @param bs this is the amount of assets to get the ratio from
     */
    function calculateTrade(
        uint256 rt,
        uint256 rs,
        uint256 bs
    ) public pure returns (uint256) {
        // Original "Algorithm" = (PSN*bs)/(PSNH+((PSN*rs+PSNH*rt)/rt));
        // where PSNH = PSN / 2
        // Simplified version, we're not going to hide stupid math
        return (rt * bs) / (rt + rs);
    }

    /**
     * @notice function to calculate the amount of GROW to sell the eggs for
     * @param eggs The amount of eggs to calculate the sell price for
     * @return The amount of GROW tokens the eggs are worth
     */
    function calculateEggSell(uint256 eggs) public view returns (uint256) {
        return calculateTrade(eggs, marketEggs, GROW.balanceOf(address(this)));
    }

    /**
     * @notice Calculates the amount of eggs that can be bought with the provided amount of GROW tokens
     * @param amount The amount of GROW tokens to calculate the buy price for
     * @param contractBalance The amount of GROW tokens in the contract
     * @return The amount of eggs that can be bought with the provided amount of GROW tokens
     */
    function calculateEggBuy(
        uint256 amount,
        uint256 contractBalance
    ) public view returns (uint256) {
        return calculateTrade(amount, contractBalance, marketEggs);
    }

    /**
     * @notice this funciton is to make it easier for the frontend to calculate the buy price
     * @param amount The amount of GROW tokens to calculate the buy price for
     * @return The amount of eggs that can be bought with the provided amount of GROW tokens
     */
    function calculateEggBuySimple(
        uint256 amount
    ) public view returns (uint256) {
        return calculateEggBuy(amount, GROW.balanceOf(address(this)));
    }

    /**
     * @notice this function returns the amount of GROW tokens in the contract
     * @return The amount of GROW tokens in the contract
     */
    function getBalance() public view returns (uint256) {
        return GROW.balanceOf(address(this));
    }

    /**
     * @notice This function returns the amount of miners a user has
     * @param _user The address of the user to get the miners for
     * @return The amount of miners the user has
     */
    function getMiners(address _user) public view returns (uint256) {
        return user[_user].miners;
    }

    /**
     * @notice this function gets the eggs available for compound or claim
     * @param _user The address of the user to get the eggs for
     * @return The amount of eggs the user has available NOW
     */
    function getEggs(address _user) public view returns (uint256) {
        return user[_user].refEggs + getEggsSinceLastHatch(_user);
    }

    /**
     * @notice this function calculates the amount of eggs a user has accumulated since their last interaction
     * @param adr The address of the user to get the eggs for
     */
    function getEggsSinceLastHatch(address adr) public view returns (uint256) {
        Mining storage currentUser = user[adr];
        uint256 secondsPassed = min(
            MAX_VAULT_TIME,
            (block.timestamp - currentUser.lastInteraction)
        );
        return secondsPassed * currentUser.miners;
    }

    /**
     * @notice This function will return the users that are available to be liquidated
     * @return _usersToLiquidate Array of users available to be liquidated
     * @return _growAmounts The amount of total GROW redeemable by each user (this is an estimate, since liquidating 1 user will affect the next)
     * @dev THIS FUNCTION IS ONLY TO BE CALLED BY THE FRONTEND SINCE IT'S VERY EXPENSIVE AND NOT MEANT TO BE CALLED ON CHAIN
     */
    function getLiquidatableUsers()
        external
        view
        returns (address[] memory _usersToLiquidate, uint[] memory _growAmounts)
    {
        uint256 totalUsers = participants.length;
        uint256 usersToLiquidate = 0;
        uint256[] memory userIndexes = new uint256[](totalUsers);

        for (uint256 i = 0; i < totalUsers; i++) {
            Mining storage miner = user[participants[i]];
            if (
                block.timestamp - miner.lastInteraction >
                MAX_VAULT_TIME + 1 hours
            ) {
                userIndexes[usersToLiquidate] = i;
                usersToLiquidate++;
            }
        }
        if (usersToLiquidate == 0) {
            return (_usersToLiquidate, _growAmounts);
        }
        _usersToLiquidate = new address[](usersToLiquidate);
        _growAmounts = new uint[](usersToLiquidate);
        for (uint256 j = 0; j < usersToLiquidate; j++) {
            uint256 index = userIndexes[j];
            _usersToLiquidate[j] = participants[index];
            uint256 eggs = getEggs(participants[index]);
            uint256 eggsValue = calculateEggSell(eggs);
            _growAmounts[j] = eggsValue;
        }
    }

    //---------------------------------------
    //  Internal/Private VIEW/PURE Functions
    //---------------------------------------
    /**
     * @notice this function gets the minimum of the 2 provided values
     * @param a Value 1
     * @param b Value 2
     * @return The minimum of the 2 provided values
     */
    function min(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? a : b;
    }
}
