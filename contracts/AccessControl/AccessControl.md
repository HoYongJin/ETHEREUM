# 관리자 권한(Access Control)

## Ownable
* 오직 소유자(Owner)만이 특정 함수를 실행할 수 있게 제한
* `abstract contract`로 구현되어 상속(`is Ownable`)을 통해 사용
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

## Ownable2Step
* Ownable의 보안 확장판(`Ownable`을 상속)
* 소유권 이전을 2단계(`Two-Step`)로 나누어 실수로 관리자 권한을 잃어버리는 사고를 방지
* State
    - `private _pendingOwner`: 바로 `_owner`를 바꾸지 않고, `newOwner`를 저장하는 변수
* Transfer Ownership
    1. `transferOwnership(address newOwner)`
        - `Ownable`의 함수를 `Override`
        - `_pendingOwner`에 `newOwner`를 후보자로 등록
        - `OwnershipTransferStarted` 이벤트를 발생
    2. `acceptOwnership`
        - `_pendingOwner`가 직접 호출
        - `msg.sender`가 `pendingOwner`와 일치하는지 확인
        - 검증아 완료되면 소유권 이전이 확정되기 직전에 `_pendingOwner`를 삭제하여 초기화
        - 실제 소유자 변경 로직은 `Ownable` 컨트랙트의 기능을 그대로 사용

## AccessControl
* 역할 기반 접근 제어(`RBAC, Role-Based Access Control`)를 구현하는 표준 모듈
* 여러 역할을 정의하고 각 역할마다 관리자를 따로 둘 수 있는 계층 구조를 제공
* Data Structures
    - RoleData Struct
        - mapping(address account => bool) `hasRole`: 특정 계정(`address`)이 해당 역할을 가지고 있는지(`bool`) 저장하는 매핑
        - bytes32 `adminRole`: 이 역할을 관리(부여/박탈)할 수 있는 상위 관리자 역할의 해시값
    - mapping(bytes32 role => RoleData) private `_roles`: 역할의 이름(`bytes32`)을 키로 받아 `RoleData`를 반환
    - `DEFAULT_ADMIN_ROLE`: 모든 역할의 기본 관리자 역할
* Read & Verification
    - supportsInterface(bytes4 interfaceId): ERC-165 표준을 따르며, 이 컨트랙트가 IAccessControl 인터페이스를 구현하고 있음을 외부에 알림
    - hasRole(bytes32 role, address account)
        - 특정 계정이 특정 역할을 가지고 있는지 확인
        - `_roles[role].hasRole[account]` 값을 읽어서 `true/false`를 반환
    - _checkRole(bytes32 role, address account)
        - 권한 검사를 수행하고, 권한이 없으면 `Revert`(에러 발생)
        1. `role`만 인자로 넘기면 `account`에 자동으로 `msg.sender`를 넣어줌
        2. `role`과 `account` 모두 인자로 넘기면 특정 `account`가 `role`을 가지고 있는지 검사
        - 실패시 `AccessControlUnauthorizedAccount(address account, bytes32 neededRole)`에러 발생
    - modifier onlyRole(bytes32 role): `_checkRole(role)`를 호출해서 `msg.sender`가 권한이 있는지 확인 후 로직 실행
* Admin Hierarchy
    - getRoleAdmin(bytes32 role): 특정 역할의 상위 관리자 역할이 무엇인지 반환
    - _setRoleAdmin(bytes32 role, bytes32 adminRole): 특정 역할의 관리자를 변경
* Write Functions
    - grantRole(bytes32 role, address account)
        - 특정 계정에 역할을 부여
        - 해당 역할의 관리자 권한을 가진 사람만 호출 가능
    - revokeRole(bytes32 role, address account)
        - 특정 계정의 역할을 강제로 박탈
        - 해당 역할의 관리자 권한을 가진 사람만 호출 가능
    - renounceRole(bytes32 role, address callerConfirmation)
        - 스스로 자신의 권한을 포기
        - `msg.sender`와 `callerConfirmation`이 일치해야 함
        - 관리자가 뺏는 게 아니라, 본인이 그만두는 것이므로 관리자 권한이 필요 없음

