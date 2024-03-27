import {
    constants,
    verifyEventsFromLogs,
} from '@0x/contracts-test-utils';


import {
    assertOrderInfoEquals,
    computeLimitOrderFilledAmounts,
    computeRfqOrderFilledAmounts,
    createExpiry,
    getActualFillableTakerTokenAmount,
    getFillableMakerTokenAmount,
    getRandomLimitOrder,
    getRandomRfqOrder,
    NativeOrdersTestEnvironment,
} from './utils/orders';

import { RevertErrors } from './utils/revert-errors';
import { SignatureType } from './utils/signature_utils';
import { ethers, waffle } from 'hardhat';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import {
    MockERC20,
    MockERC20__factory,
    NativeOrders,
    NativeOrders__factory,
    TestOrderSignerRegistryWithContractWallet,
    TestOrderSignerRegistryWithContractWallet__factory,
    TestRfqOriginRegistration,
    TestRfqOriginRegistration__factory,
    WETH9,
    WETH9__factory
} from '../../../types';
import { MaxUint128 } from '../../uniswap-v3/periphery/shared/constants';
import { createNativeOrder } from './orderFixture';
import { IZeroExEvents, LimitOrder, LimitOrderFields, OrderStatus, RfqOrder, RfqOrderFields } from './utils/constants';
import { BigNumber, ContractReceipt } from 'ethers';
import { MockProvider } from 'ethereum-waffle';
import { time } from '@nomicfoundation/hardhat-network-helpers';
import { expect } from '../shared/expect'

const { NULL_ADDRESS, MAX_UINT256, NULL_BYTES32, } = constants;
const ZERO_AMOUNT = BigNumber.from(0)
let GAS_PRICE: BigNumber
const PROTOCOL_FEE_MULTIPLIER = 1337e3;
let SINGLE_PROTOCOL_FEE: BigNumber;
const ordersInterface = NativeOrders__factory.createInterface()
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

// describe('getProtocolFeeMultiplier()', () => {
//     it('returns the protocol fee multiplier', async () => {
//         const r = await zeroEx.getProtocolFeeMultiplier().callAsync();
//         expect(r).to.bignumber.eq(PROTOCOL_FEE_MULTIPLIER);
//     });
// });


describe('getLimitOrderHash()', () => {
    it('returns the correct hash', async () => {
        const order = getTestLimitOrder();
        const hash = await zeroEx.getLimitOrderHash(order);
        expect(hash).to.eq(order.getHash());
    });
});

describe('getRfqOrderHash()', () => {
    it('returns the correct hash', async () => {
        const order = getTestRfqOrder();
        const hash = await zeroEx.getRfqOrderHash(order);
        expect(hash).to.eq(order.getHash());
    });
});

describe('getLimitOrderInfo()', () => {
    it('unfilled order', async () => {
        const order = getTestLimitOrder();
        const info = await zeroEx.getLimitOrderInfo(order);
        assertOrderInfoEquals(info, {
            status: OrderStatus.Fillable,
            orderHash: order.getHash(),
            takerTokenFilledAmount: ZERO_AMOUNT,
        });
    });

    it('unfilled cancelled order', async () => {
        const order = getTestLimitOrder();
        await zeroEx.connect(maker).cancelLimitOrder(order);
        const info = await zeroEx.getLimitOrderInfo(order);
        assertOrderInfoEquals(info, {
            status: OrderStatus.Cancelled,
            orderHash: order.getHash(),
            takerTokenFilledAmount: ZERO_AMOUNT,
        });
    });

    it('unfilled expired order', async () => {
        const order = getTestLimitOrder({ expiry: createExpiry(-60) });
        const info = await zeroEx.getLimitOrderInfo(order);
        assertOrderInfoEquals(info, {
            status: OrderStatus.Expired,
            orderHash: order.getHash(),
            takerTokenFilledAmount: ZERO_AMOUNT,
        });
    });

    it('filled then expired order', async () => {
        const expiry = createExpiry(60);
        const order = getTestLimitOrder({ expiry });

        // Fill the order first.
        await testUtils.fillLimitOrderAsync(order);

        // Advance time to expire the order.
        // await env.web3Wrapper.increaseTimeAsync(61);
        await time.increase(61)
        const info = await zeroEx.getLimitOrderInfo(order);
        assertOrderInfoEquals(info, {
            status: OrderStatus.Filled, // Still reports filled.
            orderHash: order.getHash(),
            takerTokenFilledAmount: order.takerAmount,
        });
    });

    it('filled order', async () => {
        const order = getTestLimitOrder();
        // Fill the order first.
        await testUtils.fillLimitOrderAsync(order);
        const info = await zeroEx.getLimitOrderInfo(order);
        assertOrderInfoEquals(info, {
            status: OrderStatus.Filled,
            orderHash: order.getHash(),
            takerTokenFilledAmount: order.takerAmount,
        });
    });

    it('partially filled order', async () => {
        const order = getTestLimitOrder();
        const fillAmount = order.takerAmount.sub(1);
        // Fill the order first.
        await testUtils.fillLimitOrderAsync(order, { fillAmount });
        const info = await zeroEx.getLimitOrderInfo(order);
        assertOrderInfoEquals(info, {
            status: OrderStatus.Fillable,
            orderHash: order.getHash(),
            takerTokenFilledAmount: fillAmount,
        });
    });

    it('filled then cancelled order', async () => {
        const order = getTestLimitOrder();
        // Fill the order first.
        await testUtils.fillLimitOrderAsync(order);
        await zeroEx.connect(maker).cancelLimitOrder(order);
        const info = await zeroEx.getLimitOrderInfo(order);
        assertOrderInfoEquals(info, {
            status: OrderStatus.Filled, // Still reports filled.
            orderHash: order.getHash(),
            takerTokenFilledAmount: order.takerAmount,
        });
    });

    it('partially filled then cancelled order', async () => {
        const order = getTestLimitOrder();
        const fillAmount = order.takerAmount.sub(1);
        // Fill the order first.
        await testUtils.fillLimitOrderAsync(order, { fillAmount });
        await zeroEx.connect(maker).cancelLimitOrder(order);
        const info = await zeroEx.getLimitOrderInfo(order);
        assertOrderInfoEquals(info, {
            status: OrderStatus.Cancelled,
            orderHash: order.getHash(),
            takerTokenFilledAmount: fillAmount,
        });
    });
});

describe('getRfqOrderInfo()', () => {
    it('unfilled order', async () => {
        const order = getTestRfqOrder();
        const info = await zeroEx.getRfqOrderInfo(order);
        assertOrderInfoEquals(info, {
            status: OrderStatus.Fillable,
            orderHash: order.getHash(),
            takerTokenFilledAmount: ZERO_AMOUNT,
        });
    });

    it('unfilled cancelled order', async () => {
        const order = getTestRfqOrder();
        await zeroEx.connect(maker).cancelRfqOrder(order);
        const info = await zeroEx.getRfqOrderInfo(order);
        assertOrderInfoEquals(info, {
            status: OrderStatus.Cancelled,
            orderHash: order.getHash(),
            takerTokenFilledAmount: ZERO_AMOUNT,
        });
    });

    it('unfilled expired order', async () => {
        const expiry = createExpiry(-60);
        const order = getTestRfqOrder({ expiry });
        const info = await zeroEx.getRfqOrderInfo(order);
        assertOrderInfoEquals(info, {
            status: OrderStatus.Expired,
            orderHash: order.getHash(),
            takerTokenFilledAmount: ZERO_AMOUNT,
        });
    });

    it('filled then expired order', async () => {
        const expiry = createExpiry(120);
        const order = getTestRfqOrder({ expiry });
        await testUtils.prepareBalancesForOrdersAsync([order]);
        const sig = await order.getSignatureWithProviderAsync(maker);
        // Fill the order first.
        await zeroEx.connect(taker).fillRfqOrder(order, sig, order.takerAmount);
        // Advance time to expire the order.
        // await env.web3Wrapper.increaseTimeAsync(61);
        await time.increase(121)
        const info = await zeroEx.getRfqOrderInfo(order);
        assertOrderInfoEquals(info, {
            status: OrderStatus.Filled, // Still reports filled.
            orderHash: order.getHash(),
            takerTokenFilledAmount: order.takerAmount,
        });
    });

    it('filled order', async () => {
        const order = getTestRfqOrder();
        // Fill the order first.
        await testUtils.fillRfqOrderAsync(order, order.takerAmount, taker);
        const info = await zeroEx.getRfqOrderInfo(order);
        assertOrderInfoEquals(info, {
            status: OrderStatus.Filled,
            orderHash: order.getHash(),
            takerTokenFilledAmount: order.takerAmount,
        });
    });

    it('partially filled order', async () => {
        const order = getTestRfqOrder();
        const fillAmount = order.takerAmount.sub(1);
        // Fill the order first.
        await testUtils.fillRfqOrderAsync(order, fillAmount);
        const info = await zeroEx.getRfqOrderInfo(order);
        assertOrderInfoEquals(info, {
            status: OrderStatus.Fillable,
            orderHash: order.getHash(),
            takerTokenFilledAmount: fillAmount,
        });
    });

    it('filled then cancelled order', async () => {
        const order = getTestRfqOrder();
        // Fill the order first.
        await testUtils.fillRfqOrderAsync(order);
        await zeroEx.connect(maker).cancelRfqOrder(order);
        const info = await zeroEx.getRfqOrderInfo(order);
        assertOrderInfoEquals(info, {
            status: OrderStatus.Filled, // Still reports filled.
            orderHash: order.getHash(),
            takerTokenFilledAmount: order.takerAmount,
        });
    });

    it('partially filled then cancelled order', async () => {
        const order = getTestRfqOrder();
        const fillAmount = order.takerAmount.sub(1);
        // Fill the order first.
        await testUtils.fillRfqOrderAsync(order, fillAmount);
        await zeroEx.connect(maker).cancelRfqOrder(order);
        const info = await zeroEx.getRfqOrderInfo(order);
        assertOrderInfoEquals(info, {
            status: OrderStatus.Cancelled,
            orderHash: order.getHash(),
            takerTokenFilledAmount: fillAmount,
        });
    });

    it('invalid origin', async () => {
        const order = getTestRfqOrder({ txOrigin: NULL_ADDRESS });
        const info = await zeroEx.getRfqOrderInfo(order);
        assertOrderInfoEquals(info, {
            status: OrderStatus.Invalid,
            orderHash: order.getHash(),
            takerTokenFilledAmount: ZERO_AMOUNT,
        });
    });
});

