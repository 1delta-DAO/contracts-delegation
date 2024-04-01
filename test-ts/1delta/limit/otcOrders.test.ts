import { constants } from '@0x/contracts-test-utils';
import { IZeroExEvents, OrderStatus, OtcOrder } from './utils/constants';

import {
    assertOtcOrderInfoEquals,
    computeOtcOrderFilledAmounts,
    createCleanExpiry,
    createExpiry,
    getRandomOtcOrder,
    NativeOrdersTestEnvironment,
} from './utils/orders';

import {
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
import { MaxUint128 } from '../../uniswap-v3/periphery/shared/constants';
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
    [owner, maker, taker, notMaker, notTaker, contractWalletOwner, contractWalletSigner, txOrigin, notTxOrigin, collector] =
        await ethers.getSigners()

    makerToken = await new MockERC20__factory(owner).deploy("Maker", 'M', 18)
    takerToken = await new MockERC20__factory(owner).deploy("Taker", "T", 6)
    wethToken = await new WETH9__factory(owner).deploy()

    zeroEx = await createNativeOrder(
        owner,
        collector.address,
        BigNumber.from(PROTOCOL_FEE_MULTIPLIER),
        wethToken.address
    );
    verifyingContract = zeroEx.address;
    provider = waffle.provider
    chainId = await maker.getChainId()
    console.log("ChainId", chainId, 'maker', maker.address, "taker", taker.address)
    console.log('makerToken', makerToken.address, "takerToken", takerToken.address)

    await Promise.all([
        makerToken.connect(maker).approve(zeroEx.address, MaxUint128),
        makerToken.connect(notMaker).approve(zeroEx.address, MaxUint128),
        takerToken.connect(taker).approve(zeroEx.address, MaxUint128),
        takerToken.connect(notTaker).approve(zeroEx.address, MaxUint128),
        wethToken.connect(maker).approve(zeroEx.address, MaxUint128),
        wethToken.connect(notMaker).approve(zeroEx.address, MaxUint128),
        wethToken.connect(taker).approve(zeroEx.address, MaxUint128),
        wethToken.connect(notTaker).approve(zeroEx.address, MaxUint128),
    ]);

    // contract wallet for signer delegation
    contractWallet = await new TestOrderSignerRegistryWithContractWallet__factory(contractWalletOwner).deploy(zeroEx.address)

    await contractWallet.connect(contractWalletOwner)
        .approveERC20(makerToken.address, zeroEx.address, MaxUint128);
    await contractWallet.connect(contractWalletOwner)
        .approveERC20(takerToken.address, zeroEx.address, MaxUint128);

    GAS_PRICE = await provider.getGasPrice()
    testUtils = new NativeOrdersTestEnvironment(maker, taker, makerToken, takerToken, zeroEx, GAS_PRICE, ZERO);
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
        const hash = await zeroEx.getOtcOrderHash(order);
        expect(hash).to.eq(order.getHash());
    });
});

describe('lastOtcTxOriginNonce()', () => {
    it('returns 0 if bucket is unused', async () => {
        const nonce = await zeroEx.lastOtcTxOriginNonce(taker.address, ZERO);
        expect(nonce.toString()).to.eq('0');
    });
    it('returns the last nonce used in a bucket', async () => {
        const order = getTestOtcOrder();
        await testUtils.fillOtcOrderAsync(order);
        const nonce = await zeroEx.lastOtcTxOriginNonce(taker.address, order.nonceBucket);
        expect(nonce.toString()).to.eq(order.nonce.toString());
    });
});

