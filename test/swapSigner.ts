import { BigNumber } from "@ethersproject/bignumber";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

export type SwapData = {
    background: boolean;
    body: boolean;
    arms: boolean;
    head: boolean;
    face: boolean;
    headwear: boolean;
    nonce1: BigNumber;
    nonce2: BigNumber;
}

export async function createSwapSignature(
  signer: SignerWithAddress,
  contractAddress: string,
  tokenId: BigNumber,
  counterTokenId: BigNumber,
  swaps: SwapData
) {
  const chainId = await signer.getChainId();
  const domain = {
    name: "BlockheadsSwap",
    version: "1",
    chainId: chainId,
    verifyingContract: contractAddress,
  };
  const types = {
    Swap: [
        { name: "ownersToken", type: "uint256" },
        { name: "otherToken", type: "uint256"},
        { name: "background", type: "bool"},
        { name: "body", type: "bool"},
        { name: "arms", type: "bool"},
        { name: "head", type: "bool"},
        { name: "face", type: "bool"},
        { name: "headwear", type: "bool"},
        { name: "nonce1", type: "uint16"},
        { name: "nonce2", type: "uint16"},
    ],
  };

  const sig = await signer._signTypedData(domain, types, {
    ownersToken: tokenId,
    otherToken: counterTokenId,
    ...swaps
  });
  return sig
}
