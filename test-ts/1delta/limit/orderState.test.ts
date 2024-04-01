import {
    constants,
    getRandomPortion as _getRandomPortion,
} from '@0x/contracts-test-utils';


import {
    assertOrderInfoEquals,
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
    TestOrderSignerRegistryWithContractWallet,
    TestOrderSignerRegistryWithContractWallet__factory,
    WETH9,
    WETH9__factory
} from '../../../types';
import { MaxUint128 } from '../../uniswap-v3/periphery/shared/constants';
import { createNativeOrder } from './utils/orderFixture';
import { IZeroExEvents, LimitOrder, LimitOrderFields, OrderStatus, RfqOrder, RfqOrderFields } from './utils/constants';
import { BigNumber } from 'ethers';
import { MockProvider } from 'ethereum-waffle';
import { expect } from '../shared/expect'
import { infoEqals, sumBn, validateError, verifyLogs } from './utils/utils';
import { SignatureType } from './utils/signature_utils';

const getRandomPortion = (n: BigNumber) => BigNumber.from(_getRandomPortion(n.toString()).toString())

const { NULL_ADDRESS, NULL_BYTES32, } = constants;
const ZERO_AMOUNT = BigNumber.from(0)
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

async function fundOrderMakerAsync(
    order: LimitOrder | RfqOrder,
    balance: BigNumber = order.makerAmount,
    allowance: BigNumber = order.makerAmount,
): Promise<void> {
    await makerToken.burn(maker.address, await makerToken.balanceOf(maker.address));
    await makerToken.mint(maker.address, balance);
    await makerToken.connect(maker).approve(zeroEx.address, allowance);
}

describe('getLimitOrderRelevantState()', () => {
    it('works with an empty order', async () => {
        const order = getTestLimitOrder({
            takerAmount: ZERO_AMOUNT,
        });
        await fundOrderMakerAsync(order);
        const [orderInfo, fillableTakerAmount, isSignatureValid] = await zeroEx
            .getLimitOrderRelevantState(order, await order.getSignatureWithProviderAsync(maker));
        infoEqals(orderInfo, {
            orderHash: order.getHash(),
            status: OrderStatus.Filled,
            takerTokenFilledAmount: ZERO_AMOUNT,
        });
        expect(fillableTakerAmount.toString()).to.eq('0');
        expect(isSignatureValid).to.eq(true);
    });

    it('works with cancelled order', async () => {
        const order = getTestLimitOrder();
        await fundOrderMakerAsync(order);
        await zeroEx.connect(maker).cancelLimitOrder(order);
        const [orderInfo, fillableTakerAmount, isSignatureValid] = await zeroEx
            .getLimitOrderRelevantState(order, await order.getSignatureWithProviderAsync(maker));
        infoEqals(orderInfo, {
            orderHash: order.getHash(),
            status: OrderStatus.Cancelled,
            takerTokenFilledAmount: ZERO_AMOUNT,
        });
        expect(fillableTakerAmount.toString()).to.eq('0');
        expect(isSignatureValid).to.eq(true);
    });

    it('works with a bad signature', async () => {
        const order = getTestLimitOrder();
        await fundOrderMakerAsync(order);
        const [orderInfo, fillableTakerAmount, isSignatureValid] = await zeroEx
            .getLimitOrderRelevantState(
                order,
                await order.clone({ maker: notMaker.address }).getSignatureWithProviderAsync(notMaker),
            );
        infoEqals(orderInfo, {
            orderHash: order.getHash(),
            status: OrderStatus.Fillable,
            takerTokenFilledAmount: ZERO_AMOUNT,
        });
        expect(fillableTakerAmount.toString()).to.eq(order.takerAmount.toString());
        expect(isSignatureValid).to.eq(false);
    });

    it('works with an unfilled order', async () => {
        const order = getTestLimitOrder();
        await fundOrderMakerAsync(order);
        const [orderInfo, fillableTakerAmount, isSignatureValid] = await zeroEx
            .getLimitOrderRelevantState(order, await order.getSignatureWithProviderAsync(maker));
        infoEqals(orderInfo, {
            orderHash: order.getHash(),
            status: OrderStatus.Fillable,
            takerTokenFilledAmount: ZERO_AMOUNT,
        });
        expect(fillableTakerAmount.toString()).to.eq(order.takerAmount.toString());
        expect(isSignatureValid).to.eq(true);
    });

    it('works with a fully filled order', async () => {
        const order = getTestLimitOrder();
        // Fully Fund maker and taker.
        await fundOrderMakerAsync(order);
        await takerToken
            .mint(taker.address, order.takerAmount.add(order.takerTokenFeeAmount));
        await testUtils.fillLimitOrderAsync(order);
        // Partially fill the order.
        const [orderInfo, fillableTakerAmount, isSignatureValid] = await zeroEx
            .getLimitOrderRelevantState(order, await order.getSignatureWithProviderAsync(maker));
        infoEqals(orderInfo, {
            orderHash: order.getHash(),
            status: OrderStatus.Filled,
            takerTokenFilledAmount: order.takerAmount,
        });
        expect(fillableTakerAmount.toString()).to.eq('0');
        expect(isSignatureValid).to.eq(true);
    });

    it('works with an under-funded, partially-filled order', async () => {
        const order = getTestLimitOrder();
        // Fully Fund maker and taker.
        await fundOrderMakerAsync(order);
        await takerToken
            .mint(taker.address, order.takerAmount.add(order.takerTokenFeeAmount));
        // Partially fill the order.
        const fillAmount = getRandomPortion(order.takerAmount);
        await testUtils.fillLimitOrderAsync(order, { fillAmount });
        // Reduce maker funds to be < remaining.
        const remainingMakerAmount = getFillableMakerTokenAmount(order, fillAmount);
        const balance = getRandomPortion(remainingMakerAmount);
        const allowance = getRandomPortion(remainingMakerAmount);
        await fundOrderMakerAsync(order, balance, allowance);
        // Get order state.
        const [orderInfo, fillableTakerAmount, isSignatureValid] = await zeroEx
            .getLimitOrderRelevantState(order, await order.getSignatureWithProviderAsync(maker));
        infoEqals(orderInfo, {
            orderHash: order.getHash(),
            status: OrderStatus.Fillable,
            takerTokenFilledAmount: fillAmount,
        });
        expect(fillableTakerAmount.toString()).to.eq(
            getActualFillableTakerTokenAmount(order, balance, allowance, fillAmount).toString(),
        );
        expect(isSignatureValid).to.eq(true);
    });
});

