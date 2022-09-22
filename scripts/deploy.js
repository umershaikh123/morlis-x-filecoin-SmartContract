/** @format */

// const { hre, run, network } = require("hardhat");
const hre = require("hardhat");
const { run, network } = require("hardhat");

async function main() {
  const moralisContract = await hre.ethers.getContractFactory("funder");
  console.log("\n Deploying contract... \n");
  const contract = await moralisContract.deploy();
  await contract.deployed();
  console.log(`Deployed contract to: ${contract.address}`);

  console.log("Waiting for block confirmations...");
  await contract.deployTransaction.wait(6);
  await verify(contract.address, []);
}

const verify = async (contractAddress, args) => {
  console.log("\n Verifying contract... \n");

  try {
    await run("verify:verify", {
      address: contractAddress,
      constructorArguments: args,
    });
  } catch (e) {
    if (e.message.toLowerCase().includes("already verified")) {
      console.log("Already Verified!");
    } else {
      console.log(e);
    }
  }
};

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
