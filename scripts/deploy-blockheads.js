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

  const Background = "0x0DF20d6d4A0A93889DeC0A311Ef13DcDFdb40Aa7";
  const Body = "0xa22b1896479dBA6b408e5D2d1E3308be14f8aDA3";
  const Arms = "0xdbA5943a3F519DbD8bE0f19A6F3abbc39d6E3295";
  const Head = "0x1B49C7632Ca16718596D3A196B49e1c075eD8857";
  const Face = "0x8Fc90ccddEca450D763AFd8a249c8Fdb443c9f1c";
  const Headwear = "0xD3eB8dFe56ae43D8D18F429208fe9521e72886d6";
  const dataBlockAddrs = [Background, Body, Arms, Head, Face, Headwear];
  const Blockheads = await ethers.getContractFactory("Blockheads", {});
  const blockheads = await Blockheads.deploy(
    proxyRegistryAddress,
    ...dataBlockAddrs
  );

  await blockheads.deployed();

  console.log("Blockheads deployed to:", blockheads.address);
  await blockheads.setMintingEnabled(true);

  if (hre.network.name === "mainnet" || hre.network.name === "rinkeby") {
    await new Promise((resolve) => {
      setTimeout(resolve, 33000);
    });
    await hre.run("verify:verify", {
      address: blockheads.address,
      constructorArguments: [proxyRegistryAddress, ...dataBlockAddrs],
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
