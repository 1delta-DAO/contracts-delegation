import { getContractAddressesForChainOrThrow } from '@0x/contract-addresses';
import { EIP712TypedData } from '@0x/types';
import { hexUtils, NULL_ADDRESS } from '@0x/utils';

import {
    createExchangeProxyEIP712Domain,
    EIP712_DOMAIN_PARAMETERS,
    getExchangeProxyEIP712Hash,
    getTypeHash,
} from './eip712_utils';
import {
    eip712SignTypedDataWithKey,
    eip712SignTypedDataWithProviderAsync,
    ethSignHashWithKey,
    ethSignHashWithProviderAsync,
    Signature,
    SignatureType,
} from './signature_utils';
import { BigNumber } from 'ethers';
import { toInteger } from 'lodash';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';


export const ETH_TOKEN_ADDRESS = '0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
export const ZERO = BigNumber.from(0);

export enum OrderEvents {
    ERC1155OrderCancelled = 'ERC1155OrderCancelled',
    ERC1155OrderFilled = 'ERC1155OrderFilled',
    ERC1155OrderPreSigned = 'ERC1155OrderPreSigned',
    ERC721OrderCancelled = 'ERC721OrderCancelled',
    ERC721OrderFilled = 'ERC721OrderFilled',
    ERC721OrderPreSigned = 'ERC721OrderPreSigned',
    LimitOrderFilled = 'LimitOrderFilled',
    LiquidityProviderSwap = 'LiquidityProviderSwap',
    MetaTransactionExecuted = 'MetaTransactionExecuted',
    Migrated = 'Migrated',
    OrderCancelled = 'OrderCancelled',
    OrderSignerRegistered = 'OrderSignerRegistered',
    OtcOrderFilled = 'OtcOrderFilled',
    OwnershipTransferred = 'OwnershipTransferred',
    PairCancelledLimitOrders = 'PairCancelledLimitOrders',
    PairCancelledRfqOrders = 'PairCancelledRfqOrders',
    ProxyFunctionUpdated = 'ProxyFunctionUpdated',
    QuoteSignerUpdated = 'QuoteSignerUpdated',
    RfqOrderFilled = 'RfqOrderFilled',
    RfqOrderOriginsAllowed = 'RfqOrderOriginsAllowed',
    TransformedERC20 = 'TransformedERC20',
    TransformerDeployerUpdated = 'TransformerDeployerUpdated',
}

const COMMON_ORDER_DEFAULT_VALUES = {
    makerToken: NULL_ADDRESS,
    takerToken: NULL_ADDRESS,
    makerAmount: ZERO,
    takerAmount: ZERO,
    maker: NULL_ADDRESS,
    taker: NULL_ADDRESS,
    chainId: 1,
    verifyingContract: getContractAddressesForChainOrThrow(1).exchangeProxy,
};
const LIMIT_ORDER_DEFAULT_VALUES = {
    ...COMMON_ORDER_DEFAULT_VALUES,
    takerTokenFeeAmount: ZERO,
    sender: NULL_ADDRESS,
    feeRecipient: NULL_ADDRESS,
    expiry: ZERO,
    pool: hexUtils.leftPad(0),
    salt: ZERO,
};
const RFQ_ORDER_DEFAULT_VALUES = {
    ...COMMON_ORDER_DEFAULT_VALUES,
    txOrigin: NULL_ADDRESS,
    expiry: ZERO,
    pool: hexUtils.leftPad(0),
    salt: ZERO,
};
const OTC_ORDER_DEFAULT_VALUES = {
    ...COMMON_ORDER_DEFAULT_VALUES,
    txOrigin: NULL_ADDRESS,
    expiryAndNonce: ZERO,
};

const BRIDGE_ORDER_DEFAULT_VALUES = {
    source: ZERO,
    takerTokenAmount: ZERO,
    makerTokenAmount: ZERO,
    bridgeData: '',
};

