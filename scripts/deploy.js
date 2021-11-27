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
  if (hre.network.name === 'rinkeby') {
    proxyRegistryAddress = "0xf57b2c51ded3a29e6891aba85459d600256cf317";
  } else {
    proxyRegistryAddress = "0xa5409ec958c83c3f309868babaca7c86dcb077c1";
  }
  console.log("Deploying to ", hre.network.name)
  console.log("Using opensea registry address", proxyRegistryAddress)
  
  const dataBlocks = ["Background", "Body", "Arms", "Head", "Face", "Headwear"]
  const dataBlockAddrs = []
  for (var i = 0; i < dataBlocks.length; i++) {
    const blockName = dataBlocks[i]
    console.log("Deploying ", blockName)
    const DataBlockBuilder = await ethers.getContractFactory(blockName + "ImageData")
    const dataBlock = await DataBlockBuilder.deploy()
    await dataBlock.deployed()
    dataBlockAddrs.push(dataBlock.address)
    console.log(`Deployed ${blockName}ImageData to ${dataBlock.address}`)
  }

  const Blockheads = await ethers.getContractFactory("Blockheads", {});
  const blockheads = await Blockheads.deploy(proxyRegistryAddress, ...dataBlockAddrs);

  await blockheads.deployed();
  
  console.log("Blockheads deployed to:", blockheads.address);
  await blockheads.setMintingEnabled(true);
  
  if (hre.network.name === "ropsten" || hre.network.name === "rinkeby") {
    await new Promise((resolve) => {
      setTimeout(resolve, 33000);
    });
    await hre.run("verify:verify", {
      address: blockheads.address,
      constructorArguments: [proxyRegistryAddress, ...dataBlockAddrs]
    });
  }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
