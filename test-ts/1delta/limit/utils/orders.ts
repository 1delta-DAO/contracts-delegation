import {
    constants,
    expect,
    randomAddress,
    getRandomInteger as _getRandomInteger
} from '@0x/contracts-test-utils';
import {
    LimitOrder,
    LimitOrderFields,
    OrderBase,
    OrderInfo,
    OtcOrder,
    RfqOrder,
    RfqOrderFields,
} from './constants';
import { hexUtils } from '@0x/utils';

import { MockERC20, MockERC20__factory, NativeOrders } from '../../../../types';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { MaxUint128 } from '../../../uniswap-v3/periphery/shared/constants';
import { minBn, sumBn } from './utils';
import { BigNumber, ContractTransaction } from 'ethers';
import { ethers } from 'hardhat';
import { MockProvider } from 'ethereum-waffle';

const { NULL_ADDRESS } = constants;

const DEFAULT_EXPIRY = 60 * 60

const getRandomInteger = (min: string, max: string) => {
    return BigNumber.from(_getRandomInteger(min, max).toString());
}

const ZERO = BigNumber.from(0)
interface RfqOrderFilledAmounts {
    makerTokenFilledAmount: BigNumber;
    takerTokenFilledAmount: BigNumber;
}
type OtcOrderFilledAmounts = RfqOrderFilledAmounts;

interface LimitOrderFilledAmounts {
    makerTokenFilledAmount: BigNumber;
    takerTokenFilledAmount: BigNumber;
    takerTokenFeeFilledAmount: BigNumber;
}

export enum OtcOrderWethOptions {
    LeaveAsWeth,
    WrapEth,
    UnwrapWeth,
}

export class NativeOrdersTestEnvironment {
    public static async createAsync(
        owner: SignerWithAddress,
        maker: SignerWithAddress,
        taker: SignerWithAddress,
        zeroEx: NativeOrders,
        gasPrice: BigNumber = BigNumber.from(123e9),
        protocolFeeMultiplier = 70e3,
    ): Promise<NativeOrdersTestEnvironment> {
        const makerToken = await new MockERC20__factory(owner).deploy('TokenA', 'A', 18)
        const takerToken = await new MockERC20__factory(owner).deploy('TokenB', 'A', 6)

        // const zeroEx = await createNativeOrder(owner, weth);
        await makerToken.connect(maker).approve(zeroEx.address, MaxUint128);
        await takerToken.connect(taker).approve(zeroEx.address, MaxUint128);
        return new NativeOrdersTestEnvironment(
            maker,
            taker,
            makerToken,
            takerToken,
            zeroEx,
            gasPrice,
            gasPrice.mul(protocolFeeMultiplier),
        );
    }

    constructor(
        public readonly maker: SignerWithAddress,
        public readonly taker: SignerWithAddress,
        public readonly makerToken: MockERC20,
        public readonly takerToken: MockERC20,
        public readonly zeroEx: NativeOrders,
        public readonly gasPrice: BigNumber,
        public readonly protocolFee: BigNumber,
    ) { }

    public async prepareBalancesForOrdersAsync(
        orders: LimitOrder[] | RfqOrder[] | OtcOrder[],
        taker: SignerWithAddress = this.taker,
    ): Promise<void> {
        await this.makerToken
            .mint(this.maker.address, sumBn((orders as OrderBase[]).map(order => order.makerAmount)));
        await this.takerToken
            .mint(
                taker.address,
                sumBn(
                    (orders as OrderBase[]).map(order =>
                        order.takerAmount.add(order instanceof LimitOrder ? order.takerTokenFeeAmount : 0),
                    ),
                ),
            );
    }

    public async fillLimitOrderAsync(
        order: LimitOrder,
        opts: Partial<{
            fillAmount: BigNumber | number;
            taker: SignerWithAddress;
            maker: SignerWithAddress;
            protocolFee: BigNumber | number;
        }> = {},
        fillOrKill = false
    ): Promise<ContractTransaction> {
        const { fillAmount, taker, maker, protocolFee } = {
            taker: this.taker,
            maker: this.maker,
            fillAmount: order.takerAmount,
            ...opts,
        };
        await this.prepareBalancesForOrdersAsync([order], taker);
        const value = protocolFee === undefined ? this.protocolFee : protocolFee;
        return this.zeroEx.connect(taker)
            .fillLimitOrder(
                order,
                await order.getSignatureWithProviderAsync(maker),
                BigNumber.from(fillAmount),
                fillOrKill,
                { value, gasPrice: this.gasPrice }
            );
    }

