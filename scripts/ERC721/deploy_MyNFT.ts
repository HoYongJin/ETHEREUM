import { ethers, run, network } from "hardhat"; // run, network 추가

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log("Deploying with:", deployer.address);

    // 1. 배포
    const MyNFTFactory = await ethers.getContractFactory("MyNFT");
    const myNFT = await MyNFTFactory.deploy();
    await myNFT.waitForDeployment();
    
    const contractAddress = await myNFT.getAddress();
    console.log("MyNFT deployed to:", contractAddress);


    // 2. 민팅
    const tokenURI = "ipfs://bafkreiaok2xuspb5cnjajjaqa3n7qvr3maudvaryrj6fx72p5hqa5ybhzi..."; 
    const tx = await myNFT.mintNFT(deployer.address, tokenURI);
    await tx.wait();
    
    console.log(`Minted! Token URI: ${tokenURI}`);
    console.log(`View on Rarible: https://testnet.rarible.com/token/${contractAddress}:0`);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});