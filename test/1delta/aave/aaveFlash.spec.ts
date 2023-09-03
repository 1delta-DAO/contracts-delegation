import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { BigNumber, constants } from 'ethers';
import { MockProvider } from 'ethereum-waffle';
import { ethers, waffle } from 'hardhat'
import {
    AaveFlashModule,
    MintableERC20,
    MockRouter,
    MockRouter__factory,
    WETH9
} from '../../../types';
import { expandTo18Decimals } from '../../uniswap-v3/periphery/shared/expandTo18Decimals';
import { initAaveBroker, aaveBrokerFixture, AaveBrokerFixture, ONE_18, addAaveFlashLoans } from '../shared/aaveBrokerFixture';
import { expect } from '../shared/expect'
import { initializeMakeSuite, InterestRateMode, AAVEFixture, deposit } from '../shared/aaveFixture';
import { toNumber } from 'lodash';


const AAVE_FLASH_FEE_DENOMINATOR = BigNumber.from(10_000)

// we prepare a setup for aave in hardhat
// this series of tests checks that the features used for the margin swap implementation
// are correctly set up and working
describe('AAVE Flash loans for AAVE', async () => {
    let deployer: SignerWithAddress;
    let alice: SignerWithAddress;
    let bob: SignerWithAddress;
    let carol: SignerWithAddress;
    let gabi: SignerWithAddress;
    let test: SignerWithAddress;
    let test1: SignerWithAddress;
    let test2: SignerWithAddress;
    let test3: SignerWithAddress;
    let test4: SignerWithAddress;
    let test5: SignerWithAddress;
    let test6: SignerWithAddress;
    let test7: SignerWithAddress;
    let aaveTest: AAVEFixture;
    let broker: AaveBrokerFixture;
    let tokens: (MintableERC20 | WETH9)[];
    let provider: MockProvider
    let mockRouter: MockRouter
    let balancerModule: AaveFlashModule
    let flashFee: BigNumber


    before('Deploy Account, Trader, Uniswap and AAVE', async () => {
        [deployer, alice, bob, carol, gabi, test, test1, test2, test3, test4, test5, test6, test7] = await ethers.getSigners();


        provider = waffle.provider;
        mockRouter = await new MockRouter__factory(deployer).deploy(ONE_18, 4321);
        aaveTest = await initializeMakeSuite(deployer, 0, true)
        flashFee = await aaveTest.pool.FLASHLOAN_PREMIUM_TOTAL()

        const protocolFee = await aaveTest.pool.FLASHLOAN_PREMIUM_TO_PROTOCOL()
        // flashFee = flashFee.add(protocolFee)
        tokens = Object.values(aaveTest.tokens)
        broker = await aaveBrokerFixture(deployer, ethers.constants.AddressZero, aaveTest.pool.address)
        await initAaveBroker(deployer, broker, undefined, aaveTest)
        balancerModule = await addAaveFlashLoans(deployer, broker, mockRouter.address, aaveTest.pool.address)


        // approve & fund wallets
        let keys = Object.keys(aaveTest.tokens)
        for (let i = 0; i < keys.length; i++) {
            const key = keys[i]
            await aaveTest.tokens[key].connect(deployer).approve(aaveTest.pool.address, constants.MaxUint256)
            if (key === "WETH") {
                await (aaveTest.tokens[key] as WETH9).deposit({ value: expandTo18Decimals(2_000) })
                await aaveTest.pool.connect(deployer).supply(aaveTest.tokens[key].address, expandTo18Decimals(1_000), deployer.address, 0)
                await aaveTest.tokens[key].connect(deployer).transfer(mockRouter.address, expandTo18Decimals(100))

            } else {
                await (aaveTest.tokens[key] as MintableERC20)['mint(address,uint256)'](deployer.address, expandTo18Decimals(100_000_000))
                await aaveTest.pool.connect(deployer).supply(aaveTest.tokens[key].address, expandTo18Decimals(10_000), deployer.address, 0)

                await aaveTest.tokens[key].connect(deployer).transfer(bob.address, expandTo18Decimals(1_000_000))
                await aaveTest.tokens[key].connect(deployer).transfer(alice.address, expandTo18Decimals(1_000_000))
                await aaveTest.tokens[key].connect(deployer).transfer(carol.address, expandTo18Decimals(1_000_000))
                await aaveTest.tokens[key].connect(deployer).transfer(test.address, expandTo18Decimals(1_000_000))
                await aaveTest.tokens[key].connect(deployer).transfer(test1.address, expandTo18Decimals(1_000_000))
                await aaveTest.tokens[key].connect(deployer).transfer(test2.address, expandTo18Decimals(1_000_000))
                await aaveTest.tokens[key].connect(deployer).transfer(test3.address, expandTo18Decimals(1_000_000))
                await aaveTest.tokens[key].connect(deployer).transfer(test4.address, expandTo18Decimals(1_000_000))
                await aaveTest.tokens[key].connect(deployer).transfer(test5.address, expandTo18Decimals(1_000_000))
                await aaveTest.tokens[key].connect(deployer).transfer(test6.address, expandTo18Decimals(1_000_000))
                await aaveTest.tokens[key].connect(deployer).transfer(test7.address, expandTo18Decimals(1_000_000))
                await aaveTest.tokens[key].connect(deployer).transfer(gabi.address, expandTo18Decimals(1_000_000))
                // fund router 
                await aaveTest.tokens[key].connect(deployer).transfer(mockRouter.address, expandTo18Decimals(1_000_000))

                await aaveTest.tokens[key].connect(bob).approve(aaveTest.pool.address, ethers.constants.MaxUint256)
                await aaveTest.tokens[key].connect(alice).approve(aaveTest.pool.address, ethers.constants.MaxUint256)
                await aaveTest.tokens[key].connect(carol).approve(aaveTest.pool.address, ethers.constants.MaxUint256)
                await aaveTest.tokens[key].connect(test).approve(aaveTest.pool.address, ethers.constants.MaxUint256)
                await aaveTest.tokens[key].connect(test1).approve(aaveTest.pool.address, ethers.constants.MaxUint256)
                await aaveTest.tokens[key].connect(test2).approve(aaveTest.pool.address, ethers.constants.MaxUint256)
                await aaveTest.tokens[key].connect(test3).approve(aaveTest.pool.address, ethers.constants.MaxUint256)
                await aaveTest.tokens[key].connect(test4).approve(aaveTest.pool.address, ethers.constants.MaxUint256)
                await aaveTest.tokens[key].connect(test5).approve(aaveTest.pool.address, ethers.constants.MaxUint256)
                await aaveTest.tokens[key].connect(gabi).approve(aaveTest.pool.address, ethers.constants.MaxUint256)


                await aaveTest.pool.connect(deployer).setUserUseReserveAsCollateral(aaveTest.tokens[key].address, true)

            }

            const token = aaveTest.tokens[key]
            await broker.manager.addAToken(token.address, aaveTest.aTokens[key].address)
            await broker.manager.addSToken(token.address, aaveTest.sTokens[key].address)
            await broker.manager.addVToken(token.address, aaveTest.vTokens[key].address)

        }

        await broker.manager.connect(deployer).approveAAVEPool(tokens.map(t => t.address))
        await broker.manager.connect(deployer).approveAddress(tokens.map(t => t.address), mockRouter.address)
    })

    // chcecks that the aave protocol is set up correctly, i.e. borrowing and supply works
    it('deploys everything', async () => {
        const { WETH, DAI } = aaveTest.tokens
        await (DAI as MintableERC20).connect(test3)['mint(address,uint256)'](test3.address, ONE_18.mul(1_000))
        await DAI.connect(test3).approve(aaveTest.pool.address, constants.MaxUint256)

        // supply and borrow
        await aaveTest.pool.connect(test3).supply(DAI.address, ONE_18.mul(10), test3.address, 0)
        await aaveTest.pool.connect(test3).setUserUseReserveAsCollateral(DAI.address, true)
        await aaveTest.pool.connect(test3).borrow(WETH.address, ONE_18, InterestRateMode.VARIABLE, 0, test3.address)
    })



    // flash loans input amount [has to be provided including the fee]
    // steps
    // 1) flash amount in [has to be adjusted in advance for flash loan fee]
    // 2) swap flashed amount using target calldata
    // 3) supply obtained amount
    // 4) borrow required repay amount of tokenIn to repay flash loan 
    it('allows exact in margin', async () => {
        const inId = 'DAI'
        const outId = 'AAVE'
        const depositId = 'AAVE'
        const tokenIn = aaveTest.tokens[inId]
        const tokenOut = aaveTest.tokens[outId]
        const tokenDeposit = aaveTest.tokens[depositId]

        console.log("Tokens", tokenIn.address, tokenOut.address)
        await tokenDeposit.connect(bob).approve(aaveTest.pool.address, constants.MaxUint256)
        const deposit = expandTo18Decimals(10)

        await aaveTest.pool.connect(bob).supply(tokenDeposit.address, deposit, bob.address, 0)
        const amountToBorrow = expandTo18Decimals(1)

        // we have to calibrate the amount in for the flash loan fee first - otherwise, the user would experience
        // a different amount in
        const amountToBorrowPostFee = adjustForFlashFee(amountToBorrow, flashFee) //amountToBorrow.mul(AAVE_FLASH_FEE_DENOMINATOR).div(AAVE_FLASH_FEE_DENOMINATOR.add(flashFee)).add(1)
        // produce swap calldata
        const targetCalldata = mockRouter.interface.encodeFunctionData(
            'swapExactIn',
            [
                tokenIn.address,
                tokenOut.address,
                amountToBorrowPostFee
            ]
        )

        await aaveTest.vTokens[inId].connect(bob).approveDelegation(balancerModule.address, amountToBorrowPostFee.mul(2))

        const params = {
            baseAsset: tokenOut.address, // the asset to interact with
            target: mockRouter.address,
            marginTradeType: 0, // margin open
            interestRateModeIn: InterestRateMode.VARIABLE, // the borrow mode
            interestRateModeOut: 0, // unused
            withdrawMax: false
        }
        console.log("user", bob.address)
        await balancerModule.connect(bob).executeOnAave(
            tokenIn.address,  // the asset to flash
            amountToBorrowPostFee, // the flash loan amount
            params, // oneDelta params
            targetCalldata
        )

        const balanceOut = await aaveTest.aTokens[outId].balanceOf(bob.address)
        const debtBalanceOut = await aaveTest.vTokens[inId].balanceOf(bob.address)
        console.log("Bals", balanceOut.toString(), debtBalanceOut.toString(), bob.address)

        expect(toNumber(balanceOut)).to.greaterThanOrEqual(toNumber(deposit.add(amountToBorrowPostFee.mul(99).div(100))))
        expect(debtBalanceOut.toString()).to.equal(amountToBorrow.toString())
    })

    // steps 
    //  1) Flash the optimistic input amount
    //  2) swap exact out using the target + calldata
    //  3) supply the obtained amount
    //  4) borrow the flash amount plus fee to repay flash loan
    it('allows exact out margin', async () => {
        const inId = 'DAI'
        const outId = 'AAVE'
        const depositId = 'AAVE'
        const tokenIn = aaveTest.tokens[inId]
        const tokenOut = aaveTest.tokens[outId]
        const tokenDeposit = aaveTest.tokens[depositId]

        console.log("Tokens", tokenIn.address, tokenOut.address)
        console.log("Tokens", tokenIn.address, tokenOut.address)
        await tokenDeposit.connect(carol).approve(aaveTest.pool.address, constants.MaxUint256)
        const deposit = expandTo18Decimals(10)

        await aaveTest.pool.connect(carol).supply(tokenDeposit.address, deposit, carol.address, 0)

        const amountOut = expandTo18Decimals(10)
        const amountToBorrow = amountOut

        // we have to calibrate the amount in for the flash loan fee first - otherwise, the user would experience
        // a different amount in
        const allowedSlippage = amountToBorrow.div(100) // 1%

        const amountToBorrowMax = adjustForFlashFee(amountToBorrow, flashFee).add(allowedSlippage)

        // produce swap calldata
        const targetCalldata = mockRouter.interface.encodeFunctionData(
            'swapExactOut',
            [
                tokenIn.address,
                tokenOut.address,
                amountOut
            ]
        )

        await aaveTest.vTokens[inId].connect(carol).approveDelegation(balancerModule.address, amountToBorrowMax.mul(2))

        const params = {
            baseAsset: tokenOut.address, // the asset to interact with
            target: mockRouter.address,
            marginTradeType: 0, // margin open
            interestRateModeIn: InterestRateMode.VARIABLE, // the borrow mode
            interestRateModeOut: 0, // unused
            withdrawMax: false
        }
        console.log("user", carol.address)
        await balancerModule.connect(carol).executeOnAave(
            tokenIn.address,  // the asset to flash
            amountToBorrowMax, // the flkash loan amount
            params, // oneDelta params
            targetCalldata
        )

        const balanceOut = await aaveTest.aTokens[outId].balanceOf(carol.address)
        const debtBalanceOut = await aaveTest.vTokens[inId].balanceOf(carol.address)
        console.log("Bals", balanceOut.toString(), debtBalanceOut.toString(), carol.address)

        expect(balanceOut.toString()).to.equal(deposit.add(amountOut).toString())
        expect(toNumber(debtBalanceOut)).to.lessThanOrEqual(toNumber(amountToBorrowMax))
        expect(toNumber(debtBalanceOut)).to.greaterThanOrEqual(toNumber(amountToBorrowMax) * 0.99)
    })



    // flash loans input amount [has to be provided including the fee]
    // steps
    // 1) flash amount in [has to be adjusted in advance for flash loan fee]
    // 2) swap flashed amount using target calldata
    // 3) repay obtained amount
    // 4) withdraw required repay amount of tokenIn to repay flash loan 
    it('allows exact in margin close', async () => {
        const inId = 'DAI'
        const outId = 'AAVE'
        const tokenIn = aaveTest.tokens[inId]
        const tokenOut = aaveTest.tokens[outId]

        const initDeposit = expandTo18Decimals(20)
        const initBorrow = expandTo18Decimals(10)
        await depositAndBorrow(test, aaveTest, inId, outId, initDeposit, initBorrow)

        console.log("Tokens", tokenIn.address, tokenOut.address)

        const amountToWithdraw = expandTo18Decimals(5)

        // we have to calibrate the amount in for the flash loan fee first - otherwise, the user would experience
        // a different amount in
        const amountToWithdrawPostFee = adjustForFlashFee(amountToWithdraw, flashFee) //.mul(AAVE_FLASH_FEE_DENOMINATOR).div(AAVE_FLASH_FEE_DENOMINATOR.add(flashFee)).add(1)
        // produce swap calldata
        const targetCalldata = mockRouter.interface.encodeFunctionData(
            'swapExactIn',
            [
                tokenIn.address,
                tokenOut.address,
                amountToWithdrawPostFee
            ]
        )
        // approval of actually paid amout
        await aaveTest.aTokens[inId].connect(test).approve(balancerModule.address, amountToWithdraw)

        const params = {
            baseAsset: tokenOut.address, // the asset to interact with
            target: mockRouter.address,
            marginTradeType: 1, // margin close
            interestRateModeIn: 0, // unused
            interestRateModeOut: InterestRateMode.VARIABLE, // repay mode
            withdrawMax: false
        }
        console.log("user", test.address, "aInWFee", amountToWithdrawPostFee.toString())

        const balPre = await aaveTest.aTokens[inId].balanceOf(test.address)
        const debtBalancePre = await aaveTest.vTokens[outId].balanceOf(test.address)
        console.log("BalsPre", balPre.toString(), debtBalancePre.toString(), test.address)
        await balancerModule.connect(test).executeOnAave(
            tokenIn.address,  // the asset to flash
            amountToWithdrawPostFee, // the flash loan amount
            params, // oneDelta params
            targetCalldata
        )

        const balanceOut = await aaveTest.aTokens[inId].balanceOf(test.address)
        const debtBalanceOut = await aaveTest.vTokens[outId].balanceOf(test.address)
        console.log("Bals", balanceOut.toString(), debtBalanceOut.toString(), test.address)

        expect(balanceOut.gte(balPre.sub(amountToWithdraw))).to.equal(true)
        expect(toNumber(debtBalanceOut)).to.greaterThanOrEqual(toNumber(initBorrow.sub(amountToWithdraw)))
        expect(toNumber(debtBalanceOut)).to.lessThanOrEqual(toNumber(initBorrow.sub(amountToWithdraw)) * 1.01)
    })


    // flash loans input amount [has to be provided including the fee]
    // steps
    // 1) flash amount in [has to be adjusted in advance for flash loan fee]
    // 2) swap flashed amount using target calldata
    // 3) repay obtained amount
    // 4) withdraw required repay amount of tokenIn to repay flash loan 
    it('allows exact out margin close', async () => {
        const inId = 'DAI'
        const outId = 'AAVE'
        const tokenIn = aaveTest.tokens[inId]
        const tokenOut = aaveTest.tokens[outId]

        const initDeposit = expandTo18Decimals(20)
        const initBorrow = expandTo18Decimals(10)
        await depositAndBorrow(test1, aaveTest, inId, outId, initDeposit, initBorrow)

        console.log("Tokens", tokenIn.address, tokenOut.address)

        const amountToRepay = expandTo18Decimals(5)

        const amountToWithdrawMax = amountToRepay.mul(105).div(100)
        // produce swap calldata
        const targetCalldata = mockRouter.interface.encodeFunctionData(
            'swapExactOut',
            [
                tokenIn.address,
                tokenOut.address,
                amountToRepay
            ]
        )
        // approval of actually paid amout
        await aaveTest.aTokens[inId].connect(test1).approve(balancerModule.address, amountToWithdrawMax)

        const params = {
            baseAsset: tokenOut.address, // the asset to interact with
            target: mockRouter.address,
            marginTradeType: 1, // margin close
            interestRateModeIn: 0, // unused
            interestRateModeOut: InterestRateMode.VARIABLE, // repay mode
            withdrawMax: false
        }
        console.log("user", test1.address, "aOut", amountToRepay.toString())

        const balPre = await aaveTest.aTokens[inId].balanceOf(test1.address)
        const debtBalancePre = await aaveTest.vTokens[outId].balanceOf(test1.address)
        console.log("BalsPre", balPre.toString(), debtBalancePre.toString(), test1.address)
        await balancerModule.connect(test1).executeOnAave(
            tokenIn.address,  // the asset to flash
            amountToWithdrawMax, // the flash loan amount
            params, // oneDelta params
            targetCalldata
        )

        const balanceOut = await aaveTest.aTokens[inId].balanceOf(test1.address)
        const debtBalanceOut = await aaveTest.vTokens[outId].balanceOf(test1.address)
        console.log("Bals", balanceOut.toString(), debtBalanceOut.toString(), test1.address)

        expect((debtBalancePre.sub(amountToRepay)).toString()).to.equal(debtBalanceOut.toString())
        expect(toNumber(balPre.sub(balanceOut))).to.greaterThanOrEqual(toNumber(amountToRepay))
        expect(toNumber(balPre.sub(balanceOut))).to.lessThanOrEqual(toNumber(amountToRepay) * 1.01)
    })


    // flash loans input amount [has to be provided including the fee]
    // steps
    // 1) flash amount in [has to be adjusted in advance for flash loan fee]
    // 2) swap flashed amount using target calldata
    // 3) supply obtained amount
    // 4) withdraw required repay amount of tokenIn to repay flash loan 
    it('allows exact in collateral swap', async () => {
        const inId = 'DAI'
        const outId = 'AAVE'
        const borrowId = 'WMATIC'
        const tokenIn = aaveTest.tokens[inId]
        const tokenOut = aaveTest.tokens[outId]
        const tokenBorrow = aaveTest.tokens[borrowId]

        console.log("Tokens", tokenIn.address, tokenOut.address)
        await tokenBorrow.connect(test2).approve(aaveTest.pool.address, constants.MaxUint256)
        const deposit = expandTo18Decimals(10)
        const amountToBorrow = expandTo18Decimals(10)

        // supply 2x collateral positions and borrow an asset
        await aaveTest.pool.connect(test2).supply(tokenIn.address, deposit, test2.address, 0)
        await aaveTest.pool.connect(test2).supply(tokenOut.address, deposit, test2.address, 0)
        await aaveTest.pool.connect(test2).borrow(tokenBorrow.address, amountToBorrow, InterestRateMode.VARIABLE, 0, test2.address)

        const amountToWithdraw = expandTo18Decimals(7)

        // we have to calibrate the amount in for the flash loan fee first - otherwise, the user would experience
        // a different amount in
        const amountToWithdrawPostFee = adjustForFlashFee(amountToWithdraw, flashFee) //.mul(AAVE_FLASH_FEE_DENOMINATOR).div(AAVE_FLASH_FEE_DENOMINATOR.add(flashFee)).add(1)
        // produce swap calldata
        const targetCalldata = mockRouter.interface.encodeFunctionData(
            'swapExactIn',
            [
                tokenIn.address,
                tokenOut.address,
                amountToWithdrawPostFee
            ]
        )

        await aaveTest.aTokens[inId].connect(test2).approve(balancerModule.address, amountToWithdrawPostFee.mul(2))

        const params = {
            baseAsset: tokenOut.address, // the asset to interact with
            target: mockRouter.address,
            marginTradeType: 2, // collateral swap
            interestRateModeIn: 0, // unused
            interestRateModeOut: 0, // unused
            withdrawMax: false
        }
        console.log("user", test2.address)
        const balanceInBefore = await aaveTest.aTokens[inId].balanceOf(test2.address)
        const balanceOutBefore = await aaveTest.aTokens[outId].balanceOf(test2.address)

        await balancerModule.connect(test2).executeOnAave(
            tokenIn.address,  // the asset to flash
            amountToWithdrawPostFee, // the flash loan amount
            params, // oneDelta params
            targetCalldata
        )

        const balanceIn = await aaveTest.aTokens[inId].balanceOf(test2.address)
        const balanceOut = await aaveTest.aTokens[outId].balanceOf(test2.address)

        const debtBalanceOut = await aaveTest.vTokens[inId].balanceOf(test2.address)
        console.log("Bals", balanceOut.toString(), debtBalanceOut.toString(), test2.address)

        expect(balanceIn.gte(balanceInBefore.sub(amountToWithdraw))).to.equal(true)

        expect(toNumber(balanceOut)).to.greaterThanOrEqual(toNumber(balanceOutBefore.add(amountToWithdrawPostFee.mul(99).div(100))) * 0.99)
        expect(toNumber(balanceOut)).to.lessThanOrEqual(toNumber(balanceOutBefore.add(amountToWithdrawPostFee.mul(99).div(100))) * 1.01)
    })

    // flash loans input amount [has to be provided including the fee]
    // steps
    // 1) flash amount in [has to be adjusted in advance for flash loan fee]
    // 2) swap flashed amount using target calldata
    // 3) supply obtained amount
    // 4) withdraw required repay amount of tokenIn to repay flash loan 
    it('allows exact out collateral swap', async () => {
        const inId = 'DAI'
        const outId = 'AAVE'
        const borrowId = 'WMATIC'
        const tokenIn = aaveTest.tokens[inId]
        const tokenOut = aaveTest.tokens[outId]
        const tokenBorrow = aaveTest.tokens[borrowId]

        const initDeposit = expandTo18Decimals(10)
        const initBorrow = expandTo18Decimals(7)
        // supply 2x collateral positions and borrow an asset
        await aaveTest.pool.connect(test2).supply(tokenIn.address, initDeposit, test2.address, 0)
        await aaveTest.pool.connect(test2).supply(tokenOut.address, initDeposit, test2.address, 0)
        await aaveTest.pool.connect(test2).borrow(tokenBorrow.address, initBorrow, InterestRateMode.VARIABLE, 0, test2.address)

        console.log("Tokens", tokenIn.address, tokenOut.address)

        const amountToSupply = expandTo18Decimals(7)

        const amountToWithdrawMax = amountToSupply.mul(105).div(100)
        // produce swap calldata
        const targetCalldata = mockRouter.interface.encodeFunctionData(
            'swapExactOut',
            [
                tokenIn.address,
                tokenOut.address,
                amountToSupply
            ]
        )
        // approval of actually paid amout
        await aaveTest.aTokens[inId].connect(test1).approve(balancerModule.address, amountToWithdrawMax)

        const params = {
            baseAsset: tokenOut.address, // the asset to interact with
            target: mockRouter.address,
            marginTradeType: 2, // collateral swap
            interestRateModeIn: 0, // unused
            interestRateModeOut: 0, // unused
            withdrawMax: false
        }
        console.log("user", test1.address, "aOut", amountToSupply.toString())

        const balPre = await aaveTest.aTokens[inId].balanceOf(test1.address)
        const balOutPre = await aaveTest.aTokens[outId].balanceOf(test1.address)
        const debtBalancePre = await aaveTest.vTokens[outId].balanceOf(test1.address)
        console.log("BalsPre", balPre.toString(), debtBalancePre.toString(), test1.address)
        await balancerModule.connect(test1).executeOnAave(
            tokenIn.address,  // the asset to flash
            amountToWithdrawMax, // the flash loan amount
            params, // oneDelta params
            targetCalldata
        )

        const balanceIn = await aaveTest.aTokens[inId].balanceOf(test1.address)
        const balanceOut = await aaveTest.aTokens[outId].balanceOf(test1.address)
        const debtBalanceOut = await aaveTest.vTokens[outId].balanceOf(test1.address)
        console.log("Bals", balanceOut.toString(), debtBalanceOut.toString(), test1.address)

        expect((balanceOut.sub(balOutPre))).to.equal(amountToSupply.toString())
        expect(toNumber(balPre.sub(balanceIn))).to.greaterThanOrEqual(toNumber(amountToSupply))
        expect(toNumber(balPre.sub(balanceIn))).to.lessThanOrEqual(toNumber(amountToSupply) * 1.01)
    })

    // flash loans input amount [has to be provided including the fee]
    // steps
    // 1) flash amount in [has to be adjusted in advance for flash loan fee]
    // 2) swap flashed amount using target calldata
    // 3) repay obtained amount
    // 4) borrow required repay amount of tokenIn to repay flash loan 
    it('allows exact in loan swap', async () => {
        const supplyId = 'WMATIC'
        const inId = 'DAI'
        const outId = 'AAVE'
        const tokenSupply = aaveTest.tokens[supplyId]
        const tokenIn = aaveTest.tokens[inId]
        const tokenOut = aaveTest.tokens[outId]

        console.log("Tokens", tokenIn.address, tokenOut.address)

        await tokenSupply.connect(gabi).approve(aaveTest.pool.address, constants.MaxUint256)
        const deposit = expandTo18Decimals(15)

        await aaveTest.pool.connect(gabi).supply(tokenSupply.address, deposit, gabi.address, 0)

        const initialBorrow = expandTo18Decimals(10)

        await aaveTest.pool.connect(gabi).borrow(tokenOut.address, initialBorrow, InterestRateMode.VARIABLE, 0, gabi.address)

        const amountToBorrow = expandTo18Decimals(7)
        // we have to calibrate the amount in for the flash loan fee first - otherwise, the user would experience
        // a different amount in
        const amountToBorrowPostFee = adjustForFlashFee(amountToBorrow, flashFee) //amountToBorrow.mul(AAVE_FLASH_FEE_DENOMINATOR).div(AAVE_FLASH_FEE_DENOMINATOR.add(flashFee)).add(1)
        // produce swap calldata
        const targetCalldata = mockRouter.interface.encodeFunctionData(
            'swapExactIn',
            [
                tokenIn.address,
                tokenOut.address,
                amountToBorrowPostFee
            ]
        )

        await aaveTest.vTokens[inId].connect(gabi).approveDelegation(balancerModule.address, amountToBorrowPostFee.mul(2))

        const params = {
            baseAsset: tokenOut.address, // the asset to interact with
            target: mockRouter.address,
            marginTradeType: 3, // loan swap
            interestRateModeIn: InterestRateMode.VARIABLE, // the input borrow mode
            interestRateModeOut: InterestRateMode.VARIABLE, // the output borrow mode
            withdrawMax: false
        }
        console.log("user", gabi.address)

        const debtBalanceInPre = await aaveTest.vTokens[inId].balanceOf(gabi.address)
        const debtBalanceOutPre = await aaveTest.vTokens[outId].balanceOf(gabi.address)
        await balancerModule.connect(gabi).executeOnAave(
            tokenIn.address,  // the asset to flash
            amountToBorrowPostFee, // the flash loan amount
            params, // oneDelta params
            targetCalldata
        )

        const debtBalanceIn = await aaveTest.vTokens[inId].balanceOf(gabi.address)
        const debtBalanceOut = await aaveTest.vTokens[outId].balanceOf(gabi.address)
        console.log("Bals", debtBalanceIn.toString(), debtBalanceOut.toString(), gabi.address)

        expect(debtBalanceIn.gte(debtBalanceInPre.sub(amountToBorrow))).to.equal(true)

        expect(toNumber(debtBalanceOutPre.sub(debtBalanceOut))).to.lessThanOrEqual(toNumber(amountToBorrowPostFee))
        expect(toNumber(debtBalanceOutPre.sub(debtBalanceOut))).to.greaterThanOrEqual(toNumber(amountToBorrowPostFee) * 0.99)
    })


    // flash loans input amount [has to be provided including the fee]
    // steps
    // 1) flash amount in [has to be adjusted in advance for flash loan fee]
    // 2) swap flashed amount using target calldata
    // 3) repay obtained amount
    // 4) borrw required repay amount of tokenIn to repay flash loan 
    it('allows exact out loan swap', async () => {
        const inId = 'DAI'
        const outId = 'AAVE'
        const supplyId = 'WMATIC'
        const tokenIn = aaveTest.tokens[inId]
        const tokenOut = aaveTest.tokens[outId]
        const tokenSupply = aaveTest.tokens[supplyId]

        await tokenSupply.connect(test3).approve(aaveTest.pool.address, constants.MaxUint256)
        const deposit = expandTo18Decimals(15)

        await aaveTest.pool.connect(test3).supply(tokenSupply.address, deposit, test3.address, 0)

        const initialBorrow = expandTo18Decimals(10)

        await aaveTest.pool.connect(test3).borrow(tokenOut.address, initialBorrow, InterestRateMode.VARIABLE, 0, test3.address)
        console.log("Tokens", tokenIn.address, tokenOut.address)

        const amountToRepay = expandTo18Decimals(7)

        const amountToBorrow = amountToRepay

        // we have to calibrate the amount in for the flash loan fee first - otherwise, the user would experience
        // a different amount in
        const allowedSlippage = amountToBorrow.div(100) // 1%

        const amountToBorrowMax = adjustForFlashFee(amountToBorrow, flashFee).add(allowedSlippage) //amountToBorrow.mul(AAVE_FLASH_FEE_DENOMINATOR).div(AAVE_FLASH_FEE_DENOMINATOR.add(flashFee)).add(1).add(allowedSlippage)

        // produce swap calldata
        const targetCalldata = mockRouter.interface.encodeFunctionData(
            'swapExactOut',
            [
                tokenIn.address,
                tokenOut.address,
                amountToRepay
            ]
        )

        // approval of actually paid amout
        await aaveTest.vTokens[inId].connect(test3).approveDelegation(balancerModule.address, amountToBorrowMax.mul(2))

        const params = {
            baseAsset: tokenOut.address, // the asset to interact with
            target: mockRouter.address,
            marginTradeType: 3, // loan swap
            interestRateModeIn: InterestRateMode.VARIABLE, // borrow mode in
            interestRateModeOut: InterestRateMode.VARIABLE, // borrow mode out
            withdrawMax: false
        }
        console.log("user", test3.address, "aOut", amountToRepay.toString())


        const debtBalanceInPre = await aaveTest.vTokens[inId].balanceOf(test3.address)
        const debtBalanceOutPre = await aaveTest.vTokens[outId].balanceOf(test3.address)

        console.log("BalsPre", debtBalanceInPre.toString(), debtBalanceOutPre.toString(), test3.address)
        await balancerModule.connect(test3).executeOnAave(
            tokenIn.address,  // the asset to flash
            amountToBorrowMax, // the flash loan amount
            params, // oneDelta params
            targetCalldata
        )

        const debtBalanceIn = await aaveTest.vTokens[inId].balanceOf(test3.address)
        const debtBalanceOut = await aaveTest.vTokens[outId].balanceOf(test3.address)
        console.log("Bals", debtBalanceIn.toString(), debtBalanceOut.toString(), test3.address)

        expect(debtBalanceOutPre.sub(debtBalanceOut)).to.equal(amountToRepay.toString())
        expect(toNumber(debtBalanceIn.sub(debtBalanceInPre))).to.greaterThanOrEqual(toNumber(amountToRepay))
        expect(toNumber(debtBalanceIn.sub(debtBalanceInPre))).to.lessThanOrEqual(toNumber(amountToRepay) * 1.01)
    })

    // flash loans input amount [has to be provided including the fee]
    // steps
    // 1) flash amount in [has to be adjusted in advance for flash loan fee]
    // 2) swap flashed amount using target calldata
    // 3) repay obtained amount
    // 4) withdraw entire balance
    //      1) send required repay amount of tokenIn to flash loan vault
    //      2) send remaining funds to user 
    it('allows all in margin close', async () => {
        const inId = 'DAI'
        const outId = 'AAVE'
        const repayDepoId = 'WMATIC'
        const tokenIn = aaveTest.tokens[repayDepoId]
        const tokenOut = aaveTest.tokens[outId]

        const initDeposit = expandTo18Decimals(20)
        const initBorrow = expandTo18Decimals(10)
        const additionalDepo = expandTo18Decimals(5)
        await depositAndBorrow(test4, aaveTest, inId, outId, initDeposit, initBorrow)
        await deposit(aaveTest, repayDepoId, test4, additionalDepo)

        console.log("Tokens", tokenIn.address, tokenOut.address)

        const amountToWithdraw = expandTo18Decimals(4)

        // we have to calibrate the amount in for the flash loan fee first - otherwise, the user would experience
        // a different amount in
        const amountToWithdrawPostFee = amountToWithdraw.mul(ONE_18).div(ONE_18.add(flashFee)).add(1)
        // produce swap calldata
        const targetCalldata = mockRouter.interface.encodeFunctionData(
            'swapExactIn',
            [
                tokenIn.address,
                tokenOut.address,
                amountToWithdrawPostFee
            ]
        )
        // approval of actually paid amout
        await aaveTest.aTokens[repayDepoId].connect(test4).approve(balancerModule.address, amountToWithdraw.mul(2))

        const params = {
            baseAsset: tokenOut.address, // the asset to interact with
            target: mockRouter.address,
            marginTradeType: 1, // margin close
            interestRateModeIn: 0, // unused
            interestRateModeOut: InterestRateMode.VARIABLE, // repay mode
            withdrawMax: true
        }
        console.log("user", test4.address, "aInWFee", amountToWithdrawPostFee.toString())

        const balPre = await aaveTest.aTokens[repayDepoId].balanceOf(test4.address)
        const debtBalancePre = await aaveTest.vTokens[outId].balanceOf(test4.address)
        console.log("BalsPre", balPre.toString(), debtBalancePre.toString(), test4.address)
        await balancerModule.connect(test4).executeOnAave(
            tokenIn.address,  // the asset to flash
            amountToWithdrawPostFee, // the flash loan amount
            params, // oneDelta params
            targetCalldata
        )

        const balanceOut = await aaveTest.aTokens[repayDepoId].balanceOf(test4.address)
        const debtBalanceOut = await aaveTest.vTokens[outId].balanceOf(test4.address)
        console.log("Bals", balanceOut.toString(), debtBalanceOut.toString(), test4.address)


        const balanceRouter = await aaveTest.aTokens[repayDepoId].balanceOf(balancerModule.address)
        expect((balanceOut).toString()).to.equal('0')
        expect((balanceRouter).toString()).to.equal('0')
        expect(toNumber(debtBalanceOut)).to.greaterThanOrEqual(toNumber(initBorrow.sub(amountToWithdraw)))
        expect(toNumber(debtBalanceOut)).to.lessThanOrEqual(toNumber(initBorrow.sub(amountToWithdraw)) * 1.01)
    })


    // flash loans input amount [has to be provided including the fee]
    // steps
    // 1) flash amount in [has to be adjusted in advance for flash loan fee]
    // 2) swap flashed amount using target calldata
    // 3) supply obtained amount
    // 4) withdraw required repay amount of tokenIn to repay flash loan 
    it('allows all in collateral swap', async () => {
        const inId = 'DAI'
        const outId = 'AAVE'
        const borrowId = 'WMATIC'
        const tokenIn = aaveTest.tokens[inId]
        const tokenOut = aaveTest.tokens[outId]
        const tokenBorrow = aaveTest.tokens[borrowId]

        console.log("Tokens", tokenIn.address, tokenOut.address)
        await tokenBorrow.connect(test5).approve(aaveTest.pool.address, constants.MaxUint256)
        const deposit = expandTo18Decimals(10)
        const amountToBorrow = expandTo18Decimals(10)

        // supply 2x collateral positions and borrow an asset
        await aaveTest.pool.connect(test5).supply(tokenIn.address, deposit, test5.address, 0)
        await aaveTest.pool.connect(test5).supply(tokenOut.address, deposit, test5.address, 0)
        await aaveTest.pool.connect(test5).borrow(tokenBorrow.address, amountToBorrow, InterestRateMode.VARIABLE, 0, test5.address)

        const amountToWithdraw = expandTo18Decimals(7)

        // we have to calibrate the amount in for the flash loan fee first - otherwise, the user would experience
        // a different amount in
        const amountToWithdrawPostFee = adjustForFlashFee(amountToWithdraw, flashFee)  //amountToWithdraw.mul(ONE_18).div(ONE_18.add(flashFee)).add(1)
        // produce swap calldata
        const targetCalldata = mockRouter.interface.encodeFunctionData(
            'swapExactIn',
            [
                tokenIn.address,
                tokenOut.address,
                amountToWithdrawPostFee
            ]
        )

        await aaveTest.aTokens[inId].connect(test5).approve(balancerModule.address, amountToWithdrawPostFee.mul(2))

        const params = {
            baseAsset: tokenOut.address, // the asset to interact with
            target: mockRouter.address,
            marginTradeType: 2, // collateral swap
            interestRateModeIn: 0, // unused
            interestRateModeOut: 0, // unused
            withdrawMax: true
        }
        console.log("user", test5.address)
        const balanceInBefore = await aaveTest.aTokens[inId].balanceOf(test5.address)
        const balanceOutBefore = await aaveTest.aTokens[outId].balanceOf(test5.address)

        await balancerModule.connect(test5).executeOnAave(
            tokenIn.address,  // the asset to flash
            amountToWithdrawPostFee, // the flash loan amount
            params, // oneDelta params
            targetCalldata
        )

        const balanceIn = await aaveTest.aTokens[inId].balanceOf(test5.address)
        const balanceRouter = await aaveTest.aTokens[inId].balanceOf(balancerModule.address)
        const balanceOut = await aaveTest.aTokens[outId].balanceOf(test5.address)

        const debtBalanceOut = await aaveTest.vTokens[inId].balanceOf(test5.address)
        console.log("Bals", balanceOut.toString(), debtBalanceOut.toString(), test5.address)

        expect(balanceIn.toString()).to.equal('0')
        expect(balanceRouter.toString()).to.equal('0')
        expect(toNumber(balanceOut)).to.greaterThanOrEqual(toNumber(balanceOutBefore.add(amountToWithdrawPostFee.mul(99).div(100))) * 0.99)
        expect(toNumber(balanceOut)).to.lessThanOrEqual(toNumber(balanceOutBefore.add(amountToWithdrawPostFee.mul(99).div(100))) * 1.01)
    })


    // flash loans input amount [has to be provided including the fee]
    // steps
    // 1) flash amount in [has to be adjusted in advance for flash loan fee]
    // 2) swap flashed amount using target calldata
    // 3) repay obtained amount
    // 4) withdraw required repay amount of tokenIn to repay flash loan 
    it('allows all out margin close', async () => {
        const inId = 'DAI'
        const outId = 'AAVE'
        const tokenIn = aaveTest.tokens[inId]
        const tokenOut = aaveTest.tokens[outId]

        const initDeposit = expandTo18Decimals(20)
        const initBorrow = expandTo18Decimals(10)
        await depositAndBorrow(test7, aaveTest, inId, outId, initDeposit, initBorrow)

        console.log("Tokens", tokenIn.address, tokenOut.address)

        const amountToRepay = initBorrow.mul(10001).div(10000)

        const amountToWithdrawMax = amountToRepay.mul(105).div(100)
        // produce swap calldata
        const targetCalldata = mockRouter.interface.encodeFunctionData(
            'swapExactOut',
            [
                tokenIn.address,
                tokenOut.address,
                amountToRepay
            ]
        )
        // approval of actually paid amout
        await aaveTest.aTokens[inId].connect(test7).approve(balancerModule.address, amountToWithdrawMax)

        console.log("Tokens in/out", tokenIn.address, tokenOut.address)
        const params = {
            baseAsset: tokenOut.address, // the asset to interact with
            target: mockRouter.address,
            marginTradeType: 1, // margin close
            interestRateModeIn: 0, // unused
            interestRateModeOut: InterestRateMode.VARIABLE, // repay mode
            withdrawMax: false
        }

        const balPre = await aaveTest.aTokens[inId].balanceOf(test7.address)
        const debtBalancePre = await aaveTest.vTokens[outId].balanceOf(test7.address)
        console.log("BalsPre", balPre.toString(), debtBalancePre.toString(), test7.address)
        await balancerModule.connect(test7).executeOnAave(
            tokenIn.address,  // the asset to flash
            amountToWithdrawMax, // the flash loan amount
            params, // oneDelta params
            targetCalldata
        )

        const balanceOut = await aaveTest.aTokens[inId].balanceOf(test7.address)
        const debtBalanceOut = await aaveTest.vTokens[outId].balanceOf(test7.address)
        const debtBalanceOutRouter = await aaveTest.vTokens[outId].balanceOf(balancerModule.address)
        console.log("Bals", balanceOut.toString(), debtBalanceOut.toString(), test7.address)

        expect(debtBalanceOut.toString()).to.equal('0')
        expect(debtBalanceOutRouter.toString()).to.equal('0')
        expect(toNumber(balPre.sub(balanceOut))).to.greaterThanOrEqual(toNumber(amountToRepay))
        expect(toNumber(balPre.sub(balanceOut))).to.lessThanOrEqual(toNumber(amountToRepay) * 1.01)
    })

    // flash loans input amount [has to be provided including the fee]
    // steps
    // 1) flash amount in [has to be adjusted in advance for flash loan fee]
    // 2) swap flashed amount using target calldata
    // 3) repay obtained amount
    // 4) borrw required repay amount of tokenIn to repay flash loan 
    it('allows all out loan swap', async () => {
        const inId = 'DAI'
        const outId = 'AAVE'
        const supplyId = 'WMATIC'
        const tokenIn = aaveTest.tokens[inId]
        const tokenOut = aaveTest.tokens[outId]
        const tokenSupply = aaveTest.tokens[supplyId]

        await tokenSupply.connect(test6).approve(aaveTest.pool.address, constants.MaxUint256)
        const deposit = expandTo18Decimals(15)

        await aaveTest.pool.connect(test6).supply(tokenSupply.address, deposit, test6.address, 0)

        const initialBorrow = expandTo18Decimals(10)

        await aaveTest.pool.connect(test6).borrow(tokenOut.address, initialBorrow, InterestRateMode.VARIABLE, 0, test6.address)
        console.log("Tokens", tokenIn.address, tokenOut.address)

        const amountToRepay = initialBorrow.mul(10001).div(10000)

        const amountToBorrow = amountToRepay

        // we have to calibrate the amount in for the flash loan fee first - otherwise, the user would experience
        // a different amount in
        const allowedSlippage = amountToBorrow.div(100) // 1%

        const amountToBorrowMax = amountToBorrow.mul(ONE_18).div(ONE_18.add(flashFee)).add(1).add(allowedSlippage)

        // produce swap calldata
        const targetCalldata = mockRouter.interface.encodeFunctionData(
            'swapExactOut',
            [
                tokenIn.address,
                tokenOut.address,
                amountToRepay
            ]
        )

        // approval of actually paid amout
        await aaveTest.vTokens[inId].connect(test6).approveDelegation(balancerModule.address, amountToBorrowMax.mul(2))

        const params = {
            baseAsset: tokenOut.address, // the asset to interact with
            target: mockRouter.address,
            marginTradeType: 3, // loan swap
            interestRateModeIn: InterestRateMode.VARIABLE, // borrow mode in
            interestRateModeOut: InterestRateMode.VARIABLE, // borrow mode out
            withdrawMax: true
        }
        console.log("user", test6.address, "aOut", amountToRepay.toString())


        const debtBalanceInPre = await aaveTest.vTokens[inId].balanceOf(test6.address)
        const debtBalanceOutPre = await aaveTest.vTokens[outId].balanceOf(test6.address)

        console.log("BalsPre", debtBalanceInPre.toString(), debtBalanceOutPre.toString(), test6.address)
        await balancerModule.connect(test6).executeOnAave(
            tokenIn.address,  // the asset to flash
            amountToBorrowMax, // the flash loan amount
            params, // oneDelta params
            targetCalldata
        )

        const debtBalanceIn = await aaveTest.vTokens[inId].balanceOf(test6.address)
        const debtBalanceOut = await aaveTest.vTokens[outId].balanceOf(test6.address)
        const debtBalanceOutRouter = await aaveTest.vTokens[outId].balanceOf(balancerModule.address)
        console.log("Bals", debtBalanceIn.toString(), debtBalanceOut.toString(), test6.address)

        expect(debtBalanceOut.toString()).to.equal('0')
        expect(debtBalanceOutRouter.toString()).to.equal('0')
        expect(toNumber(debtBalanceIn.sub(debtBalanceInPre))).to.greaterThanOrEqual(toNumber(amountToRepay))
        expect(toNumber(debtBalanceIn.sub(debtBalanceInPre))).to.lessThanOrEqual(toNumber(amountToRepay) * 1.01)
    })

    // flash loans input amount [has to be provided including the fee]
    // steps
    // 1) flash amount in [has to be adjusted in advance for flash loan fee]
    // 2) swap flashed amount using target calldata
    // 3) supply obtained amount
    // 4) borrow required repay amount of tokenIn to repay flash loan 
    it('allows exact in margin high flash loan', async () => {
        const inId = 'DAI'
        const outId = 'AAVE'
        const depositId = 'AAVE'
        const tokenIn = aaveTest.tokens[inId]
        const tokenOut = aaveTest.tokens[outId]
        const tokenDeposit = aaveTest.tokens[depositId]

        console.log("Tokens", tokenIn.address, tokenOut.address)
        await tokenDeposit.connect(bob).approve(aaveTest.pool.address, constants.MaxUint256)
        const deposit = expandTo18Decimals(10)

        await aaveTest.pool.connect(bob).supply(tokenDeposit.address, deposit, bob.address, 0)
        const amountToBorrow = expandTo18Decimals(1)

        // we have to calibrate the amount in for the flash loan fee first - otherwise, the user would experience
        // a different amount in
        const amountToBorrowPostFee = adjustForFlashFee(amountToBorrow, flashFee) //amountToBorrow.mul(AAVE_FLASH_FEE_DENOMINATOR).div(AAVE_FLASH_FEE_DENOMINATOR.add(flashFee)).add(1)
        // produce swap calldata
        const targetCalldata = mockRouter.interface.encodeFunctionData(
            'swapExactIn',
            [
                tokenIn.address,
                tokenOut.address,
                amountToBorrowPostFee
            ]
        )

        await aaveTest.vTokens[inId].connect(bob).approveDelegation(balancerModule.address, amountToBorrowPostFee.mul(2))
        const debtBalanceOutPre = await aaveTest.vTokens[inId].balanceOf(bob.address)
        const params = {
            baseAsset: tokenOut.address, // the asset to interact with
            target: mockRouter.address,
            marginTradeType: 0, // margin open
            interestRateModeIn: InterestRateMode.VARIABLE, // the borrow mode
            interestRateModeOut: 0, // unused
            withdrawMax: false
        }
        console.log("user", bob.address)
        await balancerModule.connect(bob).executeOnAave(
            tokenIn.address,  // the asset to flash
            amountToBorrowPostFee.mul(10), // the flash loan amount
            params, // oneDelta params
            targetCalldata
        )

        const balanceOut = await aaveTest.aTokens[outId].balanceOf(bob.address)
        const debtBalanceOut = await aaveTest.vTokens[inId].balanceOf(bob.address)
        console.log("Bals", balanceOut.toString(), debtBalanceOut.toString(), bob.address)

        expect(toNumber(balanceOut)).to.greaterThanOrEqual(toNumber(deposit.add(amountToBorrowPostFee.mul(99).div(100))))
        expect(debtBalanceOut.sub(debtBalanceOutPre).lte(amountToBorrow.mul(101).div(100))).to.equal(true)
        expect(debtBalanceOut.sub(debtBalanceOutPre).gte(amountToBorrow)).to.equal(true)
    })

    it('no dust', async () => {
        const aaveTokens = Object.keys(aaveTest.tokens)
        for (let i = 0; i < aaveTokens.length; i++) {
            const name = aaveTokens[i]
            const token = aaveTest.tokens[name]
            const aToken = aaveTest.aTokens[name]

            const bal = await token.balanceOf(balancerModule.address)
            const aBal = await aToken.balanceOf(balancerModule.address)

            expect(bal.toString()).to.equal('0')
            expect(aBal.toString()).to.equal('0')
        }
    })

})


