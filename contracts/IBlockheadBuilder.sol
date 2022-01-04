// //SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

interface IBlockheadBuilder {
    function buildBlockhead(
        address receiver,
        uint16[6] calldata partSeasons,
        uint16[6] calldata partIndexes
    ) external;
}
