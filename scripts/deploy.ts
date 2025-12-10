import { ethers } from "hardhat";

async function main() {
  // 1. 배포할 컨트랙트 공장을 가져옵니다.
  // (contracts/ERC20/MyToken.sol 파일의 contract 이름과 일치해야 함)
  const MyToken = await ethers.getContractFactory("MyToken");

  // 2. 배포 트랜잭션을 생성합니다.
  console.log("Deploying MyToken...");
  const token = await MyToken.deploy();

  // 3. 배포가 완료될 때까지 기다립니다.
  await token.waitForDeployment();

  // 4. 배포된 주소를 출력합니다.
  console.log("MyToken deployed to:", await token.getAddress());
}

// 에러 처리 패턴 (Hardhat 권장)
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});