interface TxLog {
    transactionIndex: number,
    blockNumber: number,
    transactionHash: string,
    address: string,
    topics: string[],
    data: string,
    logIndex: number,
    blockHash: string

}

const verifyLogs = (logs: TxLog[], expected: Object[], id: string) => {
    for (const log of logs) {
        const { data } = log
        let decoded: any
        try {
            decoded = ordersInterface.decodeEventLog(id, data)
        } catch (e: any) {
            continue;
        }
        const keys = Object.keys(decoded).filter(x => isNaN(Number(x)))
        let included = false
        for (const ex of expected) {
            if (keys.every(
                k => (ex as any)[k] === undefined ? true : // this allws us to skip params if the expected one is undefined
                    (ex as any)[k]?.toString().toLowerCase() === decoded[k].toString().toLowerCase())
            ) included = true;
        }
        expect(included).to.equal(true, "Not found:" + JSON.stringify(decoded))
    }
}


describe('cancelLimitOrder()', async () => {
    it('can cancel an unfilled order', async () => {
        const order = getTestLimitOrder();
        const tx = await zeroEx.connect(maker).cancelLimitOrder(order);
        const receipt = await tx.wait()
        verifyLogs(
            receipt.logs,
            [{ maker: order.maker, orderHash: order.getHash() }],
            IZeroExEvents.OrderCancelled,
        );
        const { status } = await zeroEx.getLimitOrderInfo(order);
        expect(status).to.eq(OrderStatus.Cancelled);
    });

    it('can cancel a fully filled order', async () => {
        const order = getTestLimitOrder();
        await testUtils.fillLimitOrderAsync(order);
        const tx = await zeroEx.connect(maker).cancelLimitOrder(order);
        const receipt = await tx.wait()
        verifyLogs(
            receipt.logs,
            [{ maker: order.maker, orderHash: order.getHash() }],
            IZeroExEvents.OrderCancelled,
        );
        const { status } = await zeroEx.getLimitOrderInfo(order);
        expect(status).to.eq(OrderStatus.Filled); // Still reports filled.
    });

    it('can cancel a partially filled order', async () => {
        const order = getTestLimitOrder();
        await testUtils.fillLimitOrderAsync(order, { fillAmount: order.takerAmount.sub(1) });
        const tx = await zeroEx.connect(maker).cancelLimitOrder(order);
        const receipt = await tx.wait()
        verifyLogs(
            receipt.logs,
            [{ maker: order.maker, orderHash: order.getHash() }],
            IZeroExEvents.OrderCancelled,
        );
        const { status } = await zeroEx.getLimitOrderInfo(order);
        expect(status).to.eq(OrderStatus.Cancelled);
    });

    it('can cancel an expired order', async () => {
        const expiry = createExpiry(-60);
        const order = getTestLimitOrder({ expiry });
        const tx = await zeroEx.connect(maker).cancelLimitOrder(order);
        const receipt = await tx.wait()
        verifyLogs(
            receipt.logs,
            [{ maker: order.maker, orderHash: order.getHash() }],
            IZeroExEvents.OrderCancelled,
        );
        const { status } = await zeroEx.getLimitOrderInfo(order);
        expect(status).to.eq(OrderStatus.Cancelled);
    });

    it('can cancel a cancelled order', async () => {
        const order = getTestLimitOrder();
        await zeroEx.connect(maker).cancelLimitOrder(order);
        const tx = await zeroEx.connect(maker).cancelLimitOrder(order);
        const receipt = await tx.wait()
        verifyLogs(
            receipt.logs,
            [{ maker: order.maker, orderHash: order.getHash() }],
            IZeroExEvents.OrderCancelled,
        );
        const { status } = await zeroEx.getLimitOrderInfo(order);
        expect(status).to.eq(OrderStatus.Cancelled);
    });

    it("cannot cancel someone else's order", async () => {
        const order = getTestLimitOrder();
        await expect(zeroEx.connect(notMaker).cancelLimitOrder(order)).to.be.revertedWith(
            "onlyOrderMakerAllowed"
        ).withArgs(order.getHash(), notMaker.address, order.maker)

    });
});

describe('cancelRfqOrder()', async () => {
    it('can cancel an unfilled order', async () => {
        const order = getTestRfqOrder();
        const tx = await zeroEx.connect(maker).cancelRfqOrder(order);
        const receipt = await tx.wait()
        verifyLogs(
            receipt.logs,
            [{ maker: order.maker, orderHash: order.getHash() }],
            IZeroExEvents.OrderCancelled,
        );
        const { status } = await zeroEx.getRfqOrderInfo(order);
        expect(status).to.eq(OrderStatus.Cancelled);
    });

    it('can cancel a fully filled order', async () => {
        const order = getTestRfqOrder();
        await testUtils.fillRfqOrderAsync(order);
        const tx = await zeroEx.connect(maker).cancelRfqOrder(order);
        const receipt = await tx.wait()
        verifyLogs(
            receipt.logs,
            [{ maker: order.maker, orderHash: order.getHash() }],
            IZeroExEvents.OrderCancelled,
        );
        const { status } = await zeroEx.getRfqOrderInfo(order);
        expect(status).to.eq(OrderStatus.Filled); // Still reports filled.
    });

    it('can cancel a partially filled order', async () => {
        const order = getTestRfqOrder();
        await testUtils.fillRfqOrderAsync(order, order.takerAmount.sub(1));
        const tx = await zeroEx.connect(maker).cancelRfqOrder(order);
        const receipt = await tx.wait()
        verifyLogs(
            receipt.logs,
            [{ maker: order.maker, orderHash: order.getHash() }],
            IZeroExEvents.OrderCancelled,
        );
        const { status } = await zeroEx.getRfqOrderInfo(order);
        expect(status).to.eq(OrderStatus.Cancelled); // Still reports filled.
    });

    it('can cancel an expired order', async () => {
        const expiry = createExpiry(-60);
        const order = getTestRfqOrder({ expiry });
        const tx = await zeroEx.connect(maker).cancelRfqOrder(order);
        const receipt = await tx.wait()
        verifyLogs(
            receipt.logs,
            [{ maker: order.maker, orderHash: order.getHash() }],
            IZeroExEvents.OrderCancelled,
        );
        const { status } = await zeroEx.getRfqOrderInfo(order);
        expect(status).to.eq(OrderStatus.Cancelled);
    });

    it('can cancel a cancelled order', async () => {
        const order = getTestRfqOrder();
        await zeroEx.connect(maker).cancelRfqOrder(order);
        const tx = await zeroEx.connect(maker).cancelRfqOrder(order);
        const receipt = await tx.wait()
        verifyLogs(
            receipt.logs,
            [{ maker: order.maker, orderHash: order.getHash() }],
            IZeroExEvents.OrderCancelled,
        );
        const { status } = await zeroEx.getRfqOrderInfo(order);
        expect(status).to.eq(OrderStatus.Cancelled);
    });

    it("cannot cancel someone else's order", async () => {
        const order = getTestRfqOrder();
        await expect(zeroEx.connect(notMaker).cancelRfqOrder(order)).to.revertedWith(
            "onlyOrderMakerAllowed",
        ).withArgs(order.getHash(), notMaker.address, order.maker);
    });
});