export type CommonOrderFields = typeof COMMON_ORDER_DEFAULT_VALUES;
export type LimitOrderFields = typeof LIMIT_ORDER_DEFAULT_VALUES;
export type RfqOrderFields = typeof RFQ_ORDER_DEFAULT_VALUES;
export type OtcOrderFields = typeof OTC_ORDER_DEFAULT_VALUES;
export type BridgeOrderFields = typeof BRIDGE_ORDER_DEFAULT_VALUES;
export type NativeOrder = RfqOrder | LimitOrder;

export enum OrderStatus {
    Invalid = 0,
    Fillable = 1,
    Filled = 2,
    Cancelled = 3,
    Expired = 4,
}

export interface OrderInfo {
    status: OrderStatus;
    orderHash: string;
    takerTokenFilledAmount: BigNumber;
}

export interface OtcOrderInfo {
    status: OrderStatus;
    orderHash: string;
}

export abstract class OrderBase {
    public makerToken: string;
    public takerToken: string;
    public makerAmount: BigNumber;
    public takerAmount: BigNumber;
    public maker: string;
    public taker: string;
    public chainId: number;
    public verifyingContract: string;

    protected constructor(fields: Partial<CommonOrderFields> = {}) {
        const _fields = { ...COMMON_ORDER_DEFAULT_VALUES, ...fields };
        this.makerToken = _fields.makerToken;
        this.takerToken = _fields.takerToken;
        this.makerAmount = _fields.makerAmount;
        this.takerAmount = _fields.takerAmount;
        this.maker = _fields.maker;
        this.taker = _fields.taker;
        this.chainId = _fields.chainId;
        this.verifyingContract = _fields.verifyingContract;
    }

    public abstract getStructHash(): string;
    public abstract getEIP712TypedData(): EIP712TypedData;
    public abstract willExpire(secondsFromNow: number): boolean;

    public getHash(): string {
        return getExchangeProxyEIP712Hash(this.getStructHash(), this.chainId, this.verifyingContract);
    }

    public async getSignatureWithProviderAsync(
        signer: SignerWithAddress,
        type: SignatureType = SignatureType.EthSign,
    ): Promise<Signature> {
        switch (type) {
            case SignatureType.EIP712:
                return eip712SignTypedDataWithProviderAsync(this.getEIP712TypedData(), signer);
            case SignatureType.EthSign:
                return ethSignHashWithProviderAsync(this.getHash(), signer);
            default:
                throw new Error(`Cannot sign with signature type: ${type}`);
        }
    }

    public getSignatureWithKey(key: string, type: SignatureType = SignatureType.EthSign): Signature {
        switch (type) {
            case SignatureType.EIP712:
                return eip712SignTypedDataWithKey(this.getEIP712TypedData(), key);
            case SignatureType.EthSign:
                return ethSignHashWithKey(this.getHash(), key);
            default:
                throw new Error(`Cannot sign with signature type: ${type}`);
        }
    }
}

export class LimitOrder extends OrderBase {
    public static readonly STRUCT_NAME = 'LimitOrder';
    public static readonly STRUCT_ABI = [
        { type: 'address', name: 'makerToken' },
        { type: 'address', name: 'takerToken' },
        { type: 'uint128', name: 'makerAmount' },
        { type: 'uint128', name: 'takerAmount' },
        { type: 'uint128', name: 'takerTokenFeeAmount' },
        { type: 'address', name: 'maker' },
        { type: 'address', name: 'taker' },
        { type: 'address', name: 'sender' },
        { type: 'address', name: 'feeRecipient' },
        { type: 'uint64', name: 'expiry' },
        { type: 'uint256', name: 'salt' },
    ];
    public static readonly TYPE_HASH = getTypeHash(LimitOrder.STRUCT_NAME, LimitOrder.STRUCT_ABI);

    public takerTokenFeeAmount: BigNumber;
    public sender: string;
    public feeRecipient: string;
    public pool: string;
    public salt: BigNumber;
    public expiry: BigNumber;

    constructor(fields: Partial<LimitOrderFields> = {}) {
        const _fields = { ...LIMIT_ORDER_DEFAULT_VALUES, ...fields };
        super(_fields);
        this.takerTokenFeeAmount = _fields.takerTokenFeeAmount;
        this.sender = _fields.sender;
        this.feeRecipient = _fields.feeRecipient;
        this.pool = _fields.pool;
        this.salt = _fields.salt;
        this.expiry = _fields.expiry;
    }

