// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";

interface Token {
    function balanceOf(address) external view returns(uint256);
    function ownerOf(uint256) external view returns (address);
    function safeTransferFrom(address, address, uint256, bytes memory) external;
    function safeTransferFrom(address, address, uint256) external;
    function transferFrom(address, address, uint256) external;
    function approve(address, uint256) external;
    function setApprovalForAll(address, bool) external;
    function getApproved(uint256) external view returns(address);
    function isApprovedForAll(address, address) external view returns(bool);
    function mint(address, uint256) external;
    function totalSupply() external view returns(uint256);
    function name() external view returns(string memory);
    function symbol() external view returns(string memory);
    function tokenURI(uint256 id) external returns(string memory);

    event Transfer(address indexed, address indexed, uint256 indexed);
    event Approval(address indexed, address indexed, uint256 indexed);
    event ApprovalForAll(address indexed, address indexed, bool);

    error SafeTransferToNonReceiver();
    error TransferToZeroAddress();
    error NonExistentToken();
    error NotAuthorized();
    error IncorrectFrom();
}

contract ERC721Test is Test {
    uint256 constant MAX = type(uint256).max;
    Token token;

    address user1 = 0x1111111111111111111111111111111111111111;
    address user2 = 0x2222222222222222222222222222222222222222;
    address user3 = 0x3333333333333333333333333333333333333333;

    bytes deploy_code;

    function reset() public {
        bytes memory bytecode = deploy_code;
        assembly {
            sstore(token.slot, create(0, add(bytecode, 0x20), mload(bytecode)))
        }
        if(address(token) == address(0)) {
            console.logBytes(bytecode);
            revert("Could not deploy address");
        }
        vm.label(address(token), 'erc721');
    }

    function setUp() public {
        string[] memory inputs = new string[](3);
        inputs[0] = "huffc";
        inputs[1] = "./src/erc721.huff";
        inputs[2] = "--bytecode";
        bytes memory bytecode = vm.ffi(inputs);
        if(bytecode.length == 0) {
            revert("Could not compile");
        }
        // console.logBytes(bytecode);
        deploy_code = bytecode;
        reset();
    }

    function testName() public {
        assertEq(token.name(), "MyNFT");
    }

    function testSymbol() public {
        assertEq(token.symbol(), "NFT");
    }

    function testTokenURI() public {
        reset();
        token.mint(address(1), 5);
        assertEq(token.tokenURI(0), "ipfs://QmeSjSinHpPnmXmspMjwiXyN6zS4E9zccariGR3jxcaWtq/0");
        assertEq(token.tokenURI(1), "ipfs://QmeSjSinHpPnmXmspMjwiXyN6zS4E9zccariGR3jxcaWtq/1");
        assertEq(token.tokenURI(2), "ipfs://QmeSjSinHpPnmXmspMjwiXyN6zS4E9zccariGR3jxcaWtq/2");
        assertEq(token.tokenURI(3), "ipfs://QmeSjSinHpPnmXmspMjwiXyN6zS4E9zccariGR3jxcaWtq/3");
        assertEq(token.tokenURI(4), "ipfs://QmeSjSinHpPnmXmspMjwiXyN6zS4E9zccariGR3jxcaWtq/4");
        vm.expectRevert(Token.NonExistentToken.selector);
        token.tokenURI(6);
    }

    function testSafeTransferFrom() public {
        reset();
        token.mint(user1, 1);
        vm.startPrank(user1);
        vm.expectRevert(Token.SafeTransferToNonReceiver.selector);
        token.safeTransferFrom(user1, address(this), 0);
        vm.expectRevert(Token.SafeTransferToNonReceiver.selector);
        token.safeTransferFrom(user1, address(this), 0, "");
        token.safeTransferFrom(user1, user2, 0);
    }

    function testSingleMint() public {
        reset();
        assertEq(token.totalSupply(), 0);
        assertEq(token.balanceOf(user1), 0);
        vm.expectRevert(Token.NonExistentToken.selector);
        token.ownerOf(0);

        token.mint(user1, 1);

        assertEq(token.totalSupply(), 1);
        assertEq(token.ownerOf(0), user1);
        assertEq(token.balanceOf(user1), 1);

        vm.expectRevert(Token.NonExistentToken.selector);
        token.ownerOf(1);
    }

    function testMultiMint() public {
        reset();
        assertEq(token.totalSupply(), 0);
        assertEq(token.balanceOf(user1), 0);

        vm.expectRevert(Token.NonExistentToken.selector);
        token.ownerOf(0);
        vm.expectRevert(Token.NonExistentToken.selector);
        token.ownerOf(1);
        vm.expectRevert(Token.NonExistentToken.selector);
        token.ownerOf(2);

        token.mint(user1, 3);

        assertEq(token.totalSupply(), 3);
        assertEq(token.ownerOf(0), user1);
        assertEq(token.ownerOf(1), user1);
        assertEq(token.ownerOf(2), user1);
        assertEq(token.balanceOf(user1), 3);

        vm.expectRevert(Token.NonExistentToken.selector);
        token.ownerOf(4);
        vm.expectRevert(Token.NonExistentToken.selector);
        token.ownerOf(5);
        vm.expectRevert(Token.NonExistentToken.selector);
        token.ownerOf(6);
    }

    function testSetApproval() public {
        reset();

        vm.prank(user1);
        token.setApprovalForAll(user2, true);

        assertEq(token.isApprovedForAll(user1, user2), true);
        assertEq(token.isApprovedForAll(user2, user1), false);
        assertEq(token.isApprovedForAll(user1, user3), false);
    }

    function testOperatorApprovalTransfer() public {
        reset();

        token.mint(user1, 1);
        
        vm.prank(user3);
        token.setApprovalForAll(user2, true);

        vm.startPrank(user2);
        vm.expectRevert(Token.NotAuthorized.selector);
        token.transferFrom(user1, user2, 0);
        vm.stopPrank();

        vm.prank(user1);
        token.setApprovalForAll(user2, true);

        vm.startPrank(user3);
        vm.expectRevert(Token.NotAuthorized.selector);
        token.transferFrom(user1, user3, 0);
        vm.stopPrank();

        vm.prank(user2);
        token.transferFrom(user1, user2, 0);
        assertEq(token.balanceOf(user1), 0);
        assertEq(token.balanceOf(user2), 1);
        assertEq(token.totalSupply(), 1);
        assertEq(token.ownerOf(0), user2);
    }

    function testTokenApprovalTransfer() public {
        reset();

        token.mint(user1, 1);

        assertEq(token.getApproved(0), address(0));
        
        vm.startPrank(user3);
        vm.expectRevert(Token.NotAuthorized.selector);
        token.approve(user2, 0);
        vm.stopPrank();

        vm.startPrank(user2);
        vm.expectRevert(Token.NotAuthorized.selector);
        token.transferFrom(user1, user2, 0);
        vm.stopPrank();

        vm.prank(user1);
        token.approve(user2, 0);
        assertEq(token.getApproved(0), user2);

        vm.expectRevert(Token.NonExistentToken.selector);
        token.getApproved(1);


        vm.startPrank(user3);
        vm.expectRevert(Token.NotAuthorized.selector);
        token.transferFrom(user1, user3, 0);
        vm.stopPrank();

        vm.prank(user2);
        token.transferFrom(user1, user2, 0);
        assertEq(token.balanceOf(user1), 0);
        assertEq(token.balanceOf(user2), 1);
        assertEq(token.totalSupply(), 1);
        assertEq(token.ownerOf(0), user2);
    }

    function testTokenApprovalClear() public {
        reset();

        token.mint(user1, 1);

        assertEq(token.getApproved(0), address(0));
        
        vm.startPrank(user3);
        vm.expectRevert(Token.NotAuthorized.selector);
        token.approve(user2, 0);
        vm.stopPrank();

        vm.startPrank(user2);
        vm.expectRevert(Token.NotAuthorized.selector);
        token.transferFrom(user1, user2, 0);
        vm.stopPrank();

        vm.prank(user1);
        token.approve(user2, 0);
        assertEq(token.getApproved(0), user2);

        vm.expectRevert(Token.NonExistentToken.selector);
        token.getApproved(1);


        vm.startPrank(user3);
        vm.expectRevert(Token.NotAuthorized.selector);
        token.transferFrom(user1, user3, 0);
        vm.stopPrank();

        vm.prank(user1);
        token.approve(address(0), 0);

        vm.startPrank(user2);
        vm.expectRevert(Token.NotAuthorized.selector);
        token.transferFrom(user1, user2, 0);
        vm.stopPrank();
    }
}
