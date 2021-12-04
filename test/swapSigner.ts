import { BigNumber } from "@ethersproject/bignumber";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

export async function createSwapSignature(
  signer: SignerWithAddress,
  contractAddress: string,
  tokenId: BigNumber,
  counterTokenId: BigNumber,
) {
  const chainId = await signer.getChainId();
  const domain = {
    name: "WhitelistToken",
    version: "1",
    chainId: chainId,
    verifyingContract: contractAddress,
  };

  const types = {
    Swap: [
        { name: "ownersToken", type: "uint256" },
        { name: "otherToken", type: "uint256"}
    ],
  };

  const sig = await signer._signTypedData(domain, types, {
    ownersToken: tokenId,
    otherToken: counterTokenId
  });
  return sig
}
