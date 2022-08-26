import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";

describe("MockFee", function () {

  const WITHDRAW_FEE_BPS = 500; // should try with fees of 0 and 9999 as boundary conditions
  const CARRY_FEE_BPS = 0;
  const ANNUAL_FEE_BPS = 0;
  const STARTING_COINS = 10000;

  async function deployMockFeeWithdrawFixture() {

    // Contracts are deployed using the first signer/account by default
    const [owner, treasury, investor1, investor2] = await ethers.getSigners();

    const MockCoin = await ethers.getContractFactory("MockCoin");
    const mockCoin = await MockCoin.deploy();

    await mockCoin.mint(investor1.address, STARTING_COINS);
    await mockCoin.mint(investor2.address, STARTING_COINS);

    const MockFee = await ethers.getContractFactory("MockFee");
    const mockFee = await MockFee.deploy(mockCoin.address, "MockFee", "MF", ANNUAL_FEE_BPS, CARRY_FEE_BPS, WITHDRAW_FEE_BPS, false, false);

    await mockCoin.connect(investor1).approve(mockFee.address, STARTING_COINS);
    await mockCoin.connect(investor2).approve(mockFee.address, STARTING_COINS);

    return { mockCoin, mockFee, owner, treasury, investor1, investor2 };
  }

  describe("Deployment", function () {
    it("Should set the right asset and fees", async function () {
      const { mockCoin, mockFee, owner, treasury } = await loadFixture(deployMockFeeWithdrawFixture);

      expect(await mockFee.withdrawFeeBPS()).to.equal(WITHDRAW_FEE_BPS);
      expect(await mockFee.carryFeeBPS()).to.equal(CARRY_FEE_BPS);
      expect(await mockFee.annualFeeBPS()).to.equal(ANNUAL_FEE_BPS);
      expect(await mockFee.asset()).to.equal(mockCoin.address);
    });

    it("Should fail if the fee is >= 100%", async function () {
      // We don't use the fixture here because we want a different deployment

      const MockFee = await ethers.getContractFactory("MockFee");
      await expect(MockFee.deploy(ethers.constants.AddressZero, "", "", 10000, 0, 0, false, false)).to.be.reverted;
      await expect(MockFee.deploy(ethers.constants.AddressZero, "", "", 0, 100000, 0, false, false)).to.be.reverted;
      await expect(MockFee.deploy(ethers.constants.AddressZero, "", "", 0, 0, 99990, false, false)).to.be.reverted;
    });
  });
  
  describe("Fees", function () {
    it("Should accept a deposit and return shares", async function () {
      const { mockCoin, mockFee, owner, treasury, investor1 } = await loadFixture(deployMockFeeWithdrawFixture);

      await mockFee.connect(investor1).deposit(100, investor1.address);
      expect(await mockFee.balanceOf(investor1.address)).to.equal(100);
      expect(await mockCoin.balanceOf(investor1.address)).to.equal(STARTING_COINS - 100);
    });

    it("Should take fees on simple redeem", async function () {
      const { mockCoin, mockFee, owner, treasury, investor1 } = await loadFixture(deployMockFeeWithdrawFixture);
      const ASSET_DEPOSIT = 1000;

      await mockFee.connect(investor1).deposit(ASSET_DEPOSIT, investor1.address);
      expect(await mockFee.balanceOf(investor1.address)).to.equal(ASSET_DEPOSIT);
      const shares = await mockFee.connect(investor1).maxRedeem(investor1.address);
      expect(shares).to.equal(ASSET_DEPOSIT);
      await mockFee.connect(investor1).redeem(shares, investor1.address, investor1.address);
      const fee = ASSET_DEPOSIT * WITHDRAW_FEE_BPS / 10000;
      expect(await mockFee.accruedFees()).to.equal(fee);
      expect(await mockCoin.balanceOf(investor1.address)).to.equal(STARTING_COINS - fee);
    });

    it("Should take correct fees when NAV has grown", async function () {
      const { mockCoin, mockFee, owner, treasury, investor1 } = await loadFixture(deployMockFeeWithdrawFixture);
      const ASSET_DEPOSIT = 1000;

      await mockFee.connect(investor1).deposit(ASSET_DEPOSIT, investor1.address);
      expect(await mockFee.balanceOf(investor1.address)).to.equal(ASSET_DEPOSIT);
      await mockCoin.mint(mockFee.address, ASSET_DEPOSIT); // double tokens in vault

      const totalAssets = await mockFee.totalAssets();
      const fee = totalAssets.toNumber() * WITHDRAW_FEE_BPS / 10000;

      const shares = await mockFee.connect(investor1).maxRedeem(investor1.address);
      expect(shares).to.equal(ASSET_DEPOSIT);
      await mockFee.connect(investor1).redeem(shares, investor1.address, investor1.address);

      expect(await mockFee.accruedFees()).to.equal(fee);
      expect(await mockCoin.balanceOf(investor1.address)).to.equal(STARTING_COINS + ASSET_DEPOSIT - fee);
    });

    it("Should compute fees correctly on withdraw", async function () {
      const { mockCoin, mockFee, owner, treasury, investor1 } = await loadFixture(deployMockFeeWithdrawFixture);
      const ASSET_DEPOSIT = 1000;
      const ASSET_WITHDRAW = 300;

      await mockFee.connect(investor1).deposit(ASSET_DEPOSIT, investor1.address);
      expect(await mockFee.balanceOf(investor1.address)).to.equal(ASSET_DEPOSIT);

      const fee = Math.ceil(ASSET_WITHDRAW * 10000 / (10000 - WITHDRAW_FEE_BPS)) - ASSET_WITHDRAW;
      const shares = await mockFee.connect(investor1).previewWithdraw(ASSET_WITHDRAW);
      await (await mockFee.connect(investor1).withdraw(ASSET_WITHDRAW, investor1.address, investor1.address)).wait();
      expect(shares).to.be.greaterThan(ASSET_WITHDRAW);
      expect(await mockFee.accruedFees()).to.equal(fee);
      expect(await mockCoin.balanceOf(investor1.address)).to.equal(STARTING_COINS - ASSET_DEPOSIT + ASSET_WITHDRAW);
    });

    it("Should compute fees correctly with multiple investors and gains or losses", async function () {
      const { mockCoin, mockFee, owner, treasury, investor1, investor2 } = await loadFixture(deployMockFeeWithdrawFixture);

      const INV1_DEPOSIT = 1000;
      const INV2_DEPOSIT = 400;
      const INV1_REDEEM = 400;
      const INV2_WITHDRAW = 300;
      const VAULT_RETURN_PCT = 250;

      await mockFee.connect(investor1).deposit(INV1_DEPOSIT, investor1.address);
      await mockFee.connect(investor2).deposit(INV2_DEPOSIT, investor2.address);
      expect(await mockFee.balanceOf(investor1.address)).to.equal(INV1_DEPOSIT);
      expect(await mockFee.balanceOf(investor2.address)).to.equal(INV2_DEPOSIT);

      var totalSupply = INV1_DEPOSIT + INV2_DEPOSIT;
      var totalAssets = Math.floor(totalSupply * VAULT_RETURN_PCT / 100);

      if (totalAssets > totalSupply) {
        await mockCoin.mint(mockFee.address, totalAssets - totalSupply); // increase vault value
      } else {
        await mockCoin.burn(mockFee.address, totalSupply - totalAssets); // decrease vault value
      }

      var inv1assets = Math.floor(INV1_REDEEM * totalAssets / totalSupply);
      var inv1fee = Math.ceil(inv1assets * WITHDRAW_FEE_BPS / 10000);
      inv1assets -= inv1fee;
      expect (await mockFee.connect(investor1).previewRedeem(INV1_REDEEM)).to.equal(inv1assets);

      var inv2grossAssets = Math.ceil(INV2_WITHDRAW * 10000 / (10000-WITHDRAW_FEE_BPS));
      var inv2shares = Math.ceil(inv2grossAssets * totalSupply / totalAssets);
      var inv2fee = inv2grossAssets - INV2_WITHDRAW;
      expect (await mockFee.connect(investor2).previewWithdraw(INV2_WITHDRAW)).to.equal(inv2shares);

      await (await mockFee.connect(investor1).redeem(INV1_REDEEM, investor1.address, investor1.address)).wait();
      expect(await mockCoin.balanceOf(investor1.address)).to.equal(STARTING_COINS - INV1_DEPOSIT + inv1assets);
      expect(await mockFee.balanceOf(investor1.address)).to.equal(INV1_DEPOSIT - INV1_REDEEM);
      expect(await mockFee.accruedFees()).to.equal(inv1fee);
      
      await (await mockFee.connect(investor2).withdraw(INV2_WITHDRAW, investor2.address, investor2.address)).wait();
      expect(await mockCoin.balanceOf(investor2.address)).to.equal(STARTING_COINS - INV2_DEPOSIT + INV2_WITHDRAW);
      expect(await mockFee.balanceOf(investor2.address)).to.equal(INV2_DEPOSIT - inv2shares);

      expect(await mockFee.accruedFees()).to.equal(inv1fee+inv2fee);

    });

/* TODO: compare withdraw fee calc between BasicFeee and Fee to ensure they are the same

Tests to write:
Carry Fee:
0 fee when 0 gain
0 fee when negative gain
Fee calculated correctly on gain
Deposits and withdrawals reset basis correctly
Second investor with higher basis carry calculated correctly
Carry for first investor not affected by second investor in our out

Annual fee:
0 fee when set to 0
Correct fee when one year passes
Fee resets correctly when basis resets
Deposits and withdrawals reset totalBasis correctly

Combinations:
Withdraw and carry compute correctly
Withdraw and annual compute correctly
Carry and annual compute correctly
All 3 together compute correctly

Manager functions:
One-time fee can be disabled
One-time fee accrues properly
Negative one-time fee accrues properly
Normal fee can be drawn properly
Fee can be repaid
Fee advance can be disabled
Fee larger than accrued can be drawn if advance enabled
totalAssets updated properly when fees accrued / drawn
*/

  });
});
