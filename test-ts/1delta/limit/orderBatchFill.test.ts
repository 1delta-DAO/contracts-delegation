import {
    constants,
    getRandomPortion as _getRandomPortion,
} from '@0x/contracts-test-utils';


import {
    assertOrderInfoEquals,
    computeLimitOrderFilledAmounts,
    computeRfqOrderFilledAmounts,
    createCleanExpiry,
    getRandomLimitOrder,
    getRandomRfqOrder,
    NativeOrdersTestEnvironment,
} from './utils/orders';
import { ethers, waffle } from 'hardhat';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import {
    MockERC20,
    MockERC20__factory,
    NativeOrders
} from '../../../types';
import { MaxUint128 } from '../../uniswap-v3/periphery/shared/constants';
import { createNativeOrder } from './utils/orderFixture';
import { IZeroExEvents, LimitOrder, LimitOrderFields, OrderStatus, RfqOrder, RfqOrderFields } from './utils/constants';
import { BigNumber, ContractReceipt } from 'ethers';
import { MockProvider } from 'ethereum-waffle';
import { expect } from '../shared/expect'
import { validateError, verifyLogs } from './utils/utils';
import * as _ from 'lodash';

const getRandomPortion = (n: BigNumber) => BigNumber.from(_getRandomPortion(n.toString()).toString())

