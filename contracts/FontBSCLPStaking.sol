// SPDX-License-Identifier: MIT
// Author: https://twitter.com/adalquardz

pragma solidity ^0.8.0;

//import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";


interface IUniswapV2Pair {
    function getReserves() external view returns (uint256 reserve0, uint256 reserve1, uint32 blockTimestampLast);
    function totalSupply() external view returns (uint);

}


/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

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
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    function burn(uint256 amount) external;

    
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
}

interface ERC20{
  function deposit() external payable;
  function withdraw(uint256 amount) external;
}


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
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
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
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
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
        return functionCall(target, data, "Address: low-level call failed");
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
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
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
        require(isContract(target), "Address: call to non-contract");

        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return _verifyCallResult(success, returndata, errorMessage);
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
        require(isContract(target), "Address: static call to non-contract");

        (bool success, bytes memory returndata) = target.staticcall(data);
        return _verifyCallResult(success, returndata, errorMessage);
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
        require(isContract(target), "Address: delegate call to non-contract");

        (bool success, bytes memory returndata) = target.delegatecall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    function _verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) private pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}




/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    using Address for address;

    function safeTransfer(
        IERC20 token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(oldAllowance >= value, "SafeERC20: decreased allowance below zero");
            uint256 newAllowance = oldAllowance - value;
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            // Return data is optional
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}



