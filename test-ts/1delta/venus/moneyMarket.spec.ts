import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { ethers } from 'hardhat'
import { VenusFixture, generateVenusFixture, ONE_18 } from '../shared/venusFixture'
import { expect } from 'chai';
import { ERC20Mock, ERC20Mock__factory, WETH9, WETH9__factory } from '../../../types';
import { formatEther, parseUnits } from 'ethers/lib/utils';
import { VenusBrokerFixture, initVenusBroker, venusBrokerFixture } from '../shared/venusBrokerFixture';
import { constants } from 'ethers';


// we prepare a setup for compound in hardhat
// this series of tests checks that the features used for the margin swap implementation
// are correctly set up and working
describe('Venus 1delta Test', async () => {
    let deployer: SignerWithAddress, alice: SignerWithAddress, bob: SignerWithAddress, carol: SignerWithAddress, zed: SignerWithAddress;
    let venusFixture: VenusFixture
    let venusBroker: VenusBrokerFixture
    let underlyings: ERC20Mock[]
    let weth: WETH9

    before('get wallets and fixture', async () => {
        [deployer, alice, bob, carol, zed] = await ethers.getSigners();
        const arr = [0, 1, 2, 3]
        underlyings = await Promise.all(arr.map(async (a) => await new ERC20Mock__factory(deployer).deploy(`Token ${a}`, `T${a}`, deployer.address, parseUnits('1000000000', 18))))
        weth = await new WETH9__factory(deployer).deploy()
        const options = {
            underlyings: underlyings,
            collateralFactors: arr.map(x => ONE_18.mul(8).div(10)),
            exchangeRates: arr.map(x => ONE_18.mul(912).div(333)),
            // exchangeRates: arr.map(x => ONE_18),
            borrowRates: arr.map(x => ONE_18.div(1e8)),
            cEthExchangeRate: ONE_18,
            cEthBorrowRate: ONE_18,
            compRate: ONE_18,
            closeFactor: ONE_18
        }
        // create venus
        venusFixture = await generateVenusFixture(deployer, options)
        // create 1delta
        venusBroker = await venusBrokerFixture(deployer, weth.address, venusFixture.cEther.address)
        await initVenusBroker(deployer, venusBroker, venusFixture.comptroller.address)

        // add assets
        for (const i of arr) {
            console.log("asset", i)
            const cTok = venusFixture.cTokens[i]
            const underlying = underlyings[i]
            await underlying.connect(deployer).approve(cTok.address, constants.MaxUint256)
            const baseAm = parseUnits('1000000', 18)
            await cTok.connect(deployer).mint(baseAm)
            await underlying.connect(deployer).transfer(alice.address, baseAm)
            await underlying.connect(deployer).transfer(bob.address, baseAm)
            await underlying.connect(deployer).transfer(carol.address, baseAm)
            await underlying.connect(deployer).transfer(zed.address, baseAm)
            await venusBroker.manager.addCollateralToken(underlying.address, cTok.address)

        }

        await venusBroker.manager.approveCollateralTokens(underlyings.map(a => a.address))
    })

    it('deploys everything', async () => {
        await expect(
            venusFixture.comptroller.address
        ).to.not.be.equal('')
    })

    it('allows delegated collateral provision', async () => {
        const underlying = underlyings[0]
        const am = parseUnits('1000', 18)

        await underlying.connect(bob).approve(venusBroker.aggregator.address, am)
        await venusBroker.aggregator.connect(bob).deposit(underlying.address, am)

        const expBal = await venusFixture.cTokens[0].callStatic.balanceOfUnderlying(bob.address)
        // venus produces rounding errors when converting balances
        expect(Number(formatEther(expBal))).to.approximately(Number(formatEther(am)), 1e-17)
    })

    it('allows delegated collateral withdrawal', async () => {
        const underlying = underlyings[0]
        const cToken = venusFixture.cTokens[0]
        const am = parseUnits('1000', 18)

        await underlying.connect(bob).approve(venusBroker.aggregator.address, am)
        await cToken.connect(bob).approve(venusBroker.aggregator.address, am)

        const expBalBefore = await cToken.callStatic.balanceOfUnderlying(bob.address)
        await venusBroker.aggregator.connect(bob).deposit(underlying.address, am)

        const expBal = await cToken.callStatic.balanceOfUnderlying(bob.address)
        expect(expBal.sub(expBalBefore).toString()).to.equal(am.toString())
        const withdrawAm = am.div(3)
        await venusBroker.aggregator.connect(bob).withdraw(underlying.address, withdrawAm)
        const expBalAfter = await cToken.callStatic.balanceOfUnderlying(bob.address)
        // allow minimal deviation
        expect(Number(formatEther(expBal.sub(expBalAfter)))).to.approximately(Number(formatEther(withdrawAm)), 1e-17)
    })

    it('allows delegated collateral withdrawal full', async () => {
        const underlying = underlyings[0]
        const cToken = venusFixture.cTokens[0]
        console.log("underlying", underlying.address, "cTok", cToken.address)
        const am = parseUnits('1000', 18)

        await underlying.connect(bob).approve(venusBroker.aggregator.address, am)
        await cToken.connect(bob).approve(venusBroker.aggregator.address, constants.MaxUint256)

        const withdrawAm = await cToken.callStatic.balanceOfUnderlying(bob.address)
        const balBefore = await underlying.balanceOf(bob.address)
        console.log("before:", balBefore.toString())
        await venusBroker.aggregator.connect(bob).withdraw(underlying.address, withdrawAm)
        const balAfter = await underlying.balanceOf(bob.address)
        console.log("before:", balBefore.toString(), "after:", balAfter.toString())
        expect(balAfter.sub(balBefore).toString()).to.equal(withdrawAm.toString())
        const balRouter = await underlying.balanceOf(venusBroker.aggregator.address)
        expect(Number(balRouter.toString())).to.lessThanOrEqual(1) // we accept the smallest unit as dust

        const balWithLender = await cToken.callStatic.balanceOfUnderlying(bob.address)
        expect(Number(balWithLender.toString())).to.lessThanOrEqual(0) // we accept the smallest unit as dust
    })

    it('allows collateral provision and redemption', async () => {
        const underlying = underlyings[0]
        const cToken = venusFixture.cTokens[0]
        const am = parseUnits('1000', 18)

        await underlying.connect(carol).approve(cToken.address, am)
        await cToken.connect(carol).mint(am)
        await cToken.connect(carol).redeemUnderlying(am.div(2))
        const bal = await cToken.balanceOf(carol.address)
        await cToken.connect(carol).redeem(bal)
    })

    it('allows delegated borrow', async () => {

        const borrow_underlying = underlyings[0]
        const supply_underlying = underlyings[1]

        const borrow_cToken = venusFixture.cTokens[0]
        const supply_cToken = venusFixture.cTokens[1]

        const comptroller = venusFixture.comptroller

        // supplies
        const supply_am = parseUnits('1000', 18)
        const borrow_am = parseUnits('700', 18)

        // enter market
        await comptroller.connect(bob).enterMarkets(venusFixture.cTokens.map(cT => cT.address))

        // user has to add collateral
        await supply_underlying.connect(bob).approve(supply_cToken.address, supply_am)
        await supply_cToken.connect(bob).mint(supply_am)
        await comptroller.connect(bob).enterMarkets([supply_cToken.address])

        await venusFixture.comptroller.connect(bob).updateDelegate(venusBroker.aggregator.address, true)

        const balBefore = await borrow_underlying.balanceOf(bob.address)
        await venusBroker.aggregator.connect(bob).borrow(borrow_underlying.address, borrow_am)
        const balAfter = await borrow_underlying.balanceOf(bob.address)
        expect(balAfter.sub(balBefore).toString()).to.equal(borrow_am.toString())

    })


    it('allows delegated repay', async () => {

        const borrow_underlying = underlyings[0]
        const supply_underlying = underlyings[1]

        const borrow_cToken = venusFixture.cTokens[0]
        const supply_cToken = venusFixture.cTokens[1]

        const comptroller = venusFixture.comptroller

        // supplies
        const supply_am = parseUnits('1000', 18)
        const borrow_am = parseUnits('700', 18)

        // enter market
        await comptroller.connect(zed).enterMarkets(venusFixture.cTokens.map(cT => cT.address))

        // user has to add collateral
        await supply_underlying.connect(zed).approve(supply_cToken.address, supply_am)
        await supply_cToken.connect(zed).mint(supply_am)
        await comptroller.connect(zed).enterMarkets([supply_cToken.address])

        await venusFixture.comptroller.connect(zed).updateDelegate(venusBroker.aggregator.address, true)

        const balBefore = await borrow_underlying.balanceOf(zed.address)
        await venusBroker.aggregator.connect(zed).borrow(borrow_underlying.address, borrow_am)
        const balAfter = await borrow_underlying.balanceOf(zed.address)
        expect(balAfter.sub(balBefore).toString()).to.equal(borrow_am.toString())
        await borrow_underlying.connect(zed).approve(venusBroker.aggregator.address, borrow_am)
        const repayAmount = borrow_am.div(2)
        const borrowBalBefore = await borrow_cToken.callStatic.borrowBalanceCurrent(zed.address)
        await venusBroker.aggregator.connect(zed).repay(borrow_underlying.address, repayAmount)
        const borrowBalAfter = await borrow_cToken.callStatic.borrowBalanceCurrent(zed.address)

        expect(Number(formatEther(borrowBalBefore.sub(borrowBalAfter)))).to.approximately(Number(formatEther(repayAmount)), 1e-5)

    })
})