describe('batchCancelLimitOrders()', async () => {
    it('can cancel multiple orders', async () => {
        const orders = [...new Array(3)].map(() => getTestLimitOrder());
        const tx = await zeroEx.connect(maker).batchCancelLimitOrders(orders);
        const receipt = await tx.wait()
        verifyLogs(
            receipt.logs,
            orders.map(o => ({ maker: o.maker, orderHash: o.getHash() })),
            IZeroExEvents.OrderCancelled,
        );
        const infos = await Promise.all(orders.map(o => zeroEx.getLimitOrderInfo(o)));
        expect(infos.map(i => i.status)).to.deep.eq(infos.map(() => OrderStatus.Cancelled));
    });

    it("cannot cancel someone else's orders", async () => {
        const orders = [...new Array(3)].map(() => getTestLimitOrder());
        await expect(zeroEx.connect(notMaker).batchCancelLimitOrders(orders)).to.be.revertedWith(
            "onlyOrderMakerAllowed"
        ).withArgs(orders[0].getHash(), notMaker.address, orders[0].maker)
    });
});

describe('batchCancelRfqOrders()', async () => {
    it('can cancel multiple orders', async () => {
        const orders = [...new Array(3)].map(() => getTestRfqOrder());
        const tx = await zeroEx.connect(maker).batchCancelRfqOrders(orders);
        const receipt = await tx.wait()
        verifyLogs(
            receipt.logs,
            orders.map(o => ({ maker: o.maker, orderHash: o.getHash() })),
            IZeroExEvents.OrderCancelled,
        );
        const infos = await Promise.all(orders.map(o => zeroEx.getRfqOrderInfo(o)));
        expect(infos.map(i => i.status)).to.deep.eq(infos.map(() => OrderStatus.Cancelled));
    });

    it("cannot cancel someone else's orders", async () => {
        const orders = [...new Array(3)].map(() => getTestRfqOrder());
        return expect(zeroEx.connect(notMaker).batchCancelRfqOrders(orders)).to.be.revertedWith(
            "onlyOrderMakerAllowed"
        ).withArgs(orders[0].getHash(), notMaker.address, orders[0].maker)
    });
});

describe('cancelPairOrders()', async () => {
    it('can cancel multiple limit orders of the same pair with salt < minValidSalt', async () => {
        const orders = [...new Array(3)].map((_v, i) => getTestLimitOrder().clone({ salt: BigNumber.from(i) }));
        // Cancel the first two orders.
        const minValidSalt = orders[2].salt;
        const tx = await zeroEx.connect(maker)
            .cancelPairLimitOrders(makerToken.address, takerToken.address, minValidSalt);
        const receipt = await tx.wait()
        verifyLogs(
            receipt.logs,
            [
                {
                    maker: maker.address,
                    makerToken: makerToken.address,
                    takerToken: takerToken.address,
                    minValidSalt,
                },
            ],
            IZeroExEvents.PairCancelledLimitOrders,
        );
        const statuses = (await Promise.all(orders.map(o => zeroEx.getLimitOrderInfo(o)))).map(
            oi => oi.status,
        );
        expect(statuses).to.deep.eq([OrderStatus.Cancelled, OrderStatus.Cancelled, OrderStatus.Fillable]);
    });

    it('does not cancel limit orders of a different pair', async () => {
        const order = getRandomLimitOrder({ salt: BigNumber.from(1) });
        // Cancel salts <= the order's, but flip the tokens to be a different
        // pair.
        const minValidSalt = order.salt.add(1);
        await zeroEx.connect(maker)
            .cancelPairLimitOrders(takerToken.address, makerToken.address, minValidSalt);
        const { status } = await zeroEx.getLimitOrderInfo(order);
        expect(status).to.eq(OrderStatus.Fillable);
    });

    it('can cancel multiple RFQ orders of the same pair with salt < minValidSalt', async () => {
        const orders = [...new Array(3)].map((_v, i) => getTestRfqOrder().clone({ salt: BigNumber.from(i) }));
        // Cancel the first two orders.
        const minValidSalt = orders[2].salt;
        const tx = await zeroEx.connect(maker)
            .cancelPairRfqOrders(makerToken.address, takerToken.address, minValidSalt);
        const receipt = await tx.wait()
        verifyLogs(
            receipt.logs,
            [
                {
                    maker: maker.address,
                    makerToken: makerToken.address,
                    takerToken: takerToken.address,
                    minValidSalt,
                },
            ],
            IZeroExEvents.PairCancelledRfqOrders,
        );
        const statuses = (await Promise.all(orders.map(o => zeroEx.getRfqOrderInfo(o)))).map(
            oi => oi.status,
        );
        expect(statuses).to.deep.eq([OrderStatus.Cancelled, OrderStatus.Cancelled, OrderStatus.Fillable]);
    });

    it('does not cancel RFQ orders of a different pair', async () => {
        const order = getRandomRfqOrder({ salt: BigNumber.from(1) });
        // Cancel salts <= the order's, but flip the tokens to be a different
        // pair.
        const minValidSalt = order.salt.add(1);
        await zeroEx.connect(maker)
            .cancelPairRfqOrders(takerToken.address, makerToken.address, minValidSalt);

        const { status } = await zeroEx.getRfqOrderInfo(order);
        expect(status).to.eq(OrderStatus.Fillable);
    });
});

describe('batchCancelPairOrders()', async () => {
    it('can cancel multiple limit order pairs', async () => {
        const orders = [
            getTestLimitOrder({ salt: BigNumber.from(1) }),
            // Flip the tokens for the other order.
            getTestLimitOrder({
                makerToken: takerToken.address,
                takerToken: makerToken.address,
                salt: BigNumber.from(1),
            }),
        ];
        const minValidSalt = BigNumber.from(2);
        const tx = await zeroEx.connect(maker)
            .batchCancelPairLimitOrders(
                [makerToken.address, takerToken.address],
                [takerToken.address, makerToken.address],
                [minValidSalt, minValidSalt],
            );
        const receipt = await tx.wait()
        verifyLogs(
            receipt.logs,
            [
                {
                    maker: maker.address,
                    makerToken: makerToken.address,
                    takerToken: takerToken.address,
                    minValidSalt,
                },
                {
                    maker: maker.address,
                    makerToken: takerToken.address,
                    takerToken: makerToken.address,
                    minValidSalt,
                },
            ],
            IZeroExEvents.PairCancelledLimitOrders,
        );
        const statuses = (await Promise.all(orders.map(o => zeroEx.getLimitOrderInfo(o)))).map(
            oi => oi.status,
        );
        expect(statuses).to.deep.eq([OrderStatus.Cancelled, OrderStatus.Cancelled]);
    });

    it('can cancel multiple RFQ order pairs', async () => {
        const orders = [
            getTestRfqOrder({ salt: BigNumber.from(1) }),
            // Flip the tokens for the other order.
            getTestRfqOrder({
                makerToken: takerToken.address,
                takerToken: makerToken.address,
                salt: BigNumber.from(1),
            }),
        ];
        const minValidSalt = BigNumber.from(2);
        const tx = await zeroEx.connect(maker)
            .batchCancelPairRfqOrders(
                [makerToken.address, takerToken.address],
                [takerToken.address, makerToken.address],
                [minValidSalt, minValidSalt],
            );
        const receipt = await tx.wait()
        verifyLogs(
            receipt.logs,
            [
                {
                    maker: maker.address,
                    makerToken: makerToken.address,
                    takerToken: takerToken.address,
                    minValidSalt,
                },
                {
                    maker: maker.address,
                    makerToken: takerToken.address,
                    takerToken: makerToken.address,
                    minValidSalt,
                },
            ],
            IZeroExEvents.PairCancelledRfqOrders,
        );
        const statuses = (await Promise.all(orders.map(o => zeroEx.getRfqOrderInfo(o)))).map(
            oi => oi.status,
        );
        expect(statuses).to.deep.eq([OrderStatus.Cancelled, OrderStatus.Cancelled]);
    });
});

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
        const order = getTestLimitOrder({ expiry: createExpiry(-60) });
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
        ).withArgs(order.getHash(), undefined, order.maker);
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

describe('registerAllowedRfqOrigins()', () => {
    it('cannot register through a contract', async () => {

        await expect(testRfqOriginRegistration
            .registerAllowedRfqOrigins(zeroEx.address, [], true)).to.be.revertedWith(
                'NativeOrdersFeature/NO_CONTRACT_ORIGINS'
            );
    });
});


async function getMakerTakerBalancesSingle() {
    const makerBalance = await takerToken.balanceOf(maker.address);
    const takerBalance = await makerToken.balanceOf(taker.address);
    return [makerBalance, takerBalance]
}

async function assertExpectedFinalBalancesFromRfqOrderFillAsync(
    makerBalanceBefore: BigNumber,
    takerBalanceBefore: BigNumber,
    order: RfqOrder,
    takerTokenFillAmount: BigNumber = order.takerAmount,
    takerTokenAlreadyFilledAmount: BigNumber = ZERO_AMOUNT,
): Promise<void> {
    const { makerTokenFilledAmount, takerTokenFilledAmount } = computeRfqOrderFilledAmounts(
        order,
        takerTokenFillAmount,
        takerTokenAlreadyFilledAmount,
    );
    const makerBalance = await takerToken.balanceOf(maker.address);
    const takerBalance = await makerToken.balanceOf(taker.address);
    expect(makerBalance.sub(makerBalanceBefore).toString()).to.eq(takerTokenFilledAmount.toString());
    expect(takerBalance.sub(takerBalanceBefore).toString()).to.eq(makerTokenFilledAmount.toString());
}

