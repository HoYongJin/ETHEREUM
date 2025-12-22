# 관리자 권한(Access Control)

## Ownable
- 오직 소유자(Owner)만이 특정 함수를 실행할 수 있게 제한
- `abstract contract`로 구현되어 상속(`is Ownable`)을 통해 사용
* State & Custom Errors
    - `private _owner`: 소유자의 주소를 저장
    - `OwnableUnauthorizedAccount(address account)`: 소유자가 아닌 계정이 호출했을 때 발생
    - `OwnableInvalidOwner(address owner)`: 유효하지 않은 주소(0번 주소 등)로 소유권을 설정하려 할 때 발생
* Constructor
    - `initialOwner`를 명시적으로 전달하면 `initialOwner`를 `_owner`로 설정
* Modifier
    - `onlyOwner`: 호출자(`_msgSender()`)가 소유자(`owner()`)와 다를 경우 `OwnableUnauthorizedAccount` 에러 발생 및 트랜잭션 `Revert`
* Renounce Ownership
    - `renounceOwnership`
        1. 관리자 권한을 영구적으로 포기
        2. 소유자를 `address(0)`로 변경
        3. `onlyOwner`가 적용된 모든 함수를 그 누구도 영원히 실행할 수 없게 됨
* Transfer Ownership
    - `transferOwnership(address newOwner)`
        1. 현재 소유자(`owner`)만 호출 가능
        2. `newOwner가` 0번 주소인지 검증
        3. 실제 상태 변수 `_owner`를 업데이트
        4. `OwnershipTransferred` 이벤트를 발생




Ownable2Step
AccessControl
TimelockController
AccessManager