    public clone(fields: Partial<LimitOrderFields> = {}): LimitOrder {
        return new LimitOrder({
            makerToken: this.makerToken,
            takerToken: this.takerToken,
            makerAmount: this.makerAmount,
            takerAmount: this.takerAmount,
            takerTokenFeeAmount: this.takerTokenFeeAmount,
            maker: this.maker,
            taker: this.taker,
            sender: this.sender,
            feeRecipient: this.feeRecipient,
            pool: this.pool,
            expiry: this.expiry,
            salt: this.salt,
            chainId: this.chainId,
            verifyingContract: this.verifyingContract,
            ...fields,
        });
    }

    public getStructHash(): string {
        return hexUtils.hash(
            hexUtils.concat(
                hexUtils.leftPad(LimitOrder.TYPE_HASH),
                hexUtils.leftPad(this.makerToken),
                hexUtils.leftPad(this.takerToken),
                hexUtils.leftPad(this.makerAmount.toString()),
                hexUtils.leftPad(this.takerAmount.toString()),
                hexUtils.leftPad(this.takerTokenFeeAmount.toString()),
                hexUtils.leftPad(this.maker),
                hexUtils.leftPad(this.taker),
                hexUtils.leftPad(this.sender),
                hexUtils.leftPad(this.feeRecipient),
                hexUtils.leftPad(this.expiry.toString()),
                hexUtils.leftPad(this.salt.toString()),
            ),
        );
    }

    public getEIP712TypedData(): EIP712TypedData {
        return {
            types: {
                EIP712Domain: EIP712_DOMAIN_PARAMETERS,
                [LimitOrder.STRUCT_NAME]: LimitOrder.STRUCT_ABI,
            },
            domain: createExchangeProxyEIP712Domain(this.chainId, this.verifyingContract) as any,
            primaryType: LimitOrder.STRUCT_NAME,
            message: {
                makerToken: this.makerToken,
                takerToken: this.takerToken,
                makerAmount: this.makerAmount.toString(),
                takerAmount: this.takerAmount.toString(),
                takerTokenFeeAmount: this.takerTokenFeeAmount.toString(),
                maker: this.maker,
                taker: this.taker,
                sender: this.sender,
                feeRecipient: this.feeRecipient,
                expiry: this.expiry.toString(),
                salt: this.salt.toString(),
            },
        };
    }

    public willExpire(secondsFromNow = 0): boolean {
        const millisecondsInSecond = 1000;
        const currentUnixTimestampSec = BigNumber.from(toInteger(Date.now() / millisecondsInSecond));
        return this.expiry.lt(currentUnixTimestampSec.add(secondsFromNow));
    }
}

export class RfqOrder extends OrderBase {
    public static readonly STRUCT_NAME = 'RfqOrder';
    public static readonly STRUCT_ABI = [
        { type: 'address', name: 'makerToken' },
        { type: 'address', name: 'takerToken' },
        { type: 'uint128', name: 'makerAmount' },
        { type: 'uint128', name: 'takerAmount' },
        { type: 'address', name: 'maker' },
        { type: 'address', name: 'taker' },
        { type: 'address', name: 'txOrigin' },
        { type: 'uint64', name: 'expiry' },
        { type: 'uint256', name: 'salt' },
    ];
    public static readonly TYPE_HASH = getTypeHash(RfqOrder.STRUCT_NAME, RfqOrder.STRUCT_ABI);

    public txOrigin: string;
    public pool: string;
    public salt: BigNumber;
    public expiry: BigNumber;

    constructor(fields: Partial<RfqOrderFields> = {}) {
        const _fields = { ...RFQ_ORDER_DEFAULT_VALUES, ...fields };
        super(_fields);
        this.txOrigin = _fields.txOrigin;
        this.pool = _fields.pool;
        this.salt = _fields.salt;
        this.expiry = _fields.expiry;
    }