// ·--------------------------------------------------------------------------------------------|---------------------------|-----------|-----------------------------·
// |                                    Solc version: 0.8.15                                    ·  Optimizer enabled: true  ·  Runs: 1  ·  Block limit: 30000000 gas  │
// ·····························································································|···························|···········|······························
// |  Methods                                                                                   ·              14 gwei/gas              ·       1900.47 usd/eth       │
// ························································|····································|·············|·············|···········|···············|··············
// |  Contract                                             ·  Method                            ·  Min        ·  Max        ·  Avg      ·  # calls      ·  usd (avg)  │
// ························································|····································|·············|·············|···········|···············|··············
// |  @openzeppelin/contracts/token/ERC20/ERC20.sol:ERC20  ·  approve                           ·      34108  ·      51244  ·    46948  ·            4  ·       1.25  │
// ························································|····································|·············|·············|···········|···············|··············
// |  AaveFlashModule                                      ·  executeOnAave                     ·     444096  ·     530580  ·   486487  ·           13  ·      12.99  │
// ························································|····································|·············|·············|···········|···············|··············
// |  AAVEMarginTraderInit                                 ·  initAAVEMarginTrader              ·          -  ·          -  ·   137473  ·            1  ·       3.66  │
// ························································|····································|·············|·············|···········|···············|··············
// |  ACLManager                                           ·  addEmergencyAdmin                 ·          -  ·          -  ·    50777  ·            1  ·       1.35  │
// ························································|····································|·············|·············|···········|···············|··············
// |  ACLManager                                           ·  addPoolAdmin                      ·          -  ·          -  ·    50821  ·            1  ·       1.35  │
// ························································|····································|·············|·············|···········|···············|··············
// |  ACLManager                                           ·  addRiskAdmin                      ·          -  ·          -  ·    50842  ·            1  ·       1.35  │
// ························································|····································|·············|·············|···········|···············|··············
// |  ManagementModule                                     ·  addAToken                         ·          -  ·          -  ·    51618  ·            5  ·       1.37  │
// ························································|····································|·············|·············|···········|···············|··············
// |  ManagementModule                                     ·  addSToken                         ·          -  ·          -  ·    51640  ·            5  ·       1.37  │
// ························································|····································|·············|·············|···········|···············|··············
// |  ManagementModule                                     ·  addVToken                         ·          -  ·          -  ·    51596  ·            5  ·       1.37  │



