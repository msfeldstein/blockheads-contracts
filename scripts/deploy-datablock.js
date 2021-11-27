// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");
const { ethers } = hre;
async function main() {
  console.log("Deploying to ", hre.network.name);
  const blockName = "Headwear";
  console.log("Deploying ", blockName);
  const DataBlockBuilder = await ethers.getContractFactory(
    blockName + "ImageData"
  );
  const dataBlock = await DataBlockBuilder.deploy();
  console.log("Deployment created, awaiting deployed", dataBlock.deployTransaction)
  await dataBlock.deployTransaction.wait();
  console.log(`Deployed ${blockName}ImageData to ${dataBlock.address}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
