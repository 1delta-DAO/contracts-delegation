import { constants } from '@0x/contracts-test-utils';
import { MAX_UINT256, OrderEvents, OrderStatus, OtcOrder } from './utils/constants';
import {
    assertOtcOrderInfoEquals,
    computeOtcOrderFilledAmounts,
    createCleanExpiry,
    createExpiry,
    getRandomOtcOrder,
    NativeOrdersTestEnvironment,
} from './utils/orders';
import {
    ERC20Mock__factory,
    MockERC20,
    MockERC20__factory,
    NativeOrders,
    TestOrderSignerRegistryWithContractWallet,
    TestOrderSignerRegistryWithContractWallet__factory,
    WETH9,
    WETH9__factory
} from '../../../types';
import { ethers, waffle } from 'hardhat';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { MockProvider } from 'ethereum-waffle';
import { createNativeOrder } from './utils/orderFixture';
import { BigNumber } from 'ethers';
import { expect } from '../shared/expect'
import { time } from '@nomicfoundation/hardhat-network-helpers';
import { validateError, verifyLogs } from './utils/utils';
import { SignatureType } from './utils/signature_utils';

const { NULL_ADDRESS } = constants;
const ZERO = BigNumber.from(0)
const ETH_TOKEN_ADDRESS = '0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
const PROTOCOL_FEE_MULTIPLIER = 1337e3;
let GAS_PRICE: BigNumber
let maker: SignerWithAddress;
let taker: SignerWithAddress;
let notMaker: SignerWithAddress;
let notTaker: SignerWithAddress;
let collector: SignerWithAddress;
let contractWalletOwner: SignerWithAddress;
let contractWalletSigner: SignerWithAddress;
let txOrigin: SignerWithAddress;
let owner: SignerWithAddress;
let notTxOrigin: SignerWithAddress;
let oneDeltaOrders: NativeOrders;
let verifyingContract: string;
let makerToken: MockERC20;
let takerToken: MockERC20;
let wethToken: WETH9;
let contractWallet: TestOrderSignerRegistryWithContractWallet;
let testUtils: NativeOrdersTestEnvironment;
let provider: MockProvider;
let chainId: number
before(async () => {
    [owner, maker, taker, notMaker, notTaker, contractWalletOwner, contractWalletSigner, txOrigin, notTxOrigin, collector] =
        await ethers.getSigners()

    makerToken = await new MockERC20__factory(owner).deploy("Maker", 'M', 18)
    takerToken = await new MockERC20__factory(owner).deploy("Taker", "T", 6)
    wethToken = await new WETH9__factory(owner).deploy()

    oneDeltaOrders = await createNativeOrder(
        owner,
        collector.address,
        BigNumber.from(PROTOCOL_FEE_MULTIPLIER),
        wethToken.address
    );
    verifyingContract = oneDeltaOrders.address;
    provider = waffle.provider
    chainId = await maker.getChainId()
    console.log("ChainId", chainId, 'maker', maker.address, "taker", taker.address)
    console.log('makerToken', makerToken.address, "takerToken", takerToken.address)

    await Promise.all([
        makerToken.connect(maker).approve(oneDeltaOrders.address, MAX_UINT256),
        makerToken.connect(notMaker).approve(oneDeltaOrders.address, MAX_UINT256),
        takerToken.connect(taker).approve(oneDeltaOrders.address, MAX_UINT256),
        takerToken.connect(notTaker).approve(oneDeltaOrders.address, MAX_UINT256),
        wethToken.connect(maker).approve(oneDeltaOrders.address, MAX_UINT256),
        wethToken.connect(notMaker).approve(oneDeltaOrders.address, MAX_UINT256),
        wethToken.connect(taker).approve(oneDeltaOrders.address, MAX_UINT256),
        wethToken.connect(notTaker).approve(oneDeltaOrders.address, MAX_UINT256),
    ]);

    // contract wallet for signer delegation
    contractWallet = await new TestOrderSignerRegistryWithContractWallet__factory(contractWalletOwner).deploy(oneDeltaOrders.address)

    await contractWallet.connect(contractWalletOwner)
        .approveERC20(makerToken.address, oneDeltaOrders.address, MAX_UINT256);
    await contractWallet.connect(contractWalletOwner)
        .approveERC20(takerToken.address, oneDeltaOrders.address, MAX_UINT256);

    GAS_PRICE = await provider.getGasPrice()
    testUtils = new NativeOrdersTestEnvironment(maker, taker, makerToken, takerToken, oneDeltaOrders, GAS_PRICE, ZERO);
});

function getTestOtcOrder(fields: Partial<OtcOrder> = {}): OtcOrder {
    return getRandomOtcOrder({
        maker: maker.address,
        verifyingContract,
        chainId,
        takerToken: takerToken.address,
        makerToken: makerToken.address,
        taker: NULL_ADDRESS,
        txOrigin: taker.address,
        ...fields,
    });
}

describe('getOtcOrderHash()', () => {
    it('returns the correct hash', async () => {
        const order = getTestOtcOrder();
        const hash = await oneDeltaOrders.getOtcOrderHash(order);
        expect(hash).to.eq(order.getHash());
    });
});

