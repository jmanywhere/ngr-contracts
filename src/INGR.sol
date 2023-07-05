// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

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
    struct UserInfo {
        uint initialDeposit;
        uint growAmount;
        uint depositTime;
        uint liquidationTime;
        uint cycle;
        uint cyclePrice;
    }

    event Deposit(address indexed user, uint256 amount, uint256 indexPosition);
    event Withdraw(address indexed user, uint256 amount);
    event Liquidate(address indexed user, uint256 amount);

    /**
     * @param amount The amount of Stable to Deposit
     */
    function deposit(uint256 amount) external;

    function earlyWithdraw() external;

    function liquidate() external;

    function liquidateUser(address user) external; // Can be called by anyone, no restrictions need apply

    function getDS() external view returns (uint256);

    function TCV() external view returns (uint256);

    function currentCycle() external view returns (uint256);

    function currentGrowPrice() external view returns (uint256);

    /**
     * @return The index of the next user to be liquidated
     */
    function currentUserPendingLiquidation() external view returns (uint256);

    function userLiquidationStatus(
        address user
    ) external view returns (bool indexEnabled, bool pastCycle, bool dsZero);

    function calculateSparksOnDeposit(
        uint256 amount
    ) external view returns (uint256);
}
