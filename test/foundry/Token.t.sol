// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../contracts/Token.sol";

contract TokenTest is Test {
    MyToken public token;

    function setUp() public {
        token = new MyToken();
    }

    function testName() public view{
        assertEq(token.name(), "MyToken");
    }

    function testMintInitialSupply() public view {
        // 배포자가 Test 컨트랙트 자신이므로 address(this)로 확인
        assertEq(token.balanceOf(address(this)), 1000 * 10**18);
    }
}