import { ethers } from "hardhat";

async function main() {
  const multiCall = await ethers.deployContract("EIP712MultiCall");
  await multiCall.waitForDeployment();

  console.log("EIP712MultiCall deployed to:", await multiCall.getAddress());
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});