describe('lastOtcTxOriginNonce()', () => {
    it('returns 0 if bucket is unused', async () => {
        const nonce = await oneDeltaOrders.lastOtcTxOriginNonce(taker.address, ZERO);
        expect(nonce.toString()).to.eq('0');
    });
    it('returns the last nonce used in a bucket', async () => {
        const order = getTestOtcOrder();
        await testUtils.fillOtcOrderAsync(order);
        const nonce = await oneDeltaOrders.lastOtcTxOriginNonce(taker.address, order.nonceBucket);
        expect(nonce.toString()).to.eq(order.nonce.toString());
    });
});

describe('getOtcOrderInfo()', () => {
    it('unfilled order', async () => {
        const order = getTestOtcOrder();
        const info = await oneDeltaOrders.getOtcOrderInfo(order);
        assertOtcOrderInfoEquals(info, {
            status: OrderStatus.Fillable,
            orderHash: order.getHash(),
        });
    });

    it('unfilled expired order', async () => {
        const expiry = await createCleanExpiry(provider, -60);
        const order = getTestOtcOrder({ expiry });
        const info = await oneDeltaOrders.getOtcOrderInfo(order);
        assertOtcOrderInfoEquals(info, {
            status: OrderStatus.Expired,
            orderHash: order.getHash(),
        });
    });

    it('filled then expired order', async () => {
        const expiry = await createCleanExpiry(provider, 60);
        const order = getTestOtcOrder({ expiry });
        await testUtils.fillOtcOrderAsync(order);
        // Advance time to expire the order.
        // await env.web3Wrapper.increaseTimeAsync(61);
        await time.increase(61)
        const info = await oneDeltaOrders.getOtcOrderInfo(order);
        assertOtcOrderInfoEquals(info, {
            status: OrderStatus.Invalid,
            orderHash: order.getHash(),
        });
    });

    it('filled order', async () => {
        const order = getTestOtcOrder();
        // Fill the order first.
        await testUtils.fillOtcOrderAsync(order);
        const info = await oneDeltaOrders.getOtcOrderInfo(order);
        assertOtcOrderInfoEquals(info, {
            status: OrderStatus.Invalid,
            orderHash: order.getHash(),
        });
    });
});


const getTokenBalance = async (token: string, user: string, tag: string | number | undefined = undefined) => {
    const tokenContract = await new ERC20Mock__factory(owner).attach(token)
    if (tag) {
        return await tokenContract.balanceOf(user, { blockTag: tag })
    }
    return await tokenContract.balanceOf(user)
}

const getMakerTakerBalances = async (order: OtcOrder) => {
    const makerBalance = await getTokenBalance(
        order.takerToken,
        order.maker
    );
    const takerBalance = await getTokenBalance(
        order.makerToken,
        order.taker !== NULL_ADDRESS ? order.taker : taker.address
    );

    return [makerBalance, takerBalance]
}

const validateMakerTakerBalances = (
    order: OtcOrder,
    makerBalanceBefore: BigNumber,
    takerBalanceBefore: BigNumber,
    makerBalance: BigNumber,
    takerBalance: BigNumber,
    takerTokenFillAmount?: BigNumber) => {
    const { makerTokenFilledAmount, takerTokenFilledAmount } = computeOtcOrderFilledAmounts(
        order,
        takerTokenFillAmount,
    );
    expect(makerBalance.sub(makerBalanceBefore).toString(), 'maker balance').to.eq(takerTokenFilledAmount.toString());
    expect(takerBalance.sub(takerBalanceBefore).toString(), 'taker balance').to.eq(makerTokenFilledAmount.toString());
}

