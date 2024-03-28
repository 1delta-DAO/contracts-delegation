import {
    constants,
    getRandomPortion as _getRandomPortion,
} from '@0x/contracts-test-utils';


import {
    getRandomLimitOrder,
    getRandomRfqOrder,
    NativeOrdersTestEnvironment,
} from './utils/orders';
import { ethers, waffle } from 'hardhat';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import {
    MockERC20,
    MockERC20__factory,
    NativeOrders,
    TestOrderSignerRegistryWithContractWallet,
    TestOrderSignerRegistryWithContractWallet__factory,
    TestRfqOriginRegistration,
    TestRfqOriginRegistration__factory,
    WETH9,
    WETH9__factory
} from '../../../types';
import { MaxUint128 } from '../../uniswap-v3/periphery/shared/constants';
import { createNativeOrder } from './utils/orderFixture';
import { IZeroExEvents, LimitOrder, LimitOrderFields, RfqOrder, RfqOrderFields } from './utils/constants';
import { BigNumber } from 'ethers';
import { MockProvider } from 'ethereum-waffle';
import { expect } from '../shared/expect'
import {  verifyLogs } from './utils/utils';

const { NULL_ADDRESS, } = constants;
let GAS_PRICE: BigNumber
const PROTOCOL_FEE_MULTIPLIER = 1337e3;
let SINGLE_PROTOCOL_FEE: BigNumber;
let maker: SignerWithAddress;
let taker: SignerWithAddress;
let notMaker: SignerWithAddress;
let notTaker: SignerWithAddress;
let collector: SignerWithAddress;
let contractWalletOwner: SignerWithAddress;
let contractWalletSigner: SignerWithAddress;
let zeroEx: NativeOrders;
let verifyingContract: string;
let makerToken: MockERC20;
let takerToken: MockERC20;
let wethToken: WETH9;
let testRfqOriginRegistration: TestRfqOriginRegistration;
let contractWallet: TestOrderSignerRegistryWithContractWallet;
let testUtils: NativeOrdersTestEnvironment;
let provider: MockProvider;
let chainId: number
before(async () => {
    let owner;
    [owner, maker, taker, notMaker, notTaker, contractWalletOwner, contractWalletSigner, collector] =
        await ethers.getSigners();
    makerToken = await new MockERC20__factory(owner).deploy("Maker", 'M', 18)
    takerToken = await new MockERC20__factory(owner).deploy("Taker", "T", 6)
    wethToken = await new WETH9__factory(owner).deploy()

    provider = waffle.provider
    chainId = await maker.getChainId()
    console.log("ChainId", chainId, 'maker', maker.address, "taker", taker.address)
    console.log('makerToken', makerToken.address, "takerToken", takerToken.address)
    testRfqOriginRegistration = await new TestRfqOriginRegistration__factory(owner).deploy()

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
    testRfqOriginRegistration = await new TestRfqOriginRegistration__factory(owner).deploy()
    // contract wallet for signer delegation
    contractWallet = await new TestOrderSignerRegistryWithContractWallet__factory(contractWalletOwner).deploy(zeroEx.address)

    await contractWallet.connect(contractWalletOwner)
        .approveERC20(makerToken.address, zeroEx.address, MaxUint128)
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

function getTestRfqOrder(fields: Partial<RfqOrderFields> = {}): RfqOrder {
    return getRandomRfqOrder({
        maker: maker.address,
        verifyingContract,
        chainId,
        takerToken: takerToken.address,
        makerToken: makerToken.address,
        txOrigin: taker.address,
        ...fields,
    });
}

describe('batchFillLimitOrders', () => {
    async function assertExpectedFinalBalancesAsync(
        orders: LimitOrder[],
        takerTokenFillAmounts: BigNumber[] = orders.map(order => order.takerAmount),
        takerTokenAlreadyFilledAmounts: BigNumber[] = orders.map(() => ZERO_AMOUNT),
        receipt?: TransactionReceiptWithDecodedLogs,
    ): Promise<void> {
        const expectedFeeRecipientBalances: { [feeRecipient: string]: BigNumber } = {};
        const { makerTokenFilledAmount, takerTokenFilledAmount } = orders
            .map((order, i) =>
                computeLimitOrderFilledAmounts(order, takerTokenFillAmounts[i], takerTokenAlreadyFilledAmounts[i]),
            )
            .reduce(
                (previous, current, i) => {
                    _.update(expectedFeeRecipientBalances, orders[i].feeRecipient, balance =>
                        (balance || ZERO_AMOUNT).plus(current.takerTokenFeeFilledAmount),
                    );
                    return {
                        makerTokenFilledAmount: previous.makerTokenFilledAmount.plus(
                            current.makerTokenFilledAmount,
                        ),
                        takerTokenFilledAmount: previous.takerTokenFilledAmount.plus(
                            current.takerTokenFilledAmount,
                        ),
                    };
                },
                { makerTokenFilledAmount: ZERO_AMOUNT, takerTokenFilledAmount: ZERO_AMOUNT },
            );
        const makerBalance = await takerToken.balanceOf(maker).callAsync();
        const takerBalance = await makerToken.balanceOf(taker).callAsync();
        expect(makerBalance, 'maker token balance').to.bignumber.eq(takerTokenFilledAmount);
        expect(takerBalance, 'taker token balance').to.bignumber.eq(makerTokenFilledAmount);
        for (const [feeRecipient, expectedFeeRecipientBalance] of Object.entries(expectedFeeRecipientBalances)) {
            const feeRecipientBalance = await takerToken.balanceOf(feeRecipient).callAsync();
            expect(feeRecipientBalance, `fee recipient balance`).to.bignumber.eq(expectedFeeRecipientBalance);
        }
        if (receipt) {
            const balanceOfTakerNow = await env.web3Wrapper.getBalanceInWeiAsync(taker);
            const balanceOfTakerBefore = await env.web3Wrapper.getBalanceInWeiAsync(taker, receipt.blockNumber - 1);
            const protocolFees = testUtils.protocolFee.times(orders.length);
            const totalCost = testUtils.gasPrice.times(receipt.gasUsed).plus(protocolFees);
            expect(balanceOfTakerBefore.minus(totalCost), 'taker ETH balance').to.bignumber.eq(balanceOfTakerNow);
        }
    }

    it('Fully fills multiple orders', async () => {
        const orders = [...new Array(3)].map(() => getTestLimitOrder({ takerTokenFeeAmount: ZERO_AMOUNT }));
        const signatures = await Promise.all(
            orders.map(order => order.getSignatureWithProviderAsync(env.provider)),
        );
        await testUtils.prepareBalancesForOrdersAsync(orders);
        const value = testUtils.protocolFee.times(orders.length);
        const tx = await feature
            .batchFillLimitOrders(
                orders,
                signatures,
                orders.map(order => order.takerAmount),
                false,
            )
            .awaitTransactionSuccessAsync({ from: taker, value });
        const [orderInfos] = await zeroEx.batchGetLimitOrderRelevantStates(orders, signatures).callAsync();
        orderInfos.map((orderInfo, i) =>
            assertOrderInfoEquals(orderInfo, {
                status: OrderStatus.Filled,
                orderHash: orders[i].getHash(),
                takerTokenFilledAmount: orders[i].takerAmount,
            }),
        );
        verifyEventsFromLogs(
            tx.logs,
            orders.map(order => testUtils.createLimitOrderFilledEventArgs(order)),
            IZeroExEvents.LimitOrderFilled,
        );
        return assertExpectedFinalBalancesAsync(orders);
    });
    it('Partially fills multiple orders', async () => {
        const orders = [...new Array(3)].map(getTestLimitOrder);
        const signatures = await Promise.all(
            orders.map(order => order.getSignatureWithProviderAsync(env.provider)),
        );
        await testUtils.prepareBalancesForOrdersAsync(orders);
        const value = testUtils.protocolFee.times(orders.length);
        const fillAmounts = orders.map(order => getRandomPortion(order.takerAmount));
        const tx = await feature
            .batchFillLimitOrders(orders, signatures, fillAmounts, false)
            .awaitTransactionSuccessAsync({ from: taker, value });
        const [orderInfos] = await zeroEx.batchGetLimitOrderRelevantStates(orders, signatures).callAsync();
        orderInfos.map((orderInfo, i) =>
            assertOrderInfoEquals(orderInfo, {
                status: OrderStatus.Fillable,
                orderHash: orders[i].getHash(),
                takerTokenFilledAmount: fillAmounts[i],
            }),
        );
        verifyEventsFromLogs(
            tx.logs,
            orders.map((order, i) => testUtils.createLimitOrderFilledEventArgs(order, fillAmounts[i])),
            IZeroExEvents.LimitOrderFilled,
        );
        return assertExpectedFinalBalancesAsync(orders, fillAmounts);
    });
    it('Fills multiple orders and refunds excess ETH', async () => {
        const orders = [...new Array(3)].map(() => getTestLimitOrder({ takerTokenFeeAmount: ZERO_AMOUNT }));
        const signatures = await Promise.all(
            orders.map(order => order.getSignatureWithProviderAsync(env.provider)),
        );
        await testUtils.prepareBalancesForOrdersAsync(orders);
        const value = testUtils.protocolFee.times(orders.length).plus(420);
        const tx = await feature
            .batchFillLimitOrders(
                orders,
                signatures,
                orders.map(order => order.takerAmount),
                false,
            )
            .awaitTransactionSuccessAsync({ from: taker, value });
        const [orderInfos] = await zeroEx.batchGetLimitOrderRelevantStates(orders, signatures).callAsync();
        orderInfos.map((orderInfo, i) =>
            assertOrderInfoEquals(orderInfo, {
                status: OrderStatus.Filled,
                orderHash: orders[i].getHash(),
                takerTokenFilledAmount: orders[i].takerAmount,
            }),
        );
        verifyEventsFromLogs(
            tx.logs,
            orders.map(order => testUtils.createLimitOrderFilledEventArgs(order)),
            IZeroExEvents.LimitOrderFilled,
        );
        return assertExpectedFinalBalancesAsync(orders);
    });
    it('Skips over unfillable orders and refunds excess ETH', async () => {
        const fillableOrders = [...new Array(3)].map(() => getTestLimitOrder({ takerTokenFeeAmount: ZERO_AMOUNT }));
        const expiredOrder = getTestLimitOrder({ expiry: createExpiry(-1), takerTokenFeeAmount: ZERO_AMOUNT });
        const orders = [expiredOrder, ...fillableOrders];
        const signatures = await Promise.all(
            orders.map(order => order.getSignatureWithProviderAsync(env.provider)),
        );
        await testUtils.prepareBalancesForOrdersAsync(orders);
        const value = testUtils.protocolFee.times(orders.length);
        const tx = await feature
            .batchFillLimitOrders(
                orders,
                signatures,
                orders.map(order => order.takerAmount),
                false,
            )
            .awaitTransactionSuccessAsync({ from: taker, value });
        const [orderInfos] = await zeroEx.batchGetLimitOrderRelevantStates(orders, signatures).callAsync();
        const [expiredOrderInfo, ...filledOrderInfos] = orderInfos;
        assertOrderInfoEquals(expiredOrderInfo, {
            status: OrderStatus.Expired,
            orderHash: expiredOrder.getHash(),
            takerTokenFilledAmount: ZERO_AMOUNT,
        });
        filledOrderInfos.map((orderInfo, i) =>
            assertOrderInfoEquals(orderInfo, {
                status: OrderStatus.Filled,
                orderHash: fillableOrders[i].getHash(),
                takerTokenFilledAmount: fillableOrders[i].takerAmount,
            }),
        );
        verifyEventsFromLogs(
            tx.logs,
            fillableOrders.map(order => testUtils.createLimitOrderFilledEventArgs(order)),
            IZeroExEvents.LimitOrderFilled,
        );
        return assertExpectedFinalBalancesAsync(fillableOrders);
    });
    it('Fills multiple orders with revertIfIncomplete=true', async () => {
        const orders = [...new Array(3)].map(() => getTestLimitOrder({ takerTokenFeeAmount: ZERO_AMOUNT }));
        const signatures = await Promise.all(
            orders.map(order => order.getSignatureWithProviderAsync(env.provider)),
        );
        await testUtils.prepareBalancesForOrdersAsync(orders);
        const value = testUtils.protocolFee.times(orders.length);
        const tx = await feature
            .batchFillLimitOrders(
                orders,
                signatures,
                orders.map(order => order.takerAmount),
                true,
            )
            .awaitTransactionSuccessAsync({ from: taker, value });
        const [orderInfos] = await zeroEx.batchGetLimitOrderRelevantStates(orders, signatures).callAsync();
        orderInfos.map((orderInfo, i) =>
            assertOrderInfoEquals(orderInfo, {
                status: OrderStatus.Filled,
                orderHash: orders[i].getHash(),
                takerTokenFilledAmount: orders[i].takerAmount,
            }),
        );
        verifyEventsFromLogs(
            tx.logs,
            orders.map(order => testUtils.createLimitOrderFilledEventArgs(order)),
            IZeroExEvents.LimitOrderFilled,
        );
        return assertExpectedFinalBalancesAsync(orders);
    });
    it('If revertIfIncomplete==true, reverts on an unfillable order', async () => {
        const fillableOrders = [...new Array(3)].map(() => getTestLimitOrder({ takerTokenFeeAmount: ZERO_AMOUNT }));
        const expiredOrder = getTestLimitOrder({ expiry: createExpiry(-1), takerTokenFeeAmount: ZERO_AMOUNT });
        const orders = [expiredOrder, ...fillableOrders];
        const signatures = await Promise.all(
            orders.map(order => order.getSignatureWithProviderAsync(env.provider)),
        );
        await testUtils.prepareBalancesForOrdersAsync(orders);
        const value = testUtils.protocolFee.times(orders.length);
        const tx = feature
            .batchFillLimitOrders(
                orders,
                signatures,
                orders.map(order => order.takerAmount),
                true,
            )
            .awaitTransactionSuccessAsync({ from: taker, value });
        return expect(tx).to.revertWith(
            new RevertErrors.NativeOrders.BatchFillIncompleteError(
                expiredOrder.getHash(),
                ZERO_AMOUNT,
                expiredOrder.takerAmount,
            ),
        );
    });
    it('If revertIfIncomplete==true, reverts on an incomplete fill ', async () => {
        const fillableOrders = [...new Array(3)].map(() => getTestLimitOrder({ takerTokenFeeAmount: ZERO_AMOUNT }));
        const partiallyFilledOrder = getTestLimitOrder({ takerTokenFeeAmount: ZERO_AMOUNT });
        const partialFillAmount = getRandomPortion(partiallyFilledOrder.takerAmount);
        await testUtils.fillLimitOrderAsync(partiallyFilledOrder, { fillAmount: partialFillAmount });
        const orders = [partiallyFilledOrder, ...fillableOrders];
        const signatures = await Promise.all(
            orders.map(order => order.getSignatureWithProviderAsync(env.provider)),
        );
        await testUtils.prepareBalancesForOrdersAsync(orders);
        const value = testUtils.protocolFee.times(orders.length);
        const tx = feature
            .batchFillLimitOrders(
                orders,
                signatures,
                orders.map(order => order.takerAmount),
                true,
            )
            .awaitTransactionSuccessAsync({ from: taker, value });
        return expect(tx).to.revertWith(
            new RevertErrors.NativeOrders.BatchFillIncompleteError(
                partiallyFilledOrder.getHash(),
                partiallyFilledOrder.takerAmount.minus(partialFillAmount),
                partiallyFilledOrder.takerAmount,
            ),
        );
    });
});
describe('batchFillRfqOrders', () => {
    async function assertExpectedFinalBalancesAsync(
        orders: RfqOrder[],
        takerTokenFillAmounts: BigNumber[] = orders.map(order => order.takerAmount),
        takerTokenAlreadyFilledAmounts: BigNumber[] = orders.map(() => ZERO_AMOUNT),
    ): Promise<void> {
        const { makerTokenFilledAmount, takerTokenFilledAmount } = orders
            .map((order, i) =>
                computeRfqOrderFilledAmounts(order, takerTokenFillAmounts[i], takerTokenAlreadyFilledAmounts[i]),
            )
            .reduce((previous, current) => ({
                makerTokenFilledAmount: previous.makerTokenFilledAmount.plus(current.makerTokenFilledAmount),
                takerTokenFilledAmount: previous.takerTokenFilledAmount.plus(current.takerTokenFilledAmount),
            }));
        const makerBalance = await takerToken.balanceOf(maker).callAsync();
        const takerBalance = await makerToken.balanceOf(taker).callAsync();
        expect(makerBalance).to.bignumber.eq(takerTokenFilledAmount);
        expect(takerBalance).to.bignumber.eq(makerTokenFilledAmount);
    }

    it('Fully fills multiple orders', async () => {
        const orders = [...new Array(3)].map(() => getTestRfqOrder());
        const signatures = await Promise.all(
            orders.map(order => order.getSignatureWithProviderAsync(env.provider)),
        );
        await testUtils.prepareBalancesForOrdersAsync(orders);
        const tx = await feature
            .batchFillRfqOrders(
                orders,
                signatures,
                orders.map(order => order.takerAmount),
                false,
            )
            .awaitTransactionSuccessAsync({ from: taker });
        const [orderInfos] = await zeroEx.batchGetRfqOrderRelevantStates(orders, signatures).callAsync();
        orderInfos.map((orderInfo, i) =>
            assertOrderInfoEquals(orderInfo, {
                status: OrderStatus.Filled,
                orderHash: orders[i].getHash(),
                takerTokenFilledAmount: orders[i].takerAmount,
            }),
        );
        verifyEventsFromLogs(
            tx.logs,
            orders.map(order => testUtils.createRfqOrderFilledEventArgs(order)),
            IZeroExEvents.RfqOrderFilled,
        );
        return assertExpectedFinalBalancesAsync(orders);
    });
    it('Partially fills multiple orders', async () => {
        const orders = [...new Array(3)].map(() => getTestRfqOrder());
        const signatures = await Promise.all(
            orders.map(order => order.getSignatureWithProviderAsync(env.provider)),
        );
        const fillAmounts = orders.map(order => getRandomPortion(order.takerAmount));
        await testUtils.prepareBalancesForOrdersAsync(orders);
        const tx = await feature
            .batchFillRfqOrders(orders, signatures, fillAmounts, false)
            .awaitTransactionSuccessAsync({ from: taker });
        const [orderInfos] = await zeroEx.batchGetRfqOrderRelevantStates(orders, signatures).callAsync();
        orderInfos.map((orderInfo, i) =>
            assertOrderInfoEquals(orderInfo, {
                status: OrderStatus.Fillable,
                orderHash: orders[i].getHash(),
                takerTokenFilledAmount: fillAmounts[i],
            }),
        );
        verifyEventsFromLogs(
            tx.logs,
            orders.map((order, i) => testUtils.createRfqOrderFilledEventArgs(order, fillAmounts[i])),
            IZeroExEvents.RfqOrderFilled,
        );
        return assertExpectedFinalBalancesAsync(orders, fillAmounts);
    });
    it('Skips over unfillable orders', async () => {
        const fillableOrders = [...new Array(3)].map(() => getTestRfqOrder());
        const expiredOrder = getTestRfqOrder({ expiry: createExpiry(-1) });
        const orders = [expiredOrder, ...fillableOrders];
        const signatures = await Promise.all(
            orders.map(order => order.getSignatureWithProviderAsync(env.provider)),
        );
        await testUtils.prepareBalancesForOrdersAsync(orders);
        const tx = await feature
            .batchFillRfqOrders(
                orders,
                signatures,
                orders.map(order => order.takerAmount),
                false,
            )
            .awaitTransactionSuccessAsync({ from: taker });
        const [orderInfos] = await zeroEx.batchGetRfqOrderRelevantStates(orders, signatures).callAsync();
        const [expiredOrderInfo, ...filledOrderInfos] = orderInfos;
        assertOrderInfoEquals(expiredOrderInfo, {
            status: OrderStatus.Expired,
            orderHash: expiredOrder.getHash(),
            takerTokenFilledAmount: ZERO_AMOUNT,
        });
        filledOrderInfos.map((orderInfo, i) =>
            assertOrderInfoEquals(orderInfo, {
                status: OrderStatus.Filled,
                orderHash: fillableOrders[i].getHash(),
                takerTokenFilledAmount: fillableOrders[i].takerAmount,
            }),
        );
        verifyEventsFromLogs(
            tx.logs,
            fillableOrders.map(order => testUtils.createRfqOrderFilledEventArgs(order)),
            IZeroExEvents.RfqOrderFilled,
        );
        return assertExpectedFinalBalancesAsync(fillableOrders);
    });
    it('Fills multiple orders with revertIfIncomplete=true', async () => {
        const orders = [...new Array(3)].map(() => getTestRfqOrder());
        const signatures = await Promise.all(
            orders.map(order => order.getSignatureWithProviderAsync(env.provider)),
        );
        await testUtils.prepareBalancesForOrdersAsync(orders);
        const tx = await feature
            .batchFillRfqOrders(
                orders,
                signatures,
                orders.map(order => order.takerAmount),
                true,
            )
            .awaitTransactionSuccessAsync({ from: taker });
        const [orderInfos] = await zeroEx.batchGetRfqOrderRelevantStates(orders, signatures).callAsync();
        orderInfos.map((orderInfo, i) =>
            assertOrderInfoEquals(orderInfo, {
                status: OrderStatus.Filled,
                orderHash: orders[i].getHash(),
                takerTokenFilledAmount: orders[i].takerAmount,
            }),
        );
        verifyEventsFromLogs(
            tx.logs,
            orders.map(order => testUtils.createRfqOrderFilledEventArgs(order)),
            IZeroExEvents.RfqOrderFilled,
        );
        return assertExpectedFinalBalancesAsync(orders);
    });
    it('If revertIfIncomplete==true, reverts on an unfillable order', async () => {
        const fillableOrders = [...new Array(3)].map(() => getTestRfqOrder());
        const expiredOrder = getTestRfqOrder({ expiry: createExpiry(-1) });
        const orders = [expiredOrder, ...fillableOrders];
        const signatures = await Promise.all(
            orders.map(order => order.getSignatureWithProviderAsync(env.provider)),
        );
        await testUtils.prepareBalancesForOrdersAsync(orders);
        const tx = feature
            .batchFillRfqOrders(
                orders,
                signatures,
                orders.map(order => order.takerAmount),
                true,
            )
            .awaitTransactionSuccessAsync({ from: taker });
        return expect(tx).to.revertWith(
            new RevertErrors.NativeOrders.BatchFillIncompleteError(
                expiredOrder.getHash(),
                ZERO_AMOUNT,
                expiredOrder.takerAmount,
            ),
        );
    });
    it('If revertIfIncomplete==true, reverts on an incomplete fill ', async () => {
        const fillableOrders = [...new Array(3)].map(() => getTestRfqOrder());
        const partiallyFilledOrder = getTestRfqOrder();
        const partialFillAmount = getRandomPortion(partiallyFilledOrder.takerAmount);
        await testUtils.fillRfqOrderAsync(partiallyFilledOrder, partialFillAmount);
        const orders = [partiallyFilledOrder, ...fillableOrders];
        const signatures = await Promise.all(
            orders.map(order => order.getSignatureWithProviderAsync(env.provider)),
        );
        await testUtils.prepareBalancesForOrdersAsync(orders);
        const tx = feature
            .batchFillRfqOrders(
                orders,
                signatures,
                orders.map(order => order.takerAmount),
                true,
            )
            .awaitTransactionSuccessAsync({ from: taker });
        return expect(tx).to.revertWith(
            new RevertErrors.NativeOrders.BatchFillIncompleteError(
                partiallyFilledOrder.getHash(),
                partiallyFilledOrder.takerAmount.minus(partialFillAmount),
                partiallyFilledOrder.takerAmount,
            ),
        );
    });
});
});