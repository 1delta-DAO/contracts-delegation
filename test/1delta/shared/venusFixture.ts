import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { BigNumber, constants } from "ethers";
import { ethers } from "hardhat"
import {
    VenusBep20Harness,
    VenusBep20Harness__factory,
    VBNBHarness,
    VBNBHarness__factory,
    ComptrollerHarness,
    ComptrollerHarness__factory,
    Comp__factory,
    ERC20Mock,
    InterestRateModelHarness,
    InterestRateModelHarness__factory,
    JumpRateModel,
    SimplePriceOracle,
    SimplePriceOracle__factory,
    Unitroller,
    Unitroller__factory,
    WhitePaperInterestRateModel,
    AccessControlManagerHarness__factory,
}
    from "../../../types"
import ComptrollerHarnessArtifact from "../../../artifacts/contracts/external-protocols/venus/test/ComptrollerHarness.sol/ComptrollerHarness.json"
import UnitrollerArtifact from "../../../artifacts/contracts/external-protocols/venus/Comptroller/Unitroller.sol/Unitroller.json"

export const ONE_18 = ethers.BigNumber.from(10).pow(18)
export const ZERO = ethers.BigNumber.from(0)
export const ONE = ethers.BigNumber.from(1)


export function etherMantissa(num: number | BigNumber, scale: number | BigNumber = ONE_18) {
    if (num < 0)
        return ethers.BigNumber.from(2).pow(256).add(num);
    return ethers.BigNumber.from(num).mul(scale);
}


export interface CompoundFixture {
    cTokens: VenusBep20Harness[]
    cEther: VBNBHarness
    comptroller: ComptrollerHarness
    unitroller: Unitroller
    interestRateModels: (InterestRateModelHarness | WhitePaperInterestRateModel | JumpRateModel)[]
    cEthInterestRateModel: InterestRateModelHarness | WhitePaperInterestRateModel | JumpRateModel,
    priceOracle: SimplePriceOracle
}

export interface CompoundOptions {
    underlyings: ERC20Mock[]
    collateralFactors: BigNumber[]
    exchangeRates: BigNumber[]
    borrowRates: BigNumber[]
    cEthExchangeRate: BigNumber
    cEthBorrowRate: BigNumber
    ethCollateralFactor?: BigNumber
    compRate?: BigNumber
    closeFactor?: BigNumber

}

export async function generateVenusFixture(signer: SignerWithAddress, options: CompoundOptions): Promise<CompoundFixture> {

    // deploy unitroller
    const unitroller = await new Unitroller__factory(signer).deploy()

    // deploy oracle
    const priceOracle = await new SimplePriceOracle__factory(signer).deploy();


    const comp = await new Comp__factory(signer).deploy(signer.address)
    // deploy comptroller harness
    const comptrollerLogic = await new ComptrollerHarness__factory(signer).deploy(comp.address)
    const comptroller = await ethers.getContractAt(
        [...ComptrollerHarnessArtifact.abi, ...UnitrollerArtifact.abi],
        unitroller.address) as ComptrollerHarness // ( await new ethers.Contract(unitroller.address,comptrollerLogic.interface)) as ComptrollerHarness


    // set implementation
    await unitroller._setPendingImplementation(comptrollerLogic.address)

    await comptrollerLogic.connect(signer)._become(unitroller.address)


    const closeFactor = options?.closeFactor ?? ONE_18.mul(51).div(1000);

    const accessControl = await new AccessControlManagerHarness__factory(signer).deploy()

    const liquidationIncentive = etherMantissa(1);
    const compRate = options?.compRate ?? ONE_18;
    console.log("start venus config")
    await comptroller.connect(signer)._setAccessControl(accessControl.address)
    // set parameters
    await comptroller.connect(signer)._setLiquidationIncentive(liquidationIncentive);
    console.log("_setLiquidationIncentive")
    await comptroller.connect(signer)._setCloseFactor(closeFactor);
    console.log("_setCloseFactor")
    await comptroller.connect(signer)._setVenusRate(compRate)
    console.log("_setVenusRate")
    await comptroller.connect(signer)._setPriceOracle(priceOracle.address);
    console.log("venus config complete")
    const interestRateModelCETH = await new InterestRateModelHarness__factory(signer).deploy(options.cEthBorrowRate)

    console.log("deploy vBNB harness")
    const cEther = await new VBNBHarness__factory(signer).deploy(
        comptroller.address,
        interestRateModelCETH.address,
        options.cEthExchangeRate,
        'cETH',
        'cETH',
        18,
        signer.address
    )
    console.log("vBNB harness deployed")
    await priceOracle.setUnderlyingPrice(cEther.address, options.cEthExchangeRate);
    await comptroller._supportMarket(cEther.address)
    await comptroller.harnessAddCompMarkets([cEther.address]);
    await comptroller._setCollateralFactor(cEther.address, options.ethCollateralFactor ?? ONE_18.mul(7).div(10))

    let cTokens: VenusBep20Harness[] = [], interestRateModels: InterestRateModelHarness[] = [];
    for (let i = 0; i < options.underlyings.length; i++) {
        const interestRateModel = await new InterestRateModelHarness__factory(signer).deploy(options.borrowRates[i])
        const decimals = 18;
        const symbol = 'OMG' + i;
        const name = `Erc20 ${i}`;
        const underlying = options.underlyings[i]
        const cerc20Token = await new VenusBep20Harness__factory(signer).deploy(
            underlying.address,
            comptroller.address,
            interestRateModel.address,
            options.exchangeRates[i],
            name,
            symbol,
            decimals,
            signer.address
        );
        const cToken = cerc20Token
        cTokens.push(cToken)
        interestRateModels.push(interestRateModel)


        const price = etherMantissa(options.exchangeRates[i]);
        await priceOracle.setUnderlyingPrice(cToken.address, price);
        await comptroller._supportMarket(cToken.address)
        await comptroller.harnessAddCompMarkets([cToken.address]);
        await comptroller._setCollateralFactor(cToken.address, options.collateralFactors[i])
        await comptroller._setMarketSupplyCaps([cToken.address], [constants.MaxUint256])
        await comptroller._setMarketBorrowCaps([cToken.address], [constants.MaxUint256])
    }

    return {
        cEther,
        cTokens,
        comptroller,
        unitroller,
        interestRateModels,
        cEthInterestRateModel: interestRateModelCETH,
        priceOracle
    }
}