describe('getRfqOrderRelevantState()', () => {
    it('works with an empty order', async () => {
        const order = getTestRfqOrder({
            takerAmount: ZERO_AMOUNT,
        });
        await fundOrderMakerAsync(order);
        const [orderInfo, fillableTakerAmount, isSignatureValid] = await zeroEx
            .getRfqOrderRelevantState(order, await order.getSignatureWithProviderAsync(maker));
        infoEqals(orderInfo, {
            orderHash: order.getHash(),
            status: OrderStatus.Filled,
            takerTokenFilledAmount: ZERO_AMOUNT,
        });
        expect(fillableTakerAmount).to.eq('0');
        expect(isSignatureValid).to.eq(true);
    });

    it('works with cancelled order', async () => {
        const order = getTestRfqOrder();
        await fundOrderMakerAsync(order);
        await zeroEx.connect(maker).cancelRfqOrder(order);
        const [orderInfo, fillableTakerAmount, isSignatureValid] = await zeroEx
            .getRfqOrderRelevantState(order, await order.getSignatureWithProviderAsync(maker));
        infoEqals(orderInfo, {
            orderHash: order.getHash(),
            status: OrderStatus.Cancelled,
            takerTokenFilledAmount: ZERO_AMOUNT,
        });
        expect(fillableTakerAmount).to.eq('0');
        expect(isSignatureValid).to.eq(true);
    });

    it('works with a bad signature', async () => {
        const order = getTestRfqOrder();
        await fundOrderMakerAsync(order);
        const [orderInfo, fillableTakerAmount, isSignatureValid] = await zeroEx
            .getRfqOrderRelevantState(
                order,
                await order.clone({ maker: notMaker.address }).getSignatureWithProviderAsync(notMaker),
            );
        infoEqals(orderInfo, {
            orderHash: order.getHash(),
            status: OrderStatus.Fillable,
            takerTokenFilledAmount: ZERO_AMOUNT,
        });
        expect(fillableTakerAmount.toString()).to.eq(order.takerAmount.toString());
        expect(isSignatureValid).to.eq(false);
    });

    it('works with an unfilled order', async () => {
        const order = getTestRfqOrder();
        await fundOrderMakerAsync(order);
        const [orderInfo, fillableTakerAmount, isSignatureValid] = await zeroEx
            .getRfqOrderRelevantState(order, await order.getSignatureWithProviderAsync(maker));
        infoEqals(orderInfo, {
            orderHash: order.getHash(),
            status: OrderStatus.Fillable,
            takerTokenFilledAmount: ZERO_AMOUNT,
        });
        expect(fillableTakerAmount.toString()).to.eq(order.takerAmount.toString());
        expect(isSignatureValid).to.eq(true);
    });

    it('works with a fully filled order', async () => {
        const order = getTestRfqOrder();
        // Fully Fund maker and taker.
        await fundOrderMakerAsync(order);
        await takerToken.mint(taker.address, order.takerAmount);
        await testUtils.fillRfqOrderAsync(order);
        // Partially fill the order.
        const [orderInfo, fillableTakerAmount, isSignatureValid] = await zeroEx
            .getRfqOrderRelevantState(order, await order.getSignatureWithProviderAsync(maker));
        infoEqals(orderInfo, {
            orderHash: order.getHash(),
            status: OrderStatus.Filled,
            takerTokenFilledAmount: order.takerAmount,
        });
        expect(fillableTakerAmount).to.eq('0');
        expect(isSignatureValid).to.eq(true);
    });

    it('works with an under-funded, partially-filled order', async () => {
        const order = getTestRfqOrder();
        // Fully Fund maker and taker.
        await fundOrderMakerAsync(order);
        await takerToken.mint(taker.address, order.takerAmount);
        // Partially fill the order.
        const fillAmount = getRandomPortion(order.takerAmount);
        await testUtils.fillRfqOrderAsync(order, fillAmount);
        // Reduce maker funds to be < remaining.
        const remainingMakerAmount = getFillableMakerTokenAmount(order, fillAmount);
        const balance = getRandomPortion(remainingMakerAmount);
        const allowance = getRandomPortion(remainingMakerAmount);
        await fundOrderMakerAsync(order, balance, allowance);
        // Get order state.
        const [orderInfo, fillableTakerAmount, isSignatureValid] = await zeroEx
            .getRfqOrderRelevantState(order, await order.getSignatureWithProviderAsync(maker));
        infoEqals(orderInfo, {
            orderHash: order.getHash(),
            status: OrderStatus.Fillable,
            takerTokenFilledAmount: fillAmount,
        });
        expect(fillableTakerAmount.toString()).to.eq(
            getActualFillableTakerTokenAmount(order, balance, allowance, fillAmount).toString(),
        );
        expect(isSignatureValid).to.eq(true);
    });
});