contract FontBSCLPStaking is AccessControl {

    using SafeMath for uint;    
    using SafeMath for uint8;
    using SafeMath for uint16;    
    using SafeMath for uint256;    
    using SafeERC20 for IERC20;

    /**********************************************************************************************************/
    /**********************************************   Variables  **********************************************/
    /**********************************************************************************************************/

    /*********** Settings ************/

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");


    //100 = 1%, monthly 2%, yearly 24% 
    uint16 APY = 3600; 
    
    //100 = 1%
    uint16 coverImpermanentLoss = 0;

    // 1 = 0.01% for premature unstake
    uint16 public taxFee = 200; 

    address ownerAddress; //Main admin of this contract

    
    //token address of the font
    //ETH Rinkeby 0x17225e68D3761af8fbDA959367B788cC861943Df
    address FONT_token_address = 0x17225e68D3761af8fbDA959367B788cC861943Df; 
    //LP Token Address BNB-FONT
    //Uni Rinkeby 0x4c2dFBf6b7d258969A632f891301532C19E9D96D
    address LP_token_address = 0x4C25Bdf026Ea05F32713F00f73Ca55857Fbf6342; 
    

    uint32 public minStakeTime = 7776000; //90 days in second
    
    //Font token ERC20
    IERC20 public FONT_ERC20; 
    //Pankcake Pair ERC20, to keep the safety checks  
    IERC20 public PAIR_ERC20; 

    //To use pair methods
    IUniswapV2Pair public UNI_PAIR_V2; 



    bool public stakingPaused; //Status of staking 
    //Total tax accumulated, subjected to reset from 0 on burn 
    uint256 public totalTaxAmount = 0; 
    //Current stake ID. Counter
    uint256 public stakeCounter; 
    //Total Uni V2 Tokens currently staked
    uint256 public totalStaked = 0; 


    //Total Uni V2 token currently staked per user
    mapping (address => uint256) public usersStake; 

    //$FONT earned by user, subject to reset after withdrawal
    mapping (address => uint256) public FontReward;

    

    //Staking info
    struct stakingInfo {
        uint16 APY; //APY for this current stake, this will keep on change
        uint16 cil; //Cover Impermanent Loss
        uint32 duration; //Duration 

        uint256 amount; //LP Amount 

        uint256 fontInitial; //Initial Font Supply of this pool 
        uint256 fontFinal; //Initial Font Supply of this pool 
        uint256 fontReward; //Initial Font Supply of this pool 
        
        uint256 bnbInitial; //Initial Font Supply of this pool 
        uint256 bnbFinal; //Initial Font Supply of this pool 

        uint256 lockedTime; //Time LP Locked 
        uint256 unstakeTime; //Time LP unstaked 
        

        address user; //Staking user
        bool closed; //if closed
        
    }
    mapping(uint256 => stakingInfo) private StakeMap; 


    //users stake ids 
    mapping(address => uint256[]) private userStakeIds;


    constructor(address _font_token_address, address _uni_pair) {
        //Start the staking counter with 1
        stakeCounter = 1;
        //Font Token, this is for distribute the reward
        FONT_ERC20 = IERC20(_font_token_address); 

        //Pankcake swap FONT/BNB Pair address
        UNI_PAIR_V2 = IUniswapV2Pair(_uni_pair);
        //Pancakeswap Pair Address with safetychecks
        PAIR_ERC20 = IERC20(_uni_pair); 

        LP_token_address = _uni_pair;

        FONT_token_address = _font_token_address;

        //Owner address
        ownerAddress = msg.sender;
        //Staking is not paused initially
        stakingPaused = false;
        //Set up Admin role
        _setupRole(ADMIN_ROLE, msg.sender); // Assign admin role to contract creator
    }

    //@done
    event Staked(address _address, uint256 _stake_id, uint256 amount); 
    /**
    * @dev stake a specific amount to a token
    * @param _amount the amount to be staked
    * for demo purposes, not requiring user to actually send in tokens right now  
    */
    function stake(uint256 _amount) public {
        require(!stakingPaused, 'Paused');
        
        uint256 _userShareFont;
        uint256 _userShareBNB;

        //Get the LP share 
        (_userShareFont, _userShareBNB) = _getUserShare(_amount);

        require(_userShareFont > 0 && _userShareBNB > 0, '0 Share');

        uint256 _stake_id = stakeCounter;

        //Add total token staked per address
        usersStake[msg.sender] += _amount; //usersStake[msg.sender].add(_amount);
        

        //Add item to StakeMap

        //Staking Uni V2 Token amount
        StakeMap[_stake_id].amount = _amount;
        //Stake is not closed yet
        StakeMap[_stake_id].closed = false;
        //Time of this stake started 
        StakeMap[_stake_id].lockedTime = block.timestamp;
        //Minimum Stake duration 
        StakeMap[_stake_id].duration = minStakeTime;
        //User who stake 
        StakeMap[_stake_id].user = msg.sender;

        //Initial Total $FONTs for the LP locking 
        StakeMap[_stake_id].fontInitial = _userShareFont;
        //Set to 0
        StakeMap[_stake_id].fontFinal = 0;
        //Set to 0
        StakeMap[_stake_id].fontReward = 0;

        //Initial Total BNB for the LP locking  
        StakeMap[_stake_id].bnbInitial = _userShareBNB;
        //Set to 0
        StakeMap[_stake_id].bnbFinal = 0;

        //APY during this period 
        StakeMap[_stake_id].APY = APY;
        //If we covering the Impermanent Loss and how much % of yes 
        StakeMap[_stake_id].cil = coverImpermanentLoss;
        
        //stake ids per user
        userStakeIds[msg.sender].push(_stake_id);

        //Total LP currently staked
        totalStaked += _amount;

        //Update Stake Counter 
        stakeCounter++;
        
        //safe transfer from 
        PAIR_ERC20.safeTransferFrom(msg.sender, address(this), _amount);
        
        emit Staked(msg.sender, _stake_id,  _amount);
    }
    
    //Unstake the font Token by stake id
    //@done
    event UnStaked(address _address, uint256 _stake_id, uint256 amount, uint256 _tax);
    function unStake(uint256 _stake_id) external {
        //Only owner is able to unstake 
        require(StakeMap[_stake_id].user == msg.sender, 'Denied');
        //Stake should not be closed 
        require(!StakeMap[_stake_id].closed, 'closed');
        //Balance should be non 0 for user
        require(usersStake[msg.sender] >= StakeMap[_stake_id].amount, 'No balance');

        //@todo no need this variable
        uint256 _amount = StakeMap[_stake_id].amount; 

        //Reduce the LP balance per user
        usersStake[msg.sender] -= _amount;        

        //Update stake info 
        //Close the stake 
        StakeMap[_stake_id].closed = true;
        //Log the closing time of this stake 
        StakeMap[_stake_id].unstakeTime = block.timestamp;
        
        //Total font currently staked, reduce it 
        totalStaked -= _amount; 


        uint256 _taxfee = 0;
        uint256 _userShareFont;
        uint256 _userShareBNB;        

        //Get the LP share, font and bnb share
        (_userShareFont, _userShareBNB) = _getUserShare(_amount);
            
        //Update the $FONTs share to his LP share
        StakeMap[_stake_id].fontFinal = _userShareFont;

        //Update the $BNB/$ETH share to his LP share
        StakeMap[_stake_id].bnbFinal = _userShareBNB;


        //Take tax for premeture unstake
        if((StakeMap[_stake_id].lockedTime + StakeMap[_stake_id].duration) > block.timestamp) {
            _taxfee = _amount * taxFee / (10**4);
            //Add tax amount to total tax    
            totalTaxAmount += _taxfee;
        }
        //Reward for unstaking with maturity
        else {

            //calculate the number of days eligible for APY reward 
            //@done checked the math
            uint256 _rewardDays = (block.timestamp - StakeMap[_stake_id].lockedTime) / 86400;
            //Calculate font rewards in APY
            //@done checked the math 
            uint256 _rewardsInFont = (StakeMap[_stake_id].fontInitial * APY * _rewardDays) / (365 * 10000);

            //calculate reward for Covering Impermanent loss. 
            if(StakeMap[_stake_id].cil > 0 ) {

                uint256 _fontLoss = 0;

                //If Initial Font is higher then current font in Pool 
                if(StakeMap[_stake_id].fontInitial > _userShareFont) {
                    //@done checked the math
                    _fontLoss = (StakeMap[_stake_id].fontInitial - _userShareFont) * StakeMap[_stake_id].cil / 10000;
                }
                
                //Add to rewards total 
                _rewardsInFont += _fontLoss;
            }

            StakeMap[_stake_id].fontReward = _rewardsInFont;

            //send the reward rightaway if enough balance, else add it to user balance
            if(FONT_ERC20.balanceOf(address(this)) > _rewardsInFont) {
                FONT_ERC20.safeTransfer(msg.sender, _rewardsInFont);
            }
            //add the rewards to user balances, so they can withdraw it later
            else {
                FontReward[msg.sender] += _rewardsInFont;
            }
        }
        
        //Transfer Uni V2 token to user safetransfer
        PAIR_ERC20.safeTransfer(msg.sender, (_amount - _taxfee));

        emit UnStaked(msg.sender, _stake_id, _amount, _taxfee);
    }

    //Users can withdraw the font
    event RewardWithdrawn(address, uint256);
    function withdrawReward() external {
        require(FontReward[msg.sender] > 0, '0');
        require(totalStaked > 0, 'Empty');
        uint256 _rewardsInFont = FontReward[msg.sender];
        FontReward[msg.sender] = 0;
        FONT_ERC20.safeTransfer(msg.sender, _rewardsInFont);
        emit RewardWithdrawn(msg.sender, _rewardsInFont);

    }

    function _getUserShare(uint256 _LPamount) internal view returns (uint256, uint256) {
        //Get the total Supply 
        uint256 _totalSuppy = UNI_PAIR_V2.totalSupply();

        require(_totalSuppy >= _LPamount && _LPamount > 0);
        
        uint256 reserve_font; 
        uint256 reserve_bnb; 

        //get the total reserve
        (reserve_font, reserve_bnb,) = UNI_PAIR_V2.getReserves();

        return ((reserve_font * _LPamount) / _totalSuppy, (reserve_bnb * _LPamount) / _totalSuppy);
    }

    function getUserShare(uint256 _LPamount) external view returns (uint256, uint256) {
        return _getUserShare(_LPamount);
    }

    /**********************************************************************************************************/
    /********************************************   Admin Settings  *******************************************/
    /**********************************************************************************************************/
    
    //Change tax fee
    //@done
    event changedTaxFee(uint16);
    function setTaxFees(uint16 _fees) external {
        require(hasRole(ADMIN_ROLE, msg.sender), "Denied");
        require(_fees > 0, "0");
        taxFee = _fees;
        emit changedTaxFee(_fees);
    }

    //@done APY
    event changedAPY(uint16);
    function setAPY(uint16 apy) external {
        require(hasRole(ADMIN_ROLE, msg.sender), "Denied");
        require(apy > 0, "0");
        APY = apy;
        emit changedAPY(apy);
    }  

    //@done cover Impermanent Loss
    event changedCIL(uint16);
    function setCIL(uint16 cil) external {
        require(hasRole(ADMIN_ROLE, msg.sender), "Denied");
        coverImpermanentLoss = cil;
        emit changedCIL(cil);
    }        

    

    //Kick out a stake, dont take tax. This is to help test stakes to withdraw without tax or benifits, dont use for user stakes
    event KickedStake(uint256);
    function kickStake(uint256 _stake_id) external {
        require(hasRole(ADMIN_ROLE, msg.sender), "Denied");
        require(!StakeMap[_stake_id].closed, 'closed');
        require(StakeMap[_stake_id].amount > 0, 'No Stake Amount');
        require(totalStaked > 0, 'No FONT Balance');
        
        //Reduce the balance per user
        usersStake[StakeMap[_stake_id].user] -= StakeMap[_stake_id].amount;
        
        //Update stake info 
        StakeMap[_stake_id].closed = true;
        StakeMap[_stake_id].unstakeTime = block.timestamp;
        
        //Total font currently staked
        totalStaked -= StakeMap[_stake_id].amount;

        //safetransfer token to user 
        PAIR_ERC20.safeTransfer(StakeMap[_stake_id].user, StakeMap[_stake_id].amount);

        emit KickedStake(_stake_id);
    }


    //Burn the tax, let anyone call it. 
    event LPBurned(uint256 amount);
    function burnLP() external {
        uint256 _totalTaxAmount = totalTaxAmount;
        totalTaxAmount = 0;
        //Send the tax amount to dead address
        PAIR_ERC20.safeTransfer(0x000000000000000000000000000000000000dEaD, _totalTaxAmount);
        //PAIR_ERC20.burn(_totalTaxAmount);
        emit LPBurned(totalTaxAmount);
    }

    //withdraw the tokens that sent accidently 
    //@done
    function withdrawErc20(address _token, uint256 _amount) public {
        require(msg.sender == ownerAddress, "Denied");
        require(_token != LP_token_address, "LP");
        IERC20(_token).transfer(msg.sender, _amount);
    }    

    //Withdraw the accidently sent ETH 
    //@done
    function withdrawETH(uint256 amount) public {
        require(msg.sender == ownerAddress, "Denied");
        payable(msg.sender).transfer(amount);
     }
    

    //change the time settings 
    //@done
    function setTimings(uint32 _minStakeTime) external {
        require(hasRole(ADMIN_ROLE, msg.sender), "Denied");
        minStakeTime = _minStakeTime; //90 days default 
    }


    //Pause the staking
    //@done
    function pauseStaking() external {
      require(hasRole(ADMIN_ROLE, msg.sender), "Denied");
      stakingPaused = true;
    }

    //UnPause the staking
    //@done
    function unpauseStaking() external {
      require(hasRole(ADMIN_ROLE, msg.sender), "Denied");
      stakingPaused = false;
    }    

    /**********************************************************************************************************/
    /************************************************   views  ************************************************/
    /**********************************************************************************************************/
    //Get the number of tokens staked by user
    //@done
    function getStakeAmountByUser(address _address) external view returns (uint256) {
        return usersStake[_address];
    }

    //Get list of all users stake ids
    //@done
    function getStakeidsByUser(address _address) external view returns (uint256[] memory) {
        return userStakeIds[_address];
    }

    //Get detail about single stake info by address and id
    //@done
    function getStakeByID(uint256 _stake_id) external view returns (stakingInfo memory) {
        return StakeMap[_stake_id];
    }
    
}