describe('fillOtcOrder()', () => {
    it('can fully fill an order', async () => {
        const order = getTestOtcOrder();
        const [makerBalanceBefore, takerBalanceBefore] = await getMakerTakerBalances(order);
        const tx = await testUtils.fillOtcOrderAsync(order);
        const receipt = await tx.wait()
        verifyLogs(
            receipt.logs,
            [testUtils.createOtcOrderFilledEventArgs(order)],
            OrderEvents.OtcOrderFilled,
        );
        const [makerBalance, takerBalance] = await getMakerTakerBalances(order);

        validateMakerTakerBalances(
            order,
            makerBalanceBefore,
            takerBalanceBefore,
            makerBalance,
            takerBalance
        )
    });

    it('can partially fill an order', async () => {
        const order = getTestOtcOrder();
        const [makerBalanceBefore, takerBalanceBefore] = await getMakerTakerBalances(order);
        const fillAmount = order.takerAmount.sub(1);
        const tx = await testUtils.fillOtcOrderAsync(order, fillAmount);
        const receipt = await tx.wait()
        verifyLogs(
            receipt.logs,
            [testUtils.createOtcOrderFilledEventArgs(order, fillAmount)],
            OrderEvents.OtcOrderFilled,
        );

        const [makerBalance, takerBalance] = await getMakerTakerBalances(order);
        validateMakerTakerBalances(
            order,
            makerBalanceBefore,
            takerBalanceBefore,
            makerBalance,
            takerBalance,
            fillAmount
        )
    });

    it('clamps fill amount to remaining available', async () => {
        const order = getTestOtcOrder();
        const [makerBalanceBefore, takerBalanceBefore] = await getMakerTakerBalances(order);
        const fillAmount = order.takerAmount.add(1);
        const tx = await testUtils.fillOtcOrderAsync(order, fillAmount);
        const receipt = await tx.wait()
        verifyLogs(
            receipt.logs,
            [testUtils.createOtcOrderFilledEventArgs(order, fillAmount)],
            OrderEvents.OtcOrderFilled,
        );
        const [makerBalance, takerBalance] = await getMakerTakerBalances(order);
        validateMakerTakerBalances(
            order,
            makerBalanceBefore,
            takerBalanceBefore,
            makerBalance,
            takerBalance,
            fillAmount
        )
    });

    it('cannot fill an order with wrong tx.origin', async () => {
        const order = getTestOtcOrder();
        const tx = testUtils.fillOtcOrderAsync(order, order.takerAmount, notTaker);
        await validateError(tx,
            'orderNotFillableByOriginError',
            [order.getHash(), notTaker.address, taker.address]
        )
    });

    it('cannot fill an order with wrong taker', async () => {
        const order = getTestOtcOrder({ taker: notTaker.address });
        const tx = testUtils.fillOtcOrderAsync(order);
        await validateError(
            tx,
            'orderNotFillableByTakerError',
            [order.getHash(), taker.address, notTaker.address]
        );
    });

    it('can fill an order from a different tx.origin if registered', async () => {
        const order = getTestOtcOrder();
        await oneDeltaOrders.connect(taker).registerAllowedRfqOrigins([notTaker.address], true);
        return testUtils.fillOtcOrderAsync(order, order.takerAmount, notTaker);
    });

    it('cannot fill an order with registered then unregistered tx.origin', async () => {
        const order = getTestOtcOrder();
        await oneDeltaOrders.connect(taker).registerAllowedRfqOrigins([notTaker.address], true);
        await oneDeltaOrders.connect(taker).registerAllowedRfqOrigins([notTaker.address], false);
        const tx = testUtils.fillOtcOrderAsync(order, order.takerAmount, notTaker);
        await validateError(
            tx,
            'orderNotFillableByOriginError',
            [order.getHash(), notTaker.address, taker.address]
        )
    });

    it('cannot fill an order with a zero tx.origin', async () => {
        const order = getTestOtcOrder({ txOrigin: NULL_ADDRESS });
        const tx = testUtils.fillOtcOrderAsync(order);
        await validateError(
            tx,
            'orderNotFillableByOriginError',
            [order.getHash(), taker.address, NULL_ADDRESS]
        )
    });

    it('cannot fill an expired order', async () => {
        const order = getTestOtcOrder({ expiry: createExpiry(-60) });
        const tx = testUtils.fillOtcOrderAsync(order);
        await validateError(
            tx,
            'orderNotFillableError',
            [order.getHash(), OrderStatus.Expired]
        )
    });

    it('cannot fill order with bad signature', async () => {
        const order = getTestOtcOrder();
        // Overwrite chainId to result in a different hash and therefore different
        // signature.
        const tx = testUtils.fillOtcOrderAsync(order.clone({ chainId: 1234 }));
        await validateError(
            tx,
            'orderNotSignedByMakerError',
            [order.getHash(), undefined, order.maker]
        )
    });

    it('fails if ETH is attached', async () => {
        const order = getTestOtcOrder();
        await testUtils.prepareBalancesForOrdersAsync([order], taker);
        const tx = oneDeltaOrders.connect(taker)
            .fillOtcOrder(
                order,
                await order.getSignatureWithProviderAsync(maker),
                order.takerAmount,
                { value: 1 } as any
            );
        // This will revert at the language level because the fill function is not payable.
        return expect(tx).to.be.reverted;
    });

    it('cannot fill the same order twice', async () => {
        const order = getTestOtcOrder();
        await testUtils.fillOtcOrderAsync(order);
        const tx = testUtils.fillOtcOrderAsync(order);
        await validateError(
            tx,
            'orderNotFillableError',
            [order.getHash(), OrderStatus.Invalid]
        )
    });

    it('cannot fill two orders with the same nonceBucket and nonce', async () => {
        const order1 = getTestOtcOrder();
        await testUtils.fillOtcOrderAsync(order1);
        const order2 = getTestOtcOrder({ nonceBucket: order1.nonceBucket, nonce: order1.nonce });
        const tx = testUtils.fillOtcOrderAsync(order2);
        await validateError(
            tx,
            'orderNotFillableError',
            [order2.getHash(), OrderStatus.Invalid]
        )
    });

    it('cannot fill an order whose nonce is less than the nonce last used in that bucket', async () => {
        const order1 = getTestOtcOrder();
        await testUtils.fillOtcOrderAsync(order1);
        const order2 = getTestOtcOrder({ nonceBucket: order1.nonceBucket, nonce: order1.nonce.sub(1) });
        const tx = testUtils.fillOtcOrderAsync(order2);
        await validateError(
            tx,
            'orderNotFillableError',
            [order2.getHash(), OrderStatus.Invalid]
        )
    });

    it('can fill two orders that use the same nonce bucket and increasing nonces', async () => {
        const order1 = getTestOtcOrder();
        const tx1 = await testUtils.fillOtcOrderAsync(order1);
        const receipt1 = await tx1.wait()
        verifyLogs(
            receipt1.logs,
            [testUtils.createOtcOrderFilledEventArgs(order1)],
            OrderEvents.OtcOrderFilled,
        );
        const order2 = getTestOtcOrder({ nonceBucket: order1.nonceBucket, nonce: order1.nonce.add(1) });
        const tx2 = await testUtils.fillOtcOrderAsync(order2);
        const receipt2 = await tx2.wait()
        verifyLogs(
            receipt2.logs,
            [testUtils.createOtcOrderFilledEventArgs(order2)],
            OrderEvents.OtcOrderFilled,
        );
    });

    it('can fill two orders that use the same nonce but different nonce buckets', async () => {
        const order1 = getTestOtcOrder();
        const tx1 = await testUtils.fillOtcOrderAsync(order1);
        const receipt1 = await tx1.wait()
        verifyLogs(
            receipt1.logs,
            [testUtils.createOtcOrderFilledEventArgs(order1)],
            OrderEvents.OtcOrderFilled,
        );
        const order2 = getTestOtcOrder({ nonce: order1.nonce });
        const tx2 = await testUtils.fillOtcOrderAsync(order2);
        const receipt2 = await tx2.wait()
        verifyLogs(
            receipt2.logs,
            [testUtils.createOtcOrderFilledEventArgs(order2)],
            OrderEvents.OtcOrderFilled,
        );
    });

    it('can fill a WETH buy order and receive ETH', async () => {
        const takerEthBalanceBefore = await provider.getBalance(taker.address);
        const order = getTestOtcOrder({ makerToken: wethToken.address, makerAmount: BigNumber.from(10).pow(18) });
        await wethToken.connect(maker).deposit({ value: order.makerAmount });
        const tx = await testUtils.fillOtcOrderAsync(order, order.takerAmount, taker, true);
        const receipt = await tx.wait()
        const totalCost = testUtils.gasPrice.mul(receipt.gasUsed);
        verifyLogs(
            receipt.logs,
            [testUtils.createOtcOrderFilledEventArgs(order)],
            OrderEvents.OtcOrderFilled,
        );
        const takerEthBalanceAfter = await provider.getBalance(taker.address);
        expect(takerEthBalanceAfter.add(totalCost).sub(takerEthBalanceBefore).toString()).to.equal(order.makerAmount.toString());
    });

    it('reverts if `unwrapWeth` is true but maker token is not WETH', async () => {
        const order = getTestOtcOrder();
        const tx = testUtils.fillOtcOrderAsync(order, order.takerAmount, taker, true);
        return expect(tx).to.be.reverted // .revertWith('OtcOrdersFeature::fillOtcOrderForEth/MAKER_TOKEN_NOT_WETH');
    });

    it('allows for fills on orders signed by a approved signer', async () => {
        const order = getTestOtcOrder({ maker: contractWallet.address });
        const sig = await order.getSignatureWithProviderAsync(
            contractWalletSigner,
            SignatureType.EthSign,
        );
        // covers taker
        await testUtils.prepareBalancesForOrdersAsync([order]);
        // need to provide contract wallet with a balance
        await makerToken.mint(contractWallet.address, order.makerAmount);

        const makerBalanceBefore = await takerToken.balanceOf(order.maker)
        const takerBalanceBefore = await makerToken.balanceOf(order.taker !== NULL_ADDRESS ? order.taker : taker.address)
        // allow signer
        await contractWallet.connect(contractWalletOwner)
            .registerAllowedOrderSigner(contractWalletSigner.address, true);
        // fill should succeed
        const tx = await oneDeltaOrders.connect(taker)
            .fillOtcOrder(order, sig, order.takerAmount);
        const receipt = await tx.wait()
        verifyLogs(
            receipt.logs,
            [testUtils.createOtcOrderFilledEventArgs(order)],
            OrderEvents.OtcOrderFilled,
        );
        const [makerBalance, takerBalance] = await getMakerTakerBalances(order);
        validateMakerTakerBalances(
            order,
            makerBalanceBefore,
            takerBalanceBefore,
            makerBalance,
            takerBalance,
        )
    });

    it('disallows fills if the signer is revoked', async () => {
        const order = getTestOtcOrder({ maker: contractWallet.address });
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
        // fill should revert
        const tx = oneDeltaOrders.connect(taker)
            .fillOtcOrder(order, sig, order.takerAmount);

        await validateError(
            tx,
            'orderNotSignedByMakerError',
            [
                order.getHash(),
                contractWalletSigner.address,
                order.maker,]
        )
    });

    it(`doesn't allow fills with an unapproved signer`, async () => {
        const order = getTestOtcOrder({ maker: contractWallet.address });
        const sig = await order.getSignatureWithProviderAsync(maker, SignatureType.EthSign);
        // covers taker
        await testUtils.prepareBalancesForOrdersAsync([order]);
        // need to provide contract wallet with a balance
        await makerToken.mint(contractWallet.address, order.makerAmount);
        // fill should revert
        const tx = oneDeltaOrders.connect(taker).fillOtcOrder(order, sig, order.takerAmount);
        await validateError(
            tx,
            'orderNotSignedByMakerError',
            [
                order.getHash(),
                maker.address,
                order.maker,
            ]
        )
    });
});

