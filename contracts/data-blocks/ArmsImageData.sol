// //SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

contract ArmsImageData {
    function getLabel(uint256 slot) public pure returns (string memory) {
        string[24] memory names = [
            "Aqua",
            "Light Blue",
            "Bright Blue",
            "Dark Blue",
            "Light Grey",
            "Medium Grey",
            "Dark Grey",
            "White",
            "Light Pink",
            "Deep Blush",
            "Yellow Green",
            "Bright Green",
            "Dark Green",
            "Olive Green",
            "Light Nougat",
            "Nougat",
            "Brick Yellow",
            "Light Brown",
            "Dark Brown",
            "Light Yellow",
            "Yellow",
            "Bright Yellow",
            "Bright Orange",
            "Bright Red"
        ];
        return names[slot % names.length];
    }

    function getData(uint256 slot) public pure returns (bytes memory) {
        string[24] memory colors = [
            "C1E4DA",
            "78BFEA",
            "00A3DA",
            "006CB7",
            "A0A19F",
            "646765",
            "42423E",
            "F4F4F4",
            "F6ADCD",
            "E95DA2",
            "9ACA3C",
            "00AF4D",
            "009247",
            "828353",
            "FCC39E",
            "DE8B5F",
            "DDC48E",
            "AF7446",
            "692E14",
            "FFF579",
            "FEE716",
            "FFCD03",
            "F57D20",
            "DD1A21"
        ];
        return
            abi.encodePacked(
                '<path d="M3 21H5V24H4V25H1V24H2V22H3V21ZM22 21H20V24H21V25H24V24H23V22H22V21Z" fill="#',
                colors[slot % colors.length],
                '"/>'
                '<path d="M5 20H3V21H2V22H1V24H0V25H1V24H2V22H3V21H5V24H4V25H5V24H6V21H5V20ZM22 20H20V21H19V24H20V25H21V24H20V21H22V22H23V24H24V25H25V24H24V22H23V21H22V20Z" fill="black"/>'
            );
    }

    // taken from https://github.com/GNSPS/solidity-bytes-utils/blob/master/contracts/BytesLib.sol
    function slice(
        bytes memory _bytes,
        uint32 _start,
        uint32 _length
    ) internal pure returns (bytes memory) {
        require(_length + 31 >= _length, "slice_overflow");
        require(_bytes.length >= _start + _length, "slice_outOfBounds");

        bytes memory tempBytes;

        assembly {
            switch iszero(_length)
            case 0 {
                tempBytes := mload(0x40)
                let lengthmod := and(_length, 31)
                let mc := add(
                    add(tempBytes, lengthmod),
                    mul(0x20, iszero(lengthmod))
                )
                let end := add(mc, _length)

                for {
                    let cc := add(
                        add(
                            add(_bytes, lengthmod),
                            mul(0x20, iszero(lengthmod))
                        ),
                        _start
                    )
                } lt(mc, end) {
                    mc := add(mc, 0x20)
                    cc := add(cc, 0x20)
                } {
                    mstore(mc, mload(cc))
                }
                mstore(tempBytes, _length)
                mstore(0x40, and(add(mc, 31), not(31)))
            }
            default {
                tempBytes := mload(0x40)
                mstore(tempBytes, 0)
                mstore(0x40, add(tempBytes, 0x20))
            }
        }

        return tempBytes;
    }
}
