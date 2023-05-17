import { ethers } from "hardhat";
// import "@nomicfoundation/hardhat-verify";
const hre = require("hardhat");

async function main() {

  const marketingWallet = "0xe685355e3005260D2117189795d79b3FD60896Fe";
  const devWallet = "0xDE76f17adbF21C96aeBbDc103b0cd044D4E178BF";
  const KandyLand = await ethers.getContractFactory("KandyLand");
  const kandyLand = await KandyLand.deploy(marketingWallet, devWallet);

  await kandyLand.deployed();

  console.log(`KandyLand deployed to ${kandyLand.address}`);

  setTimeout(async () => {
    console.log("\nVerifying contract...");
    try {
      await hre.run("verify:verify", {
        address: kandyLand.address, 
        constructorArguments: [
          marketingWallet, 
          devWallet
        ]
      });
      console.log(`Contract ${kandyLand.address} has been verified successfully!`)
    } catch (error) {
      console.log(error);
    }
    
  }, 5000);
  

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
