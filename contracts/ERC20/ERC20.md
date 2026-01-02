# ERC20(Fungible)

## ERC20

## "@openzeppelin/contracts/token/ERC20/ERC20.sol"

- 대체 가능한(Fungible) 토큰: 어떤 하나의 토큰은 다른 어떤 토큰과도 완전히 동일
- IERC20 인터페이스를 구현
- State Variables
    - private _balances: 특정 주소의 잔고를 저장하는 매핑
    - private _allowances: [`address`][`spender`] => 금액 형태의 2차원 매핑(위임 전송 권한을 관리)
    - private _totalSupply: 현재 세상에 존재하는 토큰의 총개수
    - private _name
    - private _symbol
- constructor
     - name, symbol을 인자로 받아서 `State Variables(_name, _symbol)` 초기화
- The Core Logic(_update(address from, address to, uint256 value))
    - 전송(`Transfer`), 발행(`Mint`), 소각(`Burn`) 로직이 `_update` 함수로 통합됨
    1. Source
        - if(from == address(0)) (Minting의 경우)
        - `_totalSupply`(총 발행량)를 증가
        - else(일반 전송 또는 Burning)
        - 잔고 확인 후, 부족하면 `revert`
        - _balances[from]을 value 만큼 줄임
    2. Destination
        - if(to == address(0)) (Burning의 경우)
        - `_totalSupply`(총 발행량)를 감소
        - else(일반 전송 또는 Minting)
        - 전체 발행량(`_totalSupply`)은 uint256의 범위 관리
        - `_balances[from]`을 `value` 만큼 줄임 늘림
- _mint(address account, uint256 value)
    - address(0)로의 mint는 revert
    - 내부적으로 `_update(address(0), account, value)` 호출
- _burn(address account, uint256 value)
    - address(0)에서 burn은 revert
    - 내부적으로 `_update(account, address(0), value)` 호출
- transfer(address to, uint256 value)
    - `_msgSender()` 함수로 `owner`를 설정
    - 내부적으로 `_transfer(owner, to, value)` 호출
    - `_transfer`는 `owner`와 `to`가 `address(0)`인지 확인 후 하나라도 `address(0)`이면 `revert`
    - `_transfer`에서 내부적으로 `_update(from, to, value)` 호출
- Allowance Logic
    - 위임 권한 관리 시스템(내가 허락한 만큼만 남(`Spender`)이 내 돈을 가져가도 좋다)
    1. approve(address spender, uint256 value)
        - "누구에게 얼마를 허락할지" 설정하는 함수
        - `msg.sender`가 `spender`에게 `value` 만큼 사용할 수 있도록 설정
        - `_approve(owner, spender, value)` `internal function` 호출
    2. allowance(address owner, address spender)
        - `_allowances`에서 값을 읽어옴
        - `owner`가 `spender`에게 `approve`한 금액을 읽어옴
    3. transferFrom(address from, address to, uint256 value)
        - 대리인(`Spender`)이 호출하는 함수
        - `_spendAllowance`를 통해 권한을 검증하고, 통과하면 `_transfer` 실행
    4. _spendAllowance(address owner, address spender, uint256 value)
        - if(currentAllowance < type(uint256).max)
        - 가져가려는 돈(`value`)보다 허락된 돈(`currentAllowance`)이 적으면 에러
        - `_approve(owner, spender, currentAllowance - value, false)`
        - else
        - 승인 잔고(`_allowances`)가 줄어들지 않고 계속 최댓값으로 유지
        - 스토리지 쓰기 비용(`SSTORE`)이 발생하지 않아 가스비가 대폭 절약