describe('fillRfqOrder()', () => {
    it('can fully fill an order', async () => {
        const order = getTestRfqOrder();
        const [
            makerBalanceBefore,
            takerBalanceBefore,
        ] = await getMakerTakerBalancesSingle()


        const tx = await testUtils.fillRfqOrderAsync(order);
        const receipt = await tx.wait()
        verifyLogs(
            receipt.logs,
            [testUtils.createRfqOrderFilledEventArgs(order)],
            IZeroExEvents.RfqOrderFilled,
        );
        assertOrderInfoEquals(await zeroEx.getRfqOrderInfo(order), {
            orderHash: order.getHash(),
            status: OrderStatus.Filled,
            takerTokenFilledAmount: order.takerAmount,
        });
        await assertExpectedFinalBalancesFromRfqOrderFillAsync(
            makerBalanceBefore,
            takerBalanceBefore,
            order
        );
    });

    it('can partially fill an order', async () => {
        const order = getTestRfqOrder();
        const [
            makerBalanceBefore,
            takerBalanceBefore,
        ] = await getMakerTakerBalancesSingle()

        const fillAmount = order.takerAmount.sub(1);
        const tx = await testUtils.fillRfqOrderAsync(order, fillAmount);
        const receipt = await tx.wait()
        verifyLogs(
            receipt.logs,
            [testUtils.createRfqOrderFilledEventArgs(order, fillAmount)],
            IZeroExEvents.RfqOrderFilled,
        );
        assertOrderInfoEquals(await zeroEx.getRfqOrderInfo(order), {
            orderHash: order.getHash(),
            status: OrderStatus.Fillable,
            takerTokenFilledAmount: fillAmount,
        });
        await assertExpectedFinalBalancesFromRfqOrderFillAsync(
            makerBalanceBefore,
            takerBalanceBefore,
            order,
            fillAmount
        );
    });

    it('can fully fill an order in two steps', async () => {
        const order = getTestRfqOrder();
        let fillAmount = order.takerAmount.div(2);
        let tx = await testUtils.fillRfqOrderAsync(order, fillAmount);
        let receipt = await tx.wait()
        verifyLogs(
            receipt.logs,
            [testUtils.createRfqOrderFilledEventArgs(order, fillAmount)],
            IZeroExEvents.RfqOrderFilled,
        );
        const alreadyFilledAmount = fillAmount;
        fillAmount = order.takerAmount.sub(fillAmount);
        tx = await testUtils.fillRfqOrderAsync(order, fillAmount);
        receipt = await tx.wait()
        verifyLogs(
            receipt.logs,
            [testUtils.createRfqOrderFilledEventArgs(order, fillAmount, alreadyFilledAmount)],
            IZeroExEvents.RfqOrderFilled,
        );
        assertOrderInfoEquals(await zeroEx.getRfqOrderInfo(order), {
            orderHash: order.getHash(),
            status: OrderStatus.Filled,
            takerTokenFilledAmount: order.takerAmount,
        });
    });

    it('clamps fill amount to remaining available', async () => {
        const order = getTestRfqOrder();
        const fillAmount = order.takerAmount.add(1);
        const [
            makerBalanceBefore,
            takerBalanceBefore,
        ] = await getMakerTakerBalancesSingle()

        const tx = await testUtils.fillRfqOrderAsync(order, fillAmount);
        const receipt = await tx.wait()
        verifyLogs(
            receipt.logs,
            [testUtils.createRfqOrderFilledEventArgs(order, fillAmount)],
            IZeroExEvents.RfqOrderFilled,
        );
        assertOrderInfoEquals(await zeroEx.getRfqOrderInfo(order), {
            orderHash: order.getHash(),
            status: OrderStatus.Filled,
            takerTokenFilledAmount: order.takerAmount,
        });
        await assertExpectedFinalBalancesFromRfqOrderFillAsync(
            makerBalanceBefore,
            takerBalanceBefore,
            order,
            fillAmount
        );
    });

    it('clamps fill amount to remaining available in partial filled order', async () => {
        const order = getTestRfqOrder();
        let fillAmount = order.takerAmount.div(2);
        let tx = await testUtils.fillRfqOrderAsync(order, fillAmount);
        let receipt = await tx.wait()
        verifyLogs(
            receipt.logs,
            [testUtils.createRfqOrderFilledEventArgs(order, fillAmount)],
            IZeroExEvents.RfqOrderFilled,
        );
        const alreadyFilledAmount = fillAmount;
        fillAmount = order.takerAmount.sub(fillAmount).add(1);
        tx = await testUtils.fillRfqOrderAsync(order, fillAmount);
        receipt = await tx.wait()
        verifyLogs(
            receipt.logs,
            [testUtils.createRfqOrderFilledEventArgs(order, fillAmount, alreadyFilledAmount)],
            IZeroExEvents.RfqOrderFilled,
        );
        assertOrderInfoEquals(await zeroEx.getRfqOrderInfo(order), {
            orderHash: order.getHash(),
            status: OrderStatus.Filled,
            takerTokenFilledAmount: order.takerAmount,
        });
    });

    it('cannot fill an order with wrong tx.origin', async () => {
        const order = getTestRfqOrder();
        const tx = testUtils.fillRfqOrderAsync(order, order.takerAmount, notTaker);
        return expect(tx).to.be.revertedWith(
            "orderNotFillableByOriginError",
        ).withArgs(order.getHash(), notTaker.address, taker.address);
    });

    it('can fill an order from a different tx.origin if registered', async () => {
        const order = getTestRfqOrder();

        const tx = await zeroEx.connect(taker)
            .registerAllowedRfqOrigins([notTaker.address], true);
        const receipt = await tx.wait()
        verifyLogs(
            receipt.logs,
            [
                {
                    origin: taker.address,
                    addrs: [notTaker.address],
                    allowed: true,
                },
            ],
            IZeroExEvents.RfqOrderOriginsAllowed,
        );
        return testUtils.fillRfqOrderAsync(order, order.takerAmount, notTaker);
    });

    it('cannot fill an order with registered then unregistered tx.origin', async () => {
        const order = getTestRfqOrder();

        await zeroEx.connect(taker).registerAllowedRfqOrigins([notTaker.address], true);
        const tx = await zeroEx.connect(taker)
            .registerAllowedRfqOrigins([notTaker.address], false);
        const receipt = await tx.wait()
        verifyLogs(
            receipt.logs,
            [
                {
                    origin: taker.address,
                    addrs: [notTaker.address],
                    allowed: false,
                },
            ],
            IZeroExEvents.RfqOrderOriginsAllowed,
        );


        await expect(testUtils.fillRfqOrderAsync(order, order.takerAmount, notTaker)).to.be.revertedWith(
            "orderNotFillableByOriginError",
        ).withArgs(order.getHash(), notTaker.address, taker.address);
    });

    it('cannot fill an order with a zero tx.origin', async () => {
        const order = getTestRfqOrder({ txOrigin: NULL_ADDRESS });
        const tx = testUtils.fillRfqOrderAsync(order, order.takerAmount, notTaker);
        return expect(tx).to.be.revertedWith(
            "orderNotFillableError",
        ).withArgs(order.getHash(), OrderStatus.Invalid);
    });

    it('non-taker cannot fill order', async () => {
        const order = getTestRfqOrder({ taker: taker.address, txOrigin: notTaker.address });
        await expect(testUtils.fillRfqOrderAsync(order, order.takerAmount, notTaker)).to.be.revertedWith(
            "orderNotFillableByTakerError",
        ).withArgs(order.getHash(), notTaker.address, order.taker);
    });

    it('cannot fill an expired order', async () => {
        const order = getTestRfqOrder({ expiry: createExpiry(-60) });
        const tx = testUtils.fillRfqOrderAsync(order);
        await expect(tx).to.be.revertedWith(
            "orderNotFillableError",
        ).withArgs(order.getHash(), OrderStatus.Expired);
    });

    it('cannot fill a cancelled order', async () => {
        const order = getTestRfqOrder();
        await zeroEx.connect(maker).cancelRfqOrder(order);
        await expect(testUtils.fillRfqOrderAsync(order)).to.be.revertedWith(
            "orderNotFillableError",
        ).withArgs(order.getHash(), OrderStatus.Cancelled);
    });

    it('cannot fill a salt/pair cancelled order', async () => {
        const order = getTestRfqOrder();
        await zeroEx.connect(maker)
            .cancelPairRfqOrders(makerToken.address, takerToken.address, order.salt.add(1));
        await expect(testUtils.fillRfqOrderAsync(order)).to.be.revertedWith(
            "orderNotFillableError",
        ).withArgs(order.getHash(), OrderStatus.Cancelled);
    });

    // @TODO we have to see how we can validate signle revert parameters
    it('cannot fill order with bad signature', async () => {
        const order = getTestRfqOrder();
        // Overwrite chainId to result in a different hash and therefore different
        // signature.
        await expect(testUtils.fillRfqOrderAsync(order.clone({ chainId: 1234 }))).to.be.revertedWith(
            "orderNotSignedByMakerError",
        ) // .withArgs(order.getHash(), undefined, order.maker);
    });

    it('fails if ETH is attached', async () => {
        const order = getTestRfqOrder();
        await testUtils.prepareBalancesForOrdersAsync([order], taker);
        // This will revert at the language level because the fill function is not payable.
        await expect(zeroEx.connect(taker)
            .fillRfqOrder(
                order,
                await order.getSignatureWithProviderAsync(taker),
                order.takerAmount,
                { value: 1 } as any
            )).to.be.reverted;
    });
});

