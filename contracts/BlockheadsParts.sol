// //SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

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

interface IBlockheadsToys {
    function buildBlockhead(
        address receiver,
        uint256 backgroundId,
        uint256 bodyId,
        uint256 armsId,
        uint256 headId,
        uint256 faceId,
        uint256 headwearId
    ) external;

    function getLayerLabel(
        uint16 season,
        uint16 index,
        uint16 layerIndex
    ) external view returns (string memory);

    function getLayerData(
        uint16 season,
        uint16 index,
        uint16 layerIndex
    ) external view returns (bytes memory);
}

/**
@title Blockheads Parts
@author Michael Feldstein
@notice NFT tokens representing individual blockheads parts.
A friend contract to Blockheads.sol which will allow this contract to mint full blockheads with the particular parts.
 */
contract BlockheadsParts is ERC721Tradable, ERC2981ContractWideRoyalties {
    IBlockheadsToys mainContract;
    mapping(address => bool) friendContracts;

    constructor(address proxyRegistryAddress)
        ERC721Tradable("Blockhead Parts", "BKPT", proxyRegistryAddress)
    {}

    uint256 private nextTokenId = 1;

    enum LayerIndex {
        BACKGROUND,
        BODY,
        ARMS,
        HEAD,
        FACE,
        HEADWEAR
    }

    /** Layer represents a single layer of a composition, ie background, head, face, etc  */
    struct Layer {
        // season is an index into the pack arrays above
        uint16 season;
        // Index of the represented item in the pack
        uint16 index;
        // The index of the layer on the toy (background=0, body = 1, arms = 2, head = 3, face = 4, headwear = 5
        LayerIndex layerIndex;
    }

    mapping(uint256 => Layer) tokenInfo;

    function registerFriendContract(address friend) external onlyOwner {
        friendContracts[friend] = true;
    }

    function unregisterFriendContract(address enemy) external onlyOwner {
        friendContracts[enemy] = false;
    }

    function setMainContract(address mainDeployment) external onlyOwner {
        mainContract = IBlockheadsToys(mainDeployment);
    }

    function build(uint256[6] calldata tokenIds) external {}

    function mintPart(
        address receiver,
        address, /* packAddress */
        uint16 season,
        uint16 index,
        uint16 layerNumber
    ) external {
        require(friendContracts[msg.sender]);
        _safeMint(receiver, nextTokenId);
        tokenInfo[nextTokenId] = Layer(season, index, LayerIndex(layerNumber));
        nextTokenId++;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        Layer memory layer = tokenInfo[tokenId];
        string memory label = mainContract.getLayerLabel(
            layer.season,
            layer.index,
            uint16(layer.layerIndex)
        );
        bytes memory svg = abi.encodePacked(
            "<svg xmlns='http://www.w3.org/2000/svg' preserveAspectRatio='xMinYMin meet' viewBox='0 0 25 25' width='500' height='500'>",
            mainContract.getLayerData(
                layer.season,
                layer.index,
                uint16(layer.layerIndex)
            ),
            "</svg>"
        );

        // Need to break up the json generation into 2 encodePackeds to avoid stack too deep errors
        bytes memory json = abi.encodePacked(
            '{"name": "Blockhead Part", "description": "Blockheads Parts", "image": "data:image/svg+xml;base64,',
            Utils.base64Encode(svg),
            '", "attributes": [{"trait_type": "Piece", "value": "',
            label,
            '"}]}'
        );
        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Utils.base64Encode(json)
                )
            );
    }
}
