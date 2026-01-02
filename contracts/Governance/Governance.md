## ABI Encoding & Call

- 거버넌스 시스템(`Governor, Timelock`)이 제안(`Proposal`)을 실제로 실행하는 방법
- ABI Encoding
    - 스마트 컨트랙트의 함수를 호출하려면, `EVM`이 이해할 수 있는 16진수 문자열(`Calldata`)로 변환해야 함
    - Struct: Selector + Arguments
        - Function Selector(4 bytes)
        - "어떤 함수를 실행할 것인가?"
        - 함수 시그니처(`transfer(address,uint256)`)의 `Keccak-256` 해시값 중 앞 4바이트
    - Arguments(32 bytes)
        - "어떤 파라미터를 넣을 것인가?"
        - 각 인자를 32 bytes 슬롯에 맞춰서 넣음(`Padding`)
    - Example
        - ERC20.transfer(bob, 100) 호출
        - bob 주소: 0x123... / amount: 100
        - bytes memory payload:
            1. Selector (transfer, 4bytes): 0xa9059cbb
            2. Argument1(bob, 32bytes): 000000000000000000000000123...
            3. Argument2(amount, 32bytes): 0000000000000000000000000000000000000000000000000000000000000064
    - Implementation
        1. abi.encodeCall
            - 타입 체크를 컴파일 타임에 수행(오타나 타입 불일치 방지)
            - Ex: bytes memory data = abi.encodeCall(IERC20.transfer, (bob, 100))
        2. abi.encodeWithSignature
            - 오타가 나도 컴파일러가 모름
            - Ex: bytes memory data = abi.encodeWithSignature("transfer(address,uint256)", bob, 100)
        3. abi.encodeWithSelector
            - 셀렉터를 직접 작성
            - Ex: bytes memory data = abi.encodeWithSelector(IERC20.transfer.selector, bob, 100)
- Low-level Call
    - 거버넌스 컨트랙트의 실행
    - (bool success, bytes memory returnData) = targetAddress.call{value: ethAmount}(encodedData)
    - targetAddress: 명령을 받을 컨트랙트
    - call: EVM의 CALL Opcode를 실행하는 저수준 함수(특정 함수를 지정하지 않고, encodedData를 그대로 실행)
    - value: ETH를 같이 보낼지 결정
    - encodedData: ABI Encoding Data

## Proxy Pattern
- Core Concept
    - 스마트 컨트랙트는 한 번 배포하면 절대 수정 불가능(Immutable)
    - 현실의 소프트웨어는 버그 수정 및 새로운 기능 추가가 필요
    - 사용자는 변하지 않는 주소(Proxy)와 소통하고, Proxy가 바라보는 로직(Implementation)만 교체하는 방식
    - UUPS (Universal Upgradeable Proxy Standard): 가스비가 저렴하고 안전한 최신 표준
- Architecture
    - Proxy
        - 사용자와 직접 상호작용하는 진입점(`ERC1967Proxy`)
        - 주소(`Address`)와 상태(`Storage`)를 저장
        - 절대 변하지 않음
    - Implementation
        - 실행 로직(`Code`) 저장
        - 데이터를 저장하지 않음
        - 교체 가능
- Mechanisms
    - DelegateCall
        - `Proxy`가 `Implementation(Logic)`의 코드를 실행
        - Context
        - `msg.sender` = 최초 호출자(`Proxy` 자신이 아님)
        - `msg.value` = 최초 전송된 이더
        - `Storage` = `Proxy`의 스토리지를 사용
    - Fallback Function
        - `Proxy`에 정의되지 않은 함수를 호출하면 `fallback`이 발동하여 `Logic`으로 `delegatecall`을 수행
- UUPS (Universal Upgradeable Proxy Standard)
    - 업그레이드 기능(upgradeTo)이 Logic 컨트랙트 내부에 구현
    - Proxy가 매우 가볍고 단순함 --> 가스비 절감
    - UUPSUpgradeable 상속
    - _authorizeUpgrade 함수 오버라이딩(onlyOwner 필수 적용)
    - Bricking Risk: V2 업그레이드 시에도 반드시 UUPS 기능을 포함해야 함(실수로 누락하면 영원히 업그레이드 불가능)
- Initialization Rules
    - initialize 함수 사용
        - Proxy는 Logic의 constructor를 실행할 수 없음
        - 일반 함수(initialize)를 만들어 Proxy 배포 직후 delegatecall로 실행하여 Proxy의 스토리지를 초기화
        - initializer modifier로 딱 한 번만 실행되도록 보호
    - constructor
        - 배포 즉시 `Logic` 본체의 `_initialized` 상태를 잠가버림(`_disableInitializers`)
- Storage Layout
    - Storage Collision: Proxy와 Logic, 혹은 Logic V1과 V2 간의 변수 위치가 겹쳐서 데이터가 오염되는 현상
    - Append-Only: 새로운 변수는 반드시 맨 뒤에 추가
    - __gap: 부모 컨트랙트를 만들 때, 50개 정도의 슬롯을 미리 예약(점유)


