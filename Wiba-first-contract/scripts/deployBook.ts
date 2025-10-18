import { network } from "hardhat";

const { ethers } = await network.connect();

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying with:", deployer.address);

  const Bookstore = await ethers.getContractFactory("Bookstore");
  const bookstore = await Bookstore.deploy();

  await bookstore.waitForDeployment();
  console.log("Bookstore deployed to:", await bookstore.getAddress());
}

main().catch(console.error);
