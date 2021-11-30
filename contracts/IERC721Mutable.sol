//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

/// @notice IERC721Mutable is a standard for managing ERC721 tokens with mutable metadata
///         It is useful for both keeping metadata updated in indexed marketplaces as well as 
///         preventing malicious sellers from accepting offers placed before changing the metadata.
/// @title IERC721Mutable
/// @dev Interface for the ERC721Mutable - Mutable Token Metadata standard
interface IERC721Mutable {
    /// @notice Returns a hash of the relevent metadata characteristics that should be taken into account for considering if an NFT has changed.
    ///         Marketplaces should expire offers if the metadata has changed after the offer was placed.
    /// @param _tokenId - the NFT asset queried
    /// @return _metadataHash - the royalty payment amount for value sale price
    /// @return _timeToLive - The amount of time the metadata is expected to be valid for, in seconds.  Return 0 for an infinite TTL if the metadata isn't time based, and only changes via external action.
    function tokenMetadataHash(uint256 _tokenId)
        external
        view
        returns (uint256 _metadataHash, uint256 _timeToLive);

    event TokenMetadataChanged(uint256 indexed _tokenId, uint256 _metadataHash, uint256 _timeToLive);
}
