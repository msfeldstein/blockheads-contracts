// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");
const { ethers } = hre;
async function main() {
  // OpenSea proxy registry addresses for rinkeby and mainnet.
  let proxyRegistryAddress = "";
  if (hre.network.name === "rinkeby") {
    proxyRegistryAddress = "0xf57b2c51ded3a29e6891aba85459d600256cf317";
  } else {
    proxyRegistryAddress = "0xa5409ec958c83c3f309868babaca7c86dcb077c1";
  }
  console.log("Deploying to ", hre.network.name);
  console.log("Using opensea registry address", proxyRegistryAddress);

  const Blockheads = await ethers.getContractFactory("BlockheadsToys");
  const blockheads = await Blockheads.deploy(proxyRegistryAddress);
  await blockheads.deployed();

  console.log("BlockheadsToys deployed to", blockheads.address);

  const BlockheadsParts = await ethers.getContractFactory("BlockheadsParts");
  const blockheadsParts = await BlockheadsParts.deploy(proxyRegistryAddress);
  await blockheadsParts.deployed();
  console.log("BlockheadsParts deployed to ", blockheadsParts.address);
  await blockheadsParts.registerFriendContract(blockheads.address);
  await blockheads.setPartMaker(blockheadsParts.address);
  await blockheadsParts.setMainContract(blockheads.address);

  const dataBlocks = ["Background", "Body", "Arms", "Head", "Face", "Headwear"];
  const dataBlockAddrs = [];
  for (var i = 0; i < dataBlocks.length; i++) {
    const blockName = dataBlocks[i];
    const DataBlockBuilder = await ethers.getContractFactory(
      blockName + "ImageData"
    );
    const dataBlock = await DataBlockBuilder.deploy();
    await dataBlock.deployed();
    dataBlockAddrs.push(dataBlock.address);
  }
  await blockheads.publishSeason(
    dataBlockAddrs[0],
    dataBlockAddrs[1],
    dataBlockAddrs[2],
    dataBlockAddrs[3],
    dataBlockAddrs[4],
    dataBlockAddrs[5]
  );

  if (hre.network.name === "rinkeby") {
    // for (var i = 0; i < 5; i++) {
    //   await blockheads.mint();
    // }
    // for (var i = 1; i < 3; i++) {
    //   await blockheads.separate(10000 + i);
    // }
  }

  await new Promise((resolve) => {
    setTimeout(resolve, 13000);
  });
  await hre.run("verify:verify", {
    address: blockheads.address,
    constructorArguments: [proxyRegistryAddress],
  });
  await hre.run("verify:verify", {
    address: blockheadsParts.address,
    constructorArguments: [proxyRegistryAddress],
  });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
