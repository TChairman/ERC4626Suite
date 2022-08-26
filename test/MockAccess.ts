import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";

describe("MockAccess", function () {

  const STARTING_COINS = 10000;

  async function deployMockAccessFixture() {

    // Contracts are deployed using the first signer/account by default
    const [owner, treasury, investor1, investor2] = await ethers.getSigners();

    const MockCoin = await ethers.getContractFactory("MockCoin");
    const mockCoin = await MockCoin.deploy();

    await mockCoin.mint(investor1.address, STARTING_COINS);
    await mockCoin.mint(investor2.address, STARTING_COINS);

    const MockAccess = await ethers.getContractFactory("MockAccess");
    const mockAccess = await MockAccess.deploy(mockCoin.address, "MockAccess", "MA");

    await mockCoin.connect(investor1).approve(mockAccess.address, STARTING_COINS);
    await mockCoin.connect(investor2).approve(mockAccess.address, STARTING_COINS);

    return { mockCoin, mockAccess, owner, treasury, investor1, investor2 };
  }

  async function deployWhitelistRouterFixture() {

    // Contracts are deployed using the first signer/account by default, don't want same owner
    const [,, investor1, investor2, routerOwner] = await ethers.getSigners();

    const WhitelistRouter = await ethers.getContractFactory("GlobalWhitelistERC4626Router");
    const whitelistRouter = await WhitelistRouter.connect(routerOwner).deploy();

    // start with whitelist investor1 but not investor2
    await whitelistRouter.whitelist(investor1.address);

    return { whitelistRouter, routerOwner };
  }

  describe("Deployment", function () {
    it("Should set the right asset, name and symbol", async function () {
      const { mockCoin, mockAccess, owner, treasury } = await loadFixture(deployMockAccessFixture);

      expect(await mockAccess.asset()).to.equal(mockCoin.address);
      expect(await mockAccess.name()).to.equal("MockAccess");
      expect(await mockAccess.symbol()).to.equal("MA");
    });

    it("Should set DEFAULT_ADMIN_ROLE for owner", async function () {
      const { mockCoin, mockAccess, owner, treasury } = await loadFixture(deployMockAccessFixture);

      var adminRole = await mockAccess.DEFAULT_ADMIN_ROLE();
      expect(await mockAccess.hasRole(adminRole, owner.address)).to.be.true;
    });
  });

/* Tests to write:
Admin Roles
Only owner can pause and disable deposits, withdraws, and transfers
Only owner can grant deposit, withdraw, and transfer roles

Basic Access // could extract these into separate test file
Reject mints, deposits, withdraws, redeems, and transfers when paused
Reject deposits when deposit disabled
Reject withdraws when withdraw disabled
Reject transfers when transfer disabled

Whitelists
Reject deposits unless on DEPOSIT list
Reject withdraws unless on WITHDRAW list
Reject transfers unless on TRANSFER list
Open deposits allows anyone to deposit
Open withdraws allows anyone to withdraw
Open transfers allows anyone to transfer
Disable deposit overrides open deposit

Router Access
Deposit via router succeeds, coins transferred correctly
Withdraw via router succeeds, coins transferred correctly
Transfer via router succeeds, coins transferred correctly
Deposit fails if not on router whitelist
Transfer fails if "to" not on router whitelist
Access can be revoked
  */
});