describe('fillOtcOrderWithEth()', () => {
    it('Can fill an order with ETH (takerToken=WETH)', async () => {
        const order = getTestOtcOrder({ takerToken: wethToken.address });
        const [makerBalanceBefore, takerBalanceBefore] = await getMakerTakerBalances(order);
        const tx = await testUtils.fillOtcOrderWithEthAsync(order);
        const receipt = await tx.wait()
        verifyLogs(
            receipt.logs,
            [testUtils.createOtcOrderFilledEventArgs(order)],
            OrderEvents.OtcOrderFilled,
        );

        const [makerBalance, takerBalance] = await getMakerTakerBalances(order);

        validateMakerTakerBalances(
            order,
            makerBalanceBefore,
            takerBalanceBefore,
            makerBalance,
            takerBalance
        )
    });
    it('Can fill an order with ETH (takerToken=ETH)', async () => {
        const order = getTestOtcOrder({ takerToken: ETH_TOKEN_ADDRESS, taker: taker.address });
        const makerEthBalanceBefore = await provider.getBalance(maker.address);
        const takerBalanceBefore = await getTokenBalance(order.makerToken, taker.address);
        const tx = await testUtils.fillOtcOrderWithEthAsync(order);
        const receipt = await tx.wait()
        verifyLogs(
            receipt.logs,
            [testUtils.createOtcOrderFilledEventArgs(order)],
            OrderEvents.OtcOrderFilled,
        );
        const takerBalance = await getTokenBalance(order.makerToken, taker.address);
        expect(takerBalance.sub(takerBalanceBefore).toString(), 'taker balance').to.eq(order.makerAmount.toString());
        const makerEthBalanceAfter = await provider.getBalance(maker.address);
        expect(
            makerEthBalanceAfter.sub(makerEthBalanceBefore).toString(),
            'maker balance'
        ).to.equal(
            order.takerAmount.toString(),
        );
    });
    it('Can partially fill an order with ETH (takerToken=WETH)', async () => {
        const order = getTestOtcOrder({ takerToken: wethToken.address });
        const fillAmount = order.takerAmount.sub(1);

        const [makerBalanceBefore, takerBalanceBefore] = await getMakerTakerBalances(order);

        const tx = await testUtils.fillOtcOrderWithEthAsync(order, fillAmount);
        const receipt = await tx.wait()
        verifyLogs(
            receipt.logs,
            [testUtils.createOtcOrderFilledEventArgs(order, fillAmount)],
            OrderEvents.OtcOrderFilled,
        );

        const [makerBalance, takerBalance] = await getMakerTakerBalances(order);

        validateMakerTakerBalances(
            order,
            makerBalanceBefore,
            takerBalanceBefore,
            makerBalance,
            takerBalance,
            fillAmount
        )

    });
    it('Can partially fill an order with ETH (takerToken=ETH)', async () => {
        const order = getTestOtcOrder({ takerToken: ETH_TOKEN_ADDRESS });
        const fillAmount = order.takerAmount.sub(1);
        const makerEthBalanceBefore = await provider.getBalance(maker.address);
        const takerBalanceBefore = await getTokenBalance(order.makerToken, taker.address);
        const tx = await testUtils.fillOtcOrderWithEthAsync(order, fillAmount);
        const receipt = await tx.wait()
        verifyLogs(
            receipt.logs,
            [testUtils.createOtcOrderFilledEventArgs(order, fillAmount)],
            OrderEvents.OtcOrderFilled,
        );
        const { makerTokenFilledAmount, takerTokenFilledAmount } = computeOtcOrderFilledAmounts(order, fillAmount);
        const takerBalance = await getTokenBalance(order.makerToken, taker.address);
        expect(takerBalance.sub(takerBalanceBefore).toString(), 'taker balance').to.eq(makerTokenFilledAmount);
        const makerEthBalanceAfter = await provider.getBalance(maker.address);
        expect(makerEthBalanceAfter.sub(makerEthBalanceBefore).toString(), 'maker balance').to.equal(
            takerTokenFilledAmount.toString(),
        );
    });
    it('Can refund excess ETH is msg.value > order.takerAmount (takerToken=WETH)', async () => {
        const order = getTestOtcOrder({ takerToken: wethToken.address });

        const [makerBalanceBefore, takerBalanceBefore] = await getMakerTakerBalances(order);

        const fillAmount = order.takerAmount.add(420);
        const tx = await testUtils.fillOtcOrderWithEthAsync(order, fillAmount);
        const receipt = await tx.wait()
        const takerEthBalanceBefore = await provider.getBalance(taker.address, receipt.blockNumber - 1);
        verifyLogs(
            receipt.logs,
            [testUtils.createOtcOrderFilledEventArgs(order)],
            OrderEvents.OtcOrderFilled,
        );
        const totalCost = GAS_PRICE.mul(receipt.gasUsed);
        const takerEthBalanceAfter = await provider.getBalance(taker.address);
        expect(takerEthBalanceBefore.sub(totalCost).sub(takerEthBalanceAfter).toString()).to.equal(order.takerAmount.toString());

        const [makerBalance, takerBalance] = await getMakerTakerBalances(order);

        validateMakerTakerBalances(
            order,
            makerBalanceBefore,
            takerBalanceBefore,
            makerBalance,
            takerBalance
        )

    });
    it('Can refund excess ETH is msg.value > order.takerAmount (takerToken=ETH)', async () => {
        const order = getTestOtcOrder({ takerToken: ETH_TOKEN_ADDRESS });
        const fillAmount = order.takerAmount.add(420);
        const takerEthBalanceBefore = await provider.getBalance(taker.address);
        const makerEthBalanceBefore = await provider.getBalance(maker.address);
        const tx = await testUtils.fillOtcOrderWithEthAsync(order, fillAmount);
        const receipt = await tx.wait()
        verifyLogs(
            receipt.logs,
            [testUtils.createOtcOrderFilledEventArgs(order)],
            OrderEvents.OtcOrderFilled,
        );
        const takerEthBalanceAfter = await provider.getBalance(taker.address);
        const totalCost = GAS_PRICE.mul(receipt.gasUsed);
        expect(takerEthBalanceBefore.sub(totalCost).sub(takerEthBalanceAfter).toString(), 'taker eth balance').to.equal(
            order.takerAmount.toString(),
        );
        const takerBalanceBefore = await getTokenBalance(order.makerToken, taker.address, receipt.blockNumber - 1);
        const takerBalance = await getTokenBalance(order.makerToken, taker.address);
        expect(takerBalance.sub(takerBalanceBefore).toString(), 'taker balance').to.eq(order.makerAmount.toString());
        const makerEthBalanceAfter = await provider.getBalance(maker.address);
        expect(makerEthBalanceAfter.sub(makerEthBalanceBefore).toString(), 'maker balance').to.equal(
            order.takerAmount.toString(),
        );
    });
    it('Cannot fill an order if taker token is not ETH or WETH', async () => {
        const order = getTestOtcOrder();
        const tx = testUtils.fillOtcOrderWithEthAsync(order);
        return expect(tx).to.reverted; // With('OtcOrdersFeature::fillOtcOrderWithEth/INVALID_TAKER_TOKEN');
    });
});

