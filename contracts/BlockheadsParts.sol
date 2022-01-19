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
import "./IBlockheadBuilder.sol";

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

interface IBlockheadsToys is IBlockheadBuilder {
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

    function buildBlockhead(address receiver, uint16[12] calldata partValues)
        external;
}

/**
@title Blockheads Parts
@author Michael Feldstein
@notice NFT tokens representing individual blockheads parts.
A friend contract to Blockheads.sol which will allow this contract to mint full blockheads with the particular parts.
 */
contract BlockheadsParts is ERC721Tradable, ERC2981ContractWideRoyalties {
    IBlockheadsToys public mainContract;
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
        uint16 layerIndex;
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

    function mintPart(
        address receiver,
        address, /* packAddress */
        uint16 season,
        uint16 index,
        uint16 layerNumber
    ) external {
        require(friendContracts[msg.sender]);
        _safeMint(receiver, nextTokenId);
        tokenInfo[nextTokenId] = Layer(season, index, layerNumber);
        nextTokenId++;
    }

    function buildBlockhead(uint256[6] calldata partTokens) external {
        uint16[6] memory seasons;
        uint16[6] memory indices;
        for (uint256 i = 0; i < 6; i++) {
            uint256 partToken = partTokens[i];
            require(ownerOf(partToken) == msg.sender);
            require(tokenInfo[partToken].layerIndex == i);
            seasons[i] = tokenInfo[partToken].season;
            indices[i] = tokenInfo[partToken].index;
        }

        mainContract.buildBlockhead(msg.sender, seasons, indices);
    }

    function layerSVG(uint256 tokenId) external view returns (string memory) {
        Layer memory layer = tokenInfo[tokenId];
        return
            string(
                mainContract.getLayerData(
                    layer.season,
                    layer.index,
                    uint16(layer.layerIndex)
                )
            );
    }

    function _layerSVG(uint256 tokenId) internal view returns (bytes memory) {
        Layer memory layer = tokenInfo[tokenId];
        bytes
            memory svg = "<svg xmlns='http://www.w3.org/2000/svg' preserveAspectRatio='xMinYMin meet' viewBox='0 0 25 25' width='500' height='500'>";
        string
            memory placeholder = "<path fill-rule='evenodd' clip-rule='evenodd' style='mix-blend-mode: multiply;' d='M15 5H10V6H15V5ZM18 7V8H19V17H18V18H14V19H16V20H14H11H9V19H11V18H7V17H6V8H7V7H18ZM19 21V24H20V25H5V24H6V21H19ZM20 24V21H22V22H23V24H24V25H21V24H20ZM5 21V24H4V25H1V24H2V22H3V21H5Z' fill='#E5E5E5'/>"
            "<path fill-rule='evenodd' clip-rule='evenodd' style='mix-blend-mode: multiply;' d='M18 7V6H16V4H9V6H7V7H6V8H5V17H6V18H7V19H8V20H6V21H5V20H3V21H2V22H1V24H0V25H1V24H2V22H3V21H5V24H4V25H5V24H6V21H19V24H20V25H21V24H20V21H22V22H23V24H24V25H25V24H24V22H23V21H22V20H20V21H19V20H17V19H18V18H19V17H20V8H19V7H18ZM18 7V8H19V17H18V18H7V17H6V8H7V7H18ZM16 20V19H9V20H11H14H16ZM10 5H15V6H10V5Z' fill='#C1C1C1'/>";
        string memory svgEnd = "</svg>";
        if (uint16(layer.layerIndex) == 0) {
            svg = abi.encodePacked(
                svg,
                "<g id='content'>",
                mainContract.getLayerData(
                    layer.season,
                    layer.index,
                    uint16(layer.layerIndex)
                ),
                "</g>",
                placeholder,
                svgEnd
            );
        } else {
            svg = abi.encodePacked(
                svg,
                placeholder,
                "<g id='content'>",
                mainContract.getLayerData(
                    layer.season,
                    layer.index,
                    uint16(layer.layerIndex)
                ),
                "</g>",
                svgEnd
            );
        }
        return svg;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        bytes memory svg = _layerSVG(tokenId);

        Layer memory layer = tokenInfo[tokenId];
        string memory label = mainContract.getLayerLabel(
            layer.season,
            layer.index,
            uint16(layer.layerIndex)
        );

        string[6] memory LAYER_NAMES = [
            "Background",
            "Body",
            "Arms",
            "Head",
            "Face",
            "Headwear"
        ];

        // Need to break up the json generation into 2 encodePackeds to avoid stack too deep errors
        bytes memory json = abi.encodePacked(
            '{"name": "Blockhead Part", "description": "Blockheads Parts", "image": "data:image/svg+xml;base64,',
            Utils.base64Encode(svg),
            '", "attributes": [{"trait_type": "Piece", "value": "',
            label,
            '"}, {"trait_type": "Layer", "value": "',
            LAYER_NAMES[layer.layerIndex],
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
