import { ethers } from "hardhat";

async function main() {
  const assetAddress = "0x00";
  const treasuryAddress = "0x00";

  const VaultContract = await ethers.getContractFactory("MockBasicFee");
  const vault = await VaultContract.deploy(assetAddress, "MyVault", "MV", treasuryAddress, 50);

  await vault.deployed();

  console.log(`Vault deployed to ${vault.address}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
