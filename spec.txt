Font staking 

Fixed time. 
Tax on early withdrawal 
Reward for 30+ days 
based on % of stake 
All ERC split expect FONT 

Backdoor to and pausable 

Burn the tax 
WETH from ETH 


Full end to end Testing 

Add mininum balance to withdrawal


What if people witdraw tokens by one ERC after one 


make it claimable 

----------------- Test Cases ----------------
stake
unstake
getStakeByID
pauseStaking
unpauseStaking
setTaxFees
setMinStakeRequired
kickStake
excludeAccount
includeAccount
NewRewardToken
EditRewardToken
burnFont
withdrawErc20
makeAdmin
revokeAdmin
getStakeByUser
getStakeidsByUser
getCurrentRewardShare
isRewardTokenExists
calculateTax
takeShapshot
DistributeRewards
claimRewards


Need test font, 
    test erc20s 
    payment erc20s 
    addresses 
    limited time schedule 


====================================================================================================================================
=========================================================  Font NFT exchange =======================================================
====================================================================================================================================

Royality 
Multichain 
fees to staking contract 
accepts mutiple tokens (potential partnership)
0 commision for trading in FONT (whats the value of font)
Supports fractions trade (Respect ERC1155)
commission burn 
include the font mining into it exchange
rearrage the font miining in favour of buyers in terms of volume 
Minting is in this contract which admin adds the whitelist stuffs 
Affliate will get % 
Royality works only if the trade is happening in our exchange.

Add role to kicker, snapshot, distributor

Auction? No



====================================================================================================================================
=========================================================  Font fund raising =======================================================
====================================================================================================================================

1% of total raise sent to staking rewards 
99% goes to fund raisers 
Success full fund raisers will earn some fonts? 
single contract to the specific job 
after successfull fundraise, erc1155 share will be distributed to investors based on the invested ratio and listed as exclusive NFT 

Create Font page in drupal 
Create it as NFT in ERC1155 and move it to fund raising contract 
After successfull ICO, distribute the funds to investors
Method 1 
    Follow ERC1155 standard to distribute the share (hard to implement)
Methor 2 
    Sell and distribute the profit based on share (hard in business wise )


Better use method 2 and exit the project 

====================================================================================================================================
=========================================================  Self Minting NFT =======================================================
====================================================================================================================================

in backend, authorize gmail, twitter and metamask 
conform in email and in SMS 
Save the wallet address
get the items to mint in batch 

create a contract that mint nft in font nft address 
that contract will get chain, id, address and it will call the main NFT contract and move the 
this proxy contract will hold all the font IDs irrespective of mint or not
This will be batch run every x items .


====================================================================================================================================
=========================================================  Fees ====================================================================
====================================================================================================================================
2% to stakers 
2% to burn 


====================================================================================================================================
=========================================================  Font License contract ===================================================
====================================================================================================================================

4% of the license value will be rewarded as token to buyers. 

able to do universal license 