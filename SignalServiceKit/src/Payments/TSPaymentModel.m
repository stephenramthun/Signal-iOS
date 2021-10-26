//
//  Copyright (c) 2021 Open Whisper Systems. All rights reserved.
//

#import "TSPaymentModel.h"
#import <SignalCoreKit/NSDate+OWS.h>
#import <SignalServiceKit/SignalServiceKit-Swift.h>

NS_ASSUME_NONNULL_BEGIN

@interface TSPaymentModel ()

@property (nonatomic) TSPaymentState paymentState;

@property (nonatomic) TSPaymentFailure paymentFailure;

@property (nonatomic, nullable) TSPaymentAmount *paymentAmount;

@property (nonatomic) uint64_t createdTimestamp;

@property (nonatomic, nullable) NSString *addressUuidString;

@property (nonatomic, nullable) NSString *memoMessage;

@property (nonatomic, nullable) NSString *requestUuidString;

@property (nonatomic) BOOL isUnread;

@property (nonatomic, nullable) MobileCoinPayment *mobileCoin;
@property (nonatomic) uint64_t mcLedgerBlockIndex;
@property (nonatomic, nullable) NSData *mcTransactionData;
@property (nonatomic, nullable) NSData *mcReceiptData;

@end

#pragma mark -

@interface MobileCoinPayment ()

@property (nonatomic) uint64_t ledgerBlockTimestamp;

@property (nonatomic) uint64_t ledgerBlockIndex;

+ (MobileCoinPayment *)copy:(nullable MobileCoinPayment *)oldCopy withLedgerBlockIndex:(uint64_t)ledgerBlockIndex;

+ (MobileCoinPayment *)copy:(nullable MobileCoinPayment *)oldCopy
    withLedgerBlockTimestamp:(uint64_t)ledgerBlockTimestamp;

@end

#pragma mark -

@implementation TSPaymentModel

- (instancetype)initWithPaymentType:(TSPaymentType)paymentType
                       paymentState:(TSPaymentState)paymentState
                      paymentAmount:(nullable TSPaymentAmount *)paymentAmount
                        createdDate:(NSDate *)createdDate
                  addressUuidString:(nullable NSString *)addressUuidString
                        memoMessage:(nullable NSString *)memoMessage
                  requestUuidString:(nullable NSString *)requestUuidString
                           isUnread:(BOOL)isUnread
                         mobileCoin:(MobileCoinPayment *)mobileCoin
{
    self = [super init];

    if (!self) {
        return self;
    }

    _paymentType = paymentType;
    _paymentState = paymentState;
    _paymentAmount = paymentAmount;
    _createdTimestamp = createdDate.ows_millisecondsSince1970;
    _addressUuidString = addressUuidString;
    _memoMessage = memoMessage;
    _requestUuidString = requestUuidString;
    _isUnread = isUnread;
    _mobileCoin = mobileCoin;

    _mcLedgerBlockIndex = mobileCoin.ledgerBlockIndex;
    _mcTransactionData = mobileCoin.transactionData;
    _mcReceiptData = mobileCoin.receiptData;

    OWSAssertDebug(self.isValid);

    OWSLogInfo(@"Creating payment model: %@", self.descriptionForLogs);

    return self;
}

- (nullable instancetype)initWithCoder:(NSCoder *)coder
{
    return [super initWithCoder:coder];
}

// --- CODE GENERATION MARKER

// This snippet is generated by /Scripts/sds_codegen/sds_generate.py. Do not manually edit it, instead run `sds_codegen.sh`.

// clang-format off

- (instancetype)initWithGrdbId:(int64_t)grdbId
                      uniqueId:(NSString *)uniqueId
               addressUuidString:(nullable NSString *)addressUuidString
                createdTimestamp:(uint64_t)createdTimestamp
                        isUnread:(BOOL)isUnread
              mcLedgerBlockIndex:(uint64_t)mcLedgerBlockIndex
                   mcReceiptData:(nullable NSData *)mcReceiptData
               mcTransactionData:(nullable NSData *)mcTransactionData
                     memoMessage:(nullable NSString *)memoMessage
                      mobileCoin:(nullable MobileCoinPayment *)mobileCoin
                   paymentAmount:(nullable TSPaymentAmount *)paymentAmount
                  paymentFailure:(TSPaymentFailure)paymentFailure
                    paymentState:(TSPaymentState)paymentState
                     paymentType:(TSPaymentType)paymentType
               requestUuidString:(nullable NSString *)requestUuidString
{
    self = [super initWithGrdbId:grdbId
                        uniqueId:uniqueId];

    if (!self) {
        return self;
    }

    _addressUuidString = addressUuidString;
    _createdTimestamp = createdTimestamp;
    _isUnread = isUnread;
    _mcLedgerBlockIndex = mcLedgerBlockIndex;
    _mcReceiptData = mcReceiptData;
    _mcTransactionData = mcTransactionData;
    _memoMessage = memoMessage;
    _mobileCoin = mobileCoin;
    _paymentAmount = paymentAmount;
    _paymentFailure = paymentFailure;
    _paymentState = paymentState;
    _paymentType = paymentType;
    _requestUuidString = requestUuidString;

    return self;
}

