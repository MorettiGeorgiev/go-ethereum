const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");

describe("Lock", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployOneYearLockFixture(unlockTimestamp) {
    const ONE_YEAR_IN_SECS = 365 * 24 * 60 * 60;
    const ONE_GWEI = 1_000_000_000;

    const lockedAmount = ONE_GWEI;
    
    // Get the current block information
    const blockNumBefore = await ethers.provider.getBlockNumber();
    const blockBefore = await ethers.provider.getBlock(blockNumBefore);
    const timestampBefore = blockBefore.timestamp;
    const unlockTime = unlockTimestamp || timestampBefore + ONE_YEAR_IN_SECS;

    // Contracts are deployed using the first signer/account by default
    const [owner, otherAccount] = await ethers.getSigners();

    const Lock = await ethers.getContractFactory("Lock");
    const lock = await Lock.deploy(unlockTime, { value: lockedAmount });
    
    // Wait for contract to be deployed and confirmed
    await lock.deploymentTransaction().wait();
    
    // Verify contract was deployed successfully
    const code = await ethers.provider.getCode(lock.target);
    if (code === '0x') {
      throw new Error('Contract deployment failed');
    }
  

    return { lock, unlockTime, lockedAmount, owner, otherAccount };
  }

  describe("Deployment", function () {
    it("Should set the right unlockTime", async function () {
      const { lock, unlockTime } = await deployOneYearLockFixture();

      expect(await lock.unlockTime()).to.equal(unlockTime);
    });

    it("Should set the right owner", async function () {
      const { lock, owner } = await deployOneYearLockFixture();
      expect(await lock.owner()).to.equal(owner.address);
    });

    it("Should receive and store the funds to lock", async function () {
      const { lock, lockedAmount } = await deployOneYearLockFixture();

      expect(await ethers.provider.getBalance(lock.target)).to.equal(
        lockedAmount
      );
    });

    it("Should fail if the unlockTime is not in the future", async function () {
      // We don't use the fixture here because we want a different deployment
      const blockNumber = await ethers.provider.getBlockNumber();
      const block = await ethers.provider.getBlock(blockNumber);
      const latestTime = block.timestamp;
      const Lock = await ethers.getContractFactory("Lock");
      await expect(Lock.deploy(latestTime, { value: 1 })).to.be.revertedWith(
        "Unlock time should be in the future"
      );
    });
  });

  describe("Withdrawals", function () {
    describe("Validations", function () {
      it("Should revert with the right error if called too soon", async function () {
        const { lock } = await deployOneYearLockFixture();

        await expect(lock.withdraw()).to.be.revertedWith(
          "You can't withdraw yet"
        );
      });

      it("Should revert with the right error if called from another account", async function () {
        const twoSecsFromNow = Math.floor(Date.now() / 1000) + 2;
        const { lock, otherAccount } = await deployOneYearLockFixture(twoSecsFromNow)

        await new Promise(resolve => setTimeout(resolve, 2000));

        // We use lock.connect() to send a transaction from another account
        await expect(lock.connect(otherAccount).withdraw()).to.be.revertedWith(
          "You aren't the owner"
        );
      });

      it("Shouldn't fail if the unlockTime has arrived and the owner calls it", async function () {
        const twoSecsFromNow = Math.floor(Date.now() / 1000) + 2;
        const { lock } = await deployOneYearLockFixture(twoSecsFromNow)

        await new Promise(resolve => setTimeout(resolve, 2000));

        // Transactions are sent using the first signer by default
        const tx = await lock.withdraw();
        await tx.wait();

        await expect(tx).not.to.be.reverted;
      });
    });

    describe("Events", function () {
      it("Should emit an event on withdrawals", async function () {
        const twoSecsFromNow = Math.floor(Date.now() / 1000) + 2;
        const { lock, lockedAmount } = await deployOneYearLockFixture(twoSecsFromNow)

        await new Promise(resolve => setTimeout(resolve, 2000));

        const tx = await lock.withdraw();
        const receipt = await tx.wait();
        
        expect(receipt.logs).to.have.length.at.least(1);
        
        await expect(tx)
          .to.emit(lock, "Withdrawal")
          .withArgs(lockedAmount, anyValue); // We accept any value as `when` arg

      });
    });

    describe("Transfers", function () {
      it("Should transfer the funds to the owner", async function () {
        const twoSecsFromNow = Math.floor(Date.now() / 1000) + 2;
        const { lock, lockedAmount, owner } = await deployOneYearLockFixture(twoSecsFromNow)

        await new Promise(resolve => setTimeout(resolve, 2000));

        const tx = await lock.withdraw();
        await tx.wait();

        await expect(tx).to.changeEtherBalances(
          [owner, lock],
          [lockedAmount, -lockedAmount]
        );
      });
    });
  });
});
