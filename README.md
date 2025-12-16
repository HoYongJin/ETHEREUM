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