describe('fillOrKillLimitOrder()', () => {
    it('can fully fill an order', async () => {
        const order = getTestLimitOrder();
        await testUtils.prepareBalancesForOrdersAsync([order]);
        const tx = await zeroEx.connect(taker)
            .fillOrKillLimitOrder(
                order,
                await order.getSignatureWithProviderAsync(maker),
                order.takerAmount,
                { value: SINGLE_PROTOCOL_FEE, gasPrice: GAS_PRICE }
            );
        const receipt = await tx.wait()
        verifyLogs(
            receipt.logs,
            [testUtils.createLimitOrderFilledEventArgs(order)],
            IZeroExEvents.LimitOrderFilled,
        );
    });

    it('reverts if cannot fill the exact amount', async () => {
        const order = getTestLimitOrder();
        await testUtils.prepareBalancesForOrdersAsync([order]);
        const fillAmount = order.takerAmount.add(1);
        await expect(zeroEx.connect(taker)
            .fillOrKillLimitOrder(
                order,
                await order.getSignatureWithProviderAsync(maker),
                fillAmount,
                { value: SINGLE_PROTOCOL_FEE }
            )).to.be.revertedWith(
                "fillOrKillFailedError"
            ).withArgs(order.getHash(), order.takerAmount, fillAmount);
    });

    it('refunds excess protocol fee', async () => {
        const order = getTestLimitOrder();
        await testUtils.prepareBalancesForOrdersAsync([order]);
        const takerBalanceBefore = await provider.getBalance(taker.address);
        const tx = await zeroEx.connect(taker)
            .fillOrKillLimitOrder(
                order,
                await order.getSignatureWithProviderAsync(maker),
                order.takerAmount,
                { value: SINGLE_PROTOCOL_FEE.add(1), gasPrice: GAS_PRICE }
            );
        const receipt = await tx.wait()
        const takerBalanceAfter = await provider.getBalance(taker.address);
        const totalCost = GAS_PRICE.mul(receipt.gasUsed).add(SINGLE_PROTOCOL_FEE);
        expect(takerBalanceBefore.sub(totalCost).toString()).to.eq(takerBalanceAfter.toString());
    });
});

describe('fillOrKillRfqOrder()', () => {
    it('can fully fill an order', async () => {
        const order = getTestRfqOrder();
        await testUtils.prepareBalancesForOrdersAsync([order]);
        const tx = await zeroEx.connect(taker)
            .fillOrKillRfqOrder(order, await order.getSignatureWithProviderAsync(maker), order.takerAmount);
        const receipt = await tx.wait()
        verifyLogs(
            receipt.logs,
            [testUtils.createRfqOrderFilledEventArgs(order)],
            IZeroExEvents.RfqOrderFilled,
        );
    });

    it('reverts if cannot fill the exact amount', async () => {
        const order = getTestRfqOrder();
        await testUtils.prepareBalancesForOrdersAsync([order]);
        const fillAmount = order.takerAmount.add(1);
        const tx = zeroEx.connect(taker)
            .fillOrKillRfqOrder(order, await order.getSignatureWithProviderAsync(maker), fillAmount);
        await expect(tx).to.be.revertedWith(
            "fillOrKillFailedError"
        ).withArgs(order.getHash(), order.takerAmount, fillAmount);

    });

    it('fails if ETH is attached', async () => {
        const order = getTestRfqOrder();
        await testUtils.prepareBalancesForOrdersAsync([order]);
        const tx = zeroEx.connect(taker)
            .fillOrKillRfqOrder(
                order,
                await order.getSignatureWithProviderAsync(maker),
                order.takerAmount,
                { value: 1 } as any
            );
        // This will revert at the language level because the fill function is not payable.
        return expect(tx).to.be.reverted // ('revert');
    });
});

// async function fundOrderMakerAsync(
//     order: LimitOrder | RfqOrder,
//     balance: BigNumber = order.makerAmount,
//     allowance: BigNumber = order.makerAmount,
// ): Promise<void> {
//     await makerToken.burn(maker, await makerToken.balanceOf(maker).callAsync()).awaitTransactionSuccessAsync();
//     await makerToken.mint(maker, balance).awaitTransactionSuccessAsync();
//     await makerToken.approve(zeroEx.address, allowance).awaitTransactionSuccessAsync({ from: maker });
// }

// describe('getLimitOrderRelevantState()', () => {
//     it('works with an empty order', async () => {
//         const order = getTestLimitOrder({
//             takerAmount: ZERO_AMOUNT,
//         });
//         await fundOrderMakerAsync(order);
//         const [orderInfo, fillableTakerAmount, isSignatureValid] = await zeroEx
//             .getLimitOrderRelevantState(order, await order.getSignatureWithProviderAsync(env.provider))
//             .callAsync();
//         expect(orderInfo).to.deep.eq({
//             orderHash: order.getHash(),
//             status: OrderStatus.Filled,
//             takerTokenFilledAmount: ZERO_AMOUNT,
//         });
//         expect(fillableTakerAmount).to.bignumber.eq(0);
//         expect(isSignatureValid).to.eq(true);
//     });

//     it('works with cancelled order', async () => {
//         const order = getTestLimitOrder();
//         await fundOrderMakerAsync(order);
//         await zeroEx.cancelLimitOrder(order).awaitTransactionSuccessAsync({ from: maker });
//         const [orderInfo, fillableTakerAmount, isSignatureValid] = await zeroEx
//             .getLimitOrderRelevantState(order, await order.getSignatureWithProviderAsync(env.provider))
//             .callAsync();
//         expect(orderInfo).to.deep.eq({
//             orderHash: order.getHash(),
//             status: OrderStatus.Cancelled,
//             takerTokenFilledAmount: ZERO_AMOUNT,
//         });
//         expect(fillableTakerAmount).to.bignumber.eq(0);
//         expect(isSignatureValid).to.eq(true);
//     });

//     it('works with a bad signature', async () => {
//         const order = getTestLimitOrder();
//         await fundOrderMakerAsync(order);
//         const [orderInfo, fillableTakerAmount, isSignatureValid] = await zeroEx
//             .getLimitOrderRelevantState(
//                 order,
//                 await order.clone({ maker: notMaker }).getSignatureWithProviderAsync(env.provider),
//             )
//             .callAsync();
//         expect(orderInfo).to.deep.eq({
//             orderHash: order.getHash(),
//             status: OrderStatus.Fillable,
//             takerTokenFilledAmount: ZERO_AMOUNT,
//         });
//         expect(fillableTakerAmount).to.bignumber.eq(order.takerAmount);
//         expect(isSignatureValid).to.eq(false);
//     });

//     it('works with an unfilled order', async () => {
//         const order = getTestLimitOrder();
//         await fundOrderMakerAsync(order);
//         const [orderInfo, fillableTakerAmount, isSignatureValid] = await zeroEx
//             .getLimitOrderRelevantState(order, await order.getSignatureWithProviderAsync(env.provider))
//             .callAsync();
//         expect(orderInfo).to.deep.eq({
//             orderHash: order.getHash(),
//             status: OrderStatus.Fillable,
//             takerTokenFilledAmount: ZERO_AMOUNT,
//         });
//         expect(fillableTakerAmount).to.bignumber.eq(order.takerAmount);
//         expect(isSignatureValid).to.eq(true);
//     });

//     it('works with a fully filled order', async () => {
//         const order = getTestLimitOrder();
//         // Fully Fund maker and taker.
//         await fundOrderMakerAsync(order);
//         await takerToken
//             .mint(taker, order.takerAmount.plus(order.takerTokenFeeAmount))
//             .awaitTransactionSuccessAsync();
//         await testUtils.fillLimitOrderAsync(order);
//         // Partially fill the order.
//         const [orderInfo, fillableTakerAmount, isSignatureValid] = await zeroEx
//             .getLimitOrderRelevantState(order, await order.getSignatureWithProviderAsync(env.provider))
//             .callAsync();
//         expect(orderInfo).to.deep.eq({
//             orderHash: order.getHash(),
//             status: OrderStatus.Filled,
//             takerTokenFilledAmount: order.takerAmount,
//         });
//         expect(fillableTakerAmount).to.bignumber.eq(0);
//         expect(isSignatureValid).to.eq(true);
//     });