// clang-format on

// --- CODE GENERATION MARKER

- (NSDate *)createdDate
{
    return [NSDate ows_dateWithMillisecondsSince1970:self.createdTimestamp];
}

- (nullable NSUUID *)addressUuid
{
    if (self.addressUuidString == nil) {
        return nil;
    }
    return [[NSUUID alloc] initWithUUIDString:self.addressUuidString];
}

- (nullable SignalServiceAddress *)address
{
    if (self.addressUuid == nil) {
        return nil;
    }
    return [[SignalServiceAddress alloc] initWithUuid:self.addressUuid];
}

- (NSDate *)sortDate
{
    OWSAssertDebug(self.createdDate != nil);
    if (self.mcLedgerBlockDate != nil) {
        return self.mcLedgerBlockDate;
    }
    return self.createdDate;
}

- (void)updateWithPaymentState:(TSPaymentState)paymentState transaction:(SDSAnyWriteTransaction *)transaction
{
    OWSLogVerbose(@"[%@] paymentState: %@ -> %@",
        self.uniqueId,
        NSStringFromTSPaymentState(self.paymentState),
        NSStringFromTSPaymentState(paymentState));

    [self anyUpdateWithTransaction:transaction
                             block:^(TSPaymentModel *paymentModel) {
                                 OWSAssertDebug([PaymentUtils isIncomingPaymentState:paymentModel.paymentState] ==
                                     [PaymentUtils isIncomingPaymentState:paymentState]);
                                 paymentModel.paymentState = paymentState;
                             }];
}

- (void)updateWithMCLedgerBlockIndex:(uint64_t)ledgerBlockIndex transaction:(SDSAnyWriteTransaction *)transaction
{
    OWSAssertDebug(ledgerBlockIndex > 0);

    [self anyUpdateWithTransaction:transaction
                             block:^(TSPaymentModel *paymentModel) {
                                 OWSAssertDebug(!paymentModel.hasMCLedgerBlockIndex);
                                 paymentModel.mobileCoin = [MobileCoinPayment copy:paymentModel.mobileCoin
                                                              withLedgerBlockIndex:ledgerBlockIndex];
                                 paymentModel.mcLedgerBlockIndex = ledgerBlockIndex;
                                 OWSAssertDebug(paymentModel.mobileCoin != nil);
                             }];
}

- (void)updateWithMCLedgerBlockTimestamp:(uint64_t)ledgerBlockTimestamp
                             transaction:(SDSAnyWriteTransaction *)transaction
{
    OWSAssertDebug(ledgerBlockTimestamp > 0);

    if (SSKDebugFlags.paymentsIgnoreBlockTimestamps.get) {
        OWSLogInfo(@"Ignoring ledger timestamp.");
        return;
    }

    [self anyUpdateWithTransaction:transaction
                             block:^(TSPaymentModel *paymentModel) {
                                 OWSAssertDebug(!paymentModel.hasMCLedgerBlockTimestamp);
                                 paymentModel.mobileCoin = [MobileCoinPayment copy:paymentModel.mobileCoin
                                                          withLedgerBlockTimestamp:ledgerBlockTimestamp];
                                 OWSAssertDebug(paymentModel.mobileCoin != nil);
                             }];
}

- (void)updateWithPaymentFailure:(TSPaymentFailure)paymentFailure
                    paymentState:(TSPaymentState)paymentState
                     transaction:(SDSAnyWriteTransaction *)transaction
{
    OWSAssertDebug(paymentFailure != TSPaymentFailureNone);
    OWSAssertDebug(paymentState == TSPaymentStateIncomingFailed || paymentState == TSPaymentStateOutgoingFailed);

    OWSLogVerbose(@"[%@] paymentState: %@, paymentFailure: %@",
        self.uniqueId,
        NSStringFromTSPaymentState(paymentState),
        NSStringFromTSPaymentFailure(paymentFailure));

    [self anyUpdateWithTransaction:transaction
                             block:^(TSPaymentModel *paymentModel) {
                                 OWSAssertDebug([PaymentUtils isIncomingPaymentState:paymentModel.paymentState] ==
                                     [PaymentUtils isIncomingPaymentState:paymentState]);

                                 paymentModel.paymentState = paymentState;
                                 paymentModel.paymentFailure = paymentFailure;

                                 // Scrub any MC state associated with the failure payment.
                                 paymentModel.mobileCoin = nil;
                                 paymentModel.mcLedgerBlockIndex = 0;
                                 paymentModel.mcTransactionData = nil;
                                 paymentModel.mcReceiptData = nil;
                             }];
}

