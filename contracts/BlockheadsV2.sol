// //SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./ERC2981ContractWideRoyalties.sol";
import "./IERC721Mutable.sol";
import "./Utils.sol";
import "./ERC721Tradable.sol";

/**************                                                                                             
                                                                                                                                                                                                                                     




                                                                
                                ████████████████                                
                                ██            ██                                
                           ▐████████████████████████▌                           
                         ▐██                        ▐██                         
                       ██                              ██                       
                       ██                              ██                       
                       ██                              ██                       
                       ██       ████▌                  ██                       
                       ██       ████▌       ████▌      ██                       
                       ██                              ██                       
                       ██                              ██                       
                       ██          ██       ██         ██                       
                       ██            ███████           ██
                       ██                              ██                       
                         ▐██                        ▐██            
                            ▐███████████████████████▌                         
                                ██            ██
                  █████  ▐████████████████████████████▌  █████                
                ██     ██                              ██     ██  
              ██       ██                              ██       ██             
              ██       ██                              ██       ██            
           ▐██       ██                                  ██▌      ██▌           
                                                                                
     ▄▄▄▄▄   ▄▄▄  ▄▄▄▄    ▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄ ▄▄▄  ▄▄▄▄▄▄   ▄▄▄▄ ▄▄▄▄▄▄    ▄▄▄▄     
    █     █ █   █▀    █▄█▀   ▐█  █   █   █  ▀▄█▌     ██▀    █       ██▀    ▐█   
   █▌ ▀▀  ██  ▄█▌ ██▌  █   ████    ▄██      ▐██   ▀▀██   █  █  ▐██   ██  ▀▀█▄   
   █  ▀▀  █▌  ▀▀▌      ██     █▌     █   ██  █   ▀▀▀█▌  ▄▄  ██      █▌  ▀   █▌  
   ▀█▄▄▄▄█▀█▄▄▄█▀█▄▄▄██▀▀██▄▄█▀█▄██▄███▄█▀█▄▀▀█▄▄▄▄▄█▀██▀█▄███▄▄▄▄▄███▄▄▄▄██▀   
                                                                                





******************/

// Interface that all the data blocks exported from figma fulfill
interface ImageDataBlock {
    // Provide a renderable SVG string at the given slot
    function getData(uint256 slot) external pure returns (bytes memory);

    // Provide a human readable name at the given slot
    function getLabel(uint256 slot) external pure returns (string memory);
}

// ERC20 used for the 'withdrawERC20' just-in-case function, there is no actual erc20 involved here.
interface IERC20 {
    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    function balanceOf(address account) external view returns (uint256);
}

