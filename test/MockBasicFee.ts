import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";

describe("MockBasicFee", function () {

  const FEE_BPS = 500; // should try with fees of 0 and 9999 as boundary conditions
  const STARTING_COINS = 10000;

  async function deployMockBasicFeeFixture() {

    // Contracts are deployed using the first signer/account by default
    const [owner, treasury, investor1, investor2] = await ethers.getSigners();

    const MockCoin = await ethers.getContractFactory("MockCoin");
    const mockCoin = await MockCoin.deploy();

    await mockCoin.mint(investor1.address, STARTING_COINS);
    await mockCoin.mint(investor2.address, STARTING_COINS);

    const MockBasicFee = await ethers.getContractFactory("MockBasicFee");
    const mockBasicFee = await MockBasicFee.deploy(mockCoin.address, "MockBasic", "MB", treasury.address, FEE_BPS);

    await mockCoin.connect(investor1).approve(mockBasicFee.address, STARTING_COINS);
    await mockCoin.connect(investor2).approve(mockBasicFee.address, STARTING_COINS);

    return { mockCoin, mockBasicFee, owner, treasury, investor1, investor2 };
  }

  describe("Deployment", function () {
    it("Should set the right asset, address and fee", async function () {
      const { mockCoin, mockBasicFee, owner, treasury } = await loadFixture(deployMockBasicFeeFixture);

      expect(await mockBasicFee.withdrawFeeBPS()).to.equal(FEE_BPS);
      expect(await mockBasicFee.feeAddress()).to.equal(treasury.address);
      expect(await mockBasicFee.asset()).to.equal(mockCoin.address);
    });

    it("Should fail if the fee is >= 100%", async function () {
      // We don't use the fixture here because we want a different deployment

      const MockBasicFee = await ethers.getContractFactory("MockBasicFee");
      await expect(MockBasicFee.deploy(ethers.constants.AddressZero, "", "", ethers.constants.AddressZero, 10000)).to.be.reverted;
    });
  });
  
  describe("Fees", function () {
    it("Should accept a deposit and return shares", async function () {
      const { mockCoin, mockBasicFee, owner, treasury, investor1 } = await loadFixture(deployMockBasicFeeFixture);

      await mockBasicFee.connect(investor1).deposit(100, investor1.address);
      expect(await mockBasicFee.balanceOf(investor1.address)).to.equal(100);
      expect(await mockCoin.balanceOf(investor1.address)).to.equal(STARTING_COINS - 100);
    });

    it("Should take fees on simple redeem", async function () {
      const { mockCoin, mockBasicFee, owner, treasury, investor1 } = await loadFixture(deployMockBasicFeeFixture);
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
      const { mockCoin, mockBasicFee, owner, treasury, investor1 } = await loadFixture(deployMockBasicFeeFixture);
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
      const { mockCoin, mockBasicFee, owner, treasury, investor1 } = await loadFixture(deployMockBasicFeeFixture);
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
      const { mockCoin, mockBasicFee, owner, treasury, investor1, investor2 } = await loadFixture(deployMockBasicFeeFixture);

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
});
