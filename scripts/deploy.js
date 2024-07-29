
async function main(){
    const rewardsPerToken = ethers.parseUnits("10", 18);
    const unboundPeriod = 5;
    const rewardDelayPeriod = 5;
    const rewardTokensInitialSupply = ethers.parseUnits("1000000", 18);
    const NFTsInitialSupply = 1000;

    const [deployer] = await ethers.getSigners();
    console.log(`Deploying contracts with: ${await deployer.getAddress()}`);

    //Deploy ERC721 Mock contract to mint NFTs to stack in the staking contract

    const ERC721Mock = await ethers.getContractFactory("ERC721Mock");
    const nftToken = await ERC721Mock.deploy("NFTs", "NFT", NFTsInitialSupply, );
    await nftToken.waitForDeployment();

    const nftTokenAddress = await nftToken.getAddress();
    console.log(`The NFT Token contract is deployed to: ${nftTokenAddress}`);

    //Deploy ERC20 Mock contract to mint the reward tokens to distribute to the stakers

    const ERC20Mock = await ethers.getContractFactory("ERC20Mock");
    const rewardToken = await ERC20Mock.deploy("Reward Token", "RWT", rewardTokensInitialSupply);
    await rewardToken.waitForDeployment();
    const rewardTokenAddress = await rewardToken.getAddress();
    console.log(`The Reward Token is deployed to: ${rewardTokenAddress}`);

    //Deploy Staking token contract 
    const StakingNFTs = await ethers.getContractFactory("StakingNFTs");
    const stakingNFTs = await StakingNFTs.deploy(
        nftTokenAddress,
        rewardTokenAddress,
        rewardsPerToken,
        unboundPeriod,
        rewardDelayPeriod
    );

    await stakingNFTs.waitForDeployment();
    const stakingNFTsAddress = await stakingNFTs.getAddress();
    console.log(`Staking NFTs contract is deployed to: ${stakingNFTsAddress}`);
    console.log(`nftTokenAddress: ${await stakingNFTs.nftToken()}`);

    await rewardToken.transfer(stakingNFTsAddress, rewardTokensInitialSupply);
    console.log("Successfully transferred reward tokens to the Staking NFTs contract.");
}

    main()
    .then(()=> process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    })

