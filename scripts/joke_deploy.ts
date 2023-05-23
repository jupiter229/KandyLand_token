import { ethers } from "hardhat";
// import "@nomicfoundation/hardhat-verify";
const hre = require("hardhat");

async function main() {

  const url = "https://ipfs.io/ipfs/QmbeJNGDavH24XxULEc4uMtq4Z11DRYh7mqm5wAvAK9xFU/";
  const Joke = await ethers.getContractFactory("Joke");
  const joke = await Joke.deploy(url, url, url);

  await joke.deployed();

  console.log(`joke deployed to ${joke.address}`);

  setTimeout(async () => {
    console.log("\nVerifying contract...");
    try {
      await hre.run("verify:verify", {
        address: joke.address, 
        constructorArguments: [
          url, 
          url,
          url
        ]
      });
      console.log(`Contract ${joke.address} has been verified successfully!`)
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
