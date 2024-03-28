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
import { sumBn, verifyLogs } from './utils/utils';
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
