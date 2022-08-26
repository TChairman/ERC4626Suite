import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import dotenv from "dotenv";

// if .env not being found, make sure you are running npx hardhat from same dir as .env
dotenv.config();

const config: HardhatUserConfig = {
  solidity: "0.8.9",
};

const GOERLI_ACCOUNTS = process.env.GOERLI_PRIVATE_KEY ? [process.env.GOERLI_PRIVATE_KEY] : [];
const GOERLI_URL = process.env.GOERLI_URL ? process.env.GOERLI_URL : "";
const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY ? process.env.ETHERSCAN_API_KEY : "";

module.exports = {
  solidity: "0.8.9",
  networks: {
    goerli: {
      url: GOERLI_URL,
      accounts: GOERLI_ACCOUNTS
    },
  },
  etherscan: {
    apiKey: ETHERSCAN_API_KEY
  }
};

export default config;