    public clone(fields: Partial<RfqOrderFields> = {}): RfqOrder {
        return new RfqOrder({
            makerToken: this.makerToken,
            takerToken: this.takerToken,
            makerAmount: this.makerAmount,
            takerAmount: this.takerAmount,
            maker: this.maker,
            taker: this.taker,
            txOrigin: this.txOrigin,
            pool: this.pool,
            expiry: this.expiry,
            salt: this.salt,
            chainId: this.chainId,
            verifyingContract: this.verifyingContract,
            ...fields,
        });
    }

    public getStructHash(): string {
        return hexUtils.hash(
            hexUtils.concat(
                hexUtils.leftPad(RfqOrder.TYPE_HASH),
                hexUtils.leftPad(this.makerToken),
                hexUtils.leftPad(this.takerToken),
                hexUtils.leftPad(this.makerAmount.toString()),
                hexUtils.leftPad(this.takerAmount.toString()),
                hexUtils.leftPad(this.maker),
                hexUtils.leftPad(this.taker),
                hexUtils.leftPad(this.txOrigin),
                hexUtils.leftPad(this.expiry.toString()),
                hexUtils.leftPad(this.salt.toString()),
            ),
        );
    }

    public getEIP712TypedData(): EIP712TypedData {
        return {
            types: {
                EIP712Domain: EIP712_DOMAIN_PARAMETERS,
                [RfqOrder.STRUCT_NAME]: RfqOrder.STRUCT_ABI,
            },
            domain: createExchangeProxyEIP712Domain(this.chainId, this.verifyingContract) as any,
            primaryType: RfqOrder.STRUCT_NAME,
            message: {
                makerToken: this.makerToken,
                takerToken: this.takerToken,
                makerAmount: this.makerAmount.toString(),
                takerAmount: this.takerAmount.toString(),
                maker: this.maker,
                taker: this.taker,
                txOrigin: this.txOrigin,
                pool: this.pool,
                expiry: this.expiry.toString(),
                salt: this.salt.toString(),
            },
        };
    }

    public willExpire(secondsFromNow = 0): boolean {
        const millisecondsInSecond = 1000;
        const currentUnixTimestampSec = BigNumber.from(toInteger(Date.now() / millisecondsInSecond));
        return this.expiry.lt(currentUnixTimestampSec.add(secondsFromNow));
    }
}

export class OtcOrder extends OrderBase {
    public static readonly STRUCT_NAME = 'OtcOrder';
    public static readonly STRUCT_ABI = [
        { type: 'address', name: 'makerToken' },
        { type: 'address', name: 'takerToken' },
        { type: 'uint128', name: 'makerAmount' },
        { type: 'uint128', name: 'takerAmount' },
        { type: 'address', name: 'maker' },
        { type: 'address', name: 'taker' },
        { type: 'address', name: 'txOrigin' },
        { type: 'uint256', name: 'expiryAndNonce' },
    ];
    public static readonly TYPE_HASH = getTypeHash(OtcOrder.STRUCT_NAME, OtcOrder.STRUCT_ABI);
    public static readonly MAX_EXPIRY = BigNumber.from(2).pow(64).sub(1);
    public static readonly MAX_NONCE_BUCKET = BigNumber.from(2).pow(64).sub(1);
    public static readonly MAX_NONCE_VALUE = BigNumber.from(2).pow(128).sub(1);

    public txOrigin: string;
    public expiryAndNonce: BigNumber;
    public expiry: BigNumber;
    public nonceBucket: BigNumber;
    public nonce: BigNumber;

    public static parseExpiryAndNonce(expiryAndNonce: BigNumber): {
        expiry: BigNumber;
        nonceBucket: BigNumber;
        nonce: BigNumber;
    } {
        const expiryAndNonceHex = hexUtils.leftPad(expiryAndNonce.toString());
        const expiry = BigNumber.from('0x' + hexUtils.slice(expiryAndNonceHex, 0, 8).substr(2));
        const nonceBucket = BigNumber.from('0x' + hexUtils.slice(expiryAndNonceHex, 8, 16).substr(2));
        const nonce = BigNumber.from('0x' + hexUtils.slice(expiryAndNonceHex, 16, 32).substr(2));
        return {
            expiry,
            nonceBucket,
            nonce,
        };
    }