describe('fillTakerSignedOtcOrder()', () => {
    it('can fully fill an order', async () => {
        const order = getTestOtcOrder({ taker: taker.address, txOrigin: txOrigin.address });
        const [makerBalanceBefore, takerBalanceBefore] = await getMakerTakerBalances(order);
        const tx = await testUtils.fillTakerSignedOtcOrderAsync(order, txOrigin.address, taker);
        const receipt = await tx.wait()
        verifyLogs(
            receipt.logs,
            [testUtils.createOtcOrderFilledEventArgs(order)],
            OrderEvents.OtcOrderFilled,
        );

        const [makerBalance, takerBalance] = await getMakerTakerBalances(order);
        validateMakerTakerBalances(
            order,
            makerBalanceBefore,
            takerBalanceBefore,
            makerBalance,
            takerBalance
        )
    });

    it('cannot fill an order with wrong tx.origin', async () => {
        const order = getTestOtcOrder({ taker: taker.address, txOrigin: txOrigin.address });
        const tx = testUtils.fillTakerSignedOtcOrderAsync(order, notTxOrigin.address, taker);
        await validateError(tx,
            'orderNotFillableByOriginError',
            [order.getHash(), notTxOrigin.address, txOrigin.address]
        )
    });

    it('can fill an order from a different tx.origin if registered', async () => {
        const order = getTestOtcOrder({ taker: taker.address, txOrigin: txOrigin.address });
        await oneDeltaOrders.connect(txOrigin)
            .registerAllowedRfqOrigins([notTxOrigin.address], true);
        return testUtils.fillTakerSignedOtcOrderAsync(order, notTxOrigin.address, taker);
    });

    it('cannot fill an order with registered then unregistered tx.origin', async () => {
        const order = getTestOtcOrder({ taker: taker.address, txOrigin: txOrigin.address });
        await oneDeltaOrders.connect(txOrigin)
            .registerAllowedRfqOrigins([notTxOrigin.address], true);
        await oneDeltaOrders.connect(txOrigin)
            .registerAllowedRfqOrigins([notTxOrigin.address], false);
        const tx = testUtils.fillTakerSignedOtcOrderAsync(order, notTxOrigin.address, taker);
        await validateError(tx,
            'orderNotFillableByOriginError',
            [order.getHash(), notTxOrigin.address, txOrigin.address]
        )
    });

    it('cannot fill an order with a zero tx.origin', async () => {
        const order = getTestOtcOrder({ taker: taker.address, txOrigin: NULL_ADDRESS });
        const tx = testUtils.fillTakerSignedOtcOrderAsync(order, txOrigin.address, taker);

        await validateError(tx,
            'orderNotFillableByOriginError',
            [order.getHash(), txOrigin.address, NULL_ADDRESS]
        )
    });

    it('cannot fill an expired order', async () => {
        const order = getTestOtcOrder({ taker: taker.address, txOrigin: txOrigin.address, expiry: await createCleanExpiry(provider, -60) });
        const tx = testUtils.fillTakerSignedOtcOrderAsync(order, txOrigin.address, taker);

        await validateError(
            tx,
            'orderNotFillableError',
            [order.getHash(), OrderStatus.Expired]
        )
    });

    it('cannot fill an order with bad taker signature', async () => {
        const order = getTestOtcOrder({ taker: taker.address, txOrigin: txOrigin.address });
        const tx = testUtils.fillTakerSignedOtcOrderAsync(order, txOrigin.address, notTaker);
        await validateError(
            tx,
            'orderNotFillableByTakerError',
            [order.getHash(), notTaker.address, taker.address]
        );
    });

    it('cannot fill order with bad maker signature', async () => {
        const order = getTestOtcOrder({ taker: taker.address, txOrigin: txOrigin.address });
        const anotherOrder = getTestOtcOrder({ taker: taker.address, txOrigin: txOrigin.address });
        await testUtils.prepareBalancesForOrdersAsync([order], taker);
        const tx = oneDeltaOrders.connect(txOrigin)
            .fillTakerSignedOtcOrder(
                order,
                await anotherOrder.getSignatureWithProviderAsync(await ethers.getSigner(anotherOrder.maker)),
                await order.getSignatureWithProviderAsync(taker, SignatureType.EthSign),
            );
        await validateError(
            tx,
            'orderNotSignedByMakerError',
            [order.getHash(), undefined, order.maker]
        )
    });

    it('fails if ETH is attached', async () => {
        const order = getTestOtcOrder({ taker: taker.address, txOrigin: txOrigin.address });
        await testUtils.prepareBalancesForOrdersAsync([order], taker);
        const tx = oneDeltaOrders.connect(txOrigin)
            .fillTakerSignedOtcOrder(
                order,
                await order.getSignatureWithProviderAsync(await ethers.getSigner(order.maker)),
                await order.getSignatureWithProviderAsync(taker, SignatureType.EthSign),
                { value: 1 } as any
            );
        // This will revert at the language level because the fill function is not payable.
        return expect(tx).to.be.reverted // ('revert');
    });

    it('cannot fill the same order twice', async () => {
        const order = getTestOtcOrder({ taker: taker.address, txOrigin: txOrigin.address });
        await testUtils.fillTakerSignedOtcOrderAsync(order);
        const tx = testUtils.fillTakerSignedOtcOrderAsync(order);
        await validateError(
            tx,
            'orderNotFillableError',
            [order.getHash(), OrderStatus.Invalid]
        )
    });

    it('cannot fill two orders with the same nonceBucket and nonce', async () => {
        const order1 = getTestOtcOrder({ taker: taker.address, txOrigin: txOrigin.address });
        await testUtils.fillTakerSignedOtcOrderAsync(order1);
        const order2 = getTestOtcOrder({
            taker: taker.address,
            txOrigin: txOrigin.address,
            nonceBucket: order1.nonceBucket,
            nonce: order1.nonce
        });
        const tx = testUtils.fillTakerSignedOtcOrderAsync(order2);
        await validateError(
            tx,
            'orderNotFillableError',
            [order2.getHash(), OrderStatus.Invalid]
        )
    });

    it('cannot fill an order whose nonce is less than the nonce last used in that bucket', async () => {
        const order1 = getTestOtcOrder({ taker: taker.address, txOrigin: txOrigin.address });
        await testUtils.fillTakerSignedOtcOrderAsync(order1);
        const order2 = getTestOtcOrder({
            taker: taker.address,
            txOrigin: txOrigin.address,
            nonceBucket: order1.nonceBucket,
            nonce: order1.nonce.sub(1),
        });
        const tx = testUtils.fillTakerSignedOtcOrderAsync(order2);
        await validateError(
            tx,
            'orderNotFillableError',
            [order2.getHash(), OrderStatus.Invalid]
        )
    });

    it('can fill two orders that use the same nonce bucket and increasing nonces', async () => {
        const order1 = getTestOtcOrder({ taker: taker.address, txOrigin: txOrigin.address });
        const tx1 = await testUtils.fillTakerSignedOtcOrderAsync(order1);
        const receipt1 = await tx1.wait()
        verifyLogs(
            receipt1.logs,
            [testUtils.createOtcOrderFilledEventArgs(order1)],
            OrderEvents.OtcOrderFilled,
        );
        const order2 = getTestOtcOrder({
            taker: taker.address,
            txOrigin: txOrigin.address,
            nonceBucket: order1.nonceBucket,
            nonce: order1.nonce.add(1),
        });
        const tx2 = await testUtils.fillTakerSignedOtcOrderAsync(order2);
        const receipt2 = await tx2.wait()
        verifyLogs(
            receipt2.logs,
            [testUtils.createOtcOrderFilledEventArgs(order2)],
            OrderEvents.OtcOrderFilled,
        );
    });

    it('can fill two orders that use the same nonce but different nonce buckets', async () => {
        const order1 = getTestOtcOrder({ taker: taker.address, txOrigin: txOrigin.address });
        const tx1 = await testUtils.fillTakerSignedOtcOrderAsync(order1);
        const receipt1 = await tx1.wait()
        verifyLogs(
            receipt1.logs,
            [testUtils.createOtcOrderFilledEventArgs(order1)],
            OrderEvents.OtcOrderFilled,
        );
        const order2 = getTestOtcOrder({
            taker: taker.address,
            txOrigin: txOrigin.address,
            nonce: order1.nonce
        });
        const tx2 = await testUtils.fillTakerSignedOtcOrderAsync(order2);
        const receipt2 = await tx2.wait()
        verifyLogs(
            receipt2.logs,
            [testUtils.createOtcOrderFilledEventArgs(order2)],
            OrderEvents.OtcOrderFilled,
        );
    });

    it('can fill a WETH buy order and receive ETH', async () => {
        const takerEthBalanceBefore = await provider.getBalance(taker.address);
        const order = getTestOtcOrder({
            taker: taker.address,
            txOrigin: txOrigin.address,
            makerToken: wethToken.address,
            makerAmount: BigNumber.from(10).pow(18),
        });
        await wethToken.connect(maker).deposit({ value: order.makerAmount });
        const tx = await testUtils.fillTakerSignedOtcOrderAsync(order, txOrigin.address, taker, true);
        const receipt = await tx.wait()
        verifyLogs(
            receipt.logs,
            [testUtils.createOtcOrderFilledEventArgs(order)],
            OrderEvents.OtcOrderFilled,
        );
        const takerEthBalanceAfter = await provider.getBalance(taker.address);
        expect(takerEthBalanceAfter.sub(takerEthBalanceBefore).toString()).to.equal(order.makerAmount.toString());
    });

    it('reverts if `unwrapWeth` is true but maker token is not WETH', async () => {
        const order = getTestOtcOrder({ taker: taker.address, txOrigin: txOrigin.address });
        const tx = testUtils.fillTakerSignedOtcOrderAsync(order, txOrigin.address, taker, true);
        return expect(tx).to.reverted; // With('OtcOrdersFeature::fillTakerSignedOtcOrder/MAKER_TOKEN_NOT_WETH');
    });
});

