import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { FlashModule__factory, IERC20__factory, IZiSwapFactory, IZiSwapFactory__factory, LimitOrderModule__factory, LiquidityManager, LiquidityManager__factory, LiquidityModule__factory, SwapX2YModule__factory } from '../../../types';
import { BigNumber, constants } from 'ethers';
import { FeeAmount, TICK_SPACINGS } from '../../uniswap-v3/periphery/shared/constants';
import { ethers } from 'hardhat';
import { getMaxTick, getMinTick } from '../../uniswap-v3/periphery/shared/ticks';


export interface iZiFixture {
  factory: IZiSwapFactory
  liquidityManager: LiquidityManager
}

export async function deploy_iZi(signer: SignerWithAddress,
  weth: string,
  defaultFeeChargePercent: number,
  receiver = signer.address): Promise<iZiFixture> {

  const flashModule = await new FlashModule__factory(signer).deploy({
    type: 2
  });
  await flashModule.deployed();

  console.log("flashModule addr: " + flashModule.address);

  const limitOrderModule = await new LimitOrderModule__factory(signer).deploy();
  await limitOrderModule.deployed();

  console.log("limitOrderModule addr: " + limitOrderModule.address);

  const liquidityModule = await new LiquidityModule__factory(signer).deploy();
  await liquidityModule.deployed();

  console.log("liquidityModule addr: " + liquidityModule.address);


  const swapX2YModule = await new SwapX2YModule__factory(signer).deploy();
  await swapX2YModule.deployed();

  console.log("swapX2YModule addr: " + swapX2YModule.address);

  const swapY2XModule = await new SwapX2YModule__factory(signer).deploy();
  await swapY2XModule.deployed();

  console.log("swapY2XModule addr: " + swapY2XModule.address);

  console.log("Paramters: ");

  // deploy a factory

  console.log('swapX2YModule: ', swapX2YModule.address)
  console.log('swapY2XModule: ', swapY2XModule.address)
  console.log('liquidityModule: ', liquidityModule.address)
  console.log('limitOrderModule: ', limitOrderModule.address)
  console.log('flashModule: ', flashModule.address);

  const factory = await new IZiSwapFactory__factory(signer).deploy(
    receiver,
    swapX2YModule.address,
    swapY2XModule.address,
    liquidityModule.address,
    limitOrderModule.address,
    flashModule.address,
    defaultFeeChargePercent);
  await factory.deployed();

  console.log("factory addr: " + factory.address);

  const liquidityManager = await new LiquidityManager__factory(signer).deploy(factory.address, weth)

  return { factory, liquidityManager }
}


export async function addLiquidity(
  signer: SignerWithAddress,
  tokenAddressA: string,
  tokenAddressB: string,
  amountA: BigNumber,
  amountB: BigNumber,
  uniswap: iZiFixture
) {
  if (tokenAddressA.toLowerCase() > tokenAddressB.toLowerCase())
    [tokenAddressA, tokenAddressB, amountA, amountB] = [tokenAddressB, tokenAddressA, amountB, amountA]


  await uniswap.liquidityManager.connect(signer).createPool(tokenAddressA, tokenAddressB, FeeAmount.MEDIUM, 0)

  const poolAddr = await uniswap.factory.pool(tokenAddressA, tokenAddressB, FeeAmount.MEDIUM)

  const tA = await new ethers.Contract(tokenAddressA, IERC20__factory.createInterface(), signer)
  await tA.connect(signer).approve(uniswap.factory.address, constants.MaxUint256)

  const tB = await new ethers.Contract(tokenAddressB, IERC20__factory.createInterface(), signer)
  await tB.connect(signer).approve(uniswap.factory.address, constants.MaxUint256)

  console.log("add liquidity", tokenAddressA, tokenAddressB)

  const poolId = await uniswap.liquidityManager.poolIds(poolAddr)

  const liquidityParams = {
    tokenX: tokenAddressA,
    tokenY: tokenAddressB,
    fee: FeeAmount.MEDIUM,
    pl: -1000,
    pr: 1050,
    xLim: "104869958",
    yLim: "100000000",
    amountXMin: 0,
    amountYMin: 0,
    deadline: 1,
    miner: signer.address,
    poolId
  }

  return uniswap.liquidityManager.connect(signer).mint(liquidityParams)
}