    public static encodeExpiryAndNonce(expiry: BigNumber, nonceBucket: BigNumber, nonce: BigNumber): BigNumber {
        if (expiry.lt(0) || expiry.gt(this.MAX_EXPIRY)) {
            throw new Error('Expiry out of range');
        }
        if (nonceBucket.lt(0) || nonceBucket.gt(this.MAX_NONCE_BUCKET)) {
            throw new Error('Nonce bucket out of range');
        }
        if (nonce.lt(0) || nonce.gt(this.MAX_NONCE_VALUE)) {
            throw new Error('Nonce out of range');
        }
        return BigNumber.from( '0x' +
            hexUtils
                .concat(
                    hexUtils.leftPad(expiry.toString(), 8),
                    hexUtils.leftPad(nonceBucket.toString(), 8),
                    hexUtils.leftPad(nonce.toString(), 16)
                )
                .substr(2),

        );
    }

    constructor(fields: Partial<OtcOrderFields> = {}) {
        const _fields = { ...OTC_ORDER_DEFAULT_VALUES, ...fields };
        super(_fields);
        this.txOrigin = _fields.txOrigin;
        this.expiryAndNonce = _fields.expiryAndNonce;
        const { expiry, nonceBucket, nonce } = OtcOrder.parseExpiryAndNonce(_fields.expiryAndNonce);
        this.expiry = expiry;
        this.nonceBucket = nonceBucket;
        this.nonce = nonce;
    }

    public clone(fields: Partial<OtcOrder> = {}): OtcOrder {
        return new OtcOrder({
            makerToken: this.makerToken,
            takerToken: this.takerToken,
            makerAmount: this.makerAmount,
            takerAmount: this.takerAmount,
            maker: this.maker,
            taker: this.taker,
            txOrigin: this.txOrigin,
            expiryAndNonce: this.expiryAndNonce,
            chainId: this.chainId,
            verifyingContract: this.verifyingContract,
            ...fields,
        });
    }

    public getStructHash(): string {
        return hexUtils.hash(
            hexUtils.concat(
                hexUtils.leftPad(OtcOrder.TYPE_HASH),
                hexUtils.leftPad(this.makerToken),
                hexUtils.leftPad(this.takerToken),
                hexUtils.leftPad(this.makerAmount.toString()),
                hexUtils.leftPad(this.takerAmount.toString()),
                hexUtils.leftPad(this.maker),
                hexUtils.leftPad(this.taker),
                hexUtils.leftPad(this.txOrigin),
                hexUtils.leftPad(this.expiryAndNonce.toString()),
            ),
        );
    }

    public getEIP712TypedData(): EIP712TypedData {
        return {
            types: {
                EIP712Domain: EIP712_DOMAIN_PARAMETERS,
                [OtcOrder.STRUCT_NAME]: OtcOrder.STRUCT_ABI,
            },
            domain: createExchangeProxyEIP712Domain(this.chainId, this.verifyingContract) as any,
            primaryType: OtcOrder.STRUCT_NAME,
            message: {
                makerToken: this.makerToken,
                takerToken: this.takerToken,
                makerAmount: this.makerAmount.toString(),
                takerAmount: this.takerAmount.toString(),
                maker: this.maker,
                taker: this.taker,
                txOrigin: this.txOrigin,
                expiryAndNonce: this.expiryAndNonce.toString(),
            },
        };
    }

    public willExpire(secondsFromNow = 0): boolean {
        const millisecondsInSecond = 1000;
        const currentUnixTimestampSec = BigNumber.from(toInteger(Date.now() / millisecondsInSecond));
        const expiryRightShift = BigNumber.from(2).pow(192);
        const expiry = this.expiryAndNonce.div(expiryRightShift);
        return expiry.lt(currentUnixTimestampSec.add(secondsFromNow));
    }
}
