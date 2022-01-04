import chai, { expect } from "chai";
import { ethers } from "hardhat";
import { BlockheadsToys, BlockheadsParts } from "../typechain";
import { solidity } from "ethereum-waffle";

chai.use(solidity);

import isSvg from "is-svg";

describe("Blockheads", function () {
  let blockheads: BlockheadsToys;
  let blockheadsParts: BlockheadsParts;

  beforeEach(async function () {
    // Opensea's Rinkeby address, this shouldn't matter though
    let proxyRegistryAddress = "0xf57b2c51ded3a29e6891aba85459d600256cf317";

    const Blockheads = await ethers.getContractFactory("BlockheadsToys");
    blockheads = await Blockheads.deploy(proxyRegistryAddress);
    await blockheads.deployed();

    const BlockheadsParts = await ethers.getContractFactory("BlockheadsParts");
    blockheadsParts = await BlockheadsParts.deploy(proxyRegistryAddress);
    await blockheadsParts.deployed();
    // @ts-ignore
    await blockheadsParts.registerFriendContract(blockheads.address);
    // @ts-ignore
    await blockheads.setPartMaker(blockheadsParts.address);
    // @ts-ignore
    await blockheadsParts.setMainContract(blockheads.address);

    const dataBlocks = [
      "Background",
      "Body",
      "Arms",
      "Head",
      "Face",
      "Headwear",
    ];
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
  });

  it("should return valid metadata", async function () {
    const metadata = await blockheads.tokenURI(1);

    const json = JSON.parse(
      Buffer.from(metadata.split(",")[1], "base64").toString()
    );
    expect(json).to.have.property("image");
    expect(json).to.have.property("name");
    expect(json).to.have.property("attributes");
    console.log(json.attributes);
    console.log(Buffer.from(json.image.split(",")[1], "base64").toString());

    // todo test that the image is valid svg
    const svg = Buffer.from(json.image.split(",")[1], "base64").toString();
    expect(isSvg(svg)).to.be.true;
  });

  it("Should allow minting", async function () {
    const accounts = await ethers.getSigners();
    const mainAccount = accounts[0];
    await blockheads.mint({ value: ethers.utils.parseEther("0.05") });
    let balance = await blockheads.balanceOf(mainAccount.address);
    expect(balance).to.equal(1);
    await blockheads.mint({ value: ethers.utils.parseEther("0.05") });
    balance = await blockheads.balanceOf(mainAccount.address);
    expect(balance).to.equal(2);
  });

  it("Shouldn't allow non owners to change name", async function () {
    const accounts = await ethers.getSigners();
    const mainAccount = accounts[0];
    const otherAccount = accounts[2];
    await blockheads.mint({ value: ethers.utils.parseEther("0.12") });
    const token = await blockheads.tokenOfOwnerByIndex(mainAccount.address, 0);
    await expect(blockheads.connect(otherAccount).setName(token, "Bad")).to.be
      .reverted;
  });

  it("Should allow owners to change name", async function () {
    const accounts = await ethers.getSigners();
    const mainAccount = accounts[0];
    await blockheads.mint({ value: ethers.utils.parseEther("0.12") });
    console.log("SHOULD ALLOW?");
    const token = await blockheads.tokenOfOwnerByIndex(mainAccount.address, 0);
    console.log("Token", token);
    await blockheads.setName(token, "Good");
    const metadata = await blockheads.tokenURI(token);
    const json = JSON.parse(
      Buffer.from(metadata.split(",")[1], "base64").toString()
    );
    expect(json.name).to.equal("Good");
  });

  it("Shouldn't allow duplicate names", async function () {
    const accounts = await ethers.getSigners();
    const mainAccount = accounts[0];
    await blockheads.mint({ value: ethers.utils.parseEther("0.12") });
    await blockheads.mint({ value: ethers.utils.parseEther("0.12") });
    const token = await blockheads.tokenOfOwnerByIndex(mainAccount.address, 0);
    const token2 = await blockheads.tokenOfOwnerByIndex(mainAccount.address, 1);
    await blockheads.setName(token, "Good");
    const metadata = await blockheads.tokenURI(token);
    const json = JSON.parse(
      Buffer.from(metadata.split(",")[1], "base64").toString()
    );
    expect(json.name).to.equal("Good");
    await expect(blockheads.setName(token2, "Good")).to.be.reverted;
    await blockheads.setName(token, "Something else");
    await blockheads.setName(token2, "Good");
    const metadata2 = await blockheads.tokenURI(token2);
    const json2 = JSON.parse(
      Buffer.from(metadata2.split(",")[1], "base64").toString()
    );
    expect(json2.name).to.equal("Good");
  });

  it("Can be withdrawn by owning account", async function () {
    const accounts = await ethers.getSigners();
    const mainAccount = accounts[0];
    await blockheads.connect(mainAccount).withdraw();
  });

  it("Can't be withdrawn by random account", async function () {
    const accounts = await ethers.getSigners();
    const otherAccount = accounts[1];
    await expect(blockheads.connect(otherAccount).withdraw()).to.be.reverted;
  });

  describe("Separation", async function () {
    it("Should be broken aparty into pieces and recombined", async function () {
      const accounts = await ethers.getSigners();
      const mainAccount = accounts[0];
      await blockheads.mint({ value: ethers.utils.parseEther("0.12") });
      let tokenId = await blockheads.tokenOfOwnerByIndex(
        mainAccount.address,
        0
      );
      await blockheads.separate(tokenId);
      const partBalance = await blockheadsParts.balanceOf(mainAccount.address);
      expect(partBalance).to.equal(6);
      const partIDs = [];
      for (let i = 0; i < 6; i++) {
        partIDs.push(
          await blockheadsParts.tokenOfOwnerByIndex(mainAccount.address, i)
        );
      }
      const metadata = await blockheadsParts.tokenURI(2);
      const json = JSON.parse(
        Buffer.from(metadata.split(",")[1], "base64").toString()
      );
      await expect(blockheads.tokenURI(tokenId)).to.be.reverted;
      await blockheadsParts.buildBlockhead(partIDs as any);
      tokenId = await blockheads.tokenOfOwnerByIndex(mainAccount.address, 0);
    });
  });
  // Test royalties

  // test withdraw
});
