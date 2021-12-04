const { expect } = require("chai");
const { ethers } = require("hardhat");
import { BigNumber } from "@ethersproject/bignumber";
import { Contract } from "@ethersproject/contracts";
import { expectRevert } from "@openzeppelin/test-helpers";
import isSvg from "is-svg";
import { createSwapSignature } from "./swapSigner";

describe("Blockheads", function () {
  let blockheads: Contract;

  beforeEach(async function () {
    // Opensea's Rinkeby address, this shouldn't matter though
    let proxyRegistryAddress = "0xf57b2c51ded3a29e6891aba85459d600256cf317";

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

    const Blockheads = await ethers.getContractFactory("Blockheads");
    blockheads = await Blockheads.deploy(
      proxyRegistryAddress,
      ...dataBlockAddrs
    );
    await blockheads.deployed();
    await blockheads.setMintingEnabled(true);
    await blockheads.setCurrentlyAvailable(100);
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

  it("Should buy 4 get 1 free", async function () {
    const accounts = await ethers.getSigners();
    const mainAccount = accounts[0];
    const mintCost = await blockheads.mintCost();
    const mintPackCost = mintCost.mul(4);
    await blockheads.buy4get1free({ value: mintPackCost });
    const numOwned = await blockheads.balanceOf(mainAccount.address);
    expect(numOwned).to.equal(5);
  });

  it("Should allow minting up to the limit", async function() {
    const accounts = await ethers.getSigners();
    const mainAccount = accounts[0];
    const nextTokenId = await blockheads.nextTokenId()
    await blockheads.setCurrentlyAvailable(nextTokenId.toNumber() + 2);
    await blockheads.mint({ value: ethers.utils.parseEther("0.05") });
    let balance = await blockheads.balanceOf(mainAccount.address)
    expect(balance).to.equal(1)
    await blockheads.mint({ value: ethers.utils.parseEther("0.05") });
    balance = await blockheads.balanceOf(mainAccount.address)
    expect(balance).to.equal(2)
  })

  it ("Shouldn't allow minting past the limit", async function() {
    const accounts = await ethers.getSigners();
    const mainAccount = accounts[0];
    const nextTokenId = await blockheads.nextTokenId()
    await blockheads.setCurrentlyAvailable(nextTokenId.toNumber() + 1);
    await blockheads.mint({ value: ethers.utils.parseEther("0.05") });
    let balance = await blockheads.balanceOf(mainAccount.address)
    expect(balance).to.equal(1)
    await blockheads.mint({ value: ethers.utils.parseEther("0.05") });
    balance = await blockheads.balanceOf(mainAccount.address)
    expect(balance).to.equal(2)
  })

  it("Shouldn't allow non owners to change name", async function () {
    const accounts = await ethers.getSigners();
    const mainAccount = accounts[0];
    const otherAccount = accounts[2];
    await blockheads.mint({ value: ethers.utils.parseEther("0.12") });
    const token = await blockheads.tokenOfOwnerByIndex(mainAccount.address, 0);
    await expectRevert.unspecified(
      blockheads.connect(otherAccount).setName(token, "Bad")
    );
  });

  it("Should allow owners to change name", async function () {
    const accounts = await ethers.getSigners();
    const mainAccount = accounts[0];
    await blockheads.mint({ value: ethers.utils.parseEther("0.12") });
    const token = await blockheads.tokenOfOwnerByIndex(mainAccount.address, 0);
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
    await expectRevert.unspecified(blockheads.setName(token2, "Good"));
    await blockheads.setName(token, "Something else");
    await blockheads.setName(token2, "Good");
    const metadata2 = await blockheads.tokenURI(token2);
    const json2 = JSON.parse(
      Buffer.from(metadata2.split(",")[1], "base64").toString()
    );
    expect(json2.name).to.equal("Good");
  });

  it("Should allow batched part swapping", async function () {
    const accounts = await ethers.getSigners();
    const mainAccount = accounts[0];
    await blockheads.mint({ value: ethers.utils.parseEther("0.12") });
    await blockheads.mint({ value: ethers.utils.parseEther("0.12") });
    for (var i = 0; i < 10; i++) {
      const token1 = await blockheads.tokenOfOwnerByIndex(
        mainAccount.address,
        0
      );
      const token2 = await blockheads.tokenOfOwnerByIndex(
        mainAccount.address,
        1
      );
      let token1HeadBefore = await blockheads.headIndex(token1);
      let token2HeadBefore = await blockheads.headIndex(token2);
      await blockheads.swapParts(
        token1,
        token2,
        false,
        false,
        false,
        true,
        false,
        false
      );
      let token1HeadAfter = await blockheads.headIndex(token1);
      let token2HeadAfter = await blockheads.headIndex(token2);
      expect(token1HeadAfter).to.equal(token2HeadBefore);
      expect(token2HeadAfter).to.equal(token1HeadBefore);
    }
  });

  it("Should allow swapping parts with another user via signature", async function() {
    const accounts = await ethers.getSigners();
    const mainAccount = accounts[0];
    const otherAccount = accounts[1]
    await blockheads.mint({ value: ethers.utils.parseEther("0.12") });
    await blockheads.connect(otherAccount).mint({ value: ethers.utils.parseEther("0.12") });
    const token1 = await blockheads.tokenOfOwnerByIndex(
      mainAccount.address,
      0
    );
    // Bump the nonce here so the nonces are different and we actually test that, rather than
    // them both being 0 and not being tested
    await blockheads.bumpNonce(token1)
    const token2 = await blockheads.tokenOfOwnerByIndex(
      otherAccount.address,
      0
    );
    const token2Values = await blockheads.layerValues(token2)
    const token1BodyBefore = await blockheads.bodyIndex(token1);
    const token2BodyBefore = await blockheads.bodyIndex(token2);
    // Create a swap signature representing the final state where `otherAccount` requests
    // the body index of token 1.
    const desiredState = {
      background: token2Values.background,
      body: token1BodyBefore, // Take the body value from token1
      head: token2Values.head,
      arms: token2Values.arms,
      face: token2Values.face,
      headwear: token2Values.headwear,
      nonce: token2Values.nonce + 1, // Since the signature should be for the final state, we need to use the incremented nonce
    };
    const signature = await createSwapSignature(otherAccount, blockheads.address, token2, desiredState)
    await blockheads.swapPartsCrossUser(
      token1,
      token2,
      signature,
      false,
      true,
      false,
      false,
      false,
      false
    );
    let token1BodyAfter = await blockheads.bodyIndex(token1);
    let token2BodyAfter = await blockheads.bodyIndex(token2);
    expect(token1BodyAfter).to.equal(token2BodyBefore);
    expect(token2BodyAfter).to.equal(token1BodyBefore);
  })

  it("Can't use the same signature twice", async function() {
    const accounts = await ethers.getSigners();
    const mainAccount = accounts[0];
    const otherAccount = accounts[1]
    await blockheads.mint({ value: ethers.utils.parseEther("0.12") });
    await blockheads.connect(otherAccount).mint({ value: ethers.utils.parseEther("0.12") });
    const token1 = await blockheads.tokenOfOwnerByIndex(
      mainAccount.address,
      0
    );
    // Bump the nonce here so the nonces are different and we actually test that, rather than
    // them both being 0 and not being tested
    await blockheads.bumpNonce(token1)
    const token2 = await blockheads.tokenOfOwnerByIndex(
      otherAccount.address,
      0
    );
    const token2Values = await blockheads.layerValues(token2)
    const token1BodyBefore = await blockheads.bodyIndex(token1);
    // Create a swap signature representing the final state where `otherAccount` requests
    // the body index of token 1.
    const signature = await createSwapSignature(otherAccount, blockheads.address, token2, {
      background: token2Values.background,
      body: token1BodyBefore, // Take the body value from token1
      head: token2Values.head,
      arms: token2Values.arms,
      face: token2Values.face,
      headwear: token2Values.headwear,
      nonce: token2Values.nonce + 1, // Since the signature should be for the final state, we need to use the incremented nonce,
    })
    await blockheads.swapPartsCrossUser(
      token1,
      token2,
      signature,
      false,
      true,
      false,
      false,
      false,
      false
    );
    await expectRevert.unspecified(blockheads.swapPartsCrossUser(
      token1,
      token2,
      signature,
      false,
      true,
      false,
      false,
      false,
      false
    ));
  })

  it("Should not allow swapping different parts than signature signed for", async function() {
    const accounts = await ethers.getSigners();
    const mainAccount = accounts[0];
    const otherAccount = accounts[1]
    await blockheads.mint({ value: ethers.utils.parseEther("0.12") });
    await blockheads.connect(otherAccount).mint({ value: ethers.utils.parseEther("0.12") });
    const token1 = await blockheads.tokenOfOwnerByIndex(
      mainAccount.address,
      0
    );
    // Bump the nonce here so the nonces are different and we actually test that, rather than
    // them both being 0 and not being tested
    await blockheads.bumpNonce(token1)
    const token2 = await blockheads.tokenOfOwnerByIndex(
      otherAccount.address,
      0
    );
    const token2Values = await blockheads.layerValues(token2)
    let token1HeadBefore = await blockheads.headIndex(token1);
    let token1BodyBefore = await blockheads.bodyIndex(token2);
    // Signature signs to swap body but below we'll swap head too, and that should be rejected
    const desiredState = {
      background: token2Values.background,
      body: token1BodyBefore, // Take the body value from token1
      head: token1HeadBefore,
      arms: token2Values.arms,
      face: token2Values.face,
      headwear: token2Values.headwear,
      nonce: token2Values.nonce,
    }
    const signature = await createSwapSignature(otherAccount, blockheads.address, token2, desiredState)
    await expectRevert.unspecified(blockheads.swapPartsCrossUser(
      token1,
      token2,
      signature,
      false,
      true,
      true,
      false,
      false,
      false
    ));
  })

  it("Should allow swapping parts between two owned tokens", async function () {
    const accounts = await ethers.getSigners();
    const mainAccount = accounts[0];
    // This list needs to match the order of booleans in swapParts
    const getFunctions = [
      "backgroundIndex",
      "bodyIndex",
      "armsIndex",
      "headIndex",
      "faceIndex",
      "headwearIndex",
    ];

    for (var i = 0; i < getFunctions.length; i++) {
      const getFn = getFunctions[i];
      let swapArgs = [false, false, false, false, false, false];
      swapArgs[i] = true;

      await blockheads.mint({ value: ethers.utils.parseEther("0.12") });
      await blockheads.mint({ value: ethers.utils.parseEther("0.12") });
      const token1 = await blockheads.tokenOfOwnerByIndex(
        mainAccount.address,
        i * 2
      );
      const token2 = await blockheads.tokenOfOwnerByIndex(
        mainAccount.address,
        i * 2 + 1
      );
      let token1Before = await blockheads[getFn](token1);
      let token2Before = await blockheads[getFn](token2);
      const bodyBefore = await blockheads.bodyIndex(token1);
      await blockheads.swapParts(token1, token2, ...swapArgs);
      let token1After = await blockheads[getFn](token1);
      let token2After = await blockheads[getFn](token2);
      const bodyAfter = await blockheads.bodyIndex(token1);
      expect(token1After).to.equal(token2Before);
      expect(token2After).to.equal(token1Before);
      // Ensure body hasn't changed (as long as its not us trying to change the body)
      if (i != 1) {
        expect(bodyBefore).to.equal(bodyAfter);
      }
      // Run it again to see if you can swap back from already overriden ones
      token1Before = await blockheads[getFn](token1);
      token2Before = await blockheads[getFn](token2);
      await blockheads.swapParts(token1, token2, ...swapArgs);
      token1After = await blockheads[getFn](token1);
      token2After = await blockheads[getFn](token2);
      expect(token1After).to.equal(token2Before);
      expect(token2After).to.equal(token1Before);
    }
  });

  it("Shouldn't allow swapping parts if you don't own the other token", async function () {
    const accounts = await ethers.getSigners();
    const mainAccount = accounts[0];
    const otherAccount = accounts[1];
    await blockheads.mint({ value: ethers.utils.parseEther("0.12") });
    await blockheads
      .connect(otherAccount)
      .mint({ value: ethers.utils.parseEther("0.12") });
    const token1 = await blockheads.tokenOfOwnerByIndex(mainAccount.address, 0);
    const token2 = await blockheads.tokenOfOwnerByIndex(
      otherAccount.address,
      0
    );
    const token1HeadBefore = await blockheads.headIndex(token1);
    const token2HeadBefore = await blockheads.headIndex(token2);
    await expectRevert.unspecified(
      blockheads.swapParts(
        token1,
        token2,
        false,
        false,
        false,
        true,
        false,
        false
      )
    );
    const token1HeadAfter = await blockheads.headIndex(token1);
    const token2HeadAfter = await blockheads.headIndex(token2);
    expect(token1HeadAfter).to.equal(token1HeadBefore);
    expect(token2HeadAfter).to.equal(token2HeadBefore);
  });

  it("Should emit an event and change metadata hash on swap", async function () {
    const accounts = await ethers.getSigners();
    const mainAccount = accounts[0];
    await blockheads.mint({ value: ethers.utils.parseEther("0.12") });
    await blockheads.mint({ value: ethers.utils.parseEther("0.12") });
    const token1 = await blockheads.tokenOfOwnerByIndex(mainAccount.address, 0);
    const token2 = await blockheads.tokenOfOwnerByIndex(
      mainAccount.address,
      1
    );
    const [token1MetadataHashBefore] = await blockheads.tokenMetadataHash(token1);
    await 
      expect(blockheads.swapParts(
        token1,
        token2,
        false,
        true,
        false,
        true,
        false,
        false
    )).to.emit(blockheads, "TokenMetadataChanged");
    const [token1MetadataHashAfter] = await blockheads.tokenMetadataHash(token1);
    expect(token1MetadataHashAfter).not.to.equal(token1MetadataHashBefore)
  });

  it("Can be withdrawn by owning account", async function () {
    const accounts = await ethers.getSigners();
    const mainAccount = accounts[0];
    await blockheads.withdraw();
  });

  it("Can't be withdrawn by random account", async function () {
    const accounts = await ethers.getSigners();
    const otherAccount = accounts[1];
    expectRevert.unspecified(blockheads.connect(otherAccount).withdraw());
  });

  it("Should be mint in box before any changes and not afterward", async function() {
    const accounts = await ethers.getSigners();
    const mainAccount = accounts[0];
    await blockheads.mint({ value: ethers.utils.parseEther("0.12") });
    await blockheads.mint({ value: ethers.utils.parseEther("0.12") });
    const token1 = await blockheads.tokenOfOwnerByIndex(
      mainAccount.address,
      0
    );
    const token2 = await blockheads.tokenOfOwnerByIndex(
      mainAccount.address,
      1
    );
    expect(await blockheads.isMintInBox(token1)).to.be.true
    expect(await blockheads.isMintInBox(token2)).to.be.true

    await blockheads.swapParts(token1, token2, true, false, false, false, false, false);
    expect(await blockheads.isMintInBox(token1)).to.be.false
    expect(await blockheads.isMintInBox(token2)).to.be.false
  })

  // Test royalties

  // test withdraw
});
