import {
    constants,
    expect,
    randomAddress,
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
import { TransactionReceiptWithDecodedLogs } from 'ethereum-types';


import { SignatureType } from './signature_utils';
import { MockERC20, MockERC20__factory, NativeOrders } from '../../../../types';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { MaxUint128 } from '../../../uniswap-v3/periphery/shared/constants';
import { minBn, sumBn } from './utils';
import { BigNumber, ContractTransaction } from 'ethers';
import { ethers, waffle } from 'hardhat';
import { createNativeOrder } from '../orderFixture';

const { ZERO_AMOUNT, NULL_ADDRESS } = constants;


const getRandomInteger = (min: number, max: number, decs = 18) => {
    const randNum = Math.round((Math.random() * (max - min) + min) * 1e6) / 1e6;
    return ethers.utils.parseUnits(randNum.toString(), decs);
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
    ): Promise<ContractTransaction> {
        const { fillAmount, taker, protocolFee } = {
            taker: this.taker,
            fillAmount: order.takerAmount,
            ...opts,
        };
        await this.prepareBalancesForOrdersAsync([order], taker);
        const value = protocolFee === undefined ? this.protocolFee : protocolFee;
        const maker = await ethers.getSigner(order.maker)
        return this.zeroEx.connect(taker)
            .fillLimitOrder(
                order,
                await order.getSignatureWithProviderAsync(maker),
                BigNumber.from(fillAmount),
                { value, gasPrice: this.gasPrice }
            );
    }

    public async fillRfqOrderAsync(
        order: RfqOrder,
        fillAmount: BigNumber | number = order.takerAmount,
        taker: SignerWithAddress = this.taker,
    ): Promise<any> {
        await this.prepareBalancesForOrdersAsync([order], taker);
        const maker = await ethers.getSigner(order.maker)
        return this.zeroEx.connect(taker)
            .fillRfqOrder(
                order,
                await order.getSignatureWithProviderAsync(maker),
                BigNumber.from(fillAmount),
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
            pool: order.pool,
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
            pool: order.pool,
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
        makerAmount: getRandomInteger(1, 100, 18),
        takerAmount: getRandomInteger(1, 100, 6),
        takerTokenFeeAmount: getRandomInteger(0.01, 1, 18),
        maker: randomAddress(),
        taker: randomAddress(),
        sender: randomAddress(),
        feeRecipient: randomAddress(),
        pool: hexUtils.random(),
        expiry: createExpiry(60 * 60),
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
        makerAmount: getRandomInteger(1, 100, 18),
        takerAmount: getRandomInteger(1, 100, 6),
        maker: randomAddress(),
        txOrigin: randomAddress(),
        pool: hexUtils.random(),
        expiry: createExpiry(60 * 60),
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
        makerAmount: getRandomInteger(1, 100, 18),
        takerAmount: getRandomInteger(1, 100, 6),
        maker: randomAddress(),
        taker: randomAddress(),
        txOrigin: randomAddress(),
        expiryAndNonce: OtcOrder.encodeExpiryAndNonce(
            fields.expiry ?? createExpiry(60 * 60), // expiry
            fields.nonceBucket ?? getRandomInteger(0, OtcOrder.MAX_NONCE_BUCKET.toNumber(), 0), // nonceBucket
            fields.nonce ?? getRandomInteger(0, OtcOrder.MAX_NONCE_VALUE.toNumber(), 0), // nonce
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
 * Creates an order expiry field.
 */
export function createExpiry(deltaSeconds = 60): BigNumber {
    return BigNumber.from(Math.floor(Date.now() / 1000) + deltaSeconds);
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
        .div(order.takerAmount)
        .sub(1);
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
        .div(order.takerAmount)
        .sub(1);
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
        .div(order.takerAmount)
        .sub(1);
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
