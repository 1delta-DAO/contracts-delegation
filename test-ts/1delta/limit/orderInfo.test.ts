import {
    constants,
    getRandomPortion as _getRandomPortion,
    randomAddress,
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
import { createNativeOrder } from './utils/orderFixture';
import { IZeroExEvents, LimitOrder, LimitOrderFields, OrderStatus, RfqOrder, RfqOrderFields } from './utils/constants';
import { BigNumber, ContractReceipt } from 'ethers';
import { MockProvider } from 'ethereum-waffle';
import { time } from '@nomicfoundation/hardhat-network-helpers';
import { expect } from '../shared/expect'
import { sumBn } from './utils/utils';
import { SignatureType } from './utils/signature_utils';

const getRandomPortion = (n: BigNumber) => BigNumber.from(_getRandomPortion(n.toString()).toString())

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