describe('batchFillTakerSignedOtcOrders()', () => {
    it('Fills multiple orders', async () => {
        const order1 = getTestOtcOrder({ taker: taker.address, txOrigin: txOrigin.address });
        const order2 = getTestOtcOrder({
            taker: notTaker.address,
            txOrigin: txOrigin.address,
            nonceBucket: order1.nonceBucket,
            nonce: order1.nonce.add(1),
        });
        await testUtils.prepareBalancesForOrdersAsync([order1], taker);
        await testUtils.prepareBalancesForOrdersAsync([order2], notTaker);
        const tx = await oneDeltaOrders.connect(txOrigin)
            .batchFillTakerSignedOtcOrders(
                [order1, order2],
                [
                    await order1.getSignatureWithProviderAsync(await ethers.getSigner(order1.maker)),
                    await order2.getSignatureWithProviderAsync(await ethers.getSigner(order2.maker)),
                ],
                [
                    await order1.getSignatureWithProviderAsync(taker, SignatureType.EthSign),
                    await order2.getSignatureWithProviderAsync(notTaker, SignatureType.EthSign),
                ],
                [false, false],
            );

        const receipt = await tx.wait()
        verifyLogs(
            receipt.logs,
            [testUtils.createOtcOrderFilledEventArgs(order1), testUtils.createOtcOrderFilledEventArgs(order2)],
            OrderEvents.OtcOrderFilled,
        );
    });
    it('Fills multiple orders and unwraps WETH', async () => {
        const order1 = getTestOtcOrder({ taker: taker.address, txOrigin: txOrigin.address });
        const order2 = getTestOtcOrder({
            taker: notTaker.address,
            txOrigin: txOrigin.address,
            nonceBucket: order1.nonceBucket,
            nonce: order1.nonce.add(1),
            makerToken: wethToken.address,
            makerAmount: BigNumber.from(10).pow(18),
        });
        await testUtils.prepareBalancesForOrdersAsync([order1], taker);
        await testUtils.prepareBalancesForOrdersAsync([order2], notTaker);
        await wethToken.connect(maker).deposit({ value: order2.makerAmount });
        const tx = await oneDeltaOrders.connect(txOrigin)
            .batchFillTakerSignedOtcOrders(
                [order1, order2],
                [
                    await order1.getSignatureWithProviderAsync(await ethers.getSigner(order1.maker)),
                    await order2.getSignatureWithProviderAsync(await ethers.getSigner(order2.maker)),
                ],
                [
                    await order1.getSignatureWithProviderAsync(taker, SignatureType.EthSign),
                    await order2.getSignatureWithProviderAsync(notTaker, SignatureType.EthSign),
                ],
                [false, true],
            );
        const receipt = await tx.wait()
        verifyLogs(
            receipt.logs,
            [testUtils.createOtcOrderFilledEventArgs(order1), testUtils.createOtcOrderFilledEventArgs(order2)],
            OrderEvents.OtcOrderFilled,
        );
    });
    it('Skips over unfillable orders', async () => {
        const order1 = getTestOtcOrder({ taker: taker.address, txOrigin: txOrigin.address });
        const order2 = getTestOtcOrder({
            taker: notTaker.address,
            txOrigin: txOrigin.address,
            nonceBucket: order1.nonceBucket,
            nonce: order1.nonce.add(1),
        });
        await testUtils.prepareBalancesForOrdersAsync([order1], taker);
        await testUtils.prepareBalancesForOrdersAsync([order2], notTaker);
        const tx = await oneDeltaOrders.connect(txOrigin)
            .batchFillTakerSignedOtcOrders(
                [order1, order2],
                [
                    await order1.getSignatureWithProviderAsync(await ethers.getSigner(order1.maker)),
                    await order2.getSignatureWithProviderAsync(await ethers.getSigner(order2.maker)),
                ],
                [
                    await order1.getSignatureWithProviderAsync(taker, SignatureType.EthSign),
                    await order2.getSignatureWithProviderAsync(taker, SignatureType.EthSign), // Invalid signature for order2
                ],
                [false, false],
            );
        const receipt = await tx.wait()
        verifyLogs(
            receipt.logs,
            [testUtils.createOtcOrderFilledEventArgs(order1)],
            OrderEvents.OtcOrderFilled,
        );
    });
});