const { NULL_ADDRESS, } = constants;
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
let testUtils: NativeOrdersTestEnvironment;
let provider: MockProvider;
let chainId: number
before(async () => {
    let owner;
    [owner, maker, taker, notMaker, notTaker, collector] =
        await ethers.getSigners();
    makerToken = await new MockERC20__factory(owner).deploy("Maker", 'M', 18)
    takerToken = await new MockERC20__factory(owner).deploy("Taker", "T", 6)

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
        receipt?: ContractReceipt,
    ): Promise<void> {
        const blockTag = await provider.getBlockNumber() - 1
        const expectedFeeRecipientBalances: { [feeRecipient: string]: BigNumber } = {};
        const { makerTokenFilledAmount, takerTokenFilledAmount } = orders
            .map((order, i) =>
                computeLimitOrderFilledAmounts(order, takerTokenFillAmounts[i], takerTokenAlreadyFilledAmounts[i]),
            )
            .reduce(
                (previous, current, i) => {
                    _.update(expectedFeeRecipientBalances, orders[i].feeRecipient, balance =>
                        (balance || ZERO_AMOUNT).add(current.takerTokenFeeFilledAmount),
                    );
                    return {
                        makerTokenFilledAmount: previous.makerTokenFilledAmount.add(
                            current.makerTokenFilledAmount,
                        ),
                        takerTokenFilledAmount: previous.takerTokenFilledAmount.add(
                            current.takerTokenFilledAmount,
                        ),
                    };
                },
                { makerTokenFilledAmount: ZERO_AMOUNT, takerTokenFilledAmount: ZERO_AMOUNT },
            );
        const makerBalanceBefore = await takerToken.balanceOf(maker.address, { blockTag });
        const takerBalanceBefore = await makerToken.balanceOf(taker.address, { blockTag });
        const makerBalance = await takerToken.balanceOf(maker.address);
        const takerBalance = await makerToken.balanceOf(taker.address);

        expect(makerBalance.sub(makerBalanceBefore).toString(), 'maker token balance').to.eq(takerTokenFilledAmount.toString());
        expect(takerBalance.sub(takerBalanceBefore).toString(), 'taker token balance').to.eq(makerTokenFilledAmount.toString());
        for (const [feeRecipient, expectedFeeRecipientBalance] of Object.entries(expectedFeeRecipientBalances)) {
            const feeRecipientBalance = await takerToken.balanceOf(feeRecipient);
            const feeRecipientBalanceBefore = await takerToken.balanceOf(feeRecipient, { blockTag });
            expect(feeRecipientBalance.sub(feeRecipientBalanceBefore).toString(), `fee recipient balance`).to.eq(expectedFeeRecipientBalance.toString());
        }
        if (receipt) {
            const balanceOfTakerNow = await provider.getBalance(taker.address);
            const balanceOfTakerBefore = await provider.getBalance(taker.address, blockTag);
            const protocolFees = testUtils.protocolFee.mul(orders.length);
            const totalCost = testUtils.gasPrice.mul(receipt.gasUsed).add(protocolFees);
            expect(balanceOfTakerBefore.sub(totalCost).toString(), 'taker ETH balance').to.eq(balanceOfTakerNow.toString());
        }
    }

    it('Fully fills multiple orders', async () => {

        const orders = [...new Array(3)].map(() => getTestLimitOrder({ takerTokenFeeAmount: ZERO_AMOUNT }));

        const signatures = await Promise.all(
            orders.map(async order => order.getSignatureWithProviderAsync(await ethers.getSigner(order.maker))),
        );
        await testUtils.prepareBalancesForOrdersAsync(orders);
        const value = testUtils.protocolFee.mul(orders.length);
        const tx = await zeroEx.connect(taker)
            .batchFillLimitOrders(
                orders,
                signatures,
                orders.map(order => order.takerAmount),
                false,
                { value, gasPrice: GAS_PRICE }
            );
        const receipt = await tx.wait()
        const [orderInfos] = await zeroEx.batchGetLimitOrderRelevantStates(orders, signatures);
        orderInfos.map((orderInfo, i) =>
            assertOrderInfoEquals(orderInfo, {
                status: OrderStatus.Filled,
                orderHash: orders[i].getHash(),
                takerTokenFilledAmount: orders[i].takerAmount,
            }),
        );
        verifyLogs(
            receipt.logs,
            orders.map(order => testUtils.createLimitOrderFilledEventArgs(order)),
            IZeroExEvents.LimitOrderFilled,
        );
        return assertExpectedFinalBalancesAsync(orders);
    });
    it('Partially fills multiple orders', async () => {
        const orders = [...new Array(3)].map(getTestLimitOrder);
        const signatures = await Promise.all(
            orders.map(async order => order.getSignatureWithProviderAsync(await ethers.getSigner(order.maker))),
        );
        await testUtils.prepareBalancesForOrdersAsync(orders);
        const value = testUtils.protocolFee.mul(orders.length);
        const fillAmounts = orders.map(order => getRandomPortion(order.takerAmount));
        const tx = await zeroEx.connect(taker)
            .batchFillLimitOrders(orders, signatures, fillAmounts, false, { value, gasPrice: GAS_PRICE });
        const receipt = await tx.wait()
        const [orderInfos] = await zeroEx.batchGetLimitOrderRelevantStates(orders, signatures);
        orderInfos.map((orderInfo, i) =>
            assertOrderInfoEquals(orderInfo, {
                status: OrderStatus.Fillable,
                orderHash: orders[i].getHash(),
                takerTokenFilledAmount: fillAmounts[i],
            }),
        );
        verifyLogs(
            receipt.logs,
            orders.map((order, i) => testUtils.createLimitOrderFilledEventArgs(order, fillAmounts[i])),
            IZeroExEvents.LimitOrderFilled,
        );
        return assertExpectedFinalBalancesAsync(orders, fillAmounts);
    });
    it('Fills multiple orders and refunds excess ETH', async () => {
        const orders = [...new Array(3)].map(() => getTestLimitOrder({ takerTokenFeeAmount: ZERO_AMOUNT }));
        const signatures = await Promise.all(
            orders.map(async order => order.getSignatureWithProviderAsync(await ethers.getSigner(order.maker))),
        );
        await testUtils.prepareBalancesForOrdersAsync(orders);
        const value = testUtils.protocolFee.mul(orders.length).add(420);
        const tx = await zeroEx.connect(taker)
            .batchFillLimitOrders(
                orders,
                signatures,
                orders.map(order => order.takerAmount),
                false,
                { value, gasPrice: GAS_PRICE }
            );
        const reeipt = await tx.wait()
        const [orderInfos] = await zeroEx.batchGetLimitOrderRelevantStates(orders, signatures);
        orderInfos.map((orderInfo, i) =>
            assertOrderInfoEquals(orderInfo, {
                status: OrderStatus.Filled,
                orderHash: orders[i].getHash(),
                takerTokenFilledAmount: orders[i].takerAmount,
            }),
        );
        verifyLogs(
            reeipt.logs,
            orders.map(order => testUtils.createLimitOrderFilledEventArgs(order)),
            IZeroExEvents.LimitOrderFilled,
        );
        return assertExpectedFinalBalancesAsync(orders);
    });
    it('Skips over unfillable orders and refunds excess ETH', async () => {
        const fillableOrders = [...new Array(3)].map(() => getTestLimitOrder({ takerTokenFeeAmount: ZERO_AMOUNT }));
        const expiredOrder = getTestLimitOrder({ expiry: await createCleanExpiry(provider, -1), takerTokenFeeAmount: ZERO_AMOUNT });
        const orders = [expiredOrder, ...fillableOrders];
        const signatures = await Promise.all(
            orders.map(async order => order.getSignatureWithProviderAsync(await ethers.getSigner(order.maker))),
        );
        await testUtils.prepareBalancesForOrdersAsync(orders);
        const value = testUtils.protocolFee.mul(orders.length);
        const tx = await zeroEx.connect(taker)
            .batchFillLimitOrders(
                orders,
                signatures,
                orders.map(order => order.takerAmount),
                false,
                { value, gasPrice: GAS_PRICE }
            );
        const receipt = await tx.wait()
        const [orderInfos] = await zeroEx.batchGetLimitOrderRelevantStates(orders, signatures);
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
        verifyLogs(
            receipt.logs,
            fillableOrders.map(order => testUtils.createLimitOrderFilledEventArgs(order)),
            IZeroExEvents.LimitOrderFilled,
        );
        return assertExpectedFinalBalancesAsync(fillableOrders);
    });
    it('Fills multiple orders with revertIfIncomplete=true', async () => {
        const orders = [...new Array(3)].map(() => getTestLimitOrder({ takerTokenFeeAmount: ZERO_AMOUNT }));
        const signatures = await Promise.all(
            orders.map(async order => order.getSignatureWithProviderAsync(await ethers.getSigner(order.maker))),
        );
        await testUtils.prepareBalancesForOrdersAsync(orders);
        const value = testUtils.protocolFee.mul(orders.length);
        const tx = await zeroEx.connect(taker)
            .batchFillLimitOrders(
                orders,
                signatures,
                orders.map(order => order.takerAmount),
                true,
                { value, gasPrice: GAS_PRICE }
            );
        const receipt = await tx.wait()
        const [orderInfos] = await zeroEx.batchGetLimitOrderRelevantStates(orders, signatures);
        orderInfos.map((orderInfo, i) =>
            assertOrderInfoEquals(orderInfo, {
                status: OrderStatus.Filled,
                orderHash: orders[i].getHash(),
                takerTokenFilledAmount: orders[i].takerAmount,
            }),
        );
        verifyLogs(
            receipt.logs,
            orders.map(order => testUtils.createLimitOrderFilledEventArgs(order)),
            IZeroExEvents.LimitOrderFilled,
        );
        return assertExpectedFinalBalancesAsync(orders);
    });
    it('If revertIfIncomplete==true, reverts on an unfillable order', async () => {
        const fillableOrders = [...new Array(3)].map(() => getTestLimitOrder({ takerTokenFeeAmount: ZERO_AMOUNT }));
        const expiredOrder = getTestLimitOrder({ expiry: await createCleanExpiry(provider, -1), takerTokenFeeAmount: ZERO_AMOUNT });
        const orders = [expiredOrder, ...fillableOrders];
        const signatures = await Promise.all(
            orders.map(async order => order.getSignatureWithProviderAsync(await ethers.getSigner(order.maker))),
        );
        await testUtils.prepareBalancesForOrdersAsync(orders);
        const value = testUtils.protocolFee.mul(orders.length);
        await validateError(
            zeroEx.connect(taker)
                .batchFillLimitOrders(
                    orders,
                    signatures,
                    orders.map(order => order.takerAmount),
                    true,
                    { value, gasPrice: GAS_PRICE }
                ),
            "orderNotFillableError",
            [
                expiredOrder.getHash(),
                OrderStatus.Expired,
            ])
    });
    it('If revertIfIncomplete==true, reverts on an incomplete fill ', async () => {
        const fillableOrders = [...new Array(3)].map(() => getTestLimitOrder({ takerTokenFeeAmount: ZERO_AMOUNT }));
        const partiallyFilledOrder = getTestLimitOrder({ takerTokenFeeAmount: ZERO_AMOUNT });
        const partialFillAmount = getRandomPortion(partiallyFilledOrder.takerAmount);
        await testUtils.fillLimitOrderAsync(partiallyFilledOrder, { fillAmount: partialFillAmount });
        const orders = [partiallyFilledOrder, ...fillableOrders];
        const signatures = await Promise.all(
            orders.map(async order => order.getSignatureWithProviderAsync(await ethers.getSigner(order.maker))),
        );
        await testUtils.prepareBalancesForOrdersAsync(orders);
        const value = testUtils.protocolFee.mul(orders.length);
        await validateError(
            zeroEx.connect(taker)
                .batchFillLimitOrders(
                    orders,
                    signatures,
                    orders.map(order => order.takerAmount),
                    true,
                    { value, gasPrice: GAS_PRICE }
                ),
            "batchFillIncompleteError",
            [
                partiallyFilledOrder.getHash(),
                partiallyFilledOrder.takerAmount.sub(partialFillAmount),
                partiallyFilledOrder.takerAmount,
            ]
        )
    });
});
describe('batchFillRfqOrders', () => {

    async function getMakerTakerBalances() {
        const makerBalance = await takerToken.balanceOf(maker.address);
        const takerBalance = await makerToken.balanceOf(taker.address);
        return [makerBalance, takerBalance]
    }

    async function assertExpectedFinalBalancesAsync(
        makerBalanceBefore: BigNumber,
        takerBalanceBefore: BigNumber,
        orders: RfqOrder[],
        takerTokenFillAmounts: BigNumber[] = orders.map(order => order.takerAmount),
        takerTokenAlreadyFilledAmounts: BigNumber[] = orders.map(() => ZERO_AMOUNT),
    ): Promise<void> {
        const { makerTokenFilledAmount, takerTokenFilledAmount } = orders
            .map((order, i) =>
                computeRfqOrderFilledAmounts(order, takerTokenFillAmounts[i], takerTokenAlreadyFilledAmounts[i]),
            )
            .reduce((previous, current) => ({
                makerTokenFilledAmount: previous.makerTokenFilledAmount.add(current.makerTokenFilledAmount),
                takerTokenFilledAmount: previous.takerTokenFilledAmount.add(current.takerTokenFilledAmount),
            }));

        const makerBalance = await takerToken.balanceOf(maker.address);
        const takerBalance = await makerToken.balanceOf(taker.address);

        expect(makerBalance.sub(makerBalanceBefore).toString()).to.eq(takerTokenFilledAmount.toString());
        expect(takerBalance.sub(takerBalanceBefore).toString()).to.eq(makerTokenFilledAmount.toString());
    }

    it('Fully fills multiple orders', async () => {

        const [
            makerBalanceBefore,
            takerBalanceBefore,
        ] = await getMakerTakerBalances()

        const orders = [...new Array(3)].map(() => getTestRfqOrder());
        const signatures = await Promise.all(
            orders.map(async order => order.getSignatureWithProviderAsync(await ethers.getSigner(order.maker))),
        );
        await testUtils.prepareBalancesForOrdersAsync(orders);
        const tx = await zeroEx.connect(taker)
            .batchFillRfqOrders(
                orders,
                signatures,
                orders.map(order => order.takerAmount),
                false
            );
        const receipt = await tx.wait()
        const [orderInfos] = await zeroEx.batchGetRfqOrderRelevantStates(orders, signatures);
        orderInfos.map((orderInfo, i) =>
            assertOrderInfoEquals(orderInfo, {
                status: OrderStatus.Filled,
                orderHash: orders[i].getHash(),
                takerTokenFilledAmount: orders[i].takerAmount,
            }),
        );
        verifyLogs(
            receipt.logs,
            orders.map(order => testUtils.createRfqOrderFilledEventArgs(order)),
            IZeroExEvents.RfqOrderFilled,
        );
        return assertExpectedFinalBalancesAsync(
            makerBalanceBefore,
            takerBalanceBefore,
            orders
        );
    });
    it('Partially fills multiple orders', async () => {

        const [
            makerBalanceBefore,
            takerBalanceBefore,
        ] = await getMakerTakerBalances()

        const orders = [...new Array(3)].map(() => getTestRfqOrder());
        const signatures = await Promise.all(
            orders.map(async order => order.getSignatureWithProviderAsync(await ethers.getSigner(order.maker))),
        );
        const fillAmounts = orders.map(order => getRandomPortion(order.takerAmount));
        await testUtils.prepareBalancesForOrdersAsync(orders);
        const tx = await zeroEx.connect(taker)
            .batchFillRfqOrders(orders, signatures, fillAmounts, false);
        const receipt = await tx.wait()
        const [orderInfos] = await zeroEx.batchGetRfqOrderRelevantStates(orders, signatures);
        orderInfos.map((orderInfo, i) =>
            assertOrderInfoEquals(orderInfo, {
                status: OrderStatus.Fillable,
                orderHash: orders[i].getHash(),
                takerTokenFilledAmount: fillAmounts[i],
            }),
        );
        verifyLogs(
            receipt.logs,
            orders.map((order, i) => testUtils.createRfqOrderFilledEventArgs(order, fillAmounts[i])),
            IZeroExEvents.RfqOrderFilled,
        );
        return assertExpectedFinalBalancesAsync(
            makerBalanceBefore,
            takerBalanceBefore,
            orders,
            fillAmounts
        );
    });
    it('Skips over unfillable orders', async () => {

        const [
            makerBalanceBefore,
            takerBalanceBefore,
        ] = await getMakerTakerBalances()

        const fillableOrders = [...new Array(3)].map(() => getTestRfqOrder());
        const expiredOrder = getTestRfqOrder({ expiry: await createCleanExpiry(provider, -1) });
        const orders = [expiredOrder, ...fillableOrders];
        const signatures = await Promise.all(
            orders.map(async order => order.getSignatureWithProviderAsync(await ethers.getSigner(order.maker))),
        );
        await testUtils.prepareBalancesForOrdersAsync(orders);
        const tx = await zeroEx.connect(taker)
            .batchFillRfqOrders(
                orders,
                signatures,
                orders.map(order => order.takerAmount),
                false,
            );
        const receipt = await tx.wait()
        const [orderInfos] = await zeroEx.batchGetRfqOrderRelevantStates(orders, signatures);
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
        verifyLogs(
            receipt.logs,
            fillableOrders.map(order => testUtils.createRfqOrderFilledEventArgs(order)),
            IZeroExEvents.RfqOrderFilled,
        );
        return assertExpectedFinalBalancesAsync(
            makerBalanceBefore,
            takerBalanceBefore,
            fillableOrders
        );
    });
    it('Fills multiple orders with revertIfIncomplete=true', async () => {

        const [
            makerBalanceBefore,
            takerBalanceBefore,
        ] = await getMakerTakerBalances()

        const orders = [...new Array(3)].map(() => getTestRfqOrder());
        const signatures = await Promise.all(
            orders.map(async order => order.getSignatureWithProviderAsync(await ethers.getSigner(order.maker))),
        );
        await testUtils.prepareBalancesForOrdersAsync(orders);
        const tx = await zeroEx.connect(taker)
            .batchFillRfqOrders(
                orders,
                signatures,
                orders.map(order => order.takerAmount),
                true,
            );
        const receipt = await tx.wait()
        const [orderInfos] = await zeroEx.batchGetRfqOrderRelevantStates(orders, signatures);
        orderInfos.map((orderInfo, i) =>
            assertOrderInfoEquals(orderInfo, {
                status: OrderStatus.Filled,
                orderHash: orders[i].getHash(),
                takerTokenFilledAmount: orders[i].takerAmount,
            }),
        );
        verifyLogs(
            receipt.logs,
            orders.map(order => testUtils.createRfqOrderFilledEventArgs(order)),
            IZeroExEvents.RfqOrderFilled,
        );
        return assertExpectedFinalBalancesAsync(
            makerBalanceBefore,
            takerBalanceBefore,
            orders
        );
    });
    it('If revertIfIncomplete==true, reverts on an unfillable order', async () => {
        const fillableOrders = [...new Array(3)].map(() => getTestRfqOrder());
        const expiredOrder = getTestRfqOrder({ expiry: await createCleanExpiry(provider, -1) });
        const orders = [expiredOrder, ...fillableOrders];
        const signatures = await Promise.all(
            orders.map(async order => order.getSignatureWithProviderAsync(await ethers.getSigner(order.maker))),
        );
        await testUtils.prepareBalancesForOrdersAsync(orders);
        await validateError(
            zeroEx.connect(taker)
                .batchFillRfqOrders(
                    orders,
                    signatures,
                    orders.map(order => order.takerAmount),
                    true,
                ),
            "orderNotFillableError",
            [expiredOrder.getHash(), OrderStatus.Expired,]
        )
    });
    it('If revertIfIncomplete==true, reverts on an incomplete fill ', async () => {
        const fillableOrders = [...new Array(3)].map(() => getTestRfqOrder());
        const partiallyFilledOrder = getTestRfqOrder();
        const partialFillAmount = getRandomPortion(partiallyFilledOrder.takerAmount);
        await testUtils.fillRfqOrderAsync(partiallyFilledOrder, partialFillAmount);
        const orders = [partiallyFilledOrder, ...fillableOrders];
        const signatures = await Promise.all(
            orders.map(async order => order.getSignatureWithProviderAsync(await ethers.getSigner(order.maker))),
        );
        await testUtils.prepareBalancesForOrdersAsync(orders);
        await validateError(
            zeroEx.connect(taker)
                .batchFillRfqOrders(
                    orders,
                    signatures,
                    orders.map(order => order.takerAmount),
                    true,
                ),
            "batchFillIncompleteError", [
            partiallyFilledOrder.getHash(),
            partiallyFilledOrder.takerAmount.sub(partialFillAmount),
            partiallyFilledOrder.takerAmount,
        ]
        )
    });
});