- Decimals(특별한 이유가 없다면 18로 사용)
    - 토큰을 원하는 만큼 쪼개고 싶을 때(5GLD --> 3.5GLD + 1.5GLD)
    - `Solidity`와 `EVM`은 정수(`Integer`)만 사용 가능하기 때문에 토큰을 쪼갤 수 없음
    - 이를 해결하기 위해, ERC-20은 decimals라는 필드를 제공하여 토큰이 소수점 몇째 자리까지 있는지를 명시
    - Ex. decimals=1 이라고 했을 때, 50은 5.0GLD를 의미 --> 15(1.5GLD)와 35(3.5GLD)로 쪼갤 수 있음

## ERC20Permit

## "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol"

- 가스비 없는 승인(`Approve`)을 구현
- 암호학적 서명(`Signature`)과 `EIP-712` 표준을 결합
- Type Hash
    - `keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)")`
- constructor
    - `name`(토큰의 이름)을 입력 받아서 EIP712를 초기화(`EIP712(name, "1")`)
- permit
    - `approve`를 대신하는 핵심
    - 사용자는 트랜잭션을 보내지 않고, 서명(`v, r, s`)만 `relayer`에게 전달
    - `parameter`: `owner`, `spender`, `value`, `deadline`, `v`, `r`, `s`
        1. 서명에 포함된 deadline 시간이 지났는지 확인
        2. Create StructHash
        3. Create digest
        4. Recover Signer
        5. Validate Signer
        6. Approve(_approve(owner, spender, value) 내부적으로 호출)
- nonces(address owner)
    - 현재 특정 유저의 Nonce 값을 조회
- DOMAIN_SEPARATOR()
    - 현재 컨트랙트의 도메인 구분자 해시를 반환

## ERC20Votes

## "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol"

- `ERC20` 토큰에 거버넌스 투표 기능(`Voting Power`)을 추가한 확장 표준
- `ERC20`(자산)과 `Votes`(투표 로직) 컨트랙트를 상속받아 연결
- 체크포인트(`Checkpoints`) 시스템을 통해 과거 특정 시점의 투표권을 조회 가능(이중 투표 방지)
- Structs & Limits
    - Checkpoint208
        - 가스비 최적화를 위해 하나의 스토리지 슬롯(256bit)에 데이터를 꽉 채움
        - `key`(48bit, 시점) + `value`(208bit, 투표 수량)
    - Max Supply
        - 위 구조체 제한으로 인해 토큰의 최대 발행량이 `type(uint208).max(2^{208}-1)`로 제한
        - 이를 초과하여 발행 시 `ERC20ExceededSafeSupply` 에러 발생
- Key Functions
    - _update(from, to, value)
        - `ERC20`의 `transfer`, `mint`, `burn` 시 호출되는 `Hook` 함수를 오버라이딩
        1. `super._update`를 호출하여 토큰 잔액 변경
        2. 총 발행량이 `_maxSupply`를 넘는지 검사
        3. `_transferVotingUnits`를 호출하여 실질적인 투표권(`Delegatee`의 파워)을 갱신
    - _maxSupply()
        - 토큰의 안전한 최대 공급량을 반환 (`uint208` 최대값)
    - _getVotingUnits(account)
        - 특정 계정의 투표권을 계산하는 공식 정의
        - `default`: `balanceOf(account)` (1 토큰 = 1 투표권)
    - numCheckpoints(account)
        - 해당 계정의 투표권 변경 이력(체크포인트)의 총개수 반환
    - checkpoints(account, pos)
        - 해당 계정의 `pos`번째 체크포인트 기록 구조체를 반환
- Mechanism
    - 위임(Delegation)
        - 토큰을 보유하는 것만으로는 투표권(`Votes`)이 0
        - `delegate(myself)` 또는 `delegate(others)`를 호출해야 체크포인트 기록이 시작
    - 투표권의 이동
        - Alice가 Bob에게 토큰을 보내면, "Alice가 위임한 사람"의 표가 줄고, "Bob이 위임한 사람"의 표가 늘어남
    - 스냅샷 조회
        - getPastVotes(account, timepoint)를 통해 안건이 올라온 시점(과거 블록)의 투표권을 이진 탐색(Binary Search)으로 조회