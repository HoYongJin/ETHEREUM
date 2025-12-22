# ERC20(Fungible)

## "@openzeppelin/contracts/token/ERC20/ERC20.sol"
- 대체 가능한(Fungible) 토큰: 어떤 하나의 토큰은 다른 어떤 토큰과도 완전히 동일
- IERC20 인터페이스를 구현
    - 조회(View Function)
        - 블록체인 상태를 변경하지 않고 읽기만
        - totalSupply(): 토큰이 세상에 총 몇 개 발행되었는가?
        - balanceOf(account): 특정 계정(account) 잔고가 얼마인가?
        - decimals(): 소수점 몇 자리인가? (보통 18을 씁니다. 1 토큰 = 10^18)
    - 직접 전송
        - transfer(to, amount): 내 지갑에서 to에게 amount만큼 전송
    - 위임 전송(남이 내 지갑에서 돈을 꺼내갈 수 있게 허락)
        - approve(spender, amount): 나의 토큰을 spender가 amount만큼 꺼내가는 것을 승인
        - allowance(owner, spender): owner가 spender에게 얼마만큼 꺼내가라고 허락했는지 확인
        - transferFrom(from, to, amount): from(토큰주인)이 msg.sender에게 amount 이상을 Approve 했는지 확인 후 amount만큼 to에게 전송
- Events
    - event Transfer(from, to, value): 토큰이 이동할 때마다 발생(Mint, Burn 포함)
    - event Approval(owner, spender, value): 승인(approve)이 일어날 때마다 발생
- Decimals(특별한 이유가 없다면 18로 사용)
    - 토큰을 원하는 만큼 쪼개고 싶을 때(5GLD --> 3.5GLD + 1.5GLD)
    - Solidity와 EVM은 정수(Integer)만 사용 가능하기 때문에 토큰을 쪼갤 수 없음
    - 이를 해결하기 위해, ERC-20은 decimals라는 필드를 제공하여 토큰이 소수점 몇째 자리까지 있는지를 명시
    - Ex) decimals=1 이라고 했을 때, 50은 5.0GLD를 의미 --> 15(1.5GLD)와 35(3.5GLD)로 쪼갤 수 있음
- mapping(address => uint256) private _balances: 누가(Address) 얼마(uint256)를 가지고 있는지 기록
- Extensions
    - ERC20Burnable: 토큰을 영구적으로 삭제(소각)하는 기능
    - ERC20Pausable: 해킹 등 비상시에 토큰 이동을 전체 정지시키는 기능
    - ERC20Capped: 발행량의 최대 한도(Cap)를 설정하는 기능
    - ERC20Permit: 가스비 없이 서명(Signature)만으로 approve를 하는 기능




# ERC721(Non Fungible)

## NFT
- 그림을 블록체인에 저장할 수 있을까? --> 불가능(막대한 가스비)
- 블록체인에는 Link만 남겨두고, 실제 그림과 설명은 Off-Chain에 저장(그림설명서: Metadata, 저장소: IPFS)
- Metadata(그림 설명서)
    - 그림에 대한 정보를 담은 텍스트파일(JSON)
    - OpenSea같은 마켓플레이스는 블록체인에 있는 그림을 보여주는 게 아니라, 이 Metadata(JSON)를 읽은 후 그림을 화면에 제공
    - NFT 토큰 하나는 Metadata(JSON) 파일의 위치(URI)만 알고 있음
- IPFS(InterPlanetary File System - 저장소)
    - Metadata(JSON)가 실제 저장된 저장소
    - HTTP는 위치(Location)기반이지만 IPFS는 내용(Content)기반으로 데이터를 찾음
    - 파일 내용이 점 하나라도 바뀌면 주소가 바뀜(주소가 같다면 내용은 절대 변하지 않았음을 보장)
    - 파일의 내용을 SHA-256으로 돌련 결과가 주소가 됨
    - CID (Content Identifier)
        - Multibase: 이 문자열이 base58로 인코딩됐는지, base32로 인코딩됐는지 알려주는 접두사.
        - Multicodec: 데이터가 어떤 형식인지(예: raw binary, Merkle DAG protobuf 등) 알려주는 식별자
        - Multihash: 실제 데이터의 해시값

- 전체 연결 구조
    1. 스마트 컨트랙트(BlockChain)
        - Token ID: 1
        - Token URI: ipfs://QmMetadataHash(메타데이터가 있는 주소)
    2. Metadata(IPFS - JSON)
        - "name": "ABC"
        - "image": "ipfs://QmImageHash" (이미지가 있는 주소)
        - 그림의 실제 데이터를 보유
    3. 이미지 파일(PNG/JPG)
        - 실제 그림

## "@openzeppelin/contracts/token/ERC721/ERC721.sol"
- 대체 불가능한(Non-Fungible) 토큰
- State Variables
    - _name: 토큰의 이름
    - _symbol: 토큰의 심볼
    - _owners(tokenId => address 매핑): "누가 이 토큰의 주인인가?"를 저장
    - _balances(address => uint256 매핑): 특정 주소가 총 몇 개의 NFT를 가지고 있는지
    - _tokenApprovals(uint256 => address 매핑): 특정 토큰 1개를 다른 사람에게 전송할 권한을 부여
    - _operatorApprovals(address => (address => bool) 매핑): 특정 지갑의 모든 NFT 관리 권한을 특정 지갑에 부여
