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
    const mockAccess = await MockAccess.deploy(mockCoin.address, "MockAccess", "MOCK");

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
      expect(await mockAccess.symbol()).to.equal("MOCK");
    });

    it("Should set DEFAULT_ADMIN_ROLE for owner", async function () {
      const { mockCoin, mockAccess, owner, treasury } = await loadFixture(deployMockAccessFixture);

      var adminRole = await mockAccess.DEFAULT_ADMIN_ROLE();
      expect(await mockAccess.hasRole(adminRole, owner.address)).to.be.true;
    });
  });

  /*
Admin Roles
Only owner can pause and disable deposits, withdraws, and transfers
Only owner can grant deposit, withdraw, and transfer roles

Basic Access
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




  describe("Fees", function () {
    it("Should accept a deposit and return shares", async function () {
      const { mockCoin, mockBasicFee, owner, treasury, investor1 } = await loadFixture(deployMockAccessFixture);

      await mockBasicFee.connect(investor1).deposit(100, investor1.address);
      expect(await mockBasicFee.balanceOf(investor1.address)).to.equal(100);
      expect(await mockCoin.balanceOf(investor1.address)).to.equal(STARTING_COINS - 100);
    });

    it("Should take fees on simple redeem", async function () {
      const { mockCoin, mockBasicFee, owner, treasury, investor1 } = await loadFixture(deployMockAccessFixture);
      const ASSET_DEPOSIT = 1000;

      await mockBasicFee.connect(investor1).deposit(ASSET_DEPOSIT, investor1.address);
      expect(await mockBasicFee.balanceOf(investor1.address)).to.equal(ASSET_DEPOSIT);
      const shares = await mockBasicFee.connect(investor1).maxRedeem(investor1.address);
      expect(shares).to.equal(ASSET_DEPOSIT);
      await mockBasicFee.connect(investor1).redeem(shares, investor1.address, investor1.address);
      const fee = ASSET_DEPOSIT * FEE_BPS / 10000;
      expect(await mockCoin.balanceOf(treasury.address)).to.equal(fee);
      expect(await mockCoin.balanceOf(investor1.address)).to.equal(STARTING_COINS - fee);
    });

    it("Should take correct fees when NAV has grown", async function () {
      const { mockCoin, mockBasicFee, owner, treasury, investor1 } = await loadFixture(deployMockAccessFixture);
      const ASSET_DEPOSIT = 1000;

      await mockBasicFee.connect(investor1).deposit(ASSET_DEPOSIT, investor1.address);
      expect(await mockBasicFee.balanceOf(investor1.address)).to.equal(ASSET_DEPOSIT);
      await mockCoin.mint(mockBasicFee.address, ASSET_DEPOSIT); // double tokens in vault

      const totalAssets = await mockBasicFee.totalAssets();
      const fee = totalAssets.toNumber() * FEE_BPS / 10000;

      const shares = await mockBasicFee.connect(investor1).maxRedeem(investor1.address);
      expect(shares).to.equal(ASSET_DEPOSIT);
      await mockBasicFee.connect(investor1).redeem(shares, investor1.address, investor1.address);

      expect(await mockCoin.balanceOf(treasury.address)).to.equal(fee);
      expect(await mockCoin.balanceOf(investor1.address)).to.equal(STARTING_COINS + ASSET_DEPOSIT - fee);
    });

    it("Should compute fees correctly on withdraw", async function () {
      const { mockCoin, mockBasicFee, owner, treasury, investor1 } = await loadFixture(deployMockAccessFixture);
      const ASSET_DEPOSIT = 1000;
      const ASSET_WITHDRAW = 300;

      await mockBasicFee.connect(investor1).deposit(ASSET_DEPOSIT, investor1.address);
      expect(await mockBasicFee.balanceOf(investor1.address)).to.equal(ASSET_DEPOSIT);

      const fee = Math.ceil(ASSET_WITHDRAW * 10000 / (10000 - FEE_BPS)) - ASSET_WITHDRAW;
      const shares = await mockBasicFee.connect(investor1).previewWithdraw(ASSET_WITHDRAW);
      await (await mockBasicFee.connect(investor1).withdraw(ASSET_WITHDRAW, investor1.address, investor1.address)).wait();
      expect(shares).to.be.greaterThan(ASSET_WITHDRAW);
      expect(await mockCoin.balanceOf(treasury.address)).to.equal(fee);
      expect(await mockCoin.balanceOf(investor1.address)).to.equal(STARTING_COINS - ASSET_DEPOSIT + ASSET_WITHDRAW);
    });

    it("Should compute fees correctly with multiple investors and gains or losses", async function () {
      const { mockCoin, mockBasicFee, owner, treasury, investor1, investor2 } = await loadFixture(deployMockAccessFixture);

      const INV1_DEPOSIT = 1000;
      const INV2_DEPOSIT = 400;
      const INV1_REDEEM = 400;
      const INV2_WITHDRAW = 300;
      const VAULT_RETURN_PCT = 250;

      await mockBasicFee.connect(investor1).deposit(INV1_DEPOSIT, investor1.address);
      await mockBasicFee.connect(investor2).deposit(INV2_DEPOSIT, investor2.address);
      expect(await mockBasicFee.balanceOf(investor1.address)).to.equal(INV1_DEPOSIT);
      expect(await mockBasicFee.balanceOf(investor2.address)).to.equal(INV2_DEPOSIT);

      var totalSupply = INV1_DEPOSIT + INV2_DEPOSIT;
      var totalAssets = Math.floor(totalSupply * VAULT_RETURN_PCT / 100);

      if (totalAssets > totalSupply) {
        await mockCoin.mint(mockBasicFee.address, totalAssets - totalSupply); // increase vault value
      } else {
        await mockCoin.burn(mockBasicFee.address, totalSupply - totalAssets); // decrease vault value
      }

      var inv1assets = Math.floor(INV1_REDEEM * totalAssets / totalSupply);
      var inv1fee = Math.ceil(inv1assets * FEE_BPS / 10000);
      inv1assets -= inv1fee;
      expect (await mockBasicFee.connect(investor1).previewRedeem(INV1_REDEEM)).to.equal(inv1assets);

      var inv2grossAssets = Math.ceil(INV2_WITHDRAW * 10000 / (10000-FEE_BPS));
      var inv2shares = Math.ceil(inv2grossAssets * totalSupply / totalAssets);
      var inv2fee = inv2grossAssets - INV2_WITHDRAW;
      expect (await mockBasicFee.connect(investor2).previewWithdraw(INV2_WITHDRAW)).to.equal(inv2shares);

      await (await mockBasicFee.connect(investor1).redeem(INV1_REDEEM, investor1.address, investor1.address)).wait();
      expect(await mockCoin.balanceOf(investor1.address)).to.equal(STARTING_COINS - INV1_DEPOSIT + inv1assets);
      expect(await mockBasicFee.balanceOf(investor1.address)).to.equal(INV1_DEPOSIT - INV1_REDEEM);
      expect(await mockCoin.balanceOf(treasury.address)).to.equal(inv1fee);
      
      await (await mockBasicFee.connect(investor2).withdraw(INV2_WITHDRAW, investor2.address, investor2.address)).wait();
      expect(await mockCoin.balanceOf(investor2.address)).to.equal(STARTING_COINS - INV2_DEPOSIT + INV2_WITHDRAW);
      expect(await mockBasicFee.balanceOf(investor2.address)).to.equal(INV2_DEPOSIT - inv2shares);

      expect(await mockCoin.balanceOf(treasury.address)).to.equal(inv1fee+inv2fee);
    });


  });
  */
});
