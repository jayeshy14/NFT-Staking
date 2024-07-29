const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("StakingNFTs Contract", function () {
  let nftToken, rewardToken, stakingNFTs;
  let deployer, staker1, staker2;

  beforeEach(async function () {
    [deployer, staker1, staker2] = await ethers.getSigners();

    // Deploy ERC721Mock contract
    const ERC721Mock = await ethers.getContractFactory("ERC721Mock");
    nftToken = await ERC721Mock.deploy("NFTs", "NFT", 100);
    await nftToken.waitForDeployment();
    const nftTokenAddress = await nftToken.getAddress();
    // Mint NFTs to staker1
    for (let i = 1; i <= 5; i++) {
      await nftToken.connect(deployer).mint(staker1.getAddress(), i);
    }

    // Deploy ERC20Mock contract
    const ERC20Mock = await ethers.getContractFactory("ERC20Mock");
    rewardToken = await ERC20Mock.deploy("Reward Token", "RWT", ethers.parseUnits("1000000", 18));
    await rewardToken.waitForDeployment();
    const rewardTokenAddress = await rewardToken.getAddress();

    // Deploy StakingNFTs contract
    const StakingNFTs = await ethers.getContractFactory("StakingNFTs");
    stakingNFTs = await StakingNFTs.deploy(
      nftTokenAddress,
      rewardTokenAddress,
      ethers.parseUnits("10", 18),
      5,
      10
    );
    await stakingNFTs.waitForDeployment();
    const stakingNFTsAddress = await stakingNFTs.getAddress();

    // Transfer reward tokens to the StakingNFTs contract
    await rewardToken.transfer(stakingNFTsAddress, ethers.parseUnits("1000000", 18));
  });

  describe("Deployment", function () {
    it("should set the correct NFT and reward token addresses", async function () {

      expect(await stakingNFTs.nftToken()).to.equal(await nftToken.getAddress());
      expect(await stakingNFTs.rewardToken()).to.equal(await rewardToken.getAddress());
    });

    it("should set the correct rewards per block, unbonding period, and reward delay period", async function () {
      expect(await stakingNFTs.rewardsPerBlock()).to.equal(ethers.parseUnits("10", 18));
      expect(await stakingNFTs.unbondingPeriod()).to.equal(5);
      expect(await stakingNFTs.rewardDelayPeriod()).to.equal(10);
    });
  });

  describe("Staking", function () {
    it("should allow a user to stake NFTs", async function () {
      await nftToken.connect(staker1).approve(await stakingNFTs.getAddress(), 1);
      await stakingNFTs.connect(staker1).stakeNFTs([1]);

      expect(await nftToken.ownerOf(1)).to.equal(await stakingNFTs.getAddress());
      const stakedNFTs = await stakingNFTs.getStakedNFTs(await staker1.getAddress());

      expect(stakedNFTs[0]).to.equal(1);
    });

    it("should revert if a non-owner tries to stake an NFT", async function () {
      await nftToken.connect(staker1).approve(stakingNFTs.getAddress(), 1);
      await expect(stakingNFTs.connect(staker2).stakeNFTs([1])).to.be.revertedWith("You are not the owner of the NFT");
    });

    it("should revert if trying to stake an already staked NFT", async function () {
      await nftToken.connect(staker1).approve(await stakingNFTs.getAddress(), 1);
      await stakingNFTs.connect(staker1).stakeNFTs([1]);

      await expect(stakingNFTs.connect(staker1).stakeNFTs([1])).to.be.revertedWith("You have already staked this NFT");
    });
  });

  describe("Unstaking", function () {
    it("should allow a user to unstake NFTs", async function () {
      await nftToken.connect(staker1).approve(await stakingNFTs.getAddress(), 1);
      await stakingNFTs.connect(staker1).stakeNFTs([1]);

      await stakingNFTs.connect(staker1).unstakeNFTs([1]);
      expect(await stakingNFTs.connect(staker1).getNftUnbondingState(1)).to.be.true;
    });

    it("should revert if a non-owner tries to unstake an NFT", async function () {
      await nftToken.connect(staker1).approve(await stakingNFTs.getAddress(), 1);
      await stakingNFTs.connect(staker1).stakeNFTs([1]);

      await expect(stakingNFTs.connect(staker2).unstakeNFTs([1])).to.be.revertedWith("You're not owner of this NFT!");
    });
  });

  describe("Withdrawing", function () {
    it("should allow a user to withdraw NFTs after the unbonding period", async function () {
      await nftToken.connect(staker1).approve(await stakingNFTs.getAddress(), 1);
      await stakingNFTs.connect(staker1).stakeNFTs([1]);

      await stakingNFTs.connect(staker1).unstakeNFTs([1]);

      // Fast forward the blocks
      for (let i = 0; i < 5; i++) {
        await ethers.provider.send("evm_mine");
      }

      await stakingNFTs.connect(staker1).withdrawNFTs([1]);
      expect(await nftToken.ownerOf(1)).to.equal(await staker1.getAddress());
    });

    it("should revert if trying to withdraw before the unbonding period is over", async function () {
      await nftToken.connect(staker1).approve(await stakingNFTs.getAddress(), 1);
      await stakingNFTs.connect(staker1).stakeNFTs([1]);

      await stakingNFTs.connect(staker1).unstakeNFTs([1]);

      await expect(stakingNFTs.connect(staker1).withdrawNFTs([1])).to.be.revertedWith("You have not finished the unbonding period");
    });
  });

  describe("Claiming Rewards", function () {
    it("should allow a user to claim rewards", async function () {
      await nftToken.connect(staker1).approve(await stakingNFTs.getAddress(), 1);
      await stakingNFTs.connect(staker1).stakeNFTs([1]);

      // Fast forward the blocks
      for (let i = 0; i < 10; i++) {
        await ethers.provider.send("evm_mine");
      }

      await stakingNFTs.connect(staker1).claimRewards();
      const staker = await stakingNFTs.stakers(await staker1.getAddress());
      expect(await staker.rewardsToBeClaimed).to.equal(0);
    });

    it("should revert if trying to claim rewards before the reward delay period", async function () {
      await nftToken.connect(staker1).approve(await stakingNFTs.getAddress(), 1);
      await stakingNFTs.connect(staker1).stakeNFTs([1]);

      await ethers.provider.send("evm_mine");

      await stakingNFTs.connect(staker1).claimRewards();
      await expect(stakingNFTs.connect(staker1).claimRewards()).to.be.revertedWith("You have already claimed rewards");
    });
  });

  describe("Updating Rewards Per Block", function(){
    it("should allow owner to update rewards per block", async function () {
      const _newRewardsPerBlock = 10;
      await stakingNFTs.connect(deployer).updateRewardsPerBlock(_newRewardsPerBlock);
      expect(await stakingNFTs.rewardsPerBlock()).to.equal(_newRewardsPerBlock);

    })
  })
});
