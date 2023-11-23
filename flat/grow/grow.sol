//SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

// OpenZeppelin Contracts (last updated v4.9.0) (utils/Address.sol)

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     *
     * Furthermore, `isContract` will also return true if the target contract within
     * the same transaction is already scheduled for destruction by `SELFDESTRUCT`,
     * which only has an effect at the end of a transaction.
     * ====
     *
     * [IMPORTANT]
     * ====
     * You shouldn't rely on `isContract` to protect against flash loan attacks!
     *
     * Preventing calls from contracts is highly discouraged. It breaks composability, breaks support for smart wallets
     * like Gnosis Safe, and does not provide security since it can be circumvented by calling from a contract
     * constructor.
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.

        return account.code.length > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://consensys.net/diligence/blog/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.8.0/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and revert (either by bubbling
     * the revert reason or using the provided one) in case of unsuccessful call or if target was not a contract.
     *
     * _Available since v4.8._
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        if (success) {
            if (returndata.length == 0) {
                // only check isContract if the call was successful and the return data is empty
                // otherwise we already know that it was a contract
                require(isContract(target), "Address: call to non-contract");
            }
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason or using the provided one.
     *
     * _Available since v4.3._
     */
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    function _revert(bytes memory returndata, string memory errorMessage) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert(errorMessage);
        }
    }
}

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

// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/IERC20Metadata.sol)

/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 *
 * _Available since v4.1._
 */
interface IERC20Metadata is IERC20 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
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
    event Burn(uint amountInGrow, uint amountInStable);
}

interface IOwnableGrow is IGrow {
    function owner() external returns (address);
}