contract Blockheads is
    ERC721Tradable,
    ERC2981ContractWideRoyalties,
    IERC721Mutable
{
    address[] backgroundPacks;
    address[] bodyPacks;
    address[] armsPacks;
    address[] headPacks;
    address[] facePacks;
    address[] headwearPacks;
    address[] professionPacks;

    /** Layer represents a single layer of a composition, ie background, head, face, etc  */
    struct Layer {
        // season is an index into the pack arrays above
        uint16 season;
        // Index of the represented item in the pack
        uint16 index;
    }

    struct Blockhead {
        Layer background;
        Layer body;
        Layer arms;
        Layer head;
        Layer face;
        Layer headwear;
        // Profession is a layer that we never call getData on, only getLabel so that we can have expansion packs of professions.
        Layer profession;
        string name;
        bool isMintInBox;
    }
    mapping(uint256 => Blockhead) blockheads;

    // Birth registry is a mapping of taken names so each blockhead has a unique name.
    mapping(string => bool) birthRegistry;

    // Constructor requires the proxy for opensea, and all the data blocks
    constructor(address proxyRegistryAddress)
        ERC721Tradable("Blockheads World", "BLOK", proxyRegistryAddress)
    {
        // 5% royalties for ERC2981.  Not sure if anyone supports this yet.
        _setRoyalties(msg.sender, 500);
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

    function withdrawERC20(address tokenContract) external onlyOwner {
        IERC20 tc = IERC20(tokenContract);
        tc.transfer(owner(), tc.balanceOf(address(this)));
    }

    function random(bytes memory input) internal pure returns (uint256) {
        return uint256(keccak256(input));
    }

    modifier ownsBoth(uint256 token1, uint256 token2) {
        require(ownerOf(token1) == msg.sender);
        require(ownerOf(token2) == msg.sender);
        _;
    }

    function setName(uint256 tokenId, string memory name) public {
        require(ownerOf(tokenId) == msg.sender);
        require(bytes(name).length > 0);
        require(!birthRegistry[name]);
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

    function getProfession(uint256 tokenId)
        public
        view
        returns (string memory)
    {
        Blockhead storage blockhead = blockheads[tokenId];
        return
            ImageDataBlock(professionPacks[blockhead.profession.season])
                .getLabel(blockhead.profession.index);
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
            '"}, ',
            '{"trait_type": "Profession", "value": "',
            getProfession(tokenId),
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
                        bh.background.index,
                        bh.background.season,
                        bh.body.index,
                        bh.body.season,
                        bh.face.index,
                        bh.face.season,
                        bh.head.index,
                        bh.head.season,
                        bh.headwear.index,
                        bh.headwear.season,
                        bh.profession.index,
                        bh.profession.season,
                        bh.name
                    )
                )
            ),
            0
        );
    }

    function dataFor(Layer memory layer, address[] memory packs)
        private
        pure
        returns (bytes memory)
    {
        return ImageDataBlock(packs[layer.season]).getData(layer.index);
    }

    function getBackgroundData(uint256 tokenId)
        public
        view
        returns (bytes memory)
    {
        return dataFor(blockheads[tokenId].background, backgroundPacks);
    }

    function getBodyData(uint256 tokenId) public view returns (bytes memory) {
        return dataFor(blockheads[tokenId].body, bodyPacks);
    }

    function getArmsData(uint256 tokenId) public view returns (bytes memory) {
        return dataFor(blockheads[tokenId].arms, armsPacks);
    }

    function getHeadData(uint256 tokenId) public view returns (bytes memory) {
        return dataFor(blockheads[tokenId].head, headPacks);
    }

    function getFaceData(uint256 tokenId) public view returns (bytes memory) {
        return dataFor(blockheads[tokenId].face, facePacks);
    }

    function getHeadwearData(uint256 tokenId)
        public
        view
        returns (bytes memory)
    {
        return dataFor(blockheads[tokenId].headwear, headwearPacks);
    }

    function labelFor(Layer memory layer, address[] memory packs)
        private
        pure
        returns (string memory)
    {
        return ImageDataBlock(packs[layer.season]).getLabel(layer.index);
    }

    function getBackgroundLabel(uint256 tokenId)
        public
        view
        returns (string memory)
    {
        return labelFor(blockheads[tokenId].background, backgroundPacks);
    }

    function getBodyLabel(uint256 tokenId) public view returns (string memory) {
        return labelFor(blockheads[tokenId].body, bodyPacks);
    }

    function getArmsLabel(uint256 tokenId) public view returns (string memory) {
        return labelFor(blockheads[tokenId].arms, armsPacks);
    }

    function getHeadLabel(uint256 tokenId) public view returns (string memory) {
        return labelFor(blockheads[tokenId].head, headPacks);
    }

    function getFaceLabel(uint256 tokenId) public view returns (string memory) {
        return labelFor(blockheads[tokenId].face, facePacks);
    }

    function getHeadwearLabel(uint256 tokenId)
        public
        view
        returns (string memory)
    {
        return labelFor(blockheads[tokenId].headwear, headwearPacks);
    }

    function isMintInBox(uint256 tokenId) public view returns (bool) {
        return blockheads[tokenId].isMintInBox;
    }

    function bridgeFromV1(
        address holder,
        uint256 tokenId,
        uint16 backgroundIndex,
        uint16 bodyIndex,
        uint16 armsIndex,
        uint16 headIndex,
        uint16 faceIndex,
        uint16 headwearIndex
    ) public onlyOwner {
        _safeMint(holder, tokenId);
        Blockhead storage bh = blockheads[tokenId];
        // These are all from the first season, pack0.
        bh.background = Layer(0, backgroundIndex);
        bh.body = Layer(0, bodyIndex);
        bh.arms = Layer(0, armsIndex);
        bh.head = Layer(0, headIndex);
        bh.face = Layer(0, faceIndex);
        bh.headwear = Layer(0, headwearIndex);
        blockheads[tokenId] = bh;
    }

    function publishSeason(
        address background,
        address body,
        address arms,
        address head,
        address face, 
        address headwear
    ) public onlyOwner {
        backgroundPacks.push(background);
        bodyPacks.push(body);
        armsPacks.push(arms);
        headPacks.push(head);
        facePacks.push(face);
        headwearPacks.push(headwear);
    }

    function setRoyalties(address newRoyaltiesAddr) public onlyOwner {
        _setRoyalties(newRoyaltiesAddr, 1000);
    }
}