describe('getOtcOrderInfo()', () => {
    it('unfilled order', async () => {
        const order = getTestOtcOrder();
        const info = await zeroEx.getOtcOrderInfo(order);
        assertOtcOrderInfoEquals(info, {
            status: OrderStatus.Fillable,
            orderHash: order.getHash(),
        });
    });

    it('unfilled expired order', async () => {
        const expiry = await createCleanExpiry(provider, -60);
        const order = getTestOtcOrder({ expiry });
        const info = await zeroEx.getOtcOrderInfo(order);
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
        const info = await zeroEx.getOtcOrderInfo(order);
        assertOtcOrderInfoEquals(info, {
            status: OrderStatus.Invalid,
            orderHash: order.getHash(),
        });
    });

    it('filled order', async () => {
        const order = getTestOtcOrder();
        // Fill the order first.
        await testUtils.fillOtcOrderAsync(order);
        const info = await zeroEx.getOtcOrderInfo(order);
        assertOtcOrderInfoEquals(info, {
            status: OrderStatus.Invalid,
            orderHash: order.getHash(),
        });
    });
});

async function assertExpectedFinalBalancesFromOtcOrderFillAsync(
    order: OtcOrder,
    takerTokenFillAmount: BigNumber = order.takerAmount,
): Promise<void> {
    const blockTag = await provider.getBlockNumber() - 1
    const { makerTokenFilledAmount, takerTokenFilledAmount } = computeOtcOrderFilledAmounts(
        order,
        takerTokenFillAmount,
    );
    const makerBalance = await new MockERC20__factory(owner).attach(order.takerToken)
        .balanceOf(order.maker);
    const takerBalance = await new MockERC20__factory(owner).attach(order.makerToken)
        .balanceOf(order.taker !== NULL_ADDRESS ? order.taker : taker.address);

    const makerBalanceBefore = await takerToken.balanceOf(maker.address, { blockTag });
    const takerBalanceBefore = await makerToken.balanceOf(order.taker !== NULL_ADDRESS ? order.taker : taker.address, { blockTag });
    expect(makerBalance.sub(makerBalanceBefore).toString(), 'maker balance').to.eq(takerTokenFilledAmount.toString());
    expect(takerBalance.sub(takerBalanceBefore).toString(), 'taker balance').to.eq(makerTokenFilledAmount.toString());
}


async function assertExpectedFinalBalancesFromOtcOrderFillAsyncNoTag(
    makerBalanceBefore: BigNumber,
    takerBalanceBefore: BigNumber,
    order: OtcOrder,
    takerTokenFillAmount: BigNumber = order.takerAmount,
): Promise<void> {
    const { makerTokenFilledAmount, takerTokenFilledAmount } = computeOtcOrderFilledAmounts(
        order,
        takerTokenFillAmount,
    );
    const makerBalance = await new MockERC20__factory(owner).attach(order.takerToken)
        .balanceOf(order.maker);
    const takerBalance = await new MockERC20__factory(owner).attach(order.makerToken)
        .balanceOf(order.taker !== NULL_ADDRESS ? order.taker : taker.address);
    expect(makerBalance.sub(makerBalanceBefore).toString(), 'maker balance').to.eq(takerTokenFilledAmount.toString());
    expect(takerBalance.sub(takerBalanceBefore).toString(), 'taker balance').to.eq(makerTokenFilledAmount.toString());
}

