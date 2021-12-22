// //SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./ERC2981ContractWideRoyalties.sol";
import "./IERC721Mutable.sol";
import "./Utils.sol";
import "./ERC721Tradable.sol";
import "hardhat/console.sol";

/**************                                                                                             
                                                                                                                                                                                                                                     




                                                                
                                ████████████████                                
                                ██            ██                                
                           ▐████████████████████████▌                           
                         ▐██                        ▐██                         
                       ██                              ██                       
                       ██                              ██                       
                       ██                              ██                       
                       ██       ████▌                  ██                       
                       ██       ████▌       ████▌      ██                       
                       ██                              ██                       
                       ██                              ██                       
                       ██          ██       ██         ██                       
                       ██            ███████           ██
                       ██                              ██                       
                         ▐██                        ▐██            
                            ▐███████████████████████▌                         
                                ██            ██
                  █████  ▐████████████████████████████▌  █████                
                ██     ██                              ██     ██  
              ██       ██                              ██       ██             
              ██       ██                              ██       ██            
           ▐██       ██                                  ██▌      ██▌           
                                                                                
     ▄▄▄▄▄   ▄▄▄  ▄▄▄▄    ▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄ ▄▄▄  ▄▄▄▄▄▄   ▄▄▄▄ ▄▄▄▄▄▄    ▄▄▄▄     
    █     █ █   █▀    █▄█▀   ▐█  █   █   █  ▀▄█▌     ██▀    █       ██▀    ▐█   
   █▌ ▀▀  ██  ▄█▌ ██▌  █   ████    ▄██      ▐██   ▀▀██   █  █  ▐██   ██  ▀▀█▄   
   █  ▀▀  █▌  ▀▀▌      ██     █▌     █   ██  █   ▀▀▀█▌  ▄▄  ██      █▌  ▀   █▌  
   ▀█▄▄▄▄█▀█▄▄▄█▀█▄▄▄██▀▀██▄▄█▀█▄██▄███▄█▀█▄▀▀█▄▄▄▄▄█▀██▀█▄███▄▄▄▄▄███▄▄▄▄██▀   
                                                                                





******************/

interface BlockheadsMinter {
    function buildBlockhead(
        address receiver,
        uint256 backgroundId,
        uint256 bodyId,
        uint256 armsId,
        uint256 headId,
        uint256 faceId,
        uint256 headwearId
    ) external;
}

/**
@title Blockheads Parts
@author Michael Feldstein
@notice NFT tokens representing individual blockheads parts.
A friend contract to Blockheads.sol which will allow this contract to mint full blockheads with the particular parts.
 */
contract BlockheadsParts is ERC721Tradable, ERC2981ContractWideRoyalties {
    BlockheadsMinter mainContract;

    constructor(address proxyRegistryAddress)
        ERC721Tradable("Blockhead Parts", "BKPT", proxyRegistryAddress)
    {}

    uint256 public nextTokenId = 1;

    /** Layer represents a single layer of a composition, ie background, head, face, etc  */
    struct Layer {
        // season is an index into the pack arrays above
        uint16 season;
        // Index of the represented item in the pack
        uint16 index;
    }

    function mintPart(
        address receiver,
        address packAddress,
        uint16 season,
        uint16 index,
        uint16 layerNumber
    ) external {
        _safeMint(receiver, nextTokenId);
        nextTokenId++;
    }

    function tokenURI(uint256 tokenId)
        public
        pure
        override
        returns (string memory)
    {
        bytes
            memory svg = "<svg xmlns='http://www.w3.org/2000/svg' preserveAspectRatio='xMinYMin meet' viewBox='0 0 25 25' width='500' height='500'>";
        svg = abi.encodePacked(svg, "Parts");
        svg = abi.encodePacked(svg, "</svg>");
        // Need to break up the json generation into 2 encodePackeds to avoid stack too deep errors
        bytes memory json = abi.encodePacked(
            '{"name": "Blockhead Part", "description": "Blockheads Parts", "image": "data:image/svg+xml;base64,',
            Utils.base64Encode(svg),
            '", "attributes": [{"trait_type": "Background", "value": "white"}]}'
        );
        return string(abi.encodePacked("data:application/json;base64,", json));
    }
}