- 표준 인터페이스 지원(ERC-165)
    - supportsInterface(bytes4 interfaceId): "이 컨트랙트가 ERC-721 표준을 따릅니까?"라는 질문에 대답
        - ERC165, IERC721, IERC721Metadata 인터페이스 ID 중 하나라도 일치하면 true를 반환
- 메타데이터 및 조회(Read Functions)
    - balanceOf(address owner): 주인의 잔고(NFT 개수)를 보여줌
    - ownerOf(uint256 tokenId): 해당 토큰 ID의 주인이 누구인지 리턴
    - tokenURI(uint256 tokenId): NFT의 메타데이터(이미지, 속성 등)가 저장된 인터넷 주소(URL)를 반환
    - _baseURI(): tokenURI의 앞부분(공통 주소)을 정의(기본적으로는 빈 문자열("")을 반환, 오버라이딩하여 사용)
- 권한 부여(Approvals)
    - approve(address to, uint256 tokenId): 내 NFT 하나를 to 주소가 대신 옮길 수 있게 허락
    - getApproved(uint256 tokenId): tokenId에 매핑된 _tokenApprovals 주소를 리턴
    - setApprovalForAll(address operator, bool approved): 내 지갑에 있는 모든 NFT를 operator가 옮길 수 있게 허락(또는 취소)
    - isApprovedForAll(address owner, address operator): owner가 operator에가 모든 권한을 넘겼는지 확인
- 전송 로직(Transfer Logic)
    - transferFrom(address from, address to, uint256 tokenId): from에서 to로 NFT(tokenId)를 전송
    - safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data): transferFrom과 똑같지만, 받는 쪽이 스마트 컨트랙트일 경우 NFT를 받을 수 있는지 확인(만약 받는 컨트랙트가 이에 올바르게 응답하지 않으면 전송을 취소(Revert)하여 NFT 유실을 막음)
- 내부 핵심 엔진(Internal Core)
    - _update(address to, uint256 tokenId, address auth): 전송, 민팅(생성), 소각(삭제)의 모든 상태 변경을 담당
        - to: 받는 사람 (0이면 소각)
        - tokenId: 토큰 ID
        - auth: 권한자 (0이 아니면 권한 체크 수행)
        - Logic
            1. 권한 체크: auth가 0이 아니면, 이 요청자가 전송 권한이 있는지 _checkAuthorized로 확인
            2. 보내는 사람 처리 (from)
                - 이전 주인의 승인(approve) 내용을 초기화
                - 이전 주인의 잔고(_balances)를 1 줄임
            3. 받는 사람 처리 (to): 받는 주인의 잔고(_balances)를 1 늘림
            4. 소유권 이전: _owners 매핑을 to로 변경
            5. 이벤트: Transfer 이벤트를 블록체인에 기록
    - _mint(address to, uint256 tokenId): 새로운 NFT 생성(_update(to, tokenId, address(0))를 호출)
    - _burn(uint256 tokenId): NFT를 삭제(_update(address(0), tokenId, address(0))를 호출)
    - _checkAuthorized(address owner, address spender, uint256 tokenId): spender가 이 토큰을 움직일 자격이 있는지 엄격하게 검사
    - _safeMint(address to, uint256 tokenId, bytes memory data): "받는 사람이 받을 능력이 있는지" 확인 후 _mint(to, tokenId) 호출

# EIP712(블록체인 서명 기술)
- 사용자가 "내가 지금 무엇에 서명하는지" 눈으로 보고 확인할 수 있게 해주는 표준
    - Ex) Message: 0x48656c6c6f20576f726c64 --> To: Alice Amount: 100 ETH Item: "Golden Sword" Deadline: 2025-12-31
- 데이터의 구조(Structure)와 내용(Content)을 분리해서 해싱
- 3단계 구조
    1. TypeHash(데이터 구조 정의)
        - 데이터의 스키마(Schema)를 해싱
        - keccak256("Voucher(address buyer,uint256 tokenId)")
            - "Voucher(address buyer,uint256 tokenId)"라는 구조를 가짐
        - 데이터 필드 순서가 바뀌거나 타입이 바뀌면 서명이 깨짐
    2. StructHash = hashStruct(message) (실제 값)
        - TypeHash + Data를 섞어서 해싱
        - keccak256(abi.encode(TypeHash, buyer, tokenId))
            - 실제 데이터: "byer: 0xUser, tokenId: 1"(동적 타입(string, bytes)은 값 자체가 아니라 keccak256(값)을 인코딩)
    3. Domain Separator(영역 구분자)
        - Context 정보들을 섞어서 해싱
        - 이 서명은 이더리움 메인넷(ID:1)의 이 컨트랙트(0xABC...)에서만 유효(다른 체인이나 다른 컨트랙트에서 재사용 공격(Replay Attack) 방지)
        - keccak256(abi.encode(TypeHash, NameHash, VersionHash, ChainId, VerifyingContract))
- Digest(최종 서명에 들어가는 해시값): keccack256("\x19\x01"||DomainSeparator||hashStruct(Message))