import {
    constants,
    getRandomPortion as _getRandomPortion,
} from '@0x/contracts-test-utils';
import {
    assertOrderInfoEquals,
    computeLimitOrderFilledAmounts,
    createExpiry,
    getRandomLimitOrder,
    NativeOrdersTestEnvironment,
} from './utils/orders';
import { ethers, waffle } from 'hardhat';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import {
    MockERC20,
    MockERC20__factory,
    NativeOrders,
    WETH9,
    WETH9__factory
} from '../../../types';
import { MaxUint128 } from '../../uniswap-v3/periphery/shared/constants';
import { createNativeOrder } from './utils/orderFixture';
import { IZeroExEvents, LimitOrder, LimitOrderFields, OrderStatus } from './utils/constants';
import { BigNumber, ContractReceipt } from 'ethers';
import { MockProvider } from 'ethereum-waffle';
import { expect } from '../shared/expect'
import { verifyLogs } from './utils/utils';

const { NULL_ADDRESS,  } = constants;
const ZERO_AMOUNT = BigNumber.from(0)
let GAS_PRICE: BigNumber
const PROTOCOL_FEE_MULTIPLIER = 1337e3;
let SINGLE_PROTOCOL_FEE: BigNumber;
let maker: SignerWithAddress;
let taker: SignerWithAddress;
let notMaker: SignerWithAddress;
let notTaker: SignerWithAddress;
let collector: SignerWithAddress;
let zeroEx: NativeOrders;
let verifyingContract: string;
let makerToken: MockERC20;
let takerToken: MockERC20;
let wethToken: WETH9;
let testUtils: NativeOrdersTestEnvironment;
let provider: MockProvider;
let chainId: number
before(async () => {
    let owner;
    [owner, maker, taker, notMaker, notTaker, collector] =
        await ethers.getSigners();
    makerToken = await new MockERC20__factory(owner).deploy("Maker", 'M', 18)
    takerToken = await new MockERC20__factory(owner).deploy("Taker", "T", 6)
    wethToken = await new WETH9__factory(owner).deploy()

    provider = waffle.provider
    chainId = await maker.getChainId()
    console.log("ChainId", chainId, 'maker', maker.address, "taker", taker.address)
    console.log('makerToken', makerToken.address, "takerToken", takerToken.address)

    zeroEx = await createNativeOrder(
        owner,
        collector.address,
        BigNumber.from(PROTOCOL_FEE_MULTIPLIER)
    );

    verifyingContract = zeroEx.address;
    await Promise.all(
        [maker, notMaker].map(a =>
            makerToken.connect(a).approve(zeroEx.address, MaxUint128),
        ),
    );
    await Promise.all(
        [taker, notTaker].map(a =>
            takerToken.connect(a).approve(zeroEx.address, MaxUint128),
        ),
    );

    GAS_PRICE = await provider.getGasPrice()
    SINGLE_PROTOCOL_FEE = GAS_PRICE.mul(PROTOCOL_FEE_MULTIPLIER);
    testUtils = new NativeOrdersTestEnvironment(
        maker,
        taker,
        makerToken,
        takerToken,
        zeroEx,
        GAS_PRICE,
        SINGLE_PROTOCOL_FEE,
    );
});

function getTestLimitOrder(fields: Partial<LimitOrderFields> = {}): LimitOrder {
    return getRandomLimitOrder({
        maker: maker.address,
        verifyingContract,
        chainId,
        takerToken: takerToken.address,
        makerToken: makerToken.address,
        taker: NULL_ADDRESS,
        sender: NULL_ADDRESS,
        ...fields,
    });
}

async function getMakerTakerBalances(feeRecipient: string) {
    const makerBalance = await takerToken.balanceOf(maker.address);
    const takerBalance = await makerToken.balanceOf(taker.address);
    const feeRecipientBalance = await makerToken.balanceOf(feeRecipient);
    return [makerBalance, takerBalance, feeRecipientBalance]
}

async function assertExpectedFinalBalancesFromLimitOrderFillAsync(
    makerBalanceBefore: BigNumber,
    takerBalanceBefore: BigNumber,
    feeRecipientBalanceBefore: BigNumber,
    order: LimitOrder,
    opts: Partial<{
        takerTokenFillAmount: BigNumber;
        takerTokenAlreadyFilledAmount: BigNumber;
        receipt: ContractReceipt;
    }> = {},
): Promise<void> {
    const { takerTokenFillAmount, takerTokenAlreadyFilledAmount, receipt } = {
        takerTokenFillAmount: order.takerAmount,
        takerTokenAlreadyFilledAmount: ZERO_AMOUNT,
        receipt: undefined,
        ...opts,
    };
    const { makerTokenFilledAmount, takerTokenFilledAmount, takerTokenFeeFilledAmount } =
        computeLimitOrderFilledAmounts(order, takerTokenFillAmount, takerTokenAlreadyFilledAmount);
    const makerBalance = await takerToken.balanceOf(maker.address);
    const takerBalance = await makerToken.balanceOf(taker.address);
    const feeRecipientBalance = await takerToken.balanceOf(order.feeRecipient);
    expect(makerBalance.sub(makerBalanceBefore).toString()).to.eq(takerTokenFilledAmount.toString());
    expect(takerBalance.sub(takerBalanceBefore).toString()).to.eq(makerTokenFilledAmount.toString());
    expect(feeRecipientBalance.sub(feeRecipientBalanceBefore).toString()).to.eq(takerTokenFeeFilledAmount.toString());
    if (receipt) {
        const balanceOfTakerNow = await provider.getBalance(taker.address);
        const balanceOfTakerBefore = await provider.getBalance(taker.address, await provider.getBlockNumber() - 1);
        const protocolFee = order.taker === NULL_ADDRESS ? SINGLE_PROTOCOL_FEE : 0;
        const totalCost = GAS_PRICE.mul(receipt.gasUsed).add(protocolFee);
        expect(balanceOfTakerBefore.sub(totalCost).toString()).to.eq(balanceOfTakerNow.toString());
    }
}

describe('fillLimitOrder()', () => {
    it('can fully fill an order', async () => {
        const order = getTestLimitOrder();
        const [
            makerBalanceBefore,
            takerBalanceBefore,
            feeRecipientBalanceBefore,
        ] = await getMakerTakerBalances(order.feeRecipient)
        const tx = await testUtils.fillLimitOrderAsync(order);
        const receipt = await tx.wait()
        verifyLogs(
            receipt.logs,
            [testUtils.createLimitOrderFilledEventArgs(order)],
            IZeroExEvents.LimitOrderFilled,
        );
        assertOrderInfoEquals(await zeroEx.getLimitOrderInfo(order), {
            orderHash: order.getHash(),
            status: OrderStatus.Filled,
            takerTokenFilledAmount: order.takerAmount,
        });
        await assertExpectedFinalBalancesFromLimitOrderFillAsync(
            makerBalanceBefore,
            takerBalanceBefore,
            feeRecipientBalanceBefore,
            order, { receipt });
    });

    it('can partially fill an order', async () => {
        const order = getTestLimitOrder();
        const fillAmount = order.takerAmount.sub(1);

        const [
            makerBalanceBefore,
            takerBalanceBefore,
            feeRecipientBalanceBefore,
        ] = await getMakerTakerBalances(order.feeRecipient)

        const tx = await testUtils.fillLimitOrderAsync(order, { fillAmount });
        const receipt = await tx.wait()
        verifyLogs(
            receipt.logs,
            [testUtils.createLimitOrderFilledEventArgs(order, fillAmount)],
            IZeroExEvents.LimitOrderFilled,
        );
        assertOrderInfoEquals(await zeroEx.getLimitOrderInfo(order), {
            orderHash: order.getHash(),
            status: OrderStatus.Fillable,
            takerTokenFilledAmount: fillAmount,
        });
        await assertExpectedFinalBalancesFromLimitOrderFillAsync(
            makerBalanceBefore,
            takerBalanceBefore,
            feeRecipientBalanceBefore,
            order, {
            takerTokenFillAmount: fillAmount,
        });
    });

    it('can fully fill an order in two steps', async () => {
        const order = getTestLimitOrder();
        let fillAmount = order.takerAmount.div(2);
        let tx = await testUtils.fillLimitOrderAsync(order, { fillAmount });
        let receipt = await tx.wait()
        verifyLogs(
            receipt.logs,
            [testUtils.createLimitOrderFilledEventArgs(order, fillAmount)],
            IZeroExEvents.LimitOrderFilled,
        );
        const alreadyFilledAmount = fillAmount;
        fillAmount = order.takerAmount.sub(fillAmount);
        tx = await testUtils.fillLimitOrderAsync(order, { fillAmount });
        receipt = await tx.wait()
        verifyLogs(
            receipt.logs,
            [testUtils.createLimitOrderFilledEventArgs(order, fillAmount, alreadyFilledAmount)],
            IZeroExEvents.LimitOrderFilled,
        );
        assertOrderInfoEquals(await zeroEx.getLimitOrderInfo(order), {
            orderHash: order.getHash(),
            status: OrderStatus.Filled,
            takerTokenFilledAmount: order.takerAmount,
        });
    });

    it('clamps fill amount to remaining available', async () => {
        const order = getTestLimitOrder();
        const fillAmount = order.takerAmount.add(1);

        const [
            makerBalanceBefore,
            takerBalanceBefore,
            feeRecipientBalanceBefore,
        ] = await getMakerTakerBalances(order.feeRecipient)


        const tx = await testUtils.fillLimitOrderAsync(order, { fillAmount });
        const receipt = await tx.wait()
        verifyLogs(
            receipt.logs,
            [testUtils.createLimitOrderFilledEventArgs(order, fillAmount)],
            IZeroExEvents.LimitOrderFilled,
        );
        assertOrderInfoEquals(await zeroEx.getLimitOrderInfo(order), {
            orderHash: order.getHash(),
            status: OrderStatus.Filled,
            takerTokenFilledAmount: order.takerAmount,
        });
        await assertExpectedFinalBalancesFromLimitOrderFillAsync(
            makerBalanceBefore,
            takerBalanceBefore,
            feeRecipientBalanceBefore,
            order, {
            takerTokenFillAmount: fillAmount,
        });
    });

    it('clamps fill amount to remaining available in partial filled order', async () => {
        const order = getTestLimitOrder();
        let fillAmount = order.takerAmount.div(2);
        let tx = await testUtils.fillLimitOrderAsync(order, { fillAmount });
        let receipt = await tx.wait()
        verifyLogs(
            receipt.logs,
            [testUtils.createLimitOrderFilledEventArgs(order, fillAmount)],
            IZeroExEvents.LimitOrderFilled,
        );
        const alreadyFilledAmount = fillAmount;
        fillAmount = order.takerAmount.sub(fillAmount).add(1);
        tx = await testUtils.fillLimitOrderAsync(order, { fillAmount });
        receipt = await tx.wait()
        verifyLogs(
            receipt.logs,
            [testUtils.createLimitOrderFilledEventArgs(order, fillAmount, alreadyFilledAmount)],
            IZeroExEvents.LimitOrderFilled,
        );
        assertOrderInfoEquals(await zeroEx.getLimitOrderInfo(order), {
            orderHash: order.getHash(),
            status: OrderStatus.Filled,
            takerTokenFilledAmount: order.takerAmount,
        });
    });

    it('cannot fill an expired order', async () => {
        const order = getTestLimitOrder({ expiry: createExpiry(-60 * 60) });
        await expect(testUtils.fillLimitOrderAsync(order)).to.be.revertedWith(
            "orderNotFillableError",
        ).withArgs(order.getHash(), OrderStatus.Expired);
    });

    it('cannot fill a cancelled order', async () => {
        const order = getTestLimitOrder();
        await zeroEx.connect(maker).cancelLimitOrder(order);
        await expect(
            testUtils.fillLimitOrderAsync(order)
        ).to.be.revertedWith(
            "orderNotFillableError",
        ).withArgs(order.getHash(), OrderStatus.Cancelled);
    });

    it('cannot fill a salt/pair cancelled order', async () => {
        const order = getTestLimitOrder();
        await zeroEx.connect(maker)
            .cancelPairLimitOrders(makerToken.address, takerToken.address, order.salt.add(1));
        await expect(testUtils.fillLimitOrderAsync(order)).to.be.revertedWith(
            "orderNotFillableError",
        ).withArgs(order.getHash(), OrderStatus.Cancelled);
    });

    it('non-taker cannot fill order', async () => {
        const order = getTestLimitOrder({ taker: taker.address });
        await expect(
            testUtils.fillLimitOrderAsync(order, { fillAmount: order.takerAmount, taker: notTaker })
        ).to.be.revertedWith(
            "orderNotFillableByTakerError",
        ).withArgs(order.getHash(), notTaker.address, order.taker);
    });

    it('non-sender cannot fill order', async () => {
        const order = getTestLimitOrder({ sender: taker.address });
        await expect(
            testUtils.fillLimitOrderAsync(order, { fillAmount: order.takerAmount, taker: notTaker })
        ).to.be.revertedWith(
            "orderNotFillableBySenderError",
        ).withArgs(order.getHash(), notTaker.address, order.sender);
    });

    it('cannot fill order with bad signature', async () => {
        const order = getTestLimitOrder();
        // Overwrite chainId to result in a different hash and therefore different
        // signature.
        await expect(
            testUtils.fillLimitOrderAsync(order.clone({ chainId: 1234 }))
        ).to.be.revertedWith(
            "orderNotSignedByMakerError",
        ) // .withArgs(order.getHash(), undefined, order.maker);
    });

    // TODO: dekz Ganache gasPrice opcode is returning 0, cannot influence it up to test this case
    it('fails if no protocol fee attached', async () => {
        const order = getTestLimitOrder();
        await testUtils.prepareBalancesForOrdersAsync([order]);
        const tx = zeroEx.connect(taker)
            .fillLimitOrder(
                order,
                await order.getSignatureWithProviderAsync(maker),
                BigNumber.from(order.takerAmount),
                {
                    value: ZERO_AMOUNT
                }
            );
        // The exact revert error depends on whether we are still doing a
        // token spender fallthroigh, so we won't get too specific.
        await expect(tx).to.be.reverted;
    });

    it('refunds excess protocol fee', async () => {
        const order = getTestLimitOrder();
        const [
            makerBalanceBefore,
            takerBalanceBefore,
            feeRecipientBalanceBefore,
        ] = await getMakerTakerBalances(order.feeRecipient)

        const tx = await testUtils.fillLimitOrderAsync(order, { protocolFee: SINGLE_PROTOCOL_FEE.add(1) });
        const receipt = await tx.wait()
        verifyLogs(
            receipt.logs,
            [testUtils.createLimitOrderFilledEventArgs(order)],
            IZeroExEvents.LimitOrderFilled,
        );
        await assertExpectedFinalBalancesFromLimitOrderFillAsync(
            makerBalanceBefore,
            takerBalanceBefore,
            feeRecipientBalanceBefore,
            order, { receipt });
    });
});