    public async fillRfqOrderAsync(
        order: RfqOrder,
        fillAmount: BigNumber | number = order.takerAmount,
        taker: SignerWithAddress = this.taker,
        fillOrKill = false
    ): Promise<any> {
        await this.prepareBalancesForOrdersAsync([order], taker);
        const maker = await ethers.getSigner(order.maker)
        return this.zeroEx.connect(taker)
            .fillRfqOrder(
                order,
                await order.getSignatureWithProviderAsync(maker),
                BigNumber.from(fillAmount),
                fillOrKill
            );
    }

    // public async fillOtcOrderAsync(
    //     order: OtcOrder,
    //     fillAmount: BigNumber | number = order.takerAmount,
    //     taker: SignerWithAddress,
    //     unwrapWeth = false,
    // ): Promise<TransactionReceiptWithDecodedLogs> {
    //     await this.prepareBalancesForOrdersAsync([order], taker);
    //     const maker = await ethers.getSigner(order.maker)
    //     if (unwrapWeth) {
    //         return this.zeroEx.connect(taker)
    //             .fillOtcOrderForEth(
    //                 order,
    //                 await order.getSignatureWithProviderAsync(maker),
    //                 BigNumber.from(fillAmount),
    //             );
    //     } else {
    //         return this.zeroEx.connect(taker)
    //             .fillOtcOrder(
    //                 order,
    //                 await order.getSignatureWithProviderAsync(maker),
    //                 BigNumber.from(fillAmount),
    //             );
    //     }
    // }

    // public async fillTakerSignedOtcOrderAsync(
    //     order: OtcOrder,
    //     origin: string = order.txOrigin,
    //     taker: SignerWithAddress,
    //     unwrapWeth = false,
    // ): Promise<TransactionReceiptWithDecodedLogs> {
    //     const originSigner = await ethers.getSigner(origin)
    //     const maker = await ethers.getSigner(order.maker)
    //     await this.prepareBalancesForOrdersAsync([order], taker);
    //     if (unwrapWeth) {
    //         return this.zeroEx.connect(originSigner)
    //             .fillTakerSignedOtcOrderForEth(
    //                 order,
    //                 await order.getSignatureWithProviderAsync(maker),
    //                 await order.getSignatureWithProviderAsync(taker, SignatureType.EthSign),
    //             );
    //     } else {
    //         return this.zeroEx.connect(originSigner)
    //             .fillTakerSignedOtcOrder(
    //                 order,
    //                 await order.getSignatureWithProviderAsync(maker),
    //                 await order.getSignatureWithProviderAsync(taker, SignatureType.EthSign),
    //             );
    //     }
    // }

    // public async fillOtcOrderWithEthAsync(
    //     order: OtcOrder,
    //     fillAmount: BigNumber | number = order.takerAmount,
    //     taker: SignerWithAddress = this.taker,
    // ): Promise<TransactionReceiptWithDecodedLogs> {
    //     await this.prepareBalancesForOrdersAsync([order], taker);
    //     const maker = await ethers.getSigner(order.maker)
    //     return this.zeroEx.connect(taker)
    //         .fillOtcOrderWithEth(
    //             order,
    //             await order.getSignatureWithProviderAsync(maker),
    //             { value: fillAmount }
    //         );
    // }

    public createLimitOrderFilledEventArgs(
        order: LimitOrder,
        takerTokenFillAmount: BigNumber = order.takerAmount,
        takerTokenAlreadyFilledAmount: BigNumber = ZERO,
    ): any {
        const { makerTokenFilledAmount, takerTokenFilledAmount, takerTokenFeeFilledAmount } =
            computeLimitOrderFilledAmounts(order, takerTokenFillAmount, takerTokenAlreadyFilledAmount);
        const protocolFee = order.taker !== NULL_ADDRESS ? ZERO : this.protocolFee;
        return {
            takerTokenFilledAmount,
            makerTokenFilledAmount,
            takerTokenFeeFilledAmount,
            orderHash: order.getHash(),
            maker: order.maker,
            taker: this.taker.address,
            feeRecipient: order.feeRecipient,
            makerToken: order.makerToken,
            takerToken: order.takerToken,
            protocolFeePaid: protocolFee,
            indexed: ['orderHash', 'maker', 'taker'],
            indexedTypes: ['bytes32', 'address', 'address']
        };
    }

