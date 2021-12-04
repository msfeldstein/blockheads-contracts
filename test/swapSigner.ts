import { BigNumber } from "@ethersproject/bignumber";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

// SwapData indicates the final desired outcome of a swap.  Put the new index
// you want for any layer, and your existing index for any existing layers.
// This will be used to ensure the final result of a swap is what you wanted.
export type SwapData = {
    background: number;
    body: number;
    arms: number;
    head: number;
    face: number;
    headwear: number;
    nonce: number;
}

export async function createSwapSignature(
  signer: SignerWithAddress,
  contractAddress: string,
  tokenId: BigNumber,
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
        { name: "tokenId", type: "uint256" },
        { name: "background", type: "uint32"},
        { name: "body", type: "uint32"},
        { name: "arms", type: "uint32"},
        { name: "head", type: "uint32"},
        { name: "face", type: "uint32"},
        { name: "headwear", type: "uint32"},
        { name: "nonce", type: "uint16"},
    ],
  };

  const sig = await signer._signTypedData(domain, types, {
    tokenId,
    ...swaps,
  });
  return sig
}