## Governor
- Lifecycle(State Machine)
    0. propose
        - 안건(실행할 함수, 데이터, 설명)을 제출
        - `hashProposal`을 통해 고유한 `proposalId`가 생성
    1. Pending
        - 제안이 생성(`Propose`)되었지만, 아직 투표가 시작되지 않은 상태
        - `Voting Delay`: 사람들이 안건을 검토할 시간
        - 이 기간 동안 스냅샷 블록이 확정(플래시 론 방어)
    2. Active
        - 본격적으로 투표(Cast Vote)가 가능한 상태
        - `Voting Period`: 투표 창구가 열려 있는 기간
    3. Succeeded / Defeated
        - 기간이 끝났을 때 결과를 판정
        - `Quorum`: 최소 참여 인원을 넘겨야 유효
    4. Queued(Timelock)
        - `Min Delay`: 혹시 모를 악의적 안건 통과에 대비해, 사용자들이 탈출할 수 있는 마지막 유예 기간
    5. Executed
        - 모든 대기 시간이 끝나면, 누구나 execute 함수를 호출 가능
        - `Governor`가 `ActionExecutor`를 통해 실제 함수(`call`)를 실행
- Modular Structure
    1. `Governor`
        - 추상 컨트랙트(`Abstract`)
        - 투표 로직, 설정, 타임락 등의 모듈을 붙일 수 있는 뼈대 역할
        - 제안(`Proposal`) 관리: 제안의 생성부터 투표, 실행까지의 생명주기(`Lifecycle`)를 관리
        - 투표 행사
            - `castVote`, `castVoteWithReason`: 유저가 직접 트랜잭션을 날려 투표
            - `castVoteBySig`: 유저의 오프체인 서명(`EIP-712`)을 받아 가스비 대납(`Gasless Voting`)이 가능하도록 지원
        - 실행 로직
            - `execute`: 제안 상태를 검증(`Succeeded` 또는 `Queued`)하고 실행 완료(`executed`)로 마킹합니다.
            - `_executeOperations`: 실제 타겟 컨트랙트로 트랜잭션을 보내는 부분입니다
        - 상태 조회
            - `state`: 특정 제안이 현재 어떤 상태인지(투표 중인지, 통과되었는지, 취소되었는지)를 리턴
    2. `GovernorSettings`
        - 설정값을 관리하고, 이 규칙 자체를 투표를 통해 바꿀 수 있게 해주는 모듈
        - `_votingDelay`: 제안(`Proposal`)이 올라온 후 투표가 시작되기까지의 대기 시간
        - `_votingPeriod`: 실제로 투표가 진행되는 기간
        - `_proposalThreshold`: 제안을 올리기 위해 필요한 최소한의 토큰 개수
        - `constructor(uint48 initialVotingDelay, uint32 initialVotingPeriod, uint256 initialProposalThreshold)`
        - 설정 변경 기능
            - 설정을 바꾸는 함수 존재
            - `onlyGovernance`
    3. `GovernorCountingSimple`
        - 3-Option System
            - 사용자는 투표 시 `support` 값으로 다음 3가지 중 하나를 선택 가능
            - 0(`Against`): 반대
            - 1(`For`): 찬성
            - 2(`Abstain`): 기권
        - Winning Criteria
            1. 정족수(Quorum) 달성 여부(`_quorumReached`): (찬성표 + 기권표) >= 정족수
            2. 다수결 승리 여부(`_voteSucceeded`): 찬성표 > 반대표
        - 집계 및 보안 로직
            - 중복 투표 방지: hasVoted 매핑을 사용
            - 가중치 합산: 사용자의 토큰 보유량(`totalWeight`)만큼 해당 옵션(`For/Against/Abstain`)의 카운터를 증가
        - 데이터 조회
            - `proposalVotes`: (`againstVotes`, `forVotes`, `abstainVotes`) 순서로 현재 득표수를 반환
    4. `GovernorVotes`
        - 투표권 토큰을 연결하는 다리(`Bridge`) 역할을 하는 모듈
        - constructor(IVotes tokenAddress)
            - 배포 시 이 거버넌스에서 사용할 토큰 주소를 받아서 `_token` 변수에 영구 저장(`immutable`)
            - 오직 저 토큰의 위임된 잔고(`Delegated Balance`)만을 투표권으로 인정
        - Snapshot
            - _getVotes: 제안이 올라온 시점의 과거 잔고(`getPastVotes`)를 조회
    5. `GovernorTimelockControl`
        - `Time Delay`를 추가하는 확장 모듈
        - Delegation
            - Governor는 "명령서(Schedule)"만 작성해서 TimelockController에게 전송
            - 실제 자금(Assets)과 권한(Ownership)은 TimelockController가 소유
            - Governor가 아니라 TimelockController가 타겟 컨트랙트를 최종 실행
        - 
    - Override
        - Governor
            1. quorum(uint256 blockNumber)
        - Governor & GovernorSettings
            1. votingDelay()
            2. votingPeriod()
            3. proposalThreshold()
        - Governor & GovernorTimelockControl
            1. state(uint256 proposalId)
            2. proposalNeedsQueuing(uint256 proposalId)
            3. _executeOperations(uint256 proposalId, address[] memory targets, ...)
            4. _queueOperations(uint256 proposalId, ...)
            5. _executor()
            6. _cancel(address[] memory targets, uint256[] memory values, ...)