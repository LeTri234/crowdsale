// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');
  // We get the contract to deploy
  const account = "0x70997970c51812dc3a010c7d01b50e0d17dc79c8";
  const Token = await hre.ethers.getContractFactory("Token");
  const token = await Token.deploy();
  await token.deployed();

  const TimelockToken = await hre.ethers.getContractFactory("TimelockToken");
  const timelockToken = await TimelockToken.deploy(token.address);
  await timelockToken.deployed();

  const RefundVault = await hre.ethers.getContractFactory("RefundVault");
  const vault = await RefundVault.deploy(account);
  await vault.deployed();

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
