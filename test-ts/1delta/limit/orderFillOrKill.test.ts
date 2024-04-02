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
} from '../../../types';
import { createNativeOrder } from './utils/orderFixture';
import { OrderEvents, LimitOrder, LimitOrderFields, RfqOrder, RfqOrderFields, MAX_UINT256 } from './utils/constants';
import { BigNumber } from 'ethers';
import { MockProvider } from 'ethereum-waffle';
import { expect } from '../shared/expect'
import { validateError, verifyLogs } from './utils/utils';

const { NULL_ADDRESS, } = constants;
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

describe('fillOrKillLimitOrder()', () => {
    it('can fully fill an order', async () => {
        const order = getTestLimitOrder();
        await testUtils.prepareBalancesForOrdersAsync([order]);
        const tx = await oneDeltaOrders.connect(taker)
            .fillLimitOrder(
                order,
                await order.getSignatureWithProviderAsync(maker),
                order.takerAmount,
                true,
                { value: SINGLE_PROTOCOL_FEE, gasPrice: GAS_PRICE }
            );
        const receipt = await tx.wait()
        verifyLogs(
            receipt.logs,
            [testUtils.createLimitOrderFilledEventArgs(order)],
            OrderEvents.LimitOrderFilled,
        );
    });

    it('reverts if cannot fill the exact amount', async () => {
        const order = getTestLimitOrder();
        await testUtils.prepareBalancesForOrdersAsync([order]);
        const fillAmount = order.takerAmount.add(1);
        await validateError(
            oneDeltaOrders.connect(taker)
                .fillLimitOrder(
                    order,
                    await order.getSignatureWithProviderAsync(maker),
                    fillAmount,
                    true,
                    { value: SINGLE_PROTOCOL_FEE }
                ),
            "fillOrKillFailedError",
            [order.getHash(), order.takerAmount, fillAmount]
        );
    });

    it('refunds excess protocol fee', async () => {
        const order = getTestLimitOrder();
        await testUtils.prepareBalancesForOrdersAsync([order]);
        const takerBalanceBefore = await provider.getBalance(taker.address);
        const tx = await oneDeltaOrders.connect(taker)
            .fillLimitOrder(
                order,
                await order.getSignatureWithProviderAsync(maker),
                order.takerAmount,
                true,
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
        const tx = await oneDeltaOrders.connect(taker)
            .fillRfqOrder(
                order,
                await order.getSignatureWithProviderAsync(maker),
                order.takerAmount,
                true
            );
        const receipt = await tx.wait()
        verifyLogs(
            receipt.logs,
            [testUtils.createRfqOrderFilledEventArgs(order)],
            OrderEvents.RfqOrderFilled,
        );
    });

    it('reverts if cannot fill the exact amount', async () => {
        const order = getTestRfqOrder();
        await testUtils.prepareBalancesForOrdersAsync([order]);
        const fillAmount = order.takerAmount.add(1);
        const tx = oneDeltaOrders.connect(taker)
            .fillRfqOrder(
                order,
                await order.getSignatureWithProviderAsync(maker),
                fillAmount,
                true
            );
        await validateError(
            tx,
            "fillOrKillFailedError",
            [order.getHash(), order.takerAmount, fillAmount]
        );

    });

    it('fails if ETH is attached', async () => {
        const order = getTestRfqOrder();
        await testUtils.prepareBalancesForOrdersAsync([order]);
        const tx = oneDeltaOrders.connect(taker)
            .fillRfqOrder(
                order,
                await order.getSignatureWithProviderAsync(maker),
                order.takerAmount,
                true,
                { value: 1 } as any
            );
        // This will revert at the language level because the fill function is not payable.
        return expect(tx).to.be.reverted // ('revert');
    });
});