//     it('works with an under-funded, partially-filled order', async () => {
//         const order = getTestLimitOrder();
//         // Fully Fund maker and taker.
//         await fundOrderMakerAsync(order);
//         await takerToken
//             .mint(taker, order.takerAmount.plus(order.takerTokenFeeAmount))
//             .awaitTransactionSuccessAsync();
//         // Partially fill the order.
//         const fillAmount = getRandomPortion(order.takerAmount);
//         await testUtils.fillLimitOrderAsync(order, { fillAmount });
//         // Reduce maker funds to be < remaining.
//         const remainingMakerAmount = getFillableMakerTokenAmount(order, fillAmount);
//         const balance = getRandomPortion(remainingMakerAmount);
//         const allowance = getRandomPortion(remainingMakerAmount);
//         await fundOrderMakerAsync(order, balance, allowance);
//         // Get order state.
//         const [orderInfo, fillableTakerAmount, isSignatureValid] = await zeroEx
//             .getLimitOrderRelevantState(order, await order.getSignatureWithProviderAsync(env.provider))
//             .callAsync();
//         expect(orderInfo).to.deep.eq({
//             orderHash: order.getHash(),
//             status: OrderStatus.Fillable,
//             takerTokenFilledAmount: fillAmount,
//         });
//         expect(fillableTakerAmount).to.bignumber.eq(
//             getActualFillableTakerTokenAmount(order, balance, allowance, fillAmount),
//         );
//         expect(isSignatureValid).to.eq(true);
//     });
// });

// describe('getRfqOrderRelevantState()', () => {
//     it('works with an empty order', async () => {
//         const order = getTestRfqOrder({
//             takerAmount: ZERO_AMOUNT,
//         });
//         await fundOrderMakerAsync(order);
//         const [orderInfo, fillableTakerAmount, isSignatureValid] = await zeroEx
//             .getRfqOrderRelevantState(order, await order.getSignatureWithProviderAsync(env.provider))
//             .callAsync();
//         expect(orderInfo).to.deep.eq({
//             orderHash: order.getHash(),
//             status: OrderStatus.Filled,
//             takerTokenFilledAmount: ZERO_AMOUNT,
//         });
//         expect(fillableTakerAmount).to.bignumber.eq(0);
//         expect(isSignatureValid).to.eq(true);
//     });

//     it('works with cancelled order', async () => {
//         const order = getTestRfqOrder();
//         await fundOrderMakerAsync(order);
//         await zeroEx.cancelRfqOrder(order).awaitTransactionSuccessAsync({ from: maker });
//         const [orderInfo, fillableTakerAmount, isSignatureValid] = await zeroEx
//             .getRfqOrderRelevantState(order, await order.getSignatureWithProviderAsync(env.provider))
//             .callAsync();
//         expect(orderInfo).to.deep.eq({
//             orderHash: order.getHash(),
//             status: OrderStatus.Cancelled,
//             takerTokenFilledAmount: ZERO_AMOUNT,
//         });
//         expect(fillableTakerAmount).to.bignumber.eq(0);
//         expect(isSignatureValid).to.eq(true);
//     });

//     it('works with a bad signature', async () => {
//         const order = getTestRfqOrder();
//         await fundOrderMakerAsync(order);
//         const [orderInfo, fillableTakerAmount, isSignatureValid] = await zeroEx
//             .getRfqOrderRelevantState(
//                 order,
//                 await order.clone({ maker: notMaker }).getSignatureWithProviderAsync(env.provider),
//             )
//             .callAsync();
//         expect(orderInfo).to.deep.eq({
//             orderHash: order.getHash(),
//             status: OrderStatus.Fillable,
//             takerTokenFilledAmount: ZERO_AMOUNT,
//         });
//         expect(fillableTakerAmount).to.bignumber.eq(order.takerAmount);
//         expect(isSignatureValid).to.eq(false);
//     });

//     it('works with an unfilled order', async () => {
//         const order = getTestRfqOrder();
//         await fundOrderMakerAsync(order);
//         const [orderInfo, fillableTakerAmount, isSignatureValid] = await zeroEx
//             .getRfqOrderRelevantState(order, await order.getSignatureWithProviderAsync(env.provider))
//             .callAsync();
//         expect(orderInfo).to.deep.eq({
//             orderHash: order.getHash(),
//             status: OrderStatus.Fillable,
//             takerTokenFilledAmount: ZERO_AMOUNT,
//         });
//         expect(fillableTakerAmount).to.bignumber.eq(order.takerAmount);
//         expect(isSignatureValid).to.eq(true);
//     });

//     it('works with a fully filled order', async () => {
//         const order = getTestRfqOrder();
//         // Fully Fund maker and taker.
//         await fundOrderMakerAsync(order);
//         await takerToken.mint(taker, order.takerAmount);
//         await testUtils.fillRfqOrderAsync(order);
//         // Partially fill the order.
//         const [orderInfo, fillableTakerAmount, isSignatureValid] = await zeroEx
//             .getRfqOrderRelevantState(order, await order.getSignatureWithProviderAsync(env.provider))
//             .callAsync();
//         expect(orderInfo).to.deep.eq({
//             orderHash: order.getHash(),
//             status: OrderStatus.Filled,
//             takerTokenFilledAmount: order.takerAmount,
//         });
//         expect(fillableTakerAmount).to.bignumber.eq(0);
//         expect(isSignatureValid).to.eq(true);
//     });

//     it('works with an under-funded, partially-filled order', async () => {
//         const order = getTestRfqOrder();
//         // Fully Fund maker and taker.
//         await fundOrderMakerAsync(order);
//         await takerToken.mint(taker, order.takerAmount).awaitTransactionSuccessAsync();
//         // Partially fill the order.
//         const fillAmount = getRandomPortion(order.takerAmount);
//         await testUtils.fillRfqOrderAsync(order, fillAmount);
//         // Reduce maker funds to be < remaining.
//         const remainingMakerAmount = getFillableMakerTokenAmount(order, fillAmount);
//         const balance = getRandomPortion(remainingMakerAmount);
//         const allowance = getRandomPortion(remainingMakerAmount);
//         await fundOrderMakerAsync(order, balance, allowance);
//         // Get order state.
//         const [orderInfo, fillableTakerAmount, isSignatureValid] = await zeroEx
//             .getRfqOrderRelevantState(order, await order.getSignatureWithProviderAsync(env.provider))
//             .callAsync();
//         expect(orderInfo).to.deep.eq({
//             orderHash: order.getHash(),
//             status: OrderStatus.Fillable,
//             takerTokenFilledAmount: fillAmount,
//         });
//         expect(fillableTakerAmount).to.bignumber.eq(
//             getActualFillableTakerTokenAmount(order, balance, allowance, fillAmount),
//         );
//         expect(isSignatureValid).to.eq(true);
//     });
// });

// async function batchFundOrderMakerAsync(orders: Array<LimitOrder | RfqOrder>): Promise<void> {
//     await makerToken.burn(maker, await makerToken.balanceOf(maker).callAsync()).awaitTransactionSuccessAsync();
//     const balance = BigNumber.sum(...orders.map(o => o.makerAmount));
//     await makerToken.mint(maker, balance).awaitTransactionSuccessAsync();
//     await makerToken.approve(zeroEx.address, balance).awaitTransactionSuccessAsync({ from: maker });
// }

// describe('batchGetLimitOrderRelevantStates()', () => {
//     it('works with multiple orders', async () => {
//         const orders = new Array(3).fill(0).map(() => getTestLimitOrder());
//         await batchFundOrderMakerAsync(orders);
//         const [orderInfos, fillableTakerAmounts, isSignatureValids] = await zeroEx
//             .batchGetLimitOrderRelevantStates(
//                 orders,
//                 await Promise.all(orders.map(async o => o.getSignatureWithProviderAsync(env.provider))),
//             )
//             .callAsync();
//         expect(orderInfos).to.be.length(orders.length);
//         expect(fillableTakerAmounts).to.be.length(orders.length);
//         expect(isSignatureValids).to.be.length(orders.length);
//         for (let i = 0; i < orders.length; ++i) {
//             expect(orderInfos[i]).to.deep.eq({
//                 orderHash: orders[i].getHash(),
//                 status: OrderStatus.Fillable,
//                 takerTokenFilledAmount: ZERO_AMOUNT,
//             });
//             expect(fillableTakerAmounts[i]).to.bignumber.eq(orders[i].takerAmount);
//             expect(isSignatureValids[i]).to.eq(true);
//         }
//     });
//     it('swallows reverts', async () => {
//         const orders = new Array(3).fill(0).map(() => getTestLimitOrder());
//         // The second order will revert because its maker token is not valid.
//         orders[1].makerToken = randomAddress();
//         await batchFundOrderMakerAsync(orders);
//         const [orderInfos, fillableTakerAmounts, isSignatureValids] = await zeroEx
//             .batchGetLimitOrderRelevantStates(
//                 orders,
//                 await Promise.all(orders.map(async o => o.getSignatureWithProviderAsync(env.provider))),
//             )
//             .callAsync();
//         expect(orderInfos).to.be.length(orders.length);
//         expect(fillableTakerAmounts).to.be.length(orders.length);
//         expect(isSignatureValids).to.be.length(orders.length);
//         for (let i = 0; i < orders.length; ++i) {
//             expect(orderInfos[i]).to.deep.eq({
//                 orderHash: i === 1 ? NULL_BYTES32 : orders[i].getHash(),
//                 status: i === 1 ? OrderStatus.Invalid : OrderStatus.Fillable,
//                 takerTokenFilledAmount: ZERO_AMOUNT,
//             });
//             expect(fillableTakerAmounts[i]).to.bignumber.eq(i === 1 ? ZERO_AMOUNT : orders[i].takerAmount);
//             expect(isSignatureValids[i]).to.eq(i !== 1);
//         }
//     });
// });

