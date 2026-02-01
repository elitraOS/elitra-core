// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "forge-std/Test.sol";
import { Compatible } from "../../src/vault/Compatible.sol";

/// @notice Mock implementation of Compatible to test the abstract contract
contract CompatibleMock is Compatible {
    function exposedOnERC721Received(
        address /* operator */,
        address /* from */,
        uint256 /* tokenId */,
        bytes calldata /* data */
    ) external returns (bytes4) {
        return this.onERC721Received.selector;
    }
}

contract Compatible_Test is Test {
    CompatibleMock public target;

    function setUp() public {
        target = new CompatibleMock();
    }

    function test_Receive_EmitsEvent() public {
        vm.expectEmit(true, false, false, true);
        emit Compatible.Received(address(this), 100);
        (bool success,) = address(target).call{value: 100}("");
        assertTrue(success);
    }

    function test_Receive_AcceptsETH() public {
        uint256 amount = 1 ether;
        (bool success,) = address(target).call{value: amount}("");
        assertTrue(success);
        assertEq(address(target).balance, amount);
    }

    function test_OnERC721Received_ReturnsCorrectSelector() public {
        bytes4 selector = target.onERC721Received(
            address(0x1),
            address(0x2),
            123,
            ""
        );
        assertEq(selector, target.onERC721Received.selector);
    }

    function test_OnERC1155Received_ReturnsCorrectSelector() public {
        bytes4 selector = target.onERC1155Received(
            address(0x1),
            address(0x2),
            123,
            456,
            ""
        );
        assertEq(selector, target.onERC1155Received.selector);
    }

    function test_OnERC1155BatchReceived_ReturnsCorrectSelector() public {
        uint256[] memory ids = new uint256[](2);
        ids[0] = 1;
        ids[1] = 2;
        uint256[] memory values = new uint256[](2);
        values[0] = 100;
        values[1] = 200;

        bytes4 selector = target.onERC1155BatchReceived(
            address(0x1),
            address(0x2),
            ids,
            values,
            ""
        );
        assertEq(selector, target.onERC1155BatchReceived.selector);
    }
}