interface IUniswapV2Router01 {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);

    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    )
        external
        payable
        returns (uint amountToken, uint amountETH, uint liquidity);

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);

    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);

    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint amountA, uint amountB);

    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint amountToken, uint amountETH);

    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapExactETHForTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts);

    function swapTokensForExactETH(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapExactTokensForETH(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapETHForExactTokens(
        uint amountOut,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts);

    function quote(
        uint amountA,
        uint reserveA,
        uint reserveB
    ) external pure returns (uint amountB);

    function getAmountOut(
        uint amountIn,
        uint reserveIn,
        uint reserveOut
    ) external pure returns (uint amountOut);

    function getAmountIn(
        uint amountOut,
        uint reserveIn,
        uint reserveOut
    ) external pure returns (uint amountIn);

    function getAmountsOut(
        uint amountIn,
        address[] calldata path
    ) external view returns (uint[] memory amounts);

    function getAmountsIn(
        uint amountOut,
        address[] calldata path
    ) external view returns (uint[] memory amounts);
}

interface IUniswapV2Router02 is IUniswapV2Router01 {
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountETH);

    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

/**
 * Contract: Grow Token (xUSD fork)
 * By: SemiInvader
 *
 * Token with a built-in Automated Market Maker
 * buy tokens through contract with USDT and it will mint Grow Tokens
 * Stake stables into contract and it will mint Grow Tokens
 * Sell this token to redeem underlying stable Tokens
 * Price is calculated as a ratio between Total Supply and underlying asset quantity in Contract
 */

contract GrowToken is IGrow, ReentrancyGuard, Ownable {
    using Address for address;

    struct Stable {
        uint balance;
        uint8 index;
        uint8 decimals;
        bool accepted;
        bool setup;
    }

    // token data
    string public constant name = "Grow Token";
    string public constant symbol = "GROW";
    uint8 public constant decimals = 18;
    // Math constants
    uint256 constant PRECISION = 1 ether;

    // lock to Matrix contract
    mapping(address => bool) public isExecutor;
    // balances
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => Stable) public stables;
    address[] public currentStables;
    address[] private owners;
    uint[] private ownerShares;
    uint private totalOwnerShares;

    // 1 GROW Starting Supply
    uint256 public totalSupply = 1 ether;
    // Fees
    uint256 public mintFee = 40; // 4.0% buy fee
    uint256 public sellFee = 40; // 4.0% sell fee
    uint256 public transferFee = 40; // 4.0% transfer fee
    uint256 public constant feeDenominator = 1000;

    uint256 public devShare = 100; // 1%
    uint256 public liquidityShare = 300; // 3%
    uint256 public sharesDenominator = 400; // 4%

    address public dev;

    // fee exemption for utility
    mapping(address => bool) public isFeeExempt;

    // volume for each recipient
    mapping(address => uint256) private _volumeFor;

    // Activates Token Trading
    bool Token_Activated;

    ///@notice initialize the contract
    /// 1. Set the Dev who receives some of the tx funds
    /// 2. set fee exemptions
    /// 3. mint the initial total supply
    /// 4. add all the stables we'll accept
    /// 5. emit Events
    constructor(
        address[] memory _stables,
        address[] memory _owners,
        uint[] memory _ownerShares,
        address _dev
    ) {
        dev = _dev;
        // fee exempt this + owner
        isFeeExempt[address(this)] = true;
        isFeeExempt[msg.sender] = true;
        require(_owners.length == _ownerShares.length, "Invalid owners");
        // set owners
        for (uint8 i = 0; i < _owners.length; i++) {
            address ownerSetup = _owners[i];
            require(ownerSetup != address(0), "Invalid owner");
            owners.push(ownerSetup);
            ownerShares.push(_ownerShares[i]);
            totalOwnerShares += _ownerShares[i];
            isFeeExempt[msg.sender] = true;
        }

        // allocate one token to dead wallet to ensure total supply never reaches 0
        address dead = 0x000000000000000000000000000000000000dEaD;
        _balances[address(this)] = (totalSupply - 1);
        _balances[dead] = 1;

        require(_stables.length > 0, "No stables provided");

        for (uint8 i = 0; i < _stables.length; i++) {
            setStableToken(_stables[i], true);
            if (i == 0) {
                require(_stables[i] != address(0), "Invalid stable");
                stables[_stables[i]].balance = 1 ether;
            }
        }
        // emit allocations
        emit Transfer(address(0), address(this), (totalSupply - 1));
        emit Transfer(address(0), dead, 1);
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function allowance(
        address holder,
        address spender
    ) external view override returns (uint256) {
        return _allowances[holder][spender];
    }

    function approve(
        address spender,
        uint256 amount
    ) public override returns (bool) {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    /** Transfer Function */
    function transfer(
        address recipient,
        uint256 amount
    ) external override returns (bool) {
        return _transferFrom(msg.sender, recipient, amount);
    }

    /** Transfer Function */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external override returns (bool) {
        uint currentAllowance = _allowances[sender][msg.sender];
        require(
            currentAllowance >= amount,
            "Transfer amount exceeds allowance"
        );
        // If allowance is UINT.MAX then don't decrease it
        if (_allowances[sender][msg.sender] != ~uint256(0))
            _allowances[sender][msg.sender] = currentAllowance - amount;

        return _transferFrom(sender, recipient, amount);
    }

    /** Internal Transfer */
    function _transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) internal returns (bool) {
        // Zero Address Check
        require(
            sender != address(0) && recipient != address(0),
            "Tx to/from Zero"
        );
        // Amounts Check
        require(
            amount > 0 && _balances[sender] >= amount,
            "Invalid amount or balance"
        );
        // Track old price and sender volume
        uint256 oldPrice = _calculatePrice();
        // Update Sender balance and volume
        _balances[sender] -= amount;
        _volumeFor[sender] += amount;

        // Does Fee apply
        if (!(isFeeExempt[sender] || isFeeExempt[recipient])) {
            // Transfer Fee
            uint fee = (amount * transferFee) / feeDenominator;
            // Update actual transfer amount
            amount -= fee;
            // caculate devFee and liquidityFee
            uint devFee = (fee * devShare) / sharesDenominator;
            fee -= devFee;
            totalSupply -= fee;
            _balances[dev] += devFee;
            emit Transfer(sender, address(0), fee);
            emit Transfer(sender, dev, devFee);

            // Make sure price is updated since totalSupply changed
            // Here were simply reusing the fee variable
            fee = _calculatePrice();
            require(fee >= oldPrice, "Price MUST increase when fees apply");
            emit PriceChange(oldPrice, fee, totalSupply);
        }
        // update recipiente balance and volume
        _balances[recipient] += amount;
        _volumeFor[recipient] += amount;

        emit Transfer(sender, recipient, amount);

        return true;
    }

    /// @notice creates GROW from _stable sent.
    /// @param numTokens the amount of tokens of _stable that will be sent to contract
    /// @param _stable the address of the Stable token to receive
    /// @dev MUST HAVE PRIOR APPROVAL
    function buy(
        uint256 numTokens,
        address _stable
    ) external nonReentrant returns (uint) {
        _transferInStable(_stable, numTokens);
        return _buyToken(numTokens, msg.sender, _stable);
    }

    /// @notice creates GROW from _stable sent.
    /// @param recipient the user who will receive the tokens
    /// @param numTokens the amount of tokens of _stable that will be sent to contract
    /// @param _stable the address of the Stable token to receive
    /// @dev MUST HAVE PRIOR APPROVAL
    function buy(
        address recipient,
        uint256 numTokens,
        address _stable
    ) external nonReentrant returns (uint) {
        _transferInStable(_stable, numTokens);
        return _buyToken(numTokens, recipient, _stable);
    }

    /// @notice creates GROW by sending tokens first to the contract, this is so we can  skim a transfer on a buy.
    /// @param recipient person who gets the swapped token
    /// @param numTokens, the amount of tokens sent in STABLE
    /// @param _stable the address of the STABLE contract addess
    function buyFor(
        address recipient,
        uint256 numTokens,
        address _stable
    ) external nonReentrant returns (uint) {
        require(isExecutor[msg.sender], "Only executor allowed");
        return _buyToken(numTokens, recipient, _stable);
    }

    /// @notice sells GROW in exchange for _stable token
    /// @param tokenAmount amount of GROW to sell
    /// @param _stable contract address of the stable we want to receive
    function sell(
        uint256 tokenAmount,
        address _stable
    ) external nonReentrant returns (uint) {
        return _sell(tokenAmount, msg.sender, _stable);
    }

    /// @notice sells GROW in exchange for _stable token
    /// @param recipient address to send STABLEs to
    /// @param tokenAmount amount of GROW to sell
    /// @param _stable contract address of the stable we want to receive
    function sell(
        address recipient,
        uint256 tokenAmount,
        address _stable
    ) external nonReentrant returns (uint) {
        return _sell(tokenAmount, recipient, _stable);
    }

    /// @notice will attempt to sell all of the holding bag and receive only stable in return
    /// @param _stable the contract address of the stable to receive
    function sellAll(address _stable) external nonReentrant {
        _sell(_balances[msg.sender], msg.sender, _stable);
    }

    /// @notice a simplified version of SELL for contract use directly from explorer
    /// @param amount the amount of GROW tokens to sell to the nearest integer number
    /// @param _stable the contract address of the token we would receive
    function sellInWholeTokenAmounts(
        uint256 amount,
        address _stable
    ) external nonReentrant {
        _sell(amount * 10 ** decimals, msg.sender, _stable);
    }

    /** Deletes Grow Tokens Sent To Contract */
    function takeOutGarbage() external nonReentrant {
        _checkGarbageCollector();
    }

    /** Allows A User To Erase Their Holdings From Supply */
    function eraseHoldings(uint256 nHoldings) external {
        // get balance of caller
        uint256 bal = _balances[msg.sender];
        require(bal >= nHoldings && bal > 0, "Zero Holdings");
        // if zero erase full balance
        uint256 burnAmount = nHoldings == 0 ? bal : nHoldings;
        // Track Change In Price
        uint256 oldPrice = _calculatePrice();
        // burn tokens from sender + supply
        _burn(msg.sender, burnAmount);
        // Emit Price Difference
        emit PriceChange(oldPrice, _calculatePrice(), totalSupply);
        // Emit Call
        emit ErasedHoldings(msg.sender, burnAmount);
    }

    ///////////////////////////////////
    //////  EXTERNAL FUNCTIONS  ///////
    ///////////////////////////////////

    /** Burns GROW Token from msg.sender */
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    /** Burns GROW Token with Underlying, Must Have Prior Approval */
    function burnWithUnderlying(
        uint256 underlyingAmount,
        address _stable
    ) external {
        require(stables[_stable].accepted, "Stable Not Active");
        IERC20(_stable).transferFrom(
            msg.sender,
            address(this),
            underlyingAmount
        );
        uint256 prevAmount = _balances[address(this)];
        _buyToken(underlyingAmount, address(this), _stable);
        uint256 amount = _balances[address(this)] - prevAmount;
        _burn(address(this), amount);
        emit Burn(underlyingAmount, amount);
    }

    ///////////////////////////////////
    //////  INTERNAL FUNCTIONS  ///////
    ///////////////////////////////////

    function _distributeToOwners(uint256 amount) private {
        for (uint8 i = 0; i < owners.length; i++) {
            uint256 share = (amount * ownerShares[i]) / totalOwnerShares;
            _mint(owners[i], share);
        }
    }

    /** Requires Price of GROW Token to Rise for The Transaction to Conclude */
    function _requirePriceRises(uint256 oldPrice) internal {
        // price after transaction
        uint256 newPrice = _calculatePrice();
        // require price to rise
        require(
            newPrice >= oldPrice,
            "Price Must Rise For Transaction To Conclude"
        );
        emit PriceChange(oldPrice, newPrice, totalSupply);
    }

    function _transferInStable(address _stable, uint256 amount) internal {
        require(stables[_stable].accepted, "Stable Not Accepted");
        IERC20(_stable).transferFrom(msg.sender, address(this), amount);
    }

    /// @notice - This function is used to "STAKE" the stable token and calls to create GROW tokens
    function _buyToken(
        uint256 numTokens,
        address recipient,
        address _stable // Stable token to be used to buy
    ) internal returns (uint) {
        // make sure it's not locked
        require(
            Token_Activated || msg.sender == owner() || isExecutor[msg.sender],
            "Locked Inside the Matrix"
        );
        require(numTokens > 0, "> 0 please");
        Stable storage stable = stables[_stable];
        IERC20 token = IERC20(_stable);
        // calculate price change
        // This uses non synced values so it's fine to call after tokens have been transferred in
        uint256 oldPrice = _calculatePrice();
        // get all stables here
        uint currentBalance = stable.balance;
        uint prevAllStablesBalance = _adjustedAllStables();
        uint256 tokensToBuy = token.balanceOf(address(this));
        // update current stable amount
        stable.balance = tokensToBuy;
        tokensToBuy -= currentBalance;
        require(tokensToBuy >= numTokens, "No new tokens");
        tokensToBuy = _adjustedStableBalance(tokensToBuy, stable.decimals);
        return
            _handleMinting(
                recipient,
                tokensToBuy,
                prevAllStablesBalance,
                oldPrice
            );
    }

    /** Sells GROW Tokens And Deposits Underlying Asset Tokens into Recipients's Address */
    function _sell(
        uint256 tokenAmount,
        address recipient,
        address _stable
    ) internal returns (uint) {
        require(
            tokenAmount > 0 && _balances[msg.sender] >= tokenAmount,
            "Not enough balance"
        );
        Stable storage payoutStable = stables[_stable];
        require(payoutStable.accepted, "Stable Not Active");
        // calculate price change
        uint256 oldPrice = _calculatePrice();
        // fee exempt
        bool dontTakeFee = isFeeExempt[msg.sender];

        uint tokensToSwap;
        // tokens post fee to swap for underlying asset
        _burn(msg.sender, tokenAmount);
        if (dontTakeFee) {
            require(tokenAmount > 100, "Minimum of 100");
            tokensToSwap = tokenAmount - 100;
        } else {
            uint taxFee = (tokenAmount * sellFee) / feeDenominator;
            tokensToSwap = tokenAmount - taxFee;
            taxFee = (taxFee * devShare) / sharesDenominator;
            _distributeToOwners(taxFee);
        }

        // value of taxed tokens
        uint256 stableAmount = (tokensToSwap * oldPrice) / PRECISION;
        uint256 totalOfCurrentStable = _adjustedStableBalance(
            payoutStable.balance,
            payoutStable.decimals
        );
        // require above zero value
        require(
            stableAmount > 0 && stableAmount <= totalOfCurrentStable,
            "Not enough of STABLE"
        );
        // Adjust stable back to usable amounts
        stableAmount = _getAmountFromAdjusted(
            stableAmount,
            payoutStable.decimals
        );
        IERC20 stableToken = IERC20(_stable);
        // send Tokens to Seller
        bool successful = stableToken.transfer(recipient, stableAmount);
        // ensure Tokens were delivered
        require(successful, "Failed to send Stable");
        // set the new balance
        payoutStable.balance = stableToken.balanceOf(address(this));
        // Requires The Price of GROW to Increase in order to complete the transaction
        _requirePriceRises(oldPrice);
        // Differentiate Sell
        emit TokenSold(tokenAmount, stableAmount, recipient);
        return stableAmount;
    }

    /** Handles Minting Logic To Create New Tokens*/
    function _handleMinting(
        address recipient,
        uint256 received,
        uint256 prevTokenAmount,
        uint256 oldPrice
    ) private returns (uint) {
        // fee exempt
        bool dontTakeFee = isFeeExempt[msg.sender];
        require(received > 0, "No zero buy");
        // find the number of tokens we should mint to keep up with the current price
        // set initial value before deduction
        uint256 tokensToMint = (totalSupply * received) / prevTokenAmount;
        // apply fee to minted tokens to inflate price relative to total supply
        if (dontTakeFee) {
            tokensToMint -= 100;
        } else {
            uint256 taxTaken = (tokensToMint * mintFee) / feeDenominator;
            tokensToMint -= taxTaken;
            // allocate dev share - we're reusing variables
            taxTaken = (taxTaken * devShare) / sharesDenominator;
            // mint to dev
            _distributeToOwners(taxTaken);
        }

        // mint to Buyer
        _mint(recipient, tokensToMint);
        // Requires The Price of GROW to Increase in order to complete the transaction
        _requirePriceRises(oldPrice);
        return tokensToMint;
    }

    /** Mints Tokens to the Receivers Address */
    function _mint(address receiver, uint256 amount) private {
        _balances[receiver] += amount;
        totalSupply += amount;
        _volumeFor[receiver] += amount;
        emit Transfer(address(0), receiver, amount);
    }

    /** Burns Tokens from the Receivers Address */
    function _burn(address receiver, uint256 amount) private {
        require(_balances[receiver] >= amount, "Insufficient Balance");
        _balances[receiver] -= amount;
        totalSupply -= amount;
        _volumeFor[receiver] += amount;
        emit Transfer(receiver, address(0), amount);
    }

    /** Make Sure there's no Native Tokens in contract */
    function _checkGarbageCollector() internal {
        uint256 bal = _balances[address(this)];
        if (bal > 10) {
            // Track Change In Price
            uint256 oldPrice = _calculatePrice();
            // burn amount
            _burn(address(this), bal);
            // Emit Collection
            emit GarbageCollected(bal);
            // Emit Price Difference
            emit PriceChange(oldPrice, _calculatePrice(), totalSupply);
        }
    }

    ///////////////////////////////////
    //////    READ FUNCTIONS    ///////
    ///////////////////////////////////

    /** Price Of GROW in USD in wei */
    function calculatePrice() external view returns (uint256) {
        return _calculatePrice();
    }

    /** Precision Of $0.001 */
    function price() external view returns (uint256) {
        return (_calculatePrice() * 10 ** 3) / PRECISION;
    }

    /** Returns the Current Price of 1 Token */
    function _calculatePrice() internal view returns (uint256) {
        // get balance of accepted stables
        uint256 tokenBalance = _adjustedAllStables();
        return (tokenBalance * PRECISION) / totalSupply;
    }

    function _adjustedAllStables() private view returns (uint256) {
        uint256 tokenBalance = 0;
        for (uint8 i = 0; i < currentStables.length; i++) {
            Stable storage stable = stables[currentStables[i]];
            tokenBalance += _adjustedStableBalance(
                stable.balance,
                stable.decimals
            ); // adjust so everything is 18 decimals
        }
        return tokenBalance;
    }

    function _adjustedStableBalance(
        uint _stableBalance,
        uint8 _decimals
    ) private pure returns (uint) {
        return (_stableBalance * 1 ether) / (10 ** _decimals);
    }

    function _getAmountFromAdjusted(
        uint _adjustedAmount,
        uint8 _decimals
    ) private pure returns (uint) {
        return (_adjustedAmount * (10 ** _decimals)) / 1 ether;
    }

    /** Returns the value of your holdings before the sell fee */
    function getValueOfHoldings(address holder) public view returns (uint256) {
        return (_balances[holder] * _calculatePrice()) / PRECISION;
    }

    /** Returns the value of your holdings after the sell fee */
    function getValueOfHoldingsAfterTax(
        address holder
    ) external view returns (uint256) {
        uint currentHoldingValue = getValueOfHoldings(holder);
        uint tax = (getValueOfHoldings(holder) * sellFee) / feeDenominator;
        return currentHoldingValue - tax;
    }

    /** Volume in GROW For A Particular Wallet */
    function volumeFor(address wallet) external view returns (uint256) {
        return _volumeFor[wallet];
    }

    ///////////////////////////////////
    //////   OWNER FUNCTIONS    ///////
    ///////////////////////////////////

    /** Enables Trading For This Token, This Action Cannot be Undone */
    function ActivateToken() external onlyOwner {
        require(!Token_Activated, "Already Activated Token");
        Token_Activated = true;
        emit TokenActivated(totalSupply, _calculatePrice(), block.timestamp);
    }

    /** Excludes Contract From Fees */
    function setFeeExemption(address Contract, bool exempt) external onlyOwner {
        require(Contract != address(0), "Invalid address");
        isFeeExempt[Contract] = exempt;
        emit SetFeeExemption(Contract, exempt);
    }

    /** Set Matrix Contract */
    /**
     *
     * @param executorAddress The address to make an executor
     * @param exempt wether or not to make the address an executor
     */
    function setExecutorAddress(
        address executorAddress,
        bool exempt
    ) external onlyOwner {
        require(executorAddress != address(0), "Invalid address");
        isExecutor[executorAddress] = exempt;
        emit SetExecutor(executorAddress, exempt);
    }

    /** Updates The devShare and liquidityShare */
    function updateShares(
        uint256 newDevShare,
        uint256 newLiquidityShare
    ) external onlyOwner {
        require(newDevShare + newLiquidityShare <= 995, "invalid shares");
        devShare = newDevShare;
        liquidityShare = newLiquidityShare;
        sharesDenominator = devShare + liquidityShare;
        emit UpdateShares(devShare, liquidityShare);
    }

    /** Updates The dev Address */
    function updateDevAddress(address newDev) external onlyOwner {
        require(newDev != address(0), "No address zero");
        dev = newDev;
        emit UpdateDevAddress(newDev);
    }

    /** Updates The Sell, Mint, and Transfer Fees */
    function updateFees(
        uint256 newSellFee,
        uint256 newMintFee,
        uint256 newTransferFee
    ) external onlyOwner {
        require(
            newSellFee + newMintFee <= 250 && newTransferFee <= 250,
            "invalid fees"
        );
        sellFee = newSellFee;
        mintFee = newMintFee;
        transferFee = newTransferFee;
        emit UpdateFees(sellFee, mintFee, transferFee);
    }

    /// @notice Add or remove a Stable token to be used by GROW
    /// @param _stable The address of the STABLE token to change
    /// @param _accept The status to enable or disable the stable token
    /// @dev if the token is already set a few extra requirements are needed: 1. Not the only accepted token, 2. there are no more tokens held by this contract
    /// if setting up a new token, it would be ideal that some balance is sent before hand.
    function setStableToken(address _stable, bool _accept) public onlyOwner {
        require(_stable != address(0), "Zero");
        Stable storage stable = stables[_stable];
        require(stable.accepted != _accept, "Already set");
        stable.accepted = _accept;
        if (!_accept && stable.setup) {
            // If deleted && setup
            if (currentStables[0] == _stable) {
                require(currentStables.length > 1, "Not enough stables");
            }
            require(stable.balance == 0, "Balance not zero");
            if (stable.index < currentStables.length - 1) {
                currentStables[stable.index] = currentStables[
                    currentStables.length - 1
                ]; // substitute current index element with last element
            }
            currentStables.pop(); // remove last element
            stables[currentStables[stable.index]].index = stable.index;
            stable.index = 0;
            stable.setup = false;
            stable.accepted = false;
        } else if (_accept && !stable.setup) {
            IERC20Metadata stableToken = IERC20Metadata(_stable);
            // If added && not setup
            stable.index = uint8(currentStables.length);
            currentStables.push(_stable);
            stable.setup = true;
            stable.balance = stableToken.balanceOf(address(this));
            stable.decimals = stableToken.decimals();
        }

        emit SetStableToken(_stable, _accept);
    }

    /// @notice Show all accepted stables
    /// @return token address array in memory
    function allStables() external view returns (address[] memory) {
        return currentStables;
    }

    function exchangeTokens(
        address _from,
        address _to,
        address _router
    ) external onlyOwner {
        require(
            stables[_from].accepted && stables[_to].accepted,
            "Invalid stables"
        );

        IERC20 fromToken = IERC20(_from);
        IERC20 toToken = IERC20(_to);
        uint fromBalance = fromToken.balanceOf(address(this));
        fromToken.approve(_router, fromBalance);
        address[] memory path = new address[](2);
        path[0] = _from;
        path[1] = _to;
        IUniswapV2Router02(_router).swapExactTokensForTokens(
            fromBalance,
            0,
            path,
            address(this),
            block.timestamp
        );
        uint newToBalance = toToken.balanceOf(address(this));
        require(newToBalance > stables[_to].balance, "No tokens received");
        stables[_to].balance = newToBalance;
        stables[_from].balance = 0;
    }
}