// describe('batchGetRfqOrderRelevantStates()', () => {
//     it('works with multiple orders', async () => {
//         const orders = new Array(3).fill(0).map(() => getTestRfqOrder());
//         await batchFundOrderMakerAsync(orders);
//         const [orderInfos, fillableTakerAmounts, isSignatureValids] = await zeroEx
//             .batchGetRfqOrderRelevantStates(
//                 orders,
//                 await Promise.all(orders.map(async o => o.getSignatureWithProviderAsync(env.provider))),
//             )
//             .callAsync();
//         expect(orderInfos).to.be.length(orders.length);
//         expect(fillableTakerAmounts).to.be.length(orders.length);
//         expect(isSignatureValids).to.be.length(orders.length);
//         for (let i = 0; i < orders.length; ++i) {
//             expect(orderInfos[i]).to.deep.eq({
//                 orderHash: orders[i].getHash(),
//                 status: OrderStatus.Fillable,
//                 takerTokenFilledAmount: ZERO_AMOUNT,
//             });
//             expect(fillableTakerAmounts[i]).to.bignumber.eq(orders[i].takerAmount);
//             expect(isSignatureValids[i]).to.eq(true);
//         }
//     });
// });

// describe('registerAllowedSigner()', () => {
//     it('fires appropriate events', async () => {
//         const receiptAllow = await contractWallet
//             .registerAllowedOrderSigner(contractWalletSigner, true)
//             .awaitTransactionSuccessAsync({ from: contractWalletOwner });

//         verifyEventsFromLogs(
//             receiptAllow.logs,
//             [
//                 {
//                     maker: contractWallet.address,
//                     signer: contractWalletSigner,
//                     allowed: true,
//                 },
//             ],
//             IZeroExEvents.OrderSignerRegistered,
//         );

//         // then disallow signer
//         const receiptDisallow = await contractWallet
//             .registerAllowedOrderSigner(contractWalletSigner, false)
//             .awaitTransactionSuccessAsync({ from: contractWalletOwner });

//         verifyEventsFromLogs(
//             receiptDisallow.logs,
//             [
//                 {
//                     maker: contractWallet.address,
//                     signer: contractWalletSigner,
//                     allowed: false,
//                 },
//             ],
//             IZeroExEvents.OrderSignerRegistered,
//         );
//     });

//     it('allows for fills on orders signed by a approved signer', async () => {
//         const order = getTestRfqOrder({ maker: contractWallet.address });
//         const sig = await order.getSignatureWithProviderAsync(
//             env.provider,
//             SignatureType.EthSign,
//             contractWalletSigner,
//         );

//         // covers taker
//         await testUtils.prepareBalancesForOrdersAsync([order]);
//         // need to provide contract wallet with a balance
//         await makerToken.mint(contractWallet.address, order.makerAmount).awaitTransactionSuccessAsync();

//         await contractWallet
//             .registerAllowedOrderSigner(contractWalletSigner, true)
//             .awaitTransactionSuccessAsync({ from: contractWalletOwner });

//         await zeroEx.fillRfqOrder(order, sig, order.takerAmount).awaitTransactionSuccessAsync({ from: taker });

//         const info = await zeroEx.getRfqOrderInfo(order).callAsync();
//         assertOrderInfoEquals(info, {
//             status: OrderStatus.Filled,
//             orderHash: order.getHash(),
//             takerTokenFilledAmount: order.takerAmount,
//         });
//     });

//     it('disallows fills if the signer is revoked', async () => {
//         const order = getTestRfqOrder({ maker: contractWallet.address });
//         const sig = await order.getSignatureWithProviderAsync(
//             env.provider,
//             SignatureType.EthSign,
//             contractWalletSigner,
//         );

//         // covers taker
//         await testUtils.prepareBalancesForOrdersAsync([order]);
//         // need to provide contract wallet with a balance
//         await makerToken.mint(contractWallet.address, order.makerAmount).awaitTransactionSuccessAsync();

//         // first allow signer
//         await contractWallet
//             .registerAllowedOrderSigner(contractWalletSigner, true)
//             .awaitTransactionSuccessAsync({ from: contractWalletOwner });

//         // then disallow signer
//         await contractWallet
//             .registerAllowedOrderSigner(contractWalletSigner, false)
//             .awaitTransactionSuccessAsync({ from: contractWalletOwner });

//         const tx = zeroEx.fillRfqOrder(order, sig, order.takerAmount).awaitTransactionSuccessAsync({ from: taker });
//         return expect(tx).to.be.revertedWith(
//             new RevertErrors.NativeOrders.orderNotSignedByMakerError(
//                 order.getHash(),
//                 contractWalletSigner,
//                 order.maker,
//             ),
//         );
//     });

//     it(`doesn't allow fills with an unapproved signer`, async () => {
//         const order = getTestRfqOrder({ maker: contractWallet.address });
//         const sig = await order.getSignatureWithProviderAsync(env.provider, SignatureType.EthSign, maker);

//         // covers taker
//         await testUtils.prepareBalancesForOrdersAsync([order]);
//         // need to provide contract wallet with a balance
//         await makerToken.mint(contractWallet.address, order.makerAmount).awaitTransactionSuccessAsync();

//         const tx = zeroEx.fillRfqOrder(order, sig, order.takerAmount).awaitTransactionSuccessAsync({ from: taker });
//         return expect(tx).to.be.revertedWith(
//             new RevertErrors.NativeOrders.orderNotSignedByMakerError(order.getHash(), maker, order.maker),
//         );
//     });

//     it(`allows an approved signer to cancel an RFQ order`, async () => {
//         const order = getTestRfqOrder({ maker: contractWallet.address });

//         await contractWallet
//             .registerAllowedOrderSigner(contractWalletSigner, true)
//             .awaitTransactionSuccessAsync({ from: contractWalletOwner });

//         const receipt = await zeroEx
//             .cancelRfqOrder(order)
//             .awaitTransactionSuccessAsync({ from: contractWalletSigner });

//         verifyEventsFromLogs(
//             receipt.logs,
//             [{ maker: contractWallet.address, orderHash: order.getHash() }],
//             IZeroExEvents.OrderCancelled,
//         );

//         const info = await zeroEx.getRfqOrderInfo(order).callAsync();
//         assertOrderInfoEquals(info, {
//             status: OrderStatus.Cancelled,
//             orderHash: order.getHash(),
//             takerTokenFilledAmount: new BigNumber(0),
//         });
//     });

//     it(`allows an approved signer to cancel a limit order`, async () => {
//         const order = getTestLimitOrder({ maker: contractWallet.address });

//         await contractWallet
//             .registerAllowedOrderSigner(contractWalletSigner, true)
//             .awaitTransactionSuccessAsync({ from: contractWalletOwner });

//         const receipt = await zeroEx
//             .cancelLimitOrder(order)
//             .awaitTransactionSuccessAsync({ from: contractWalletSigner });

//         verifyEventsFromLogs(
//             receipt.logs,
//             [{ maker: contractWallet.address, orderHash: order.getHash() }],
//             IZeroExEvents.OrderCancelled,
//         );

//         const info = await zeroEx.getLimitOrderInfo(order).callAsync();
//         assertOrderInfoEquals(info, {
//             status: OrderStatus.Cancelled,
//             orderHash: order.getHash(),
//             takerTokenFilledAmount: new BigNumber(0),
//         });
//     });

//     it(`doesn't allow an unapproved signer to cancel an RFQ order`, async () => {
//         const order = getTestRfqOrder({ maker: contractWallet.address });

//         const tx = zeroEx.cancelRfqOrder(order).awaitTransactionSuccessAsync({ from: maker });

//         return expect(tx).to.be.revertedWith(
//             new RevertErrors.NativeOrders.onlyOrderMakerAllowed(order.getHash(), maker, order.maker),
//         );
//     });

//     it(`doesn't allow an unapproved signer to cancel a limit order`, async () => {
//         const order = getTestLimitOrder({ maker: contractWallet.address });

