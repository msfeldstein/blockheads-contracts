// //SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

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

// Interface that all the data blocks exported from figma fulfill
interface ImageDataBlock {
    // Provide a renderable SVG string at the given slot
    function getData(uint256 slot) external pure returns (bytes memory);

    // Provide a human readable name at the given slot
    function getLabel(uint256 slot) external pure returns (string memory);
}

interface PartMaker {
    function mintPart(
        address receiver,
        address packAddress,
        uint16 season,
        uint16 index,
        uint16 layerNumber
    ) external;
}

contract BlockheadsToys is
    ERC721Tradable,
    ERC2981ContractWideRoyalties,
    IERC721Mutable,
    ReentrancyGuard
{
    enum LayerIndex {
        BACKGROUND,
        BODY,
        ARMS,
        HEAD,
        FACE,
        HEADWEAR
    }

    uint256 constant LAYER_COUNT = 6;

    // Packs are the ImageDataBlocks for each of the layers indexed above
    address[][LAYER_COUNT] packs;

    /** Layer represents a single layer of a composition, ie background, head, face, etc  */
    struct Layer {
        // season is an index into the pack arrays above
        uint16 season;
        // Index of the represented item in the pack
        uint16 index;
    }

    struct Blockhead {
        Layer[7] layers;
        string name;
        bool opened;
    }
    mapping(uint256 => Blockhead) blockheads;

    // Birth registry is a mapping of taken names so each blockhead has a unique name.
    mapping(string => bool) birthRegistry;

    uint256 public nextTokenId = 10000;
    PartMaker partMaker;

    // Constructor requires the proxy for opensea, and all the data blocks
    constructor(address proxyRegistryAddress)
        ERC721Tradable("Blockheads World", "BLOK", proxyRegistryAddress)
    {
        // 5% royalties for ERC2981.  Not sure if anyone supports this yet.
        _setRoyalties(msg.sender, 500);
    }

    function setPartMaker(address partMakerAddress) external onlyOwner {
        partMaker = PartMaker(partMakerAddress);
    }

    function mint() external payable {
        blockheads[nextTokenId].name = "Blockhead";
        blockheads[nextTokenId].layers[0] = Layer(0, 2);
        blockheads[nextTokenId].layers[1] = Layer(0, 3);
        blockheads[nextTokenId].layers[2] = Layer(0, 4);
        blockheads[nextTokenId].layers[3] = Layer(0, 5);
        blockheads[nextTokenId].layers[4] = Layer(0, 6);
        blockheads[nextTokenId].layers[5] = Layer(0, 17);

        _safeMint(msg.sender, nextTokenId);

        nextTokenId++;
    }

    function separate(uint256 tokenId) external nonReentrant {
        require(ownerOf(tokenId) == msg.sender);
        Blockhead memory blockhead = blockheads[tokenId];
        for (uint16 i = 0; i < 6; i++) {
            Layer memory l = blockhead.layers[i];
            partMaker.mintPart(
                msg.sender,
                packs[i][l.season],
                l.season,
                l.index,
                i
            );
        }

        _burn(tokenId);
    }

    // Withdraw balance to the owners
    function withdraw() public onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    function withdrawToContract() external onlyOwner {
        // This forwards all available gas. Be sure to check the return value!
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "Transfer failed.");
    }

    function random(bytes memory input) internal pure returns (uint256) {
        return uint256(keccak256(input));
    }

    modifier ownsBoth(uint256 token1, uint256 token2) {
        require(ownerOf(token1) == msg.sender);
        require(ownerOf(token2) == msg.sender);
        _;
    }

    error NameTaken(string name);

    function setName(uint256 tokenId, string memory name) public {
        require(ownerOf(tokenId) == msg.sender);
        require(bytes(name).length > 0);
        if (birthRegistry[name]) revert NameTaken(name);
        Blockhead storage blockhead = blockheads[tokenId];
        birthRegistry[blockhead.name] = false;
        blockhead.name = name;
        birthRegistry[name] = true;
        (uint256 metadataHash, ) = tokenMetadataHash(tokenId);
        emit TokenMetadataChanged(tokenId, metadataHash, 0);
    }

    function getName(uint256 tokenId) public view returns (string memory) {
        Blockhead storage blockhead = blockheads[tokenId];
        if (bytes(blockhead.name).length > 0) {
            return blockhead.name;
        }
        return string(abi.encodePacked("Blockhead #", Utils.toString(tokenId)));
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        bytes
            memory svg = "<svg xmlns='http://www.w3.org/2000/svg' preserveAspectRatio='xMinYMin meet' viewBox='0 0 25 25' width='500' height='500'>";
        svg = abi.encodePacked(svg, getBackgroundData(tokenId));
        svg = abi.encodePacked(svg, getBodyData(tokenId));
        svg = abi.encodePacked(svg, getArmsData(tokenId));
        svg = abi.encodePacked(svg, getHeadData(tokenId));
        svg = abi.encodePacked(svg, getFaceData(tokenId));
        svg = abi.encodePacked(svg, getHeadwearData(tokenId));
        svg = abi.encodePacked(svg, "</svg>");
        // Need to break up the json generation into 2 encodePackeds to avoid stack too deep errors
        bytes memory jsonPt1 = abi.encodePacked(
            '{"name": "',
            getName(tokenId),
            '", "description": "Blockheads", "image": "data:image/svg+xml;base64,',
            Utils.base64Encode(svg),
            '", "attributes": [{"trait_type": "Background", "value": "',
            getBackgroundLabel(tokenId),
            '"}, '
        );
        string memory json = Utils.base64Encode(
            abi.encodePacked(
                jsonPt1,
                '{"trait_type": "Body", "value": "',
                getBodyLabel(tokenId),
                '"}, ',
                '{"trait_type": "Arms", "value": "',
                getArmsLabel(tokenId),
                '"}, ',
                '{"trait_type": "Head", "value": "',
                getHeadLabel(tokenId),
                '"}, ',
                '{"trait_type": "Face", "value": "',
                getFaceLabel(tokenId),
                '"}, ',
                '{"trait_type": "Headwear", "value": "',
                getHeadwearLabel(tokenId),
                '"}]}'
            )
        );
        return string(abi.encodePacked("data:application/json;base64,", json));
    }

    function tokenMetadataHash(uint256 tokenId)
        public
        view
        override
        returns (uint256, uint256)
    {
        Blockhead storage bh = blockheads[tokenId];
        return (
            uint256(
                keccak256(
                    abi.encode(
                        bh.layers[uint256(LayerIndex.BACKGROUND)].index,
                        bh.layers[uint256(LayerIndex.BACKGROUND)].season,
                        bh.layers[uint256(LayerIndex.BODY)].index,
                        bh.layers[uint256(LayerIndex.BODY)].season,
                        bh.layers[uint256(LayerIndex.FACE)].index,
                        bh.layers[uint256(LayerIndex.FACE)].season,
                        bh.layers[uint256(LayerIndex.HEAD)].index,
                        bh.layers[uint256(LayerIndex.HEAD)].season,
                        bh.layers[uint256(LayerIndex.HEADWEAR)].index,
                        bh.layers[uint256(LayerIndex.HEADWEAR)].season,
                        bh.name
                    )
                )
            ),
            0
        );
    }

    function dataFor(Layer memory layer, address[] memory layerPacks)
        private
        pure
        returns (bytes memory)
    {
        return ImageDataBlock(layerPacks[layer.season]).getData(layer.index);
    }

    function getLayerData(
        uint16 season,
        uint16 index,
        uint16 layerIndex
    ) public view returns (bytes memory) {
        return ImageDataBlock(packs[layerIndex][season]).getData(index);
    }

    function getBackgroundData(uint256 tokenId)
        public
        view
        returns (bytes memory)
    {
        return
            dataFor(
                blockheads[tokenId].layers[uint256(LayerIndex.BACKGROUND)],
                packs[uint256(LayerIndex.BACKGROUND)]
            );
    }

    function getBodyData(uint256 tokenId) public view returns (bytes memory) {
        return
            dataFor(
                blockheads[tokenId].layers[uint256(LayerIndex.BODY)],
                packs[uint256(LayerIndex.BODY)]
            );
    }

    function getArmsData(uint256 tokenId) public view returns (bytes memory) {
        return
            dataFor(
                blockheads[tokenId].layers[uint256(LayerIndex.ARMS)],
                packs[uint256(LayerIndex.ARMS)]
            );
    }

    function getHeadData(uint256 tokenId) public view returns (bytes memory) {
        return
            dataFor(
                blockheads[tokenId].layers[uint256(LayerIndex.HEAD)],
                packs[uint256(LayerIndex.HEAD)]
            );
    }

    function getFaceData(uint256 tokenId) public view returns (bytes memory) {
        return
            dataFor(
                blockheads[tokenId].layers[uint256(LayerIndex.FACE)],
                packs[uint256(LayerIndex.FACE)]
            );
    }

    function getHeadwearData(uint256 tokenId)
        public
        view
        returns (bytes memory)
    {
        return
            dataFor(
                blockheads[tokenId].layers[uint256(LayerIndex.HEADWEAR)],
                packs[uint256(LayerIndex.HEADWEAR)]
            );
    }

    function labelFor(Layer memory layer, address[] memory layerPacks)
        private
        view
        returns (string memory)
    {
        return ImageDataBlock(layerPacks[layer.season]).getLabel(layer.index);
    }

    function getLayerLabel(
        uint16 season,
        uint16 index,
        uint16 layerIndex
    ) public view returns (string memory) {
        return ImageDataBlock(packs[layerIndex][season]).getLabel(index);
    }

    function getBackgroundLabel(uint256 tokenId)
        public
        view
        returns (string memory)
    {
        return
            labelFor(
                blockheads[tokenId].layers[uint256(LayerIndex.BACKGROUND)],
                packs[uint256(LayerIndex.BACKGROUND)]
            );
    }

    function getBodyLabel(uint256 tokenId) public view returns (string memory) {
        return
            labelFor(
                blockheads[tokenId].layers[uint256(LayerIndex.BODY)],
                packs[uint256(LayerIndex.BODY)]
            );
    }

    function getArmsLabel(uint256 tokenId) public view returns (string memory) {
        return
            labelFor(
                blockheads[tokenId].layers[uint256(LayerIndex.ARMS)],
                packs[uint256(LayerIndex.ARMS)]
            );
    }

    function getHeadLabel(uint256 tokenId) public view returns (string memory) {
        return
            labelFor(
                blockheads[tokenId].layers[uint256(LayerIndex.HEAD)],
                packs[uint256(LayerIndex.HEAD)]
            );
    }

    function getFaceLabel(uint256 tokenId) public view returns (string memory) {
        return
            labelFor(
                blockheads[tokenId].layers[uint256(LayerIndex.FACE)],
                packs[uint256(LayerIndex.FACE)]
            );
    }

    function getHeadwearLabel(uint256 tokenId)
        public
        view
        returns (string memory)
    {
        return
            labelFor(
                blockheads[tokenId].layers[uint256(LayerIndex.HEADWEAR)],
                packs[uint256(LayerIndex.HEADWEAR)]
            );
    }

    function isMintInBox(uint256 tokenId) public view returns (bool) {
        return !blockheads[tokenId].opened;
    }

    function publishSeason(
        address background,
        address body,
        address arms,
        address head,
        address face,
        address headwear
    ) public onlyOwner {
        packs[uint256(LayerIndex.BACKGROUND)].push(background);
        packs[uint256(LayerIndex.BODY)].push(body);
        packs[uint256(LayerIndex.ARMS)].push(arms);
        packs[uint256(LayerIndex.HEAD)].push(head);
        packs[uint256(LayerIndex.FACE)].push(face);
        packs[uint256(LayerIndex.HEADWEAR)].push(headwear);
    }

    function setRoyalties(address newRoyaltiesAddr) public onlyOwner {
        _setRoyalties(newRoyaltiesAddr, 1000);
    }
}