## TimelockController
* 시간 지연(`Time-Delay`)이 적용된 관리자
* 관리자 작업을 수행하려면 Proposal --> Waiting --> Excute
* Roles & Constants
    - PROPOSER_ROLE: 트랜잭션을 예약(`Schedule`) 할 수 있는 권한
    - EXECUTOR_ROLE: 예약된 시간이 지난 후 실제 트랜잭션을 실행(`Execute`) 할 수 있는 권한
        - `address(0)`에 부여하면, 시간이 지난 후 누구나 실행 가능
    - CANCELLER_ROLE: 대기 중인 트랜잭션을 취소(`Cancel`) 할 수 있는 권한
    - _DONE_TIMESTAMP: 실행 완료된 작업의 타임스탬프를 1로 고정하여 표시
* Constructor
    - minDelay: 최소 대기 시간(초 단위)을 설정
    - address[] memory proposers: 입력받은 주소들에게 제안자, 취소자 권한을 부여
    - address[] memory executors: 입력받은 주소들에게 실행자 권한을 부여
    - admin 설정
        - Administration: 기본적으로 `address(this)`에게 `DEFAULT_ADMIN_ROLE` 부여(`Timelock`의 설정을 바꾸려면 `Timelock`을 통해서만 가능)
        - `admin`이 `address(0)`이 아니면 그 사람에게 관리자 권한 부여
* State View Functions
    - 이 컨트랙트는 각 작업(`Operation`)을 `bytes32 id`(해시값)로 관리
    - hashOperation(...): `target`, `value`, `data`, `predecessor`, `salt`를 인자로 받아 `keccak256` 함수로 해시화
    - getOperationState(bytes32 id): 작업의 현재 상태를 반환
        - Unset: 등록 안 됨
        - Waiting: 등록은 됐지만 아직 대기 시간(`minDelay`)이 안 지남
        - Ready: 대기 시간이 지남(실행 가능)
        - Done: 이미 실행됨
* schedule
    - target, value, data: 실제 실행할 트랜잭션 내용
    - predecessor: 이 작업보다 먼저 실행되어야 하는 작업의 ID
    - salt: 같은 작업을 구분하기 위한 랜덤 값
    - delay: 얼마나 기다릴지(최소 `minDelay` 이상)
    1. 권한 확인 (PROPOSER_ROLE)
    2. id 생성(`hashOperation(...)`)
    3. 이미 등록된 작업인지 확인
    4. `delay`가 충분한지 확인
    5. `_timestamps[id]`에 `block.timestamp + delay`(실행 가능 시간)를 저장
* Cancellation
    - 대기 중(`Waiting`)이거나 실행 대기(`Ready`) 상태인 작업을 삭제
    - `_timestamps[id]`를 삭제하여 실행 불가능하게 만듦(악성 트랜잭션이 감지되었을 때 방어 수단)
* Execution
    - 시간이 다 된 작업을 실제로 실행
    1. 권한 확인: onlyRoleOrOpenRole -> 지정된 실행자 또는 (오픈된 경우) 누구나 실행 가능
    2. id 생성(`hashOperation(...)`)
    3. _beforeCall
        - 작업이 Ready 상태인가? (시간 지났는가?)
        - `predecessor`(선행 작업)가 있다면, 그게 완료(`Done`)되었는가?
    4. _execute
        - `target.call{value: value}(data)` 를 통해 실제 대상 컨트랙트의 함수를 호출
        - `msg.sender`는 `TimelockController`의 주소
    5. _afterCall
        - 상태를 `Done(timestamp = 1)`으로 변경하여 재실행(`Replay`)을 방지
* Self-Maintenance
    - updateDelay: minDelay(최소 대기 시간)를 변경
        - 오직 Timelock 컨트랙트 자신만 이 함수를 호출 가능
        - 대기 시간을 바꾸고 싶다면 "대기 시간을 바꾸는 작업"을 `schedule`하고, 기다렸다가 `execute` 해야 바뀜(관리자가 마음대로 대기 시간을 0으로 줄이는 것을 방지)