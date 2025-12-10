// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../../contracts/ERC20/MyToken.sol";

contract MyTokenTest is Test {  // 이 컨트랙트가 테스트용 컨트랙트임을 선언하고, Foundry의 기능을 상속받음
    // 테스트할 토큰 컨트랙트의 인스턴스를 저장할 변수
    MyToken public token;

    // 테스트에 참여할 가상의 인물들
    address public admin = address(1);  // 관리자
    address public alice = address(2);  // 일반 사용자 1
    address public bob = address(3);    // 일반 사용자 2 (또는 해커)

    // 테스트 시작 전 실행되는 설정 함수
    function setUp() public {
        vm.startPrank(admin);   // 이제부터 모든 트랜잭션은 admin이 보내는 것으로 쳐라
        token = new MyToken();  // 컨트랙트를 실제로 배포(위 줄 덕분에 배포자는 admin)
        vm.stopPrank();         // 다시 테스트 컨트랙트 자신으로 돌아옴
    }

    // [Test 1] 메타데이터 확인
    function testMetadata() public view {
        // assertEq(A, B): A와 B가 같아야만 통과(Pass)
        assertEq(token.name(), "MyToken");
        assertEq(token.symbol(), "MTK");
    }

    // [Test 2] 발행 권한 테스트
    function testMinting() public {
        // case A: 권한이 있는 admin이 발행 -> 성공해야 함
        vm.prank(admin);
        token.mint(alice, 1000 ether);
        assertEq(token.balanceOf(alice), 1000 ether);

        // Case B: 권한이 없는 bob(해커)이 발행 시도 -> 실패(Revert)해야 함
        bytes32 role = token.MINTER_ROLE();
        vm.prank(bob);
        // "다음 트랜잭션은 반드시 이 에러로 실패해야 한다"라고 선언
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                bob,
                role
            )
        );
        token.mint(bob, 1000 ether); // 실패 예상
    }

    // [Test 3] 전송 (Transfer)
    function testTransfer() public {
        // 1. admin이 alice에게 100 토큰 발행
        vm.prank(admin);
        token.mint(alice, 100 ether);

        // 2. alice가 bob에게 30 토큰 전송
        vm.prank(alice);
        token.transfer(bob, 30 ether);

        // 3. 결과 검증
        assertEq(token.balanceOf(alice), 70 ether);
        assertEq(token.balanceOf(bob), 30 ether);
    }

    // [Test 4] 제3자 전송 (Approve & TransferFrom)
    function testTransferFrom() public {
        // 1. 초기 세팅: Alice가 100 토큰 보유
        vm.prank(admin);
        token.mint(alice, 100 ether);

        // 2. Alice가 Bob에게 "내 돈 50만큼 써도 좋아"라고 승인(Approve)
        vm.prank(alice);
        token.approve(bob, 50 ether);

        // 검증: Bob의 인출 허용량(Allowance) 확인
        assertEq(token.allowance(alice, bob), 50 ether);

        // 3. Bob이 Alice의 지갑에서 자신에게 20 토큰 이체
        vm.prank(bob);
        token.transferFrom(alice, bob, 20 ether);

        // 4. 결과 검증
        assertEq(token.balanceOf(alice), 80 ether); // 100 - 20
        assertEq(token.balanceOf(bob), 20 ether);
        assertEq(token.allowance(alice, bob), 30 ether); // 남은 허용량: 50 - 20
    }

}