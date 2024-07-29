// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

 contract StakingNFTs is Ownable(msg.sender), Pausable, UUPSUpgradeable, ERC721Holder, ReentrancyGuard{


    //Defined variables that will be used in the contract
    IERC721 public nftToken;    
    IERC20  public rewardToken;

    uint256 public rewardsPerBlock; //Number of rewards per block per token to be rewarded 
    uint256 public unbondingPeriod; //The duration after which the NFT will be withdrawn after unstaking the NFT
    uint256 public rewardDelayPeriod; //The minimum interval between which a staker can claim the rewards

    //Reward per token, unbonding period, reward delay period will be taken as input while deploying the contract
    constructor(
        address _nftToken,
        address _rewardToken,
        uint256 _rewardsPerBlock,
        uint256 _unbondingPeriod,
        uint256 _rewardDelayPeriod
    ){

        nftToken = IERC721(_nftToken);
        rewardToken = IERC20(_rewardToken);
        rewardsPerBlock = _rewardsPerBlock;
        unbondingPeriod = _unbondingPeriod;
        rewardDelayPeriod = _rewardDelayPeriod;
    }

    //This struct will contain the every information of the user that will be used in the contract
    struct Staker {
        uint256 [] stakedNFTs;                      //Will store the token IDs of NFTs stacked by the user
        mapping (uint256 => uint256) stakingBlock;   //Will store the blocks at which the user staked the NFTs
        mapping (uint256 => uint256) unstakingBlock; //Will store the block at which the user unstaked the NFT
        uint256 rewardsToBeClaimed;                  //Will store the remaining rewards of the user to be claimed 
        uint256 lastRewardsClaimedBlock;             //Will store the block at which the user claimed the rewards last time
        mapping(uint256 => bool) nftUnbondingState;      //Will store if the NFT the user trying to withdraw was unstaked or not
    }

    mapping (address => Staker) public stakers;     //Will store the stakers data
    mapping (uint256 => address) public owners;     //Will store the address of the NFT owners after the NFT is staked


    //Events to be emitted upon successful execution of the particular events
    event Staked(address indexed user, uint256 tokenId);
    event Unstaked(address indexed user, uint256 tokenId);
    event Withdrawn(address indexed user, uint256 tokenId);
    event RewardsClaimed(address indexed user, uint256 amount);
    event RewardPerBlockUpdated(uint256 newRewardPerBlock);
    event StakingPaused();
    event StakingUnpaused();


    //Will return a array of tokenIds of a staker, as the maaping directly cannot be used in ether.js or web3.js
    function getStakedNFTs(address _owner) public view returns(uint256 [] memory){
        return stakers[_owner].stakedNFTs;
    }

    //Will return the unbonding state of a NFT
    function getNftUnbondingState(uint256 _tokenId) public view returns( bool){
        return stakers[msg.sender].nftUnbondingState[_tokenId];

    }

    //Will modify the rewards every time the staking, unstaking or claim rewards function will be called 
    modifier updateRewards(address _staker){
        Staker storage staker = stakers[_staker];
        uint256 length = staker.stakedNFTs.length;
        for(uint256 i=0; i<length; i++){
            if(!staker.nftUnbondingState[i]){
                uint256 newRewards = (block.number-staker.stakingBlock[i])*rewardsPerBlock;
                staker.rewardsToBeClaimed= staker.rewardsToBeClaimed+newRewards;
                staker.stakingBlock[i] = block.number; //staking block number will be set to the current block as the all the rewards till now are added to rewardsToBeClaimed
            }
        }
        _;
    }

    //function to stake NFTs
    function stakeNFTs(uint [] memory _tokenIds) external nonReentrant whenNotPaused updateRewards(msg.sender){
        Staker storage staker = stakers[msg.sender];
        uint256 length = _tokenIds.length;

        for(uint256 i=0; i<length; i++){
            uint256 tokenId = _tokenIds[i];
            require(staker.stakingBlock[tokenId] == 0, "You have already staked this NFT");       
            require(nftToken.ownerOf(tokenId) == msg.sender, "You are not the owner of the NFT");
            owners[tokenId] = msg.sender;
            staker.stakedNFTs.push(tokenId);
            staker.stakingBlock[tokenId] = block.number;
            nftToken.safeTransferFrom(msg.sender, address(this), tokenId);  //safe transfer will ensure thst the nfts are transaferred securely
            emit Staked(msg.sender, tokenId);
        }
    }

    //function to unstake selected NFTs
    function unstakeNFTs(uint [] memory _tokenIds) external nonReentrant whenNotPaused updateRewards(msg.sender){
        Staker storage staker = stakers[msg.sender];
        uint256 length = _tokenIds.length;
        for(uint256 i=0; i<length; i++){
            uint256 tokenId = _tokenIds[i];
            require(owners[tokenId] != address(0), "This NFT is not staked!");
            require(owners[tokenId] == msg.sender, "You're not owner of this NFT!");
            staker.unstakingBlock[tokenId] = block.number;
            staker.nftUnbondingState[tokenId] = true; //unbonding state will be marked true here
            emit Unstaked(msg.sender, tokenId);
        }
    }

    //function to withdraw NFTs
    function withdrawNFTs(uint [] memory _tokenIds) external nonReentrant whenNotPaused {
        Staker storage staker = stakers[msg.sender];
        uint256 length = _tokenIds.length;
        for(uint256 i=0; i<length; i++){
            uint256 tokenId = _tokenIds[i];
            require(owners[tokenId] != address(0), "This NFT is not staked!"); //if the NFT is not staked it's address will be by default zero
            require(owners[tokenId] == msg.sender, "You're not owner of this NFT!");
            require(staker.nftUnbondingState[tokenId], "You have not unstaked this NFT");
            require(block.number > (staker.unstakingBlock[tokenId]+unbondingPeriod), "You have not finished the unbonding period");
            _removeWithdrawnNFTs(staker, tokenId);
            nftToken.safeTransferFrom(address(this), msg.sender, tokenId); //safely transfering the NFT from contract to the owner
            emit Withdrawn(msg.sender, tokenId);

        }

    }

    function _removeWithdrawnNFTs(Staker storage staker, uint256 tokenId) private {
        //WIll remove the withdrwan NFT from the Staked NFTs and set it's all values to default
        delete staker.stakingBlock[tokenId];
        delete staker.nftUnbondingState[tokenId];
        delete staker.unstakingBlock[tokenId];
        owners[tokenId] = address(0);
        for (uint i = 0; i < staker.stakedNFTs.length; i++) {
            if (staker.stakedNFTs[i] == tokenId) {
                staker.stakedNFTs[i] = staker.stakedNFTs[staker.stakedNFTs.length - 1];
                staker.stakedNFTs.pop();
                break;
            }
        }
    }

    //function to claim rewards 
    function claimRewards() external nonReentrant whenNotPaused updateRewards(msg.sender){
        Staker storage staker = stakers[msg.sender];
        require(block.number >= staker.lastRewardsClaimedBlock+rewardDelayPeriod, "You have already claimed rewards");  //Ensures the user can only claim rewards afterr delay period
        staker.lastRewardsClaimedBlock = block.number;
        uint256 rewards = staker.rewardsToBeClaimed;
        staker.rewardsToBeClaimed = 0;
        rewardToken.transfer(msg.sender, rewards);
        emit RewardsClaimed(msg.sender, rewards);
    }

    //Owner can update the rewards per block at anytime
    function updateRewardsPerBlock(uint256 _newRewardsPerBlock) external onlyOwner {
        rewardsPerBlock = _newRewardsPerBlock;
        emit RewardPerBlockUpdated(_newRewardsPerBlock);
    }

    //owner can pause staking, unstaking, withdrawing, claiming rewards
    function pause() external onlyOwner {
        _pause();
        emit StakingPaused();
    }

     //owner can unpause staking, unstaking, withdrawing, claiming rewards
    function unpause() external onlyOwner {
        _unpause();
         emit StakingUnpaused();
    }

    //owner can upgrade the contract 
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}



}