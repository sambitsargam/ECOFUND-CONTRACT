import { expect } from "chai";
import { ethers } from "hardhat";

describe("EcoFund Factory", function () {
  describe("depositFunds", async () => {
    let factory: any;
    beforeEach(async () => {
      const EcoFundFactory = await ethers.getContractFactory("EcoFundFactory");
      factory = await EcoFundFactory.deploy();
      await factory.deployed();
    });

    it("Should revert ETH deposit if you attempt to pay 0", async () => {
      await expect(factory.depositFunds(0, ethers.constants.AddressZero)).to.be.revertedWith(
        "EcoFundFactory__deposit__zero_deposit"
      );
    });

    it("Should revert ETH deposit if you don't transfer enough", async () => {
      await expect(factory.depositFunds(100, ethers.constants.AddressZero)).to.be.revertedWith(
        "EcoFundFactory__deposit__less_than_declared"
      );
    });
  });
});