    public createRfqOrderFilledEventArgs(
        order: RfqOrder,
        takerTokenFillAmount: BigNumber = order.takerAmount,
        takerTokenAlreadyFilledAmount: BigNumber = ZERO,
    ): any {
        const { makerTokenFilledAmount, takerTokenFilledAmount } = computeRfqOrderFilledAmounts(
            order,
            takerTokenFillAmount,
            takerTokenAlreadyFilledAmount,
        );
        return {
            takerTokenFilledAmount,
            makerTokenFilledAmount,
            orderHash: order.getHash(),
            maker: order.maker,
            taker: this.taker.address,
            makerToken: order.makerToken,
            takerToken: order.takerToken,
            indexed: ['orderHash', 'maker', 'taker'],
            indexedTypes: ['bytes32', 'address', 'address']
        };
    }

    public createOtcOrderFilledEventArgs(
        order: OtcOrder,
        takerTokenFillAmount: BigNumber = order.takerAmount,
    ): any {
        const { makerTokenFilledAmount, takerTokenFilledAmount } = computeOtcOrderFilledAmounts(
            order,
            takerTokenFillAmount,
        );
        return {
            takerTokenFilledAmount,
            makerTokenFilledAmount,
            orderHash: order.getHash(),
            maker: order.maker,
            taker: order.taker !== NULL_ADDRESS ? order.taker : this.taker,
            makerToken: order.makerToken,
            takerToken: order.takerToken,
            indexed: ['orderHash', 'maker', 'taker'],
            indexedTypes: ['bytes32', 'address', 'address']
        };
    }
}

/**
 * Generate a random limit order.
 */
export function getRandomLimitOrder(fields: Partial<LimitOrderFields> = {}): LimitOrder {
    return new LimitOrder({
        makerToken: randomAddress(),
        takerToken: randomAddress(),
        makerAmount: getRandomInteger('1e18', '100e18'),
        takerAmount: getRandomInteger('1e6', '100e6'),
        takerTokenFeeAmount: getRandomInteger('0.01e18', '1e18'),
        maker: randomAddress(),
        taker: randomAddress(),
        sender: randomAddress(),
        feeRecipient: randomAddress(),
        pool: hexUtils.random(),
        expiry: createExpiry(DEFAULT_EXPIRY),
        salt: BigNumber.from(hexUtils.random()),
        ...fields,
    });
}

/**
 * Generate a random RFQ order.
 */
export function getRandomRfqOrder(fields: Partial<RfqOrderFields> = {}): RfqOrder {
    return new RfqOrder({
        makerToken: randomAddress(),
        takerToken: randomAddress(),
        makerAmount: getRandomInteger('1e18', '100e18'),
        takerAmount: getRandomInteger('1e6', '100e6'),
        maker: randomAddress(),
        txOrigin: randomAddress(),
        pool: hexUtils.random(),
        expiry: createExpiry(DEFAULT_EXPIRY),
        salt: BigNumber.from(hexUtils.random()),
        ...fields,
    });
}

/**
 * Generate a random OTC Order
 */
export function getRandomOtcOrder(fields: Partial<OtcOrder> = {}): OtcOrder {
    return new OtcOrder({
        makerToken: randomAddress(),
        takerToken: randomAddress(),
        makerAmount: getRandomInteger('1e18', '100e18'),
        takerAmount: getRandomInteger('1e6', '100e6'),
        maker: randomAddress(),
        taker: randomAddress(),
        txOrigin: randomAddress(),
        expiryAndNonce: OtcOrder.encodeExpiryAndNonce(
            fields.expiry ?? createExpiry(DEFAULT_EXPIRY), // expiry
            fields.nonceBucket ?? getRandomInteger('0', OtcOrder.MAX_NONCE_BUCKET.toString()), // nonceBucket
            fields.nonce ?? getRandomInteger('0', OtcOrder.MAX_NONCE_VALUE.toString()), // nonce
        ),
        ...fields,
    });
}

/**
 * Asserts the fields of an OrderInfo object.
 */