//         const tx = zeroEx.cancelLimitOrder(order).awaitTransactionSuccessAsync({ from: maker });

//         return expect(tx).to.be.revertedWith(
//             new RevertErrors.NativeOrders.onlyOrderMakerAllowed(order.getHash(), maker, order.maker),
//         );
//     });

//     it(`allows a signer to cancel pair RFQ orders`, async () => {
//         const order = getTestRfqOrder({ maker: contractWallet.address, salt: BigNumber.from(1) });

//         await contractWallet
//             .registerAllowedOrderSigner(contractWalletSigner, true)
//             .awaitTransactionSuccessAsync({ from: contractWalletOwner });

//         // Cancel salts <= the order's
//         const minValidSalt = order.salt.plus(1);

//         const receipt = await zeroEx
//             .cancelPairRfqOrdersWithSigner(
//                 contractWallet.address,
//                 makerToken.address,
//                 takerToken.address,
//                 minValidSalt,
//             )
//             .awaitTransactionSuccessAsync({ from: contractWalletSigner });
//         verifyEventsFromLogs(
//             receipt.logs,
//             [
//                 {
//                     maker: contractWallet.address,
//                     makerToken: makerToken.address,
//                     takerToken: takerToken.address,
//                     minValidSalt,
//                 },
//             ],
//             IZeroExEvents.PairCancelledRfqOrders,
//         );

//         const info = await zeroEx.getRfqOrderInfo(order).callAsync();

//         assertOrderInfoEquals(info, {
//             status: OrderStatus.Cancelled,
//             orderHash: order.getHash(),
//             takerTokenFilledAmount: new BigNumber(0),
//         });
//     });

//     it(`doesn't allow an unapproved signer to cancel pair RFQ orders`, async () => {
//         const minValidSalt = BigNumber.from(2);

//         const tx = zeroEx
//             .cancelPairRfqOrdersWithSigner(
//                 contractWallet.address,
//                 makerToken.address,
//                 takerToken.address,
//                 minValidSalt,
//             )
//             .awaitTransactionSuccessAsync({ from: maker });

//         return expect(tx).to.be.revertedWith(
//             new RevertErrors.NativeOrders.InvalidSignerError(contractWallet.address, maker),
//         );
//     });

//     it(`allows a signer to cancel pair limit orders`, async () => {
//         const order = getTestLimitOrder({ maker: contractWallet.address, salt: BigNumber.from(1) });

//         await contractWallet
//             .registerAllowedOrderSigner(contractWalletSigner, true)
//             .awaitTransactionSuccessAsync({ from: contractWalletOwner });

//         // Cancel salts <= the order's
//         const minValidSalt = order.salt.plus(1);

//         const receipt = await zeroEx
//             .cancelPairLimitOrdersWithSigner(
//                 contractWallet.address,
//                 makerToken.address,
//                 takerToken.address,
//                 minValidSalt,
//             )
//             .awaitTransactionSuccessAsync({ from: contractWalletSigner });
//         verifyEventsFromLogs(
//             receipt.logs,
//             [
//                 {
//                     maker: contractWallet.address,
//                     makerToken: makerToken.address,
//                     takerToken: takerToken.address,
//                     minValidSalt,
//                 },
//             ],
//             IZeroExEvents.PairCancelledLimitOrders,
//         );

//         const info = await zeroEx.getLimitOrderInfo(order).callAsync();

//         assertOrderInfoEquals(info, {
//             status: OrderStatus.Cancelled,
//             orderHash: order.getHash(),
//             takerTokenFilledAmount: new BigNumber(0),
//         });
//     });

//     it(`doesn't allow an unapproved signer to cancel pair limit orders`, async () => {
//         const minValidSalt = BigNumber.from(2);

//         const tx = zeroEx
//             .cancelPairLimitOrdersWithSigner(
//                 contractWallet.address,
//                 makerToken.address,
//                 takerToken.address,
//                 minValidSalt,
//             )
//             .awaitTransactionSuccessAsync({ from: maker });

//         return expect(tx).to.be.revertedWith(
//             new RevertErrors.NativeOrders.InvalidSignerError(contractWallet.address, maker),
//         );
//     });

//     it(`allows a signer to cancel multiple RFQ order pairs`, async () => {
//         const orders = [
//             getTestRfqOrder({ maker: contractWallet.address, salt: BigNumber.from(1) }),
//             // Flip the tokens for the other order.
//             getTestRfqOrder({
//                 makerToken: takerToken.address,
//                 takerToken: makerToken.address,
//                 maker: contractWallet.address,
//                 salt: BigNumber.from(1),
//             }),
//         ];

//         await contractWallet
//             .registerAllowedOrderSigner(contractWalletSigner, true)
//             .awaitTransactionSuccessAsync({ from: contractWalletOwner });

//         const minValidSalt = BigNumber.from(2);
//         const receipt = await zeroEx
//             .batchCancelPairRfqOrdersWithSigner(
//                 contractWallet.address,
//                 [makerToken.address, takerToken.address],
//                 [takerToken.address, makerToken.address],
//                 [minValidSalt, minValidSalt],
//             )
//             .awaitTransactionSuccessAsync({ from: contractWalletSigner });
//         verifyEventsFromLogs(
//             receipt.logs,
//             [
//                 {
//                     maker: contractWallet.address,
//                     makerToken: makerToken.address,
//                     takerToken: takerToken.address,
//                     minValidSalt,
//                 },
//                 {
//                     maker: contractWallet.address,
//                     makerToken: takerToken.address,
//                     takerToken: makerToken.address,
//                     minValidSalt,
//                 },
//             ],
//             IZeroExEvents.PairCancelledRfqOrders,
//         );
//         const statuses = (await Promise.all(orders.map(o => zeroEx.getRfqOrderInfo(o).callAsync()))).map(
//             oi => oi.status,
//         );
//         expect(statuses).to.deep.eq([OrderStatus.Cancelled, OrderStatus.Cancelled]);
//     });

//     it(`doesn't allow an unapproved signer to batch cancel pair rfq orders`, async () => {
//         const minValidSalt = BigNumber.from(2);

//         const tx = zeroEx
//             .batchCancelPairRfqOrdersWithSigner(
//                 contractWallet.address,
//                 [makerToken.address, takerToken.address],
//                 [takerToken.address, makerToken.address],
//                 [minValidSalt, minValidSalt],
//             )
//             .awaitTransactionSuccessAsync({ from: maker });

//         return expect(tx).to.be.revertedWith(
//             new RevertErrors.NativeOrders.InvalidSignerError(contractWallet.address, maker),
//         );
//     });

//     it(`allows a signer to cancel multiple limit order pairs`, async () => {
//         const orders = [
//             getTestLimitOrder({ maker: contractWallet.address, salt: BigNumber.from(1) }),
//             // Flip the tokens for the other order.
//             getTestLimitOrder({
//                 makerToken: takerToken.address,
//                 takerToken: makerToken.address,
//                 maker: contractWallet.address,
//                 salt: BigNumber.from(1),
//             }),
//         ];

//         await contractWallet
//             .registerAllowedOrderSigner(contractWalletSigner, true)
//             .awaitTransactionSuccessAsync({ from: contractWalletOwner });

//         const minValidSalt = BigNumber.from(2);
//         const receipt = await zeroEx
//             .batchCancelPairLimitOrdersWithSigner(
//                 contractWallet.address,
//                 [makerToken.address, takerToken.address],
//                 [takerToken.address, makerToken.address],
//                 [minValidSalt, minValidSalt],
//             )
//             .awaitTransactionSuccessAsync({ from: contractWalletSigner });
//         verifyEventsFromLogs(
//             receipt.logs,
//             [
//                 {
//                     maker: contractWallet.address,
//                     makerToken: makerToken.address,
//                     takerToken: takerToken.address,
//                     minValidSalt,
//                 },
//                 {
//                     maker: contractWallet.address,
//                     makerToken: takerToken.address,
//                     takerToken: makerToken.address,
//                     minValidSalt,
//                 },
//             ],
//             IZeroExEvents.PairCancelledLimitOrders,
//         );
//         const statuses = (await Promise.all(orders.map(o => zeroEx.getLimitOrderInfo(o).callAsync()))).map(
//             oi => oi.status,
//         );
//         expect(statuses).to.deep.eq([OrderStatus.Cancelled, OrderStatus.Cancelled]);
//     });

//     it(`doesn't allow an unapproved signer to batch cancel pair limit orders`, async () => {
//         const minValidSalt = BigNumber.from(2);

//         const tx = zeroEx
//             .batchCancelPairLimitOrdersWithSigner(
//                 contractWallet.address,
//                 [makerToken.address, takerToken.address],
//                 [takerToken.address, makerToken.address],
//                 [minValidSalt, minValidSalt],
//             )
//             .awaitTransactionSuccessAsync({ from: maker });

//         return expect(tx).to.be.revertedWith(
//             new RevertErrors.NativeOrders.InvalidSignerError(contractWallet.address, maker),
//         );
//     });
// });

