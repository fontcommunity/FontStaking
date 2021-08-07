// SPDX-License-Identifier: MIT
// Author: https://twitter.com/adalquardz

pragma solidity ^0.8.0;

//import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";


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



contract FontStaking is AccessControl {

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

    //WETH address to convert ETH to WETH 
    ERC20 weth;


    address ownerAddress; //Main admin of this contract

    uint256 taxFee = 400; // 1 = 0.01% for premature unstake
    address font_token_address = 0x4C25Bdf026Ea05F32713F00f73Ca55857Fbf6342; //token address of the font
    uint256 public maxSnapshotLifetime = 259200; // 3 days Max freshness of snapshot before reward distribution
    uint256 public minSnapshotInterval = 7776000; //3 months this is used for both snapshot and reward distribution
    uint256 public minStakeTime = 7776000; //90 days in second
    uint256 public minStakeAmount = 500 * (10**18); // Minimum eligible fonts for staking 
    
    
    IERC20 public FONT_ERC20; //Font token address

    bool public stakingPaused; //Status of staking 
    uint256 public totalTaxAmount = 0; //Total tax accumulated, subjected to reset from 0 on burn 
    uint256 public lastRewardTime = 0; //time stamp of last time reward distributed 
    uint256 public stakeCounter; //Current stake ID. Counter
    uint256 public totalStaked = 0; //Total $FONTs currently staked
    uint256 public lastSnapshotTime; //Last time the snapshot made

    //stake id to skip, this helps to reduce gas as time goes. 
    uint256 firstUnclaimedStakeId = 1;    

    //Eligible number of fonts for rewards, this helps to calculate user share of rewards 
    uint256 totalEligibleFontsForRewards = 0; //This resets often

    //list of accounts excluded from rewards 
    mapping (address => bool) private excludedAccount; 

    //Total font token currently staked per user
    mapping (address => uint256) public usersStake; 

    //Holds the ERC address of reward tokens, usefull for multiple token payment 
    struct RewardToken { 
        //uint256 balance; //balance of this token
        uint256 minBalance; //Minimum balance to send rewards / No use of spending 1$ to 1000 people. 
        //address token; //ERC20 token for rewards
        bool status; //current status or this erc token
    }
    mapping (address => uint256) public rewardTokens;
    
        struct TT {
            address a;
            bool b;
        }    

    //Staking info
    struct stakingInfo {
        uint256 amount;
        uint256 lockedTime;
        uint256 unstakeTime;
        uint256 duration;
        address user;
        bool claimed;
    }
    mapping(uint256 => stakingInfo) private StakeMap; 


    //users stake ids 
    mapping(address => uint256[]) private userStakeIds;


    //snapshots
    mapping (uint256 => mapping(address => uint256)) public SnapShot; //User balance based on the snapshot 
    mapping (uint256 => address[]) private SnapShotUsers; //list of eligible users per snapshot 

    //User reward balance claimable
    mapping (address => mapping(address => uint256)) public UserRewardBalance;


    constructor(address _font_token_address, address _weth)  {
        stakeCounter = 1;
        FONT_ERC20 = IERC20(_font_token_address); 
        ownerAddress = msg.sender;
        stakingPaused = false;
        _setupRole(ADMIN_ROLE, msg.sender); // Assign admin role to contract creator

        weth = ERC20(_weth);

    }

    //@done
    event LogStake(address _address, uint256 _stake_id, uint256 amount); 
    /**
    * @dev stake a specific amount to a token
    * @param _amount the amount to be staked
    * for demo purposes, not requiring user to actually send in tokens right now  
    */
    function stake(uint256 _amount) public {
        require(!stakingPaused, 'Paused');
        require(_amount > minStakeAmount, 'Minimum');

        uint256 _stake_id = stakeCounter;

        //Add total token staked per address
        usersStake[msg.sender] += _amount; //usersStake[msg.sender].add(_amount);
        

        //Add item to StakeMap
        StakeMap[_stake_id].amount = _amount;
        StakeMap[_stake_id].claimed = false;
        StakeMap[_stake_id].lockedTime = block.timestamp;
        StakeMap[_stake_id].duration = minStakeTime;
        StakeMap[_stake_id].user = msg.sender;
        
        //stake ids per user
        userStakeIds[msg.sender].push(_stake_id);

        //Total font currently staked
        totalStaked += _amount;

        //Update Stake Counter 
        stakeCounter++;
        
        //safe transfer from 
        FONT_ERC20.safeTransferFrom(msg.sender, address(this), _amount);
        
        emit LogStake(msg.sender, _stake_id,  _amount);
    }
    
    //Unstake the font Token by stake id
    //@done
    event UnStaked(address _address, uint256 _stake_id, uint256 amount, uint256 _tax);
    function unStake(uint256 _stake_id) external {
        require(StakeMap[_stake_id].user == msg.sender, 'Denied');
        require(!StakeMap[_stake_id].claimed, 'Claimed');
        require(usersStake[msg.sender] > 0, 'No balance');

        uint256 _amount = StakeMap[_stake_id].amount; //@todo no need this variable
        uint256 _taxfee = 0;

        //Take tax for premeture unstake
        if((StakeMap[_stake_id].lockedTime + StakeMap[_stake_id].duration) > block.timestamp) {
            _taxfee = _amount.mul(taxFee).div(10**4);
            //Add tax amount to total tax    
            totalTaxAmount += _taxfee;// totalTaxAmount.add(_taxfee);
        }
        
        //Reduce the balance per user
        //usersStake[msg.sender] = usersStake[msg.sender].sub(_amount);
        usersStake[msg.sender] -= _amount;// usersStake[msg.sender].sub(_amount);
        
        //Update stake info 
        StakeMap[_stake_id].claimed = true;
        StakeMap[_stake_id].unstakeTime = block.timestamp;
        
        //Total font currently staked
        totalStaked -= _amount; //totalStaked.sub(_amount);      

        //Transfer token to user @todo safetransfer
        FONT_ERC20.safeTransfer(msg.sender, (_amount.sub(_taxfee)));

        emit UnStaked(msg.sender, _stake_id, _amount, _taxfee);
    }

    //Get detail about single stake info by address and id
    //@done
    function getStakeByID(uint256 _stake_id) external view returns (stakingInfo memory) {
        return StakeMap[_stake_id];
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

    //emergency 

    /**********************************************************************************************************/
    /********************************************   Admin Settings  *******************************************/
    /**********************************************************************************************************/
    
    //Change tax fee
    //@done
    event changedTaxFee(uint256);
    function setTaxFees(uint256 _fees) external {
        require(hasRole(ADMIN_ROLE, msg.sender), "Denied");
        require(_fees > 0, "0");
        taxFee = _fees;
        emit changedTaxFee(_fees);
    }

    //change min required stake amount
    //@done 
    event ChangedMinStakeRequired(uint256);
    function setMinStakeRequired(uint256 _amount) external {
        require(hasRole(ADMIN_ROLE, msg.sender), "Denied");
        minStakeAmount = _amount * (10**18);
        emit ChangedMinStakeRequired(_amount);
    }

    //Kick out a stake, dont take tax. This is to help test stakes to withdraw without tax.
    //@done
    event KickedStake(uint256);
    function kickStake(uint256 _stake_id) external {
        require(hasRole(ADMIN_ROLE, msg.sender), "Denied");
        require(!StakeMap[_stake_id].claimed, 'Claimed');
        require(StakeMap[_stake_id].amount > 0, 'No Stake Amount');
        require(totalStaked > 0, 'No FONT Balance');
        
        //Reduce the balance per user
        usersStake[StakeMap[_stake_id].user] -= StakeMap[_stake_id].amount;
        //usersStake[StakeMap[_stake_id].user].sub(StakeMap[_stake_id].amount);
        
        //Update stake info 
        StakeMap[_stake_id].claimed = true;
        StakeMap[_stake_id].unstakeTime = block.timestamp;
        
        //Total font currently staked
        totalStaked -= StakeMap[_stake_id].amount;// totalStaked.sub(StakeMap[_stake_id].amount);      

        //safetransfer token to user 
        FONT_ERC20.safeTransfer(StakeMap[_stake_id].user, StakeMap[_stake_id].amount);

        emit KickedStake(_stake_id);
    }
    
    //Add an account to exclude from payment splits and rewards. 
    //this is to exclude the team / test accounts. 
    //@done
    event accountExcluded(address);
    function excludeAccount(address _address) external {
        require(hasRole(ADMIN_ROLE, msg.sender), "Denied");
        excludedAccount[_address] = true;
        emit accountExcluded(_address);
    }

    //Add an account to include from payment splits and rewards. 
    //@done
    event accountIncluded(address);
    function includeAccount(address _address) external {
        require(hasRole(ADMIN_ROLE, msg.sender), "Denied");
        excludedAccount[_address] = false;
        emit accountIncluded(_address);
    }

    //Helper function to move the stake ID pointer for first open stake
    //@done
    function setFirstUnclaimedStakeId(uint256 _id) external {
        require(hasRole(ADMIN_ROLE, msg.sender), "Denied");
        firstUnclaimedStakeId = _id;
    }

    //Edit existing reward token
    //@done
    event EditRewardToken(address _address, uint256 _minBalance);
    function editRewardToken(address _address, uint256 _minBalance) external {
        require(hasRole(ADMIN_ROLE, msg.sender), "Denied");
        rewardTokens[_address] = _minBalance;
        emit EditRewardToken(_address, _minBalance);        
    }        

    //Burn the tax, let anyone call it. 
    //@done
    event FontBurned(uint256 amount);
    function burnFont() external {
        uint256 _totalTaxAmount = totalTaxAmount;
        totalTaxAmount = 0;
        FONT_ERC20.burn(_totalTaxAmount);
        emit FontBurned(totalTaxAmount);
    }

    //withdraw the tokens that sent accidently 
    function withdrawErc20(address _token, uint256 _amount) public {
        require(msg.sender == ownerAddress, "Denied");
        require(_token != font_token_address, "FONT");
        IERC20(_token).transfer(msg.sender, _amount);
    }    

    function editFontErcAddress(address _address) external {
        require(msg.sender == ownerAddress, "Denied");
        font_token_address = _address;
    }

    //change the time settings 
    event TimingsChanged(uint256, uint256, uint256);
    function setTimings(uint256 _maxSnapshotLifetime, uint256 _minSnapshotInterval, uint256 _minStakeTime) external {
        require(msg.sender == ownerAddress, "Denied");
        maxSnapshotLifetime = _maxSnapshotLifetime; //3 days default
        minSnapshotInterval = _minSnapshotInterval; //90 days defualt 
        minStakeTime = _minStakeTime; //90 days default 
        emit TimingsChanged(_maxSnapshotLifetime, _minSnapshotInterval, _minStakeTime);
    }

    /**********************************************************************************************************/
    /************************************************   views  ************************************************/
    /**********************************************************************************************************/
    //Get the number of tokens staked by user
    //@done
    function getStakeByUser(address _address) external view returns (uint256) {
        return usersStake[_address];
    }

    //Get list of all users stake ids
    function getStakeidsByUser(address _address) external view returns (uint256[] memory) {
        return userStakeIds[_address];
    }

    //get current reward share percentage per address.
    //
    function getCurrentRewardShare(address _user) external view returns (uint256) {
        return SnapShot[lastSnapshotTime][_user];
    }

    function getUserRewardBalance(address _token, address _user) external view returns (uint256) {
        return UserRewardBalance[_user][_token];
    }

    function getTaxFee() external view returns (uint256) {
        return taxFee;
    }

    function getTotalEligibleFontsForRewards() external view returns (uint256) {
        return totalEligibleFontsForRewards;
    }

    function getlastSnapshotTime() external view returns (uint256) {
        return lastSnapshotTime;
    }

    function getSnapShotUsers(uint256 _snapshotTime) external view returns (address[] memory) {
        return SnapShotUsers[_snapshotTime];
    }

    /**********************************************************************************************************/
    /************************************************   Helpers  **********************************************/
    /**********************************************************************************************************/

    //calculate tax fee
    //@done
    function calculateTax(uint256 _amount) internal view returns (uint256) {
        return _amount.mul(taxFee).div(10**4);
    }
    
    //Convert ETH to WETH and keep it in Contract for distribution
    receive() external payable {
        weth.deposit{value: msg.value}();
    }
    function() public payable {
        weth.deposit{value: msg.value}();
    }

    /**********************************************************************************************************/
    /************************************************  Rewards  **********************************************/
    /**********************************************************************************************************/
    //Take snapshot of reward eligibility>
    //Should able to take min of 3 months 
    event SnapShoted(uint256, uint256);
    function takeSnapshot() external {
        require(hasRole(ADMIN_ROLE, msg.sender), "Denied");

        uint256 _blockTimestamp = block.timestamp;
        require(lastSnapshotTime < (_blockTimestamp - minSnapshotInterval), "Wait"); //@done
        uint256 _totalEligibleFontsForRewards = 0;
        
        stakingInfo storage _StakeMap;

        for(uint256 i = firstUnclaimedStakeId; i < stakeCounter; i++) {
            _StakeMap = StakeMap[i];
            //check if user is not already claimed, have crosed the date, and account is not excluded to get rewards
            if(!_StakeMap.claimed && (_StakeMap.lockedTime + _StakeMap.duration < _blockTimestamp)) { //@done date
                //calculate the total eligible fonts for staking rewards 
                _totalEligibleFontsForRewards += _StakeMap.amount;
                //add eligible number of tokens per user address
                if(SnapShot[_blockTimestamp][_StakeMap.user] == 0) {
                    SnapShotUsers[_blockTimestamp].push(_StakeMap.user);
                }
                SnapShot[_blockTimestamp][_StakeMap.user] += _StakeMap.amount;
                //
            }
        }

        //update the metadatas 
        lastSnapshotTime = _blockTimestamp;
        totalEligibleFontsForRewards = _totalEligibleFontsForRewards;
        emit SnapShoted(lastSnapshotTime, totalEligibleFontsForRewards);
    }

    //Distribute the reward 
    event RewardsDistributed(uint256, uint256);
    function DistributeRewards(address[] memory _tokens) external {
        require(hasRole(ADMIN_ROLE, msg.sender), "Denied");

        uint256 _blockTimestamp = block.timestamp;

        //should be called AFTER x days (30 days ) from last withdrawals
        require(lastRewardTime < (_blockTimestamp - minSnapshotInterval), 'wait'); //@done        
        //should have snapshotred before x mins (4 hours?)
        require(lastSnapshotTime > (_blockTimestamp - maxSnapshotLifetime), 'SnapShot'); //@done 
        //make sure there is enough staking from last snapshot
        require(totalEligibleFontsForRewards > 0, '0 stake'); //@done
        
        //uint256 _rewardAmount = 0;
        uint256 _token_balance = 0;
        address __address;
        uint256 _totalEligibleFontsForRewards = totalEligibleFontsForRewards;
        uint256 _min_token_balance = 0;
        address[] memory _SnapShotUsers = SnapShotUsers[lastSnapshotTime];

        mapping (address => uint256) storage _SnapShot = SnapShot[lastSnapshotTime];

        for(uint256 i = 0; i < _tokens.length; i++ ) {
            _min_token_balance = rewardTokens[_tokens[i]];
            if(_min_token_balance > 0) {
                _token_balance = IERC20(_tokens[i]).balanceOf(address(this));
                if(_token_balance >= _min_token_balance) { 
                    for(uint256 _user = 0; _user < _SnapShotUsers.length; _user++) { 
                        __address = _SnapShotUsers[_user];
                        UserRewardBalance[__address][_tokens[i]] += (_SnapShot[__address].mul(_token_balance).div(_totalEligibleFontsForRewards));
                    } //take all the users in current snapshop
                }
            } //check if reward token is enabled and its not font token 

        } // Main for loop

        //update the needed metadata 
        lastRewardTime = _blockTimestamp;

        //emit 
        emit RewardsDistributed(_tokens.length, SnapShotUsers[lastSnapshotTime].length);

    }

    //Users can cliam the reward. Can claim the multiple number of tokens in single shot
    //@todo, only allowed tokens
    event RewardClaimed(address, uint256);
    function claimRewards(address[] memory _tokens) public {
        //loop all tokens 
        uint256 _amount = 0;
        for(uint256 i = 0; i < _tokens.length; i++ ) {
            _amount = UserRewardBalance[msg.sender][_tokens[i]];
            if(_amount > 0) {
                UserRewardBalance[msg.sender][_tokens[i]] = 0;
                IERC20(_tokens[i]).safeTransfer(msg.sender, _amount);
            }
        }
        emit RewardClaimed(msg.sender, block.timestamp);
    }

    /****************************************************************/
    /************** Testing functions here ********************/
    /****************************************************************/

    //function debugger() external view returns (uint256, uint256, uint256, uint256, uint256, uint256, uint256) {
             
      //  return (ddtotalTokens,ddtotalTokensenabled ,ddtotalTokensBalance, ddtotalusers, ddtotalusersWithMoney, ddtotalreward, totalEligibleFontsForRewards);
    //}
    
}