export function assertOrderInfoEquals(actual: OrderInfo, expected: OrderInfo): void {
    expect(actual.status, 'Order status').to.eq(expected.status);
    expect(actual.orderHash, 'Order hash').to.eq(expected.orderHash);
    expect(actual.takerTokenFilledAmount.toString(), 'Order takerTokenFilledAmount').to.eq(
        expected.takerTokenFilledAmount.toString(),
    );
}

/**
 * Creates a simple order expiry field.
 */
export function createExpiry(deltaSeconds = 60): BigNumber {
    return BigNumber.from(Math.floor(Date.now() / 1000) + deltaSeconds);
}


/**
 * Creates an accurate order expiry field based on the current block timestamp.
 */
export async function createCleanExpiry(provider: MockProvider, deltaSeconds = 60): Promise<BigNumber> {
    return BigNumber.from((await provider.getBlock(await provider.getBlockNumber())).timestamp + deltaSeconds);
}



/**
 * Computes the maker, taker, and taker token fee amounts filled for
 * the given limit order.
 */
export function computeLimitOrderFilledAmounts(
    order: LimitOrder,
    takerTokenFillAmount: BigNumber = order.takerAmount,
    takerTokenAlreadyFilledAmount: BigNumber = ZERO,
): LimitOrderFilledAmounts {
    const fillAmount = minBn([
        order.takerAmount,
        takerTokenFillAmount,
        order.takerAmount.sub(takerTokenAlreadyFilledAmount),
    ]);
    const makerTokenFilledAmount = fillAmount
        .mul(order.makerAmount)
        .div(order.takerAmount);
    const takerTokenFeeFilledAmount = fillAmount
        .mul(order.takerTokenFeeAmount)
        .div(order.takerAmount);
    return {
        makerTokenFilledAmount,
        takerTokenFilledAmount: fillAmount,
        takerTokenFeeFilledAmount,
    };
}

/**
 * Computes the maker and taker amounts filled for the given RFQ order.
 */
export function computeRfqOrderFilledAmounts(
    order: RfqOrder,
    takerTokenFillAmount: BigNumber = order.takerAmount,
    takerTokenAlreadyFilledAmount: BigNumber = ZERO,
): RfqOrderFilledAmounts {
    const fillAmount = minBn([
        order.takerAmount,
        takerTokenFillAmount,
        order.takerAmount.sub(takerTokenAlreadyFilledAmount),
    ]);
    const makerTokenFilledAmount = fillAmount
        .mul(order.makerAmount)
        .div(order.takerAmount);
    return {
        makerTokenFilledAmount,
        takerTokenFilledAmount: fillAmount,
    };
}

/**
 * Computes the maker and taker amounts filled for the given OTC order.
 */
export function computeOtcOrderFilledAmounts(
    order: OtcOrder,
    takerTokenFillAmount: BigNumber = order.takerAmount,
): OtcOrderFilledAmounts {
    const fillAmount = minBn([order.takerAmount, takerTokenFillAmount, order.takerAmount]);
    const makerTokenFilledAmount = fillAmount
        .mul(order.makerAmount)
        .div(order.takerAmount);
    return {
        makerTokenFilledAmount,
        takerTokenFilledAmount: fillAmount,
    };
}

/**
 * Computes the remaining fillable amount in maker token for
 * the given order.
 */
export function getFillableMakerTokenAmount(
    order: LimitOrder | RfqOrder,
    takerTokenFilledAmount: BigNumber = ZERO,
): BigNumber {
    return order.takerAmount
        .sub(takerTokenFilledAmount)
        .mul(order.makerAmount)
        .div(order.takerAmount);
}

/**
 * Computes the remaining fillable amnount in taker token, based on
 * the amount already filled and the maker's balance/allowance.
 */
export function getActualFillableTakerTokenAmount(
    order: LimitOrder | RfqOrder,
    makerBalance: BigNumber = order.makerAmount,
    makerAllowance: BigNumber = order.makerAmount,
    takerTokenFilledAmount: BigNumber = ZERO,
): BigNumber {
    const fillableMakerTokenAmount = getFillableMakerTokenAmount(order, takerTokenFilledAmount);
    return minBn([fillableMakerTokenAmount, makerBalance, makerAllowance])
        .mul(order.takerAmount)
        .div(order.makerAmount)
        .add(1);
}