async function batchFundOrderMakerAsync(orders: Array<LimitOrder | RfqOrder>): Promise<void> {
    await makerToken.burn(maker.address, await makerToken.balanceOf(maker.address));
    const balance = sumBn(orders.map(o => o.makerAmount));
    await makerToken.mint(maker.address, balance);
    await makerToken.connect(maker).approve(zeroEx.address, balance);
}

describe('registerAllowedSigner()', () => {
    it('fires appropriate events', async () => {
        const txAllow = await contractWallet.connect(contractWalletOwner)
            .registerAllowedOrderSigner(contractWalletSigner.address, true);
        const receiptAllow = await txAllow.wait()
        verifyLogs(
            receiptAllow.logs,
            [
                {
                    maker: contractWallet.address,
                    signer: contractWalletSigner.address,
                    allowed: true,
                    indexed: ['maker', 'signer'],
                    indexedTypes: ['address', 'address'],
                },
            ],
            IZeroExEvents.OrderSignerRegistered,
        );

        // then disallow signer
        const txDisallow = await contractWallet.connect(contractWalletOwner)
            .registerAllowedOrderSigner(contractWalletSigner.address, false);
        const receiptDisallow = await txDisallow.wait()
        verifyLogs(
            receiptDisallow.logs,
            [
                {
                    maker: contractWallet.address,
                    signer: contractWalletSigner.address,
                    allowed: false,
                    indexed: ['maker', 'signer'],
                    indexedTypes: ['address', 'address'],
                },
            ],
            IZeroExEvents.OrderSignerRegistered,
        );
    });

    it('allows for fills on orders signed by a approved signer', async () => {
        const order = getTestRfqOrder({ maker: contractWallet.address });
        const sig = await order.getSignatureWithProviderAsync(
            contractWalletSigner,
            SignatureType.EthSign,
        );

        // covers taker
        await testUtils.prepareBalancesForOrdersAsync([order]);
        // need to provide contract wallet with a balance
        await makerToken.mint(contractWallet.address, order.makerAmount);

        await contractWallet.connect(contractWalletOwner)
            .registerAllowedOrderSigner(contractWalletSigner.address, true);

        await zeroEx.connect(taker).fillRfqOrder(order, sig, order.takerAmount, false);

        const info = await zeroEx.getRfqOrderInfo(order);
        assertOrderInfoEquals(info, {
            status: OrderStatus.Filled,
            orderHash: order.getHash(),
            takerTokenFilledAmount: order.takerAmount,
        });
    });

    it('disallows fills if the signer is revoked', async () => {
        const order = getTestRfqOrder({ maker: contractWallet.address });
        const sig = await order.getSignatureWithProviderAsync(
            contractWalletSigner,
            SignatureType.EthSign,
        );

        // covers taker
        await testUtils.prepareBalancesForOrdersAsync([order]);
        // need to provide contract wallet with a balance
        await makerToken.mint(contractWallet.address, order.makerAmount);

        // first allow signer
        await contractWallet.connect(contractWalletOwner)
            .registerAllowedOrderSigner(contractWalletSigner.address, true);

        // then disallow signer
        await contractWallet.connect(contractWalletOwner)
            .registerAllowedOrderSigner(contractWalletSigner.address, false);

        const tx = zeroEx.connect(taker).fillRfqOrder(order, sig, order.takerAmount, false);
        await validateError(tx,
            "orderNotSignedByMakerError",
            [
                order.getHash(),
                contractWalletSigner.address,
                order.maker,
            ]
        )
    });

    it(`doesn't allow fills with an unapproved signer`, async () => {
        const order = getTestRfqOrder({ maker: contractWallet.address });
        const sig = await order.getSignatureWithProviderAsync(maker, SignatureType.EthSign);

        // covers taker
        await testUtils.prepareBalancesForOrdersAsync([order]);
        // need to provide contract wallet with a balance
        await makerToken.mint(contractWallet.address, order.makerAmount);

        const tx = zeroEx.connect(taker).fillRfqOrder(order, sig, order.takerAmount, false);
        await validateError(tx,
            "orderNotSignedByMakerError",
            [order.getHash(), maker.address, order.maker])
    });

    it(`allows an approved signer to cancel an RFQ order`, async () => {
        const order = getTestRfqOrder({ maker: contractWallet.address });

        await contractWallet.connect(contractWalletOwner)
            .registerAllowedOrderSigner(contractWalletSigner.address, true);

        const tx = await zeroEx.connect(contractWalletSigner)
            .cancelRfqOrder(order);
        const receipt = await tx.wait()
        verifyLogs(
            receipt.logs,
            [{
                maker: contractWallet.address,
                orderHash: order.getHash(),
                indexed: ['orderHash', 'maker'],
                indexedTypes: ['bytes32', 'address'],
            }],
            IZeroExEvents.OrderCancelled,
        );

        const info = await zeroEx.getRfqOrderInfo(order);
        assertOrderInfoEquals(info, {
            status: OrderStatus.Cancelled,
            orderHash: order.getHash(),
            takerTokenFilledAmount: BigNumber.from(0),
        });
    });

    it(`allows an approved signer to cancel a limit order`, async () => {
        const order = getTestLimitOrder({ maker: contractWallet.address });

        await contractWallet.connect(contractWalletOwner)
            .registerAllowedOrderSigner(contractWalletSigner.address, true);

        const tx = await zeroEx.connect(contractWalletSigner)
            .cancelLimitOrder(order);
        const receipt = await tx.wait()
        verifyLogs(
            receipt.logs,
            [{
                maker: contractWallet.address,
                orderHash: order.getHash(),
                indexed: ['orderHash', 'maker'],
                indexedTypes: ['bytes32', 'address'],
            }],
            IZeroExEvents.OrderCancelled,
        );

        const info = await zeroEx.getLimitOrderInfo(order);
        assertOrderInfoEquals(info, {
            status: OrderStatus.Cancelled,
            orderHash: order.getHash(),
            takerTokenFilledAmount: BigNumber.from(0),
        });
    });

    it(`doesn't allow an unapproved signer to cancel an RFQ order`, async () => {
        const order = getTestRfqOrder({ maker: contractWallet.address });

        const tx = zeroEx.connect(maker).cancelRfqOrder(order);

        await validateError(tx,
            "onlyOrderMakerAllowed",
            [order.getHash(), maker.address, order.maker])
    });

    it(`doesn't allow an unapproved signer to cancel a limit order`, async () => {
        const order = getTestLimitOrder({ maker: contractWallet.address });

        const tx = zeroEx.connect(maker).cancelLimitOrder(order);

        await validateError(tx,
            "onlyOrderMakerAllowed",
            [order.getHash(), maker.address, order.maker])
    });

    it(`allows a signer to cancel pair RFQ orders`, async () => {
        const order = getTestRfqOrder({ maker: contractWallet.address, salt: BigNumber.from(1) });

        await contractWallet.connect(contractWalletOwner)
            .registerAllowedOrderSigner(contractWalletSigner.address, true);

        // Cancel salts <= the order's
        const minValidSalt = order.salt.add(1);

        const tx = await zeroEx.connect(contractWalletSigner)
            .cancelPairRfqOrdersWithSigner(
                contractWallet.address,
                makerToken.address,
                takerToken.address,
                minValidSalt,
            );
        const receipt = await tx.wait()
        verifyLogs(
            receipt.logs,
            [
                {
                    maker: contractWallet.address,
                    makerToken: makerToken.address,
                    takerToken: takerToken.address,
                    minValidSalt,
                    indexed: ['maker', 'makerToken', 'takerToken'],
                    indexedTypes: ['address', 'address', 'address'],
                },
            ],
            IZeroExEvents.PairCancelledRfqOrders,
        );

        const info = await zeroEx.getRfqOrderInfo(order);

        assertOrderInfoEquals(info, {
            status: OrderStatus.Cancelled,
            orderHash: order.getHash(),
            takerTokenFilledAmount: BigNumber.from(0),
        });
    });

    it(`doesn't allow an unapproved signer to cancel pair RFQ orders`, async () => {
        const minValidSalt = BigNumber.from(2);

        const tx = zeroEx.connect(maker)
            .cancelPairRfqOrdersWithSigner(
                contractWallet.address,
                makerToken.address,
                takerToken.address,
                minValidSalt,
            );

        await validateError(tx,
            "invalidSigner",
            [contractWallet.address, maker.address]
        )
    });

    it(`allows a signer to cancel pair limit orders`, async () => {
        const order = getTestLimitOrder({ maker: contractWallet.address, salt: BigNumber.from(1) });

        await contractWallet.connect(contractWalletOwner)
            .registerAllowedOrderSigner(contractWalletSigner.address, true);

        // Cancel salts <= the order's
        const minValidSalt = order.salt.add(1);

        const tx = await zeroEx.connect(contractWalletSigner)
            .cancelPairLimitOrdersWithSigner(
                contractWallet.address,
                makerToken.address,
                takerToken.address,
                minValidSalt,
            )
        const receipt = await tx.wait();
        verifyLogs(
            receipt.logs,
            [
                {
                    maker: contractWallet.address,
                    makerToken: makerToken.address,
                    takerToken: takerToken.address,
                    minValidSalt,
                    indexed: ['maker', 'makerToken', 'takerToken'],
                    indexedTypes: ['address', 'address', 'address'],
                },
            ],
            IZeroExEvents.PairCancelledLimitOrders,
        );

        const info = await zeroEx.getLimitOrderInfo(order);

        assertOrderInfoEquals(info, {
            status: OrderStatus.Cancelled,
            orderHash: order.getHash(),
            takerTokenFilledAmount: BigNumber.from(0),
        });
    });

    it(`doesn't allow an unapproved signer to cancel pair limit orders`, async () => {
        const minValidSalt = BigNumber.from(2);

        const tx = zeroEx.connect(maker)
            .cancelPairLimitOrdersWithSigner(
                contractWallet.address,
                makerToken.address,
                takerToken.address,
                minValidSalt,
            );

        await validateError(tx,
            "invalidSigner",
            [contractWallet.address, maker.address])
    });

    it(`allows a signer to cancel multiple RFQ order pairs`, async () => {
        const orders = [
            getTestRfqOrder({ maker: contractWallet.address, salt: BigNumber.from(1) }),
            // Flip the tokens for the other order.
            getTestRfqOrder({
                makerToken: takerToken.address,
                takerToken: makerToken.address,
                maker: contractWallet.address,
                salt: BigNumber.from(1),
            }),
        ];

        await contractWallet.connect(contractWalletOwner)
            .registerAllowedOrderSigner(contractWalletSigner.address, true);

        const minValidSalt = BigNumber.from(2);
        const tx = await zeroEx.connect(contractWalletSigner)
            .batchCancelPairRfqOrdersWithSigner(
                contractWallet.address,
                [makerToken.address, takerToken.address],
                [takerToken.address, makerToken.address],
                [minValidSalt, minValidSalt],
            );
        const receipt = await tx.wait();
        verifyLogs(
            receipt.logs,
            [
                {
                    maker: contractWallet.address,
                    makerToken: makerToken.address,
                    takerToken: takerToken.address,
                    minValidSalt,
                    indexed: ['maker', 'makerToken', 'takerToken'],
                    indexedTypes: ['address', 'address', 'address'],
                },
                {
                    maker: contractWallet.address,
                    makerToken: takerToken.address,
                    takerToken: makerToken.address,
                    minValidSalt,
                    indexed: ['maker', 'makerToken', 'takerToken'],
                    indexedTypes: ['address', 'address', 'address'],
                },
            ],
            IZeroExEvents.PairCancelledRfqOrders,
        );
        const statuses = (await Promise.all(orders.map(o => zeroEx.getRfqOrderInfo(o)))).map(
            oi => oi.status,
        );
        expect(statuses).to.deep.eq([OrderStatus.Cancelled, OrderStatus.Cancelled]);
    });

    it(`doesn't allow an unapproved signer to batch cancel pair rfq orders`, async () => {
        const minValidSalt = BigNumber.from(2);

        const tx = zeroEx.connect(maker)
            .batchCancelPairRfqOrdersWithSigner(
                contractWallet.address,
                [makerToken.address, takerToken.address],
                [takerToken.address, makerToken.address],
                [minValidSalt, minValidSalt],
            );

        await validateError(tx,
            "invalidSigner",
            [contractWallet.address, maker.address]
        )
    });

    it(`allows a signer to cancel multiple limit order pairs`, async () => {
        const orders = [
            getTestLimitOrder({ maker: contractWallet.address, salt: BigNumber.from(1) }),
            // Flip the tokens for the other order.
            getTestLimitOrder({
                makerToken: takerToken.address,
                takerToken: makerToken.address,
                maker: contractWallet.address,
                salt: BigNumber.from(1),
            }),
        ];

        await contractWallet.connect(contractWalletOwner)
            .registerAllowedOrderSigner(contractWalletSigner.address, true);

        const minValidSalt = BigNumber.from(2);
        const tx = await zeroEx.connect(contractWalletSigner)
            .batchCancelPairLimitOrdersWithSigner(
                contractWallet.address,
                [makerToken.address, takerToken.address],
                [takerToken.address, makerToken.address],
                [minValidSalt, minValidSalt],
            );
        const receipt = await tx.wait();
        verifyLogs(
            receipt.logs,
            [
                {
                    maker: contractWallet.address,
                    makerToken: makerToken.address,
                    takerToken: takerToken.address,
                    minValidSalt,
                    indexed: ['maker', 'makerToken', 'takerToken'],
                    indexedTypes: ['address', 'address', 'address'],
                },
                {
                    maker: contractWallet.address,
                    makerToken: takerToken.address,
                    takerToken: makerToken.address,
                    minValidSalt,
                    indexed: ['maker', 'makerToken', 'takerToken'],
                    indexedTypes: ['address', 'address', 'address'],
                },
            ],
            IZeroExEvents.PairCancelledLimitOrders,
        );
        const statuses = (await Promise.all(orders.map(o => zeroEx.getLimitOrderInfo(o)))).map(
            oi => oi.status,
        );
        expect(statuses).to.deep.eq([OrderStatus.Cancelled, OrderStatus.Cancelled]);
    });

    it(`doesn't allow an unapproved signer to batch cancel pair limit orders`, async () => {
        const minValidSalt = BigNumber.from(2);

        const tx = zeroEx.connect(maker)
            .batchCancelPairLimitOrdersWithSigner(
                contractWallet.address,
                [makerToken.address, takerToken.address],
                [takerToken.address, makerToken.address],
                [minValidSalt, minValidSalt],
            );

        await validateError(tx,
            "invalidSigner",
            [contractWallet.address, maker.address]
        )
    });
});

