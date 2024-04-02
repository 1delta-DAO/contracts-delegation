import {
    constants,
    getRandomPortion as _getRandomPortion,
} from '@0x/contracts-test-utils';
import {
    assertOrderInfoEquals,
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
    NativeOrders,
} from '../../../types';
import { createNativeOrder } from './utils/orderFixture';
import { LimitOrder, LimitOrderFields, OrderStatus, RfqOrder, RfqOrderFields, MAX_UINT256 } from './utils/constants';
import { BigNumber } from 'ethers';
import { MockProvider } from 'ethereum-waffle';
import { time } from '@nomicfoundation/hardhat-network-helpers';
import { expect } from '../shared/expect'

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
let oneDeltaOrders: NativeOrders;
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

    oneDeltaOrders = await createNativeOrder(
        owner,
        collector.address,
        BigNumber.from(PROTOCOL_FEE_MULTIPLIER)
    );

    verifyingContract = oneDeltaOrders.address;
    await Promise.all(
        [maker, notMaker].map(a =>
            makerToken.connect(a).approve(oneDeltaOrders.address, MAX_UINT256),
        ),
    );
    await Promise.all(
        [taker, notTaker].map(a =>
            takerToken.connect(a).approve(oneDeltaOrders.address, MAX_UINT256),
        ),
    );

    GAS_PRICE = await provider.getGasPrice()
    SINGLE_PROTOCOL_FEE = GAS_PRICE.mul(PROTOCOL_FEE_MULTIPLIER);
    testUtils = new NativeOrdersTestEnvironment(
        maker,
        taker,
        makerToken,
        takerToken,
        oneDeltaOrders,
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
//         const r = await oneDeltaOrders.getProtocolFeeMultiplier().callAsync();
//         expect(r).to.bignumber.eq(PROTOCOL_FEE_MULTIPLIER);
//     });
// });


describe('getLimitOrderHash()', () => {
    it('returns the correct hash', async () => {
        const order = getTestLimitOrder();
        const hash = await oneDeltaOrders.getLimitOrderHash(order);
        expect(hash).to.eq(order.getHash());
    });
});

describe('getRfqOrderHash()', () => {
    it('returns the correct hash', async () => {
        const order = getTestRfqOrder();
        const hash = await oneDeltaOrders.getRfqOrderHash(order);
        expect(hash).to.eq(order.getHash());
    });
});

describe('getLimitOrderInfo()', () => {
    it('unfilled order', async () => {
        const order = getTestLimitOrder();
        const info = await oneDeltaOrders.getLimitOrderInfo(order);
        assertOrderInfoEquals(info, {
            status: OrderStatus.Fillable,
            orderHash: order.getHash(),
            takerTokenFilledAmount: ZERO_AMOUNT,
        });
    });

    it('unfilled cancelled order', async () => {
        const order = getTestLimitOrder();
        await oneDeltaOrders.connect(maker).cancelLimitOrder(order);
        const info = await oneDeltaOrders.getLimitOrderInfo(order);
        assertOrderInfoEquals(info, {
            status: OrderStatus.Cancelled,
            orderHash: order.getHash(),
            takerTokenFilledAmount: ZERO_AMOUNT,
        });
    });

    it('unfilled expired order', async () => {
        const order = getTestLimitOrder({ expiry: await createCleanExpiry(provider, -1) });
        const info = await oneDeltaOrders.getLimitOrderInfo(order);
        assertOrderInfoEquals(info, {
            status: OrderStatus.Expired,
            orderHash: order.getHash(),
            takerTokenFilledAmount: ZERO_AMOUNT,
        });
    });

    it('filled then expired order', async () => {
        const expiry = await createCleanExpiry(provider, 60);
        const order = getTestLimitOrder({ expiry });

        // Fill the order first.
        await testUtils.fillLimitOrderAsync(order);

        // Advance time to expire the order.
        // await env.web3Wrapper.increaseTimeAsync(61);
        await time.increase(61)
        const info = await oneDeltaOrders.getLimitOrderInfo(order);
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
        const info = await oneDeltaOrders.getLimitOrderInfo(order);
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
        const info = await oneDeltaOrders.getLimitOrderInfo(order);
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
        await oneDeltaOrders.connect(maker).cancelLimitOrder(order);
        const info = await oneDeltaOrders.getLimitOrderInfo(order);
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
        await oneDeltaOrders.connect(maker).cancelLimitOrder(order);
        const info = await oneDeltaOrders.getLimitOrderInfo(order);
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
        const info = await oneDeltaOrders.getRfqOrderInfo(order);
        assertOrderInfoEquals(info, {
            status: OrderStatus.Fillable,
            orderHash: order.getHash(),
            takerTokenFilledAmount: ZERO_AMOUNT,
        });
    });

    it('unfilled cancelled order', async () => {
        const order = getTestRfqOrder();
        await oneDeltaOrders.connect(maker).cancelRfqOrder(order);
        const info = await oneDeltaOrders.getRfqOrderInfo(order);
        assertOrderInfoEquals(info, {
            status: OrderStatus.Cancelled,
            orderHash: order.getHash(),
            takerTokenFilledAmount: ZERO_AMOUNT,
        });
    });

    it('unfilled expired order', async () => {
        const expiry = await createCleanExpiry(provider, -1);
        const order = getTestRfqOrder({ expiry });
        const info = await oneDeltaOrders.getRfqOrderInfo(order);
        assertOrderInfoEquals(info, {
            status: OrderStatus.Expired,
            orderHash: order.getHash(),
            takerTokenFilledAmount: ZERO_AMOUNT,
        });
    });

    it('filled then expired order', async () => {
        const expiry = await createCleanExpiry(provider, 120);
        const order = getTestRfqOrder({ expiry });
        await testUtils.prepareBalancesForOrdersAsync([order]);
        const sig = await order.getSignatureWithProviderAsync(maker);
        // Fill the order first.
        await oneDeltaOrders.connect(taker).fillRfqOrder(order, sig, order.takerAmount, false);
        // Advance time to expire the order.
        // await env.web3Wrapper.increaseTimeAsync(61);
        await time.increase(121)
        const info = await oneDeltaOrders.getRfqOrderInfo(order);
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
        const info = await oneDeltaOrders.getRfqOrderInfo(order);
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
        const info = await oneDeltaOrders.getRfqOrderInfo(order);
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
        await oneDeltaOrders.connect(maker).cancelRfqOrder(order);
        const info = await oneDeltaOrders.getRfqOrderInfo(order);
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
        await oneDeltaOrders.connect(maker).cancelRfqOrder(order);
        const info = await oneDeltaOrders.getRfqOrderInfo(order);
        assertOrderInfoEquals(info, {
            status: OrderStatus.Cancelled,
            orderHash: order.getHash(),
            takerTokenFilledAmount: fillAmount,
        });
    });

    it('invalid origin', async () => {
        const order = getTestRfqOrder({ txOrigin: NULL_ADDRESS });
        const info = await oneDeltaOrders.getRfqOrderInfo(order);
        assertOrderInfoEquals(info, {
            status: OrderStatus.Invalid,
            orderHash: order.getHash(),
            takerTokenFilledAmount: ZERO_AMOUNT,
        });
    });
});