describe('fillOtcOrder()', () => {
    it('can fully fill an order', async () => {
        const order = getTestOtcOrder();
        const tx = await testUtils.fillOtcOrderAsync(order);
        const receipt = await tx.wait()
        verifyLogs(
            receipt.logs,
            [testUtils.createOtcOrderFilledEventArgs(order)],
            IZeroExEvents.OtcOrderFilled,
        );
        await assertExpectedFinalBalancesFromOtcOrderFillAsync(order);
    });

    it('can partially fill an order', async () => {
        const order = getTestOtcOrder();
        const fillAmount = order.takerAmount.sub(1);
        const tx = await testUtils.fillOtcOrderAsync(order, fillAmount);
        const receipt = await tx.wait()
        verifyLogs(
            receipt.logs,
            [testUtils.createOtcOrderFilledEventArgs(order, fillAmount)],
            IZeroExEvents.OtcOrderFilled,
        );
        await assertExpectedFinalBalancesFromOtcOrderFillAsync(order, fillAmount);
    });

    it('clamps fill amount to remaining available', async () => {
        const order = getTestOtcOrder();
        const fillAmount = order.takerAmount.add(1);
        const tx = await testUtils.fillOtcOrderAsync(order, fillAmount);
        const receipt = await tx.wait()
        verifyLogs(
            receipt.logs,
            [testUtils.createOtcOrderFilledEventArgs(order, fillAmount)],
            IZeroExEvents.OtcOrderFilled,
        );
        await assertExpectedFinalBalancesFromOtcOrderFillAsync(order, fillAmount);
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
        await zeroEx.connect(taker).registerAllowedRfqOrigins([notTaker.address], true);
        return testUtils.fillOtcOrderAsync(order, order.takerAmount, notTaker);
    });

    it('cannot fill an order with registered then unregistered tx.origin', async () => {
        const order = getTestOtcOrder();
        await zeroEx.connect(taker).registerAllowedRfqOrigins([notTaker.address], true);
        await zeroEx.connect(taker).registerAllowedRfqOrigins([notTaker.address], false);
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
        const tx = zeroEx.connect(taker)
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
            IZeroExEvents.OtcOrderFilled,
        );
        const order2 = getTestOtcOrder({ nonceBucket: order1.nonceBucket, nonce: order1.nonce.add(1) });
        const tx2 = await testUtils.fillOtcOrderAsync(order2);
        const receipt2 = await tx2.wait()
        verifyLogs(
            receipt2.logs,
            [testUtils.createOtcOrderFilledEventArgs(order2)],
            IZeroExEvents.OtcOrderFilled,
        );
    });

    it('can fill two orders that use the same nonce but different nonce buckets', async () => {
        const order1 = getTestOtcOrder();
        const tx1 = await testUtils.fillOtcOrderAsync(order1);
        const receipt1 = await tx1.wait()
        verifyLogs(
            receipt1.logs,
            [testUtils.createOtcOrderFilledEventArgs(order1)],
            IZeroExEvents.OtcOrderFilled,
        );
        const order2 = getTestOtcOrder({ nonce: order1.nonce });
        const tx2 = await testUtils.fillOtcOrderAsync(order2);
        const receipt2 = await tx2.wait()
        verifyLogs(
            receipt2.logs,
            [testUtils.createOtcOrderFilledEventArgs(order2)],
            IZeroExEvents.OtcOrderFilled,
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
            IZeroExEvents.OtcOrderFilled,
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
        const tx = await zeroEx.connect(taker)
            .fillOtcOrder(order, sig, order.takerAmount);
        const receipt = await tx.wait()
        verifyLogs(
            receipt.logs,
            [testUtils.createOtcOrderFilledEventArgs(order)],
            IZeroExEvents.OtcOrderFilled,
        );
        await assertExpectedFinalBalancesFromOtcOrderFillAsyncNoTag(
            makerBalanceBefore,
            takerBalanceBefore,
            order
        );
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
        const tx = zeroEx.connect(taker)
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
        const tx = zeroEx.connect(taker).fillOtcOrder(order, sig, order.takerAmount);
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

// describe('fillOtcOrderWithEth()', () => {
//     it('Can fill an order with ETH (takerToken=WETH)', async () => {
//         const order = getTestOtcOrder({ takerToken: wethToken.address });
//         const receipt = await testUtils.fillOtcOrderWithEthAsync(order);
//         verifyLogs(
//             receipt.logs,
//             [testUtils.createOtcOrderFilledEventArgs(order)],
//             IZeroExEvents.OtcOrderFilled,
//         );
//         await assertExpectedFinalBalancesFromOtcOrderFillAsync(order);
//     });
//     it('Can fill an order with ETH (takerToken=ETH)', async () => {
//         const order = getTestOtcOrder({ takerToken: ETH_TOKEN_ADDRESS });
//         const makerEthBalanceBefore = await env.web3Wrapper.getBalanceInWeiAsync(maker);
//         const receipt = await testUtils.fillOtcOrderWithEthAsync(order);
//         verifyLogs(
//             receipt.logs,
//             [testUtils.createOtcOrderFilledEventArgs(order)],
//             IZeroExEvents.OtcOrderFilled,
//         );
//         const takerBalance = await new TestMintableERC20TokenContract(order.makerToken, env.provider)
//             .balanceOf(taker)
//             .callAsync();
//         expect(takerBalance, 'taker balance').to.bignumber.eq(order.makerAmount);
//         const makerEthBalanceAfter = await env.web3Wrapper.getBalanceInWeiAsync(maker);
//         expect(makerEthBalanceAfter.minus(makerEthBalanceBefore), 'maker balance').to.bignumber.equal(
//             order.takerAmount,
//         );
//     });
//     it('Can partially fill an order with ETH (takerToken=WETH)', async () => {
//         const order = getTestOtcOrder({ takerToken: wethToken.address });
//         const fillAmount = order.takerAmount.minus(1);
//         const receipt = await testUtils.fillOtcOrderWithEthAsync(order, fillAmount);
//         verifyLogs(
//             receipt.logs,
//             [testUtils.createOtcOrderFilledEventArgs(order, fillAmount)],
//             IZeroExEvents.OtcOrderFilled,
//         );
//         await assertExpectedFinalBalancesFromOtcOrderFillAsync(order, fillAmount);
//     });
//     it('Can partially fill an order with ETH (takerToken=ETH)', async () => {
//         const order = getTestOtcOrder({ takerToken: ETH_TOKEN_ADDRESS });
//         const fillAmount = order.takerAmount.minus(1);
//         const makerEthBalanceBefore = await env.web3Wrapper.getBalanceInWeiAsync(maker);
//         const receipt = await testUtils.fillOtcOrderWithEthAsync(order, fillAmount);
//         verifyLogs(
//             receipt.logs,
//             [testUtils.createOtcOrderFilledEventArgs(order, fillAmount)],
//             IZeroExEvents.OtcOrderFilled,
//         );
//         const { makerTokenFilledAmount, takerTokenFilledAmount } = computeOtcOrderFilledAmounts(order, fillAmount);
//         const takerBalance = await new TestMintableERC20TokenContract(order.makerToken, env.provider)
//             .balanceOf(taker)
//             .callAsync();
//         expect(takerBalance, 'taker balance').to.bignumber.eq(makerTokenFilledAmount);
//         const makerEthBalanceAfter = await env.web3Wrapper.getBalanceInWeiAsync(maker);
//         expect(makerEthBalanceAfter.minus(makerEthBalanceBefore), 'maker balance').to.bignumber.equal(
//             takerTokenFilledAmount,
//         );
//     });
//     it('Can refund excess ETH is msg.value > order.takerAmount (takerToken=WETH)', async () => {
//         const order = getTestOtcOrder({ takerToken: wethToken.address });
//         const fillAmount = order.takerAmount.plus(420);
//         const takerEthBalanceBefore = await env.web3Wrapper.getBalanceInWeiAsync(taker);
//         const receipt = await testUtils.fillOtcOrderWithEthAsync(order, fillAmount);
//         verifyLogs(
//             receipt.logs,
//             [testUtils.createOtcOrderFilledEventArgs(order)],
//             IZeroExEvents.OtcOrderFilled,
//         );
//         const takerEthBalanceAfter = await env.web3Wrapper.getBalanceInWeiAsync(taker);
//         expect(takerEthBalanceBefore.minus(takerEthBalanceAfter)).to.bignumber.equal(order.takerAmount);
//         await assertExpectedFinalBalancesFromOtcOrderFillAsync(order);
//     });
//     it('Can refund excess ETH is msg.value > order.takerAmount (takerToken=ETH)', async () => {
//         const order = getTestOtcOrder({ takerToken: ETH_TOKEN_ADDRESS });
//         const fillAmount = order.takerAmount.plus(420);
//         const takerEthBalanceBefore = await env.web3Wrapper.getBalanceInWeiAsync(taker);
//         const makerEthBalanceBefore = await env.web3Wrapper.getBalanceInWeiAsync(maker);
//         const receipt = await testUtils.fillOtcOrderWithEthAsync(order, fillAmount);
//         verifyLogs(
//             receipt.logs,
//             [testUtils.createOtcOrderFilledEventArgs(order)],
//             IZeroExEvents.OtcOrderFilled,
//         );
//         const takerEthBalanceAfter = await env.web3Wrapper.getBalanceInWeiAsync(taker);
//         expect(takerEthBalanceBefore.minus(takerEthBalanceAfter), 'taker eth balance').to.bignumber.equal(
//             order.takerAmount,
//         );
//         const takerBalance = await new TestMintableERC20TokenContract(order.makerToken, env.provider)
//             .balanceOf(taker)
//             .callAsync();
//         expect(takerBalance, 'taker balance').to.bignumber.eq(order.makerAmount);
//         const makerEthBalanceAfter = await env.web3Wrapper.getBalanceInWeiAsync(maker);
//         expect(makerEthBalanceAfter.minus(makerEthBalanceBefore), 'maker balance').to.bignumber.equal(
//             order.takerAmount,
//         );
//     });
//     it('Cannot fill an order if taker token is not ETH or WETH', async () => {
//         const order = getTestOtcOrder();
//         const tx = testUtils.fillOtcOrderWithEthAsync(order);
//         return expect(tx).to.revertWith('OtcOrdersFeature::fillOtcOrderWithEth/INVALID_TAKER_TOKEN');
//     });
// });

// describe('fillTakerSignedOtcOrder()', () => {
//     it('can fully fill an order', async () => {
//         const order = getTestOtcOrder({ taker, txOrigin });
//         const receipt = await testUtils.fillTakerSignedOtcOrderAsync(order);
//         verifyLogs(
//             receipt.logs,
//             [testUtils.createOtcOrderFilledEventArgs(order)],
//             IZeroExEvents.OtcOrderFilled,
//         );
//         await assertExpectedFinalBalancesFromOtcOrderFillAsync(order);
//     });

//     it('cannot fill an order with wrong tx.origin', async () => {
//         const order = getTestOtcOrder({ taker, txOrigin });
//         const tx = testUtils.fillTakerSignedOtcOrderAsync(order, notTxOrigin);
//         return expect(tx).to.revertWith(
//             new RevertErrors.NativeOrders.OrderNotFillableByOriginError(order.getHash(), notTxOrigin, txOrigin),
//         );
//     });

//     it('can fill an order from a different tx.origin if registered', async () => {
//         const order = getTestOtcOrder({ taker, txOrigin });
//         await zeroEx
//             .registerAllowedRfqOrigins([notTxOrigin], true)
//             .awaitTransactionSuccessAsync({ from: txOrigin });
//         return testUtils.fillTakerSignedOtcOrderAsync(order, notTxOrigin);
//     });

//     it('cannot fill an order with registered then unregistered tx.origin', async () => {
//         const order = getTestOtcOrder({ taker, txOrigin });
//         await zeroEx
//             .registerAllowedRfqOrigins([notTxOrigin], true)
//             .awaitTransactionSuccessAsync({ from: txOrigin });
//         await zeroEx
//             .registerAllowedRfqOrigins([notTxOrigin], false)
//             .awaitTransactionSuccessAsync({ from: txOrigin });
//         const tx = testUtils.fillTakerSignedOtcOrderAsync(order, notTxOrigin);
//         return expect(tx).to.revertWith(
//             new RevertErrors.NativeOrders.OrderNotFillableByOriginError(order.getHash(), notTxOrigin, txOrigin),
//         );
//     });

//     it('cannot fill an order with a zero tx.origin', async () => {
//         const order = getTestOtcOrder({ taker, txOrigin: NULL_ADDRESS });
//         const tx = testUtils.fillTakerSignedOtcOrderAsync(order, txOrigin);
//         return expect(tx).to.revertWith(
//             new RevertErrors.NativeOrders.OrderNotFillableByOriginError(order.getHash(), txOrigin, NULL_ADDRESS),
//         );
//     });

//     it('cannot fill an expired order', async () => {
//         const order = getTestOtcOrder({ taker, txOrigin, expiry: createExpiry(-60) });
//         const tx = testUtils.fillTakerSignedOtcOrderAsync(order);
//         return expect(tx).to.revertWith(
//             new RevertErrors.NativeOrders.OrderNotFillableError(order.getHash(), OrderStatus.Expired),
//         );
//     });

//     it('cannot fill an order with bad taker signature', async () => {
//         const order = getTestOtcOrder({ taker, txOrigin });
//         const tx = testUtils.fillTakerSignedOtcOrderAsync(order, txOrigin, notTaker);
//         return expect(tx).to.revertWith(
//             new RevertErrors.NativeOrders.OrderNotFillableByTakerError(order.getHash(), notTaker, taker),
//         );
//     });

//     it('cannot fill order with bad maker signature', async () => {
//         const order = getTestOtcOrder({ taker, txOrigin });
//         const anotherOrder = getTestOtcOrder({ taker, txOrigin });
//         await testUtils.prepareBalancesForOrdersAsync([order], taker);
//         const tx = zeroEx
//             .fillTakerSignedOtcOrder(
//                 order,
//                 await anotherOrder.getSignatureWithProviderAsync(env.provider),
//                 await order.getSignatureWithProviderAsync(env.provider, SignatureType.EthSign, taker),
//             )
//             .awaitTransactionSuccessAsync({ from: txOrigin });

//         return expect(tx).to.revertWith(
//             new RevertErrors.NativeOrders.OrderNotSignedByMakerError(order.getHash(), undefined, order.maker),
//         );
//     });

//     it('fails if ETH is attached', async () => {
//         const order = getTestOtcOrder({ taker, txOrigin });
//         await testUtils.prepareBalancesForOrdersAsync([order], taker);
//         const tx = zeroEx
//             .fillTakerSignedOtcOrder(
//                 order,
//                 await order.getSignatureWithProviderAsync(env.provider),
//                 await order.getSignatureWithProviderAsync(env.provider, SignatureType.EthSign, taker),
//             )
//             .awaitTransactionSuccessAsync({ from: txOrigin, value: 1 });
//         // This will revert at the language level because the fill function is not payable.
//         return expect(tx).to.be.rejectedWith('revert');
//     });

//     it('cannot fill the same order twice', async () => {
//         const order = getTestOtcOrder({ taker, txOrigin });
//         await testUtils.fillTakerSignedOtcOrderAsync(order);
//         const tx = testUtils.fillTakerSignedOtcOrderAsync(order);
//         return expect(tx).to.revertWith(
//             new RevertErrors.NativeOrders.OrderNotFillableError(order.getHash(), OrderStatus.Invalid),
//         );
//     });

//     it('cannot fill two orders with the same nonceBucket and nonce', async () => {
//         const order1 = getTestOtcOrder({ taker, txOrigin });
//         await testUtils.fillTakerSignedOtcOrderAsync(order1);
//         const order2 = getTestOtcOrder({ taker, txOrigin, nonceBucket: order1.nonceBucket, nonce: order1.nonce });
//         const tx = testUtils.fillTakerSignedOtcOrderAsync(order2);
//         return expect(tx).to.revertWith(
//             new RevertErrors.NativeOrders.OrderNotFillableError(order2.getHash(), OrderStatus.Invalid),
//         );
//     });

//     it('cannot fill an order whose nonce is less than the nonce last used in that bucket', async () => {
//         const order1 = getTestOtcOrder({ taker, txOrigin });
//         await testUtils.fillTakerSignedOtcOrderAsync(order1);
//         const order2 = getTestOtcOrder({
//             taker,
//             txOrigin,
//             nonceBucket: order1.nonceBucket,
//             nonce: order1.nonce.minus(1),
//         });
//         const tx = testUtils.fillTakerSignedOtcOrderAsync(order2);
//         return expect(tx).to.revertWith(
//             new RevertErrors.NativeOrders.OrderNotFillableError(order2.getHash(), OrderStatus.Invalid),
//         );
//     });

//     it('can fill two orders that use the same nonce bucket and increasing nonces', async () => {
//         const order1 = getTestOtcOrder({ taker, txOrigin });
//         const tx1 = await testUtils.fillTakerSignedOtcOrderAsync(order1);
//         verifyLogs(
//             tx1.logs,
//             [testUtils.createOtcOrderFilledEventArgs(order1)],
//             IZeroExEvents.OtcOrderFilled,
//         );
//         const order2 = getTestOtcOrder({
//             taker,
//             txOrigin,
//             nonceBucket: order1.nonceBucket,
//             nonce: order1.nonce.plus(1),
//         });
//         const tx2 = await testUtils.fillTakerSignedOtcOrderAsync(order2);
//         verifyLogs(
//             tx2.logs,
//             [testUtils.createOtcOrderFilledEventArgs(order2)],
//             IZeroExEvents.OtcOrderFilled,
//         );
//     });

//     it('can fill two orders that use the same nonce but different nonce buckets', async () => {
//         const order1 = getTestOtcOrder({ taker, txOrigin });
//         const tx1 = await testUtils.fillTakerSignedOtcOrderAsync(order1);
//         verifyLogs(
//             tx1.logs,
//             [testUtils.createOtcOrderFilledEventArgs(order1)],
//             IZeroExEvents.OtcOrderFilled,
//         );
//         const order2 = getTestOtcOrder({ taker, txOrigin, nonce: order1.nonce });
//         const tx2 = await testUtils.fillTakerSignedOtcOrderAsync(order2);
//         verifyLogs(
//             tx2.logs,
//             [testUtils.createOtcOrderFilledEventArgs(order2)],
//             IZeroExEvents.OtcOrderFilled,
//         );
//     });

//     it('can fill a WETH buy order and receive ETH', async () => {
//         const takerEthBalanceBefore = await env.web3Wrapper.getBalanceInWeiAsync(taker);
//         const order = getTestOtcOrder({
//             taker,
//             txOrigin,
//             makerToken: wethToken.address,
//             makerAmount: new BigNumber('1e18'),
//         });
//         await wethToken.deposit().awaitTransactionSuccessAsync({ from: maker, value: order.makerAmount });
//         const receipt = await testUtils.fillTakerSignedOtcOrderAsync(order, txOrigin, taker, true);
//         verifyLogs(
//             receipt.logs,
//             [testUtils.createOtcOrderFilledEventArgs(order)],
//             IZeroExEvents.OtcOrderFilled,
//         );
//         const takerEthBalanceAfter = await env.web3Wrapper.getBalanceInWeiAsync(taker);
//         expect(takerEthBalanceAfter.minus(takerEthBalanceBefore)).to.bignumber.equal(order.makerAmount);
//     });

//     it('reverts if `unwrapWeth` is true but maker token is not WETH', async () => {
//         const order = getTestOtcOrder({ taker, txOrigin });
//         const tx = testUtils.fillTakerSignedOtcOrderAsync(order, txOrigin, taker, true);
//         return expect(tx).to.revertWith('OtcOrdersFeature::fillTakerSignedOtcOrder/MAKER_TOKEN_NOT_WETH');
//     });
// });

// describe('batchFillTakerSignedOtcOrders()', () => {
//     it('Fills multiple orders', async () => {
//         const order1 = getTestOtcOrder({ taker, txOrigin });
//         const order2 = getTestOtcOrder({
//             taker: notTaker,
//             txOrigin,
//             nonceBucket: order1.nonceBucket,
//             nonce: order1.nonce.plus(1),
//         });
//         await testUtils.prepareBalancesForOrdersAsync([order1], taker);
//         await testUtils.prepareBalancesForOrdersAsync([order2], notTaker);
//         const tx = await zeroEx
//             .batchFillTakerSignedOtcOrders(
//                 [order1, order2],
//                 [
//                     await order1.getSignatureWithProviderAsync(env.provider),
//                     await order2.getSignatureWithProviderAsync(env.provider),
//                 ],
//                 [
//                     await order1.getSignatureWithProviderAsync(env.provider, SignatureType.EthSign, taker),
//                     await order2.getSignatureWithProviderAsync(env.provider, SignatureType.EthSign, notTaker),
//                 ],
//                 [false, false],
//             )
//             .awaitTransactionSuccessAsync({ from: txOrigin });
//         verifyLogs(
//             tx.logs,
//             [testUtils.createOtcOrderFilledEventArgs(order1), testUtils.createOtcOrderFilledEventArgs(order2)],
//             IZeroExEvents.OtcOrderFilled,
//         );
//     });
//     it('Fills multiple orders and unwraps WETH', async () => {
//         const order1 = getTestOtcOrder({ taker, txOrigin });
//         const order2 = getTestOtcOrder({
//             taker: notTaker,
//             txOrigin,
//             nonceBucket: order1.nonceBucket,
//             nonce: order1.nonce.plus(1),
//             makerToken: wethToken.address,
//             makerAmount: new BigNumber('1e18'),
//         });
//         await testUtils.prepareBalancesForOrdersAsync([order1], taker);
//         await testUtils.prepareBalancesForOrdersAsync([order2], notTaker);
//         await wethToken.deposit().awaitTransactionSuccessAsync({ from: maker, value: order2.makerAmount });
//         const tx = await zeroEx
//             .batchFillTakerSignedOtcOrders(
//                 [order1, order2],
//                 [
//                     await order1.getSignatureWithProviderAsync(env.provider),
//                     await order2.getSignatureWithProviderAsync(env.provider),
//                 ],
//                 [
//                     await order1.getSignatureWithProviderAsync(env.provider, SignatureType.EthSign, taker),
//                     await order2.getSignatureWithProviderAsync(env.provider, SignatureType.EthSign, notTaker),
//                 ],
//                 [false, true],
//             )
//             .awaitTransactionSuccessAsync({ from: txOrigin });
//         verifyLogs(
//             tx.logs,
//             [testUtils.createOtcOrderFilledEventArgs(order1), testUtils.createOtcOrderFilledEventArgs(order2)],
//             IZeroExEvents.OtcOrderFilled,
//         );
//     });
//     it('Skips over unfillable orders', async () => {
//         const order1 = getTestOtcOrder({ taker, txOrigin });
//         const order2 = getTestOtcOrder({
//             taker: notTaker,
//             txOrigin,
//             nonceBucket: order1.nonceBucket,
//             nonce: order1.nonce.plus(1),
//         });
//         await testUtils.prepareBalancesForOrdersAsync([order1], taker);
//         await testUtils.prepareBalancesForOrdersAsync([order2], notTaker);
//         const tx = await zeroEx
//             .batchFillTakerSignedOtcOrders(
//                 [order1, order2],
//                 [
//                     await order1.getSignatureWithProviderAsync(env.provider),
//                     await order2.getSignatureWithProviderAsync(env.provider),
//                 ],
//                 [
//                     await order1.getSignatureWithProviderAsync(env.provider, SignatureType.EthSign, taker),
//                     await order2.getSignatureWithProviderAsync(env.provider, SignatureType.EthSign, taker), // Invalid signature for order2
//                 ],
//                 [false, false],
//             )
//             .awaitTransactionSuccessAsync({ from: txOrigin });
//         verifyLogs(
//             tx.logs,
//             [testUtils.createOtcOrderFilledEventArgs(order1)],
//             IZeroExEvents.OtcOrderFilled,
//         );
//     });
// });
