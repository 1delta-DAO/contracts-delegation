import {
    constants,
    getRandomPortion as _getRandomPortion,
} from '@0x/contracts-test-utils';
import {
    assertOrderInfoEquals,
    computeLimitOrderFilledAmounts,
    computeRfqOrderFilledAmounts,
    createExpiry,
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
import { IZeroExEvents, LimitOrder, LimitOrderFields, OrderStatus, RfqOrder, RfqOrderFields } from './utils/constants';
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