- (void)updateWithPaymentAmount:(TSPaymentAmount *)paymentAmount transaction:(SDSAnyWriteTransaction *)transaction
{
    [self anyUpdateWithTransaction:transaction
                             block:^(TSPaymentModel *paymentModel) {
                                 OWSAssertDebug(paymentModel.paymentAmount == nil
                                     || (paymentModel.paymentAmount.currency == paymentAmount.currency
                                         && paymentModel.paymentAmount.picoMob == paymentAmount.picoMob));
                                 paymentModel.paymentAmount = paymentAmount;
                             }];
}

- (void)updateWithIsUnread:(BOOL)isUnread transaction:(SDSAnyWriteTransaction *)transaction
{
    [self anyUpdateWithTransaction:transaction
                             block:^(TSPaymentModel *paymentModel) { paymentModel.isUnread = isUnread; }];
}

#pragma mark -

- (void)anyWillInsertWithTransaction:(SDSAnyWriteTransaction *)transaction
{
    OWSAssertDebug(self.isValid);

    [super anyWillInsertWithTransaction:transaction];

    [self.payments willInsertPayment:self transaction:transaction];
}

- (void)anyDidInsertWithTransaction:(SDSAnyWriteTransaction *)transaction
{
    OWSAssertDebug(self.isValid);

    [super anyDidInsertWithTransaction:transaction];
}

- (void)anyWillUpdateWithTransaction:(SDSAnyWriteTransaction *)transaction
{
    OWSAssertDebug(self.isValid);

    [super anyWillUpdateWithTransaction:transaction];

    [self.payments willUpdatePayment:self transaction:transaction];
}

- (void)anyDidUpdateWithTransaction:(SDSAnyWriteTransaction *)transaction
{
    OWSAssertDebug(self.isValid);

    [super anyDidUpdateWithTransaction:transaction];
}

@end

#pragma mark -

@implementation MobileCoinPayment

- (instancetype)initWithRecipientPublicAddressData:(nullable NSData *)recipientPublicAddressData
                                   transactionData:(nullable NSData *)transactionData
                                       receiptData:(nullable NSData *)receiptData
                     incomingTransactionPublicKeys:(nullable NSArray<NSData *> *)incomingTransactionPublicKeys
                                    spentKeyImages:(nullable NSArray<NSData *> *)spentKeyImages
                                  outputPublicKeys:(nullable NSArray<NSData *> *)outputPublicKeys
                              ledgerBlockTimestamp:(uint64_t)ledgerBlockTimestamp
                                  ledgerBlockIndex:(uint64_t)ledgerBlockIndex
                                         feeAmount:(nullable TSPaymentAmount *)feeAmount
{
    self = [super init];

    if (!self) {
        return self;
    }

    _recipientPublicAddressData = recipientPublicAddressData;
    _transactionData = transactionData;
    _receiptData = receiptData;
    _incomingTransactionPublicKeys = incomingTransactionPublicKeys;
    _spentKeyImages = spentKeyImages;
    _outputPublicKeys = outputPublicKeys;
    _ledgerBlockTimestamp = ledgerBlockTimestamp;
    _ledgerBlockIndex = ledgerBlockIndex;
    _feeAmount = feeAmount;

    return self;
}

- (nullable NSDate *)ledgerBlockDate
{
    if (self.ledgerBlockTimestamp > 0) {
        return [NSDate ows_dateWithMillisecondsSince1970:self.ledgerBlockTimestamp];
    } else {
        return nil;
    }
}

+ (MobileCoinPayment *)copy:(nullable MobileCoinPayment *)oldCopy withLedgerBlockIndex:(uint64_t)ledgerBlockIndex
{
    OWSAssertDebug(ledgerBlockIndex > 0);

    MobileCoinPayment *newCopy = (oldCopy != nil ? [oldCopy copy] : [MobileCoinPayment new]);
    newCopy.ledgerBlockIndex = ledgerBlockIndex;
    return newCopy;
}

+ (MobileCoinPayment *)copy:(nullable MobileCoinPayment *)oldCopy
    withLedgerBlockTimestamp:(uint64_t)ledgerBlockTimestamp
{
    OWSAssertDebug(ledgerBlockTimestamp > 0);

    MobileCoinPayment *newCopy = (oldCopy != nil ? [oldCopy copy] : [MobileCoinPayment new]);
    newCopy.ledgerBlockTimestamp = ledgerBlockTimestamp;
    return newCopy;
}


@end

NS_ASSUME_NONNULL_END
