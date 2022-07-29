// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";

interface ERC20 {
    function decimals() external view returns(uint8);
    function totalSupply() external view returns(uint256);
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
    function approve(address, uint256) external returns (bool);
    function allowance(address, address) external view returns (uint256);
    function mint(address, uint256) external;
    function name() external view returns(string memory);
    function symbol() external view returns(string memory);
    event Transfer(address indexed, address indexed, uint256);
    event Approval(address indexed, address indexed, uint256);
}

bytes4 constant Underflow = 0xcaccb6d9;
bytes4 constant Overflow = 0x35278d12;

contract ContractTest is Test {
    uint256 constant MAX = type(uint256).max;
    ERC20 token;

    address user1 = address(1);
    address user2 = address(2);
    address user3 = address(3);

    function reset() public {
        string[] memory inputs = new string[](3);
        inputs[0] = "huffc";
        inputs[1] = "./src/erc20.huff";
        inputs[2] = "--bytecode";
        bytes memory bytecode = vm.ffi(inputs);
        if(bytecode.length == 0) {
            revert("Could not find bytecode");
        }
        // console.logBytes(bytecode);

        assembly {
            sstore(token.slot, create(0, add(bytecode, 0x20), mload(bytecode)))
        }
        if(address(token) == address(0)) {
            console.logBytes(bytecode);
            revert("Could not deploy address");
        }
    }

    function setUp() public {
        reset();
    }

    function fund(address account, uint256 amount) internal {
        uint256 a = token.balanceOf(account);
        token.mint(account, amount);
        uint256 b = token.balanceOf(account);
        assertEq(b - a, amount);
    }

    function testMint() public {
        reset();
        token.mint(user1, 100);
        assertEq(token.balanceOf(user1), 100);
        assertEq(token.totalSupply(), 100);
    }

    function testTransfer() public {
        reset();

        fund(user1, 500);

        vm.prank(user1); token.transfer(user2, 100);
        assertEq(token.balanceOf(user1), 400);
        assertEq(token.balanceOf(user2), 100);
    }

    function testTransferFrom() public {
        reset();
        fund(user1, 500);

        vm.startPrank(user2);
        vm.expectRevert(Underflow);
        token.transferFrom(user1, user2, 100);
        vm.stopPrank();

        vm.prank(user1); token.approve(user2, 100);

        vm.startPrank(user2);
        vm.expectRevert(Underflow);
        token.transferFrom(user1, user2, 101);
        token.transferFrom(user1, user2, 50);
        assertEq(token.allowance(user1, user2), 50);
        assertEq(token.balanceOf(user1), 450);
        assertEq(token.balanceOf(user2), 50);

        vm.expectRevert(Underflow);
        token.transferFrom(user1, user2, 51);
        token.transferFrom(user1, user2, 50);
        assertEq(token.allowance(user1, user2), 0);
        assertEq(token.balanceOf(user1), 400);
        assertEq(token.balanceOf(user2), 100);
    }

    function testDecimals() public {
        assertEq(token.decimals(), 18);
    }

    function testName() public {
        assertEq(token.name(), "Test");
    }

    function testSymbol() public {
        assertEq(token.symbol(), "TST");
    }
}