async function depositAndBorrow(
    signer: SignerWithAddress,
    aave: AAVEFixture,
    supplyIndex: string,
    borrowIndex: string,
    supplyAmount: BigNumber,
    borrowAmount: BigNumber
) {
    const borrowToken = aave.tokens[borrowIndex]
    const supplyToken = aave.tokens[supplyIndex]

    await supplyToken.connect(signer).approve(aave.pool.address, constants.MaxUint256)
    await aave.pool.connect(signer).supply(supplyToken.address, supplyAmount, signer.address, 0)
    await aave.pool.connect(signer).borrow(borrowToken.address, borrowAmount, InterestRateMode.VARIABLE, 0, signer.address)
}



const adjustForFlashFee = (amount: BigNumber, fee: BigNumber) => {

    const amountNoRounding = amount.mul(AAVE_FLASH_FEE_DENOMINATOR).div(AAVE_FLASH_FEE_DENOMINATOR.add(fee))
    const amountRoundUp = amountNoRounding.add(1)
    console.log("value no rounding", amountNoRounding.mul(fee.add(AAVE_FLASH_FEE_DENOMINATOR)).div(AAVE_FLASH_FEE_DENOMINATOR).toString())
    if (amountNoRounding.mul(fee.add(AAVE_FLASH_FEE_DENOMINATOR)).div(AAVE_FLASH_FEE_DENOMINATOR).eq(amount))
        return amountNoRounding
    console.log("Rounding up")
    return amountRoundUp

}