//
//  TransactionManager.m
//  qtum wallet
//
//  Created by Sharaev Vladimir on 02.11.16.
//  Copyright © 2016 PixelPlex. All rights reserved.
//

#import "TransactionManager.h"
#import "RequestManager.h"
#import "RPCRequestManager.h"
#import "NSString+Extension.h"
#import "BTCTransactionInput+Extension.h"
#import "BTCTransactionOutput+Address.h"
#import "ContractInterfaceManager.h"
#import "NS+BTCBase58.h"
#import "ContractArgumentsInterpretator.h"
#import "WalletManagerRequestAdapter.h"
#import "Wallet.h"
#import "NSNumber+Comparison.h"
#import "NSNumber+Comparison.h"

static double FEE = 10000000;
static NSString* op_exec = @"c1";

@interface TransactionManager ()

@end

@implementation TransactionManager

+ (instancetype)sharedInstance {
    
    static TransactionManager *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[super alloc] initUniqueInstance];
    });
    return instance;
}

- (instancetype)initUniqueInstance {
    
    self = [super init];
    return self;
}


-(NSArray*)getAddressesFromKeys:(NSArray<BTCKey*>*) keys{
    
    NSMutableArray *addresesForSending = [NSMutableArray new];
    
    for (BTCKey *key in keys) {
        
        NSString* keyString = [AppSettings sharedInstance].isMainNet ? key.address.string : key.addressTestnet.string;
        [addresesForSending addObject:keyString];
    }
    
    NSAssert(addresesForSending.count > 0, @"There is no addresses in keys");
    
    return addresesForSending;
}

- (void)sendTransactionWalletKeys:(NSArray<BTCKey*> *)walletKeys
               toAddressAndAmount:(NSArray *)amountsAndAddresses
                       andHandler:(void(^)(TransactionManagerErrorType errorType, id response))completion {
    
    NSAssert(amountsAndAddresses && walletKeys.count > 0, @"Amount and address must be not nil, from addresses must be grater then one");
    
    __weak typeof(self) weakSelf = self;
    NSArray* walletAddreses = [self getAddressesFromKeys:walletKeys];
    NSDictionary* allPreparedValues = [self createAmountsAndAddresses:amountsAndAddresses];
    
    if (!allPreparedValues) {
        completion(TransactionManagerErrorTypeInvalidAddress, nil);
        return;
    }
    
    BTCAmount amount = [allPreparedValues[@"totalAmount"] doubleValue];
    NSArray* preparedAmountAndAddreses = allPreparedValues[@"amountsAndAddresses"];
    
    [[ApplicationCoordinator sharedInstance].walletManager.requestAdapter getunspentOutputs:walletAddreses withSuccessHandler:^(NSArray <BTCTransactionOutput*>*responseObject) {
        
        [weakSelf regularTransactionWithUnspentOutputs:responseObject amount:amount amountAndAddresses:preparedAmountAndAddreses walletKeys:walletKeys andHandler:^(TransactionManagerErrorType errorType, BTCTransaction *transaction) {
            if (errorType == TransactionManagerErrorTypeNone) {
                [weakSelf sendTransaction:transaction withSuccess:^(id response){
                    completion(TransactionManagerErrorTypeNone, response);
                } andFailure:^(NSString *message) {
                    completion(TransactionManagerErrorTypeServer, message);
                }];
            } else {
                completion(errorType, nil);
            }
        }];
    } andFailureHandler:^(NSError *error, NSString *message) {
        completion([error isNoInternetConnectionError] ? TransactionManagerErrorTypeNoInternetConnection :TransactionManagerErrorTypeServer, nil);
    }];
}

- (void)sendTransactionToToken:(Contract *)token
                     toAddress:(NSString *)toAddress
                        amount:(NSNumber *)amount
                    andHandler:(void(^)(TransactionManagerErrorType errorType, BTCTransaction * transaction, NSString* hashTransaction)) completion {
    
    // Checking address
    BTCPublicKeyAddress *address = [BTCPublicKeyAddress addressWithString:toAddress];
    if (!address) {
        completion(TransactionManagerErrorTypeInvalidAddress, nil, nil);
    }
    
    AbiinterfaceItem* transferMethod = [[ContractInterfaceManager sharedInstance] tokenStandartTransferMethodInterface];
    NSData* hashFuction = [[ContractInterfaceManager sharedInstance] hashOfFunction:transferMethod appendingParam:@[toAddress,amount]];
    NSString* __block addressWithAmountValue;
    [token.addressBalanceDictionary enumerateKeysAndObjectsUsingBlock:^(NSString* address, NSNumber* balance, BOOL * _Nonnull stop) {
        if ([balance isGreaterThan:amount]) {
            addressWithAmountValue = address;
            *stop = YES;
        }
    }];
    
    if (addressWithAmountValue) {
        [[[self class] sharedInstance] callTokenWithAddress:[NSString dataFromHexString:token.contractAddress] andBitcode:hashFuction fromAddresses:@[addressWithAmountValue] toAddress:nil walletKeys:[ApplicationCoordinator sharedInstance].walletManager.wallet.allKeys andHandler:^(NSError *error, BTCTransaction *transaction, NSString *hashTransaction) {
            if (error) {
                completion([error isNoInternetConnectionError] ? TransactionManagerErrorTypeNoInternetConnection : TransactionManagerErrorTypeServer, transaction,hashTransaction);
            }else{
                completion(TransactionManagerErrorTypeNone, transaction, hashTransaction);
            }
        }];
    } else {
        completion(TransactionManagerErrorTypeNotEnoughMoney, nil, nil);
    }
}

- (void)sendToken:(Contract*) token
      fromAddress:(NSString*) frommAddress
        toAddress:(NSString*) toAddress
           amount:(NSDecimalNumber*) amount
       andHandler:(void(^)(TransactionManagerErrorType errorType, BTCTransaction * transaction, NSString* hashTransaction)) completion {
    
    
    // Checking address
    BTCPublicKeyAddress *address = [BTCPublicKeyAddress addressWithString:toAddress];
    if (!address) {
        completion(TransactionManagerErrorTypeInvalidAddress, nil, nil);
    }
    
    AbiinterfaceItem* transferMethod = [[ContractInterfaceManager sharedInstance] tokenStandartTransferMethodInterface];
    NSData* hashFuction = [[ContractInterfaceManager sharedInstance] hashOfFunction:transferMethod appendingParam:@[toAddress,amount]];
    
    NSString* __block addressWithAmountValue = frommAddress;
    
    NSNumber* addressBalance = token.addressBalanceDictionary[addressWithAmountValue];
    if (addressBalance) {
        if ([addressBalance isLessThan:amount]) {
            completion(TransactionManagerErrorTypeNotEnoughMoney, nil, nil);
            return;
        }
    } else {
        completion(TransactionManagerErrorTypeNotEnoughMoney, nil, nil);
        return;
    }

    if (addressWithAmountValue && amount) {
        [[[self class] sharedInstance] callTokenWithAddress:[NSString dataFromHexString:token.contractAddress] andBitcode:hashFuction fromAddresses:@[addressWithAmountValue] toAddress:nil walletKeys:[ApplicationCoordinator sharedInstance].walletManager.wallet.allKeys andHandler:^(NSError *error, BTCTransaction *transaction, NSString *hashTransaction) {
            if (error) {
                completion([error isNoInternetConnectionError] ? TransactionManagerErrorTypeNoInternetConnection : TransactionManagerErrorTypeServer, transaction,hashTransaction);
            }else{
                completion(TransactionManagerErrorTypeNone, transaction, hashTransaction);
            }
        }];
    } else {
        completion(TransactionManagerErrorTypeNotEnoughMoney, nil, nil);
    }
}

- (void)createSmartContractWithKeys:(NSArray<BTCKey*> *)walletKeys
                         andBitcode:(NSData *)bitcode
                         andHandler:(void(^)(NSError *error, BTCTransaction *transaction, NSString *hashTransaction)) completion {
    
    //NSAssert(walletKeys.count > 0, @"Keys must be grater then zero");
    if (!walletKeys.count) {
        completion([NSError new],nil,nil);
    }
    
    __weak typeof(self) weakSelf = self;
    NSArray* walletAddreses = [self getAddressesFromKeys:walletKeys];
    
    [[ApplicationCoordinator sharedInstance].walletManager.requestAdapter getunspentOutputs:walletAddreses withSuccessHandler:^(NSArray <BTCTransactionOutput*>*responseObject) {
        
        BTCTransaction *tx = [weakSelf createSmartContractUnspentOutputs:responseObject amount:0 bitcode:bitcode walletKeys:walletKeys];
        
        [weakSelf sendTransaction:tx withSuccess:^(id response){
            completion(nil,tx,response[@"txid"]);
        } andFailure:^(NSString *message) {
            completion([NSError new],nil,nil);
        }];
    } andFailureHandler:^(NSError *error, NSString *message) {
        completion(error,nil, nil);
    }];
}

- (void)callTokenWithAddress:(NSData*) contractAddress
                  andBitcode:(NSData*) bitcode
                 fromAddresses:(NSArray<NSString*>*) fromAddresses
                   toAddress:(NSString*) toAddress
                  walletKeys:(NSArray<BTCKey*>*) walletKeys
                  andHandler:(void(^)(NSError* error, BTCTransaction * transaction, NSString* hashTransaction)) completion {
    
    [self sendToTokenWithAddress:contractAddress andBitcode:bitcode fromAddresses:fromAddresses toAddress:toAddress walletKeys:walletKeys andHandler:^(NSError *error, BTCTransaction *transaction, NSString *hashTransaction) {
        completion(error,transaction,hashTransaction);
    }];
}

- (void)sendToTokenWithAddress:(NSData*) contractAddress
                  andBitcode:(NSData*) bitcode
                 fromAddresses:(NSArray<NSString*>*) fromAddresses
                   toAddress:(NSString*) toAddress
                  walletKeys:(NSArray<BTCKey*>*) walletKeys
                  andHandler:(void(^)(NSError* error, BTCTransaction * transaction, NSString* hashTransaction)) completion {
    
    //NSAssert(walletKeys.count > 0, @"Keys must be grater then zero");
    if (!fromAddresses.count) {
        completion([NSError new],nil,nil);
    }
    
    __weak typeof(self) weakSelf = self;
    
    [[ApplicationCoordinator sharedInstance].walletManager.requestAdapter getunspentOutputs:fromAddresses withSuccessHandler:^(NSArray <BTCTransactionOutput*>*responseObject) {
        
        BTCTransaction *tx = [weakSelf sendToTokenWithUnspentOutputs:responseObject amount:0 contractAddress:contractAddress toAddress:toAddress fromAddresses:fromAddresses bitcode:bitcode walletKeys:walletKeys];
        
        [weakSelf sendTransaction:tx withSuccess:^(id response){
            completion(nil,tx,response[@"txid"]);
        } andFailure:^(NSString *message) {
            completion([NSError new],nil,nil);
        }];
    } andFailureHandler:^(NSError *error, NSString *message) {
        completion(error,nil, nil);
    }];
}

- (void)sendTransaction:(BTCTransaction*)transaction withSuccess:(void(^)(id response))success andFailure:(void(^)(NSString *message))failure {
    
    if (transaction) {
        
        [[ApplicationCoordinator sharedInstance].requestManager sendTransactionWithParam:@{@"data":transaction.hexWithTime,@"allowHighFee":@1} withSuccessHandler:^(id responseObject) {
            success(responseObject);
        } andFailureHandler:^(NSString *message) {
            failure(@"Can not send transaction");
        }];
    } else {
        failure (@"Cant Create Transaction");
    }
}

- (void)regularTransactionWithUnspentOutputs:(NSArray <BTCTransactionOutput*>*)unspentOutputs
                                                  amount:(CGFloat) amount
                                      amountAndAddresses:(NSArray*) amountAndAddresses
                                              walletKeys:(NSArray<BTCKey*>*) walletKeys
                                              andHandler:(void(^)(TransactionManagerErrorType errorType, BTCTransaction *transaction)) completion {
    
    NSArray *utxos = unspentOutputs;
    if (utxos.count > 0) {

        // Find enough outputs to spend the total amount and FEE.
        BTCAmount totalAmount = amount + FEE;
        
        // Sort utxo in order of
        utxos = [utxos sortedArrayUsingComparator:^(BTCTransactionOutput* obj1, BTCTransactionOutput* obj2) {
            if (obj1.value > obj2.value){
                return NSOrderedAscending;
            } else {
                return NSOrderedDescending;
            }
        }];
        
        NSMutableArray* txouts = [[NSMutableArray alloc] init];
        NSInteger total = 0;
        
        for (BTCTransactionOutput* txout in utxos) {
            
            if ([txout.script isPayToPublicKeyHashScript]) {
                [txouts addObject:txout];
                total += txout.value;
            }
            if (total >= (totalAmount)) {
                break;
            }
        }
        
        if (total < totalAmount) {
            completion(TransactionManagerErrorTypeNotEnoughMoney, nil);
            return;
        }
        
        // Create a new transaction
        BTCTransaction* tx = [[BTCTransaction alloc] init];
        tx.fee = FEE;
        BTCAmount spentCoins = 0;
        
        // Add all outputs as inputs
        for (BTCTransactionOutput* txout in txouts) {
            BTCTransactionInput* txin = [[BTCTransactionInput alloc] init];
            txin.previousHash = txout.transactionHash;
            txin.previousIndex = txout.index;
            [tx addInput:txin];
            spentCoins += txout.value;
        }
        
        // Add required outputs - payment and change
        for (NSDictionary *dictionary in amountAndAddresses) {
            BTCPublicKeyAddress *toPublicKeyAddress = dictionary[@"address"];
            BTCAmount amount = [dictionary[@"amount"] longLongValue];
            
            BTCTransactionOutput* paymentOutput;
            paymentOutput = [[BTCTransactionOutput alloc] initWithValue:amount address:toPublicKeyAddress];
            [tx addOutput:paymentOutput];
        }
        
        BTCAddress* changeAddress = [AppSettings sharedInstance].isMainNet ? walletKeys.firstObject.address : walletKeys.firstObject.addressTestnet;
        BTCTransactionOutput* changeOutput = [[BTCTransactionOutput alloc] initWithValue:(spentCoins - totalAmount) address: changeAddress];
        
        if (changeOutput.value > 0) {
            [tx addOutput:changeOutput];
        }
        
        // Sign all inputs. We now have both inputs and outputs defined, so we can sign the transaction.
        for (int i = 0; i < txouts.count; i++) {
            // Normally, we have to find proper keys to sign this txin, but in this
            // example we already know that we use a single private key.
            
            BTCTransactionOutput* txout = txouts[i];
            BTCTransactionInput* txin = tx.inputs[i];
            BTCScript* sigScript = [[BTCScript alloc] init];
            NSData* d1 = tx.data;
            NSData* hash = [tx signatureHashForScript:txout.script inputIndex:i hashType:BTCSignatureHashTypeAll error:nil];
            DLog(@"Hash Sig: %@", BTCIDFromHash(hash));
            NSData* d2 = tx.data;
            
            NSAssert([d1 isEqual:d2], @"Transaction must not change within signatureHashForScript!");
            
            if (!hash) {
                completion(TransactionManagerErrorTypeOups, nil);
                return;
            }
            
            BTCKey *key;
            for (BTCKey *someKey in walletKeys) {
                NSString* keyString = someKey.address.string;// [AppSettings sharedInstance].isMainNet ? someKey.address.string : someKey.addressTestnet.string;
                if ([keyString isEqualToString:txout.script.standardAddress.string]) {
                    key = someKey;
                    break;
                }
            }
            if (!key) {
                completion(TransactionManagerErrorTypeOups, nil);
                return;
            }
            
            NSData* signature = [key signatureForHash:hash];
            
            NSMutableData* signatureForScript = [signature mutableCopy];
            unsigned char hashtype = BTCSignatureHashTypeAll;
            [signatureForScript appendBytes:&hashtype length:1];
            [sigScript appendData:signatureForScript];
            [sigScript appendData:key.publicKey];
            
            NSAssert([key isValidSignature:signature hash:hash], @"Signature must be valid");
            txin.signatureScript = sigScript;
        }
        
        // Some checking code
        BTCScriptMachine* sm = [[BTCScriptMachine alloc] initWithTransaction:tx inputIndex:0];
        NSError* errore = nil;
        BOOL r = [sm verifyWithOutputScript:[[(BTCTransactionOutput*)txouts[0] script] copy] error:&errore];
        DLog(@"Error: %@", errore);
        NSAssert(r, @"should verify first output");
        
        DLog(@"Hash tx: %@", tx.transactionID);
        
        completion(TransactionManagerErrorTypeNone, tx);
        return;
    }
    
    completion(TransactionManagerErrorTypeOups, nil);
}

- (BTCTransaction *)sendToTokenWithUnspentOutputs:(NSArray <BTCTransactionOutput*>*)unspentOutputs
                                           amount:(CGFloat) amount
                                        contractAddress:(NSData*) contractAddress
                                        toAddress:(NSString*) toAddress
                                      fromAddresses:(NSArray<NSString*>*) fromAddresses
                                          bitcode:(NSData*) bitcode
                                       walletKeys:(NSArray<BTCKey*>*) walletKeys {
    
    NSArray *utxos = unspentOutputs;
    if (utxos.count > 0) {
        
        // Find enough outputs to spend the total amount and FEE.
        BTCAmount totalAmount = amount + FEE;
        
        // Sort utxo in order of
        utxos = [utxos sortedArrayUsingComparator:^(BTCTransactionOutput* obj1, BTCTransactionOutput* obj2) {
            if (obj1.value > obj2.value){
                return NSOrderedAscending;
            } else {
                return NSOrderedDescending;
            }
        }];
        
        NSMutableArray* txouts = [[NSMutableArray alloc] init];
        NSInteger total = 0;
        
        for (BTCTransactionOutput* txout in utxos) {
            if ([txout.script isPayToPublicKeyHashScript]) {
                [txouts addObject:txout];
                total += txout.value;
            }
            if (total >= (totalAmount)) {
                break;
            }
        }
        
        if (total < totalAmount) {
            return nil;
        }
        
        // Create a new transaction
        BTCTransaction* tx = [[BTCTransaction alloc] init];
        tx.fee = FEE;
        BTCAmount spentCoins = 0;
        
        // Add all outputs as inputs
        for (BTCTransactionOutput* txout in txouts) {
            BTCTransactionInput* txin = [[BTCTransactionInput alloc] init];
            txin.previousHash = txout.transactionHash;
            txin.previousIndex = txout.index;
            txin.runTimeAddress = txout.runTimeAddress;
            [tx addInput:txin];
            spentCoins += txout.value;
        }
        
        // Add required outputs - payment and change
        BTCAmount amount = 0;
        BTCTransactionOutput* paymentOutput;
        paymentOutput = [[BTCTransactionOutput alloc] initWithValue:amount script:[self sendContractScriptWithBiteCode:bitcode andContractAddress:contractAddress]];
        [tx addOutput:paymentOutput];
        
        BTCAddress* changeAddress = [BTCAddress addressWithString:fromAddresses.firstObject];
        BTCTransactionOutput* changeOutput = [[BTCTransactionOutput alloc] initWithValue:(spentCoins - totalAmount) address: changeAddress];
        
        if (changeOutput.value > 0) {
            [tx addOutput:changeOutput];
        }
        
        // Sign all inputs. We now have both inputs and outputs defined, so we can sign the transaction.
        for (int i = 0; i < txouts.count; i++) {
            // Normally, we have to find proper keys to sign this txin, but in this
            // example we already know that we use a single private key.
            
            BTCTransactionOutput* txout = txouts[i];
            BTCTransactionInput* txin = tx.inputs[i];
            BTCScript* sigScript = [[BTCScript alloc] init];
            NSData* d1 = tx.data;
            NSData* hash = [tx signatureHashForScript:txout.script inputIndex:i hashType:BTCSignatureHashTypeAll error:nil];
            DLog(@"Hash Sig: %@", BTCIDFromHash(hash));
            NSData* d2 = tx.data;
            
            NSAssert([d1 isEqual:d2], @"Transaction must not change within signatureHashForScript!");
            
            if (!hash) {
                return nil;
            }
            
            BTCKey *key;
            for (BTCKey *someKey in walletKeys) {
                NSString* keyString = someKey.address.string;// [AppSettings sharedInstance].isMainNet ? someKey.address.string : someKey.addressTestnet.string;
                if ([keyString isEqualToString:txout.script.standardAddress.string]) {
                    key = someKey;
                    break;
                }
            }
            if (!key) {
                return nil;
            }
            
            NSData* signature = [key signatureForHash:hash];
            
            NSMutableData* signatureForScript = [signature mutableCopy];
            unsigned char hashtype = BTCSignatureHashTypeAll;
            [signatureForScript appendBytes:&hashtype length:1];
            [sigScript appendData:signatureForScript];
            [sigScript appendData:key.publicKey];
            
            NSAssert([key isValidSignature:signature hash:hash], @"Signature must be valid");
            txin.signatureScript = sigScript;
        }
        
        // Some checking code
        BTCScriptMachine* sm = [[BTCScriptMachine alloc] initWithTransaction:tx inputIndex:0];
        NSError* errore = nil;
        BOOL r = [sm verifyWithOutputScript:[[(BTCTransactionOutput*)txouts[0] script] copy] error:&errore];
        DLog(@"Error: %@", errore);
        NSAssert(r, @"should verify first output");
        
        DLog(@"Hash tx: %@", tx.transactionID);
        return tx;
    }
    
    return nil;
}

- (BTCTransaction *)createSmartContractUnspentOutputs:(NSArray *)unspentOutputs
                                           amount:(CGFloat) amount
                                          bitcode:(NSData*) bitcode
                                       walletKeys:(NSArray<BTCKey*>*) walletKeys {
    
    NSArray *utxos = unspentOutputs;
    if (utxos.count > 0) {
        
        // Find enough outputs to spend the total amount and FEE.
        BTCAmount totalAmount = amount + FEE;
        
        // Sort utxo in order of
        utxos = [utxos sortedArrayUsingComparator:^(BTCTransactionOutput* obj1, BTCTransactionOutput* obj2) {
            if (obj1.value > obj2.value){
                return NSOrderedAscending;
            } else {
                return NSOrderedDescending;
            }
        }];
        
        NSMutableArray* txouts = [[NSMutableArray alloc] init];
        NSInteger total = 0;
        
        for (BTCTransactionOutput* txout in utxos) {
            if ([txout.script isPayToPublicKeyHashScript]) {
                [txouts addObject:txout];
                total += txout.value;
            }
            if (total >= (totalAmount)) {
                break;
            }
        }
        
        if (total < totalAmount) {
            return nil;
        }
        
        // Create a new transaction
        BTCTransaction* tx = [[BTCTransaction alloc] init];
        tx.fee = FEE;
        BTCAmount spentCoins = 0;
        
        // Add all outputs as inputs
        for (BTCTransactionOutput* txout in txouts) {
            BTCTransactionInput* txin = [[BTCTransactionInput alloc] init];
            txin.previousHash = txout.transactionHash;
            txin.previousIndex = txout.index;
            txin.runTimeAddress = txout.runTimeAddress;
            [tx addInput:txin];
            spentCoins += txout.value;
        }
        
        // Add required outputs - payment and change
        BTCAmount amount = 0;
        BTCTransactionOutput* paymentOutput;
        paymentOutput = [[BTCTransactionOutput alloc] initWithValue:amount script:[self createContractScriptWithBiteCode:bitcode]];
        [tx addOutput:paymentOutput];
        
        BTCAddress* changeAddress = [AppSettings sharedInstance].isMainNet ? walletKeys.firstObject.address : walletKeys.firstObject.addressTestnet;
        BTCTransactionOutput* changeOutput = [[BTCTransactionOutput alloc] initWithValue:(spentCoins - totalAmount) address: changeAddress];
        
        if (changeOutput.value > 0) {
            [tx addOutput:changeOutput];
        }
        
        // Sign all inputs. We now have both inputs and outputs defined, so we can sign the transaction.
        for (int i = 0; i < txouts.count; i++) {
            // Normally, we have to find proper keys to sign this txin, but in this
            // example we already know that we use a single private key.
            
            BTCTransactionOutput* txout = txouts[i];
            BTCTransactionInput* txin = tx.inputs[i];
            BTCScript* sigScript = [[BTCScript alloc] init];
            NSData* d1 = tx.data;
            NSData* hash = [tx signatureHashForScript:txout.script inputIndex:i hashType:BTCSignatureHashTypeAll error:nil];
            DLog(@"Hash Sig: %@", BTCIDFromHash(hash));
            NSData* d2 = tx.data;
            
            NSAssert([d1 isEqual:d2], @"Transaction must not change within signatureHashForScript!");
            
            if (!hash) {
                return nil;
            }
            
            BTCKey *key;
            for (BTCKey *someKey in walletKeys) {
                NSString* keyString = someKey.address.string;// [AppSettings sharedInstance].isMainNet ? someKey.address.string : someKey.addressTestnet.string;
                if ([keyString isEqualToString:txout.script.standardAddress.string]) {
                    key = someKey;
                    break;
                }
            }
            if (!key) {
                return nil;
            }
            
            NSData* signature = [key signatureForHash:hash];
            
            NSMutableData* signatureForScript = [signature mutableCopy];
            unsigned char hashtype = BTCSignatureHashTypeAll;
            [signatureForScript appendBytes:&hashtype length:1];
            [sigScript appendData:signatureForScript];
            [sigScript appendData:key.publicKey];
            
            NSAssert([key isValidSignature:signature hash:hash], @"Signature must be valid");
            txin.signatureScript = sigScript;
        }
        
        // Some checking code
        BTCScriptMachine* sm = [[BTCScriptMachine alloc] initWithTransaction:tx inputIndex:0];
        NSError* errore = nil;
        BOOL r = [sm verifyWithOutputScript:[[(BTCTransactionOutput*)txouts[0] script] copy] error:&errore];
        DLog(@"Error: %@", errore);
        NSAssert(r, @"should verify first output");
        
        DLog(@"Hash tx: %@", tx.transactionID);
        return tx;
    }
    
    return nil;
}

#pragma mark - Token Scripts

-(BTCScript*)createContractScriptWithBiteCode:(NSData*) bitcode {
    
    BTCScript* script = [[BTCScript alloc] init];
    
    uint32_t ver = 4;
    [script appendData:[NSData dataWithBytes:&ver length:4]];

    NSUInteger gasLimit = 2000000;
    [script appendData:[NSData dataWithBytes:&gasLimit length:8]];
    
    NSUInteger gasPrice = 1;
    [script appendData:[NSData dataWithBytes:&gasPrice length:8]];

    [script appendData:bitcode];

    [script appendOpcode:0xc1];
    
    return script;
}

-(BTCScript*)sendContractScriptWithBiteCode:(NSData*) bitcode andContractAddress:(NSData*) address {
    
    BTCScript* script = [[BTCScript alloc] init];
    
    uint32_t ver = 4;
    [script appendData:[NSData dataWithBytes:&ver length:4]];
    
    NSUInteger gasLimit = 2000000;
    [script appendData:[NSData dataWithBytes:&gasLimit length:8]];
    
    NSUInteger gasPrice = 1;
    [script appendData:[NSData dataWithBytes:&gasPrice length:8]];
    
    [script appendData:bitcode];
    
    [script appendData:address];

    [script appendOpcode:0xc2];
    
    return script;
}

- (BTCAmount)convertValueToAmount:(NSDecimalNumber*) value {
    
    if ([value isKindOfClass:[NSDecimalNumber class]]) {
        return [[value decimalNumberByMultiplyingBy:[[NSDecimalNumber alloc] initWithDouble:BTCCoin]] integerValue];
    }
    return value.doubleValue * BTCCoin;
}

#pragma mark - Prepare values for sending

- (NSDictionary*)createAmountsAndAddresses:(NSArray *)array {
    
    NSMutableArray *mutArray = [NSMutableArray new];
    BTCAmount totalAmount = 0;
    for (NSDictionary *dictionary in array) {
        
        BTCPublicKeyAddress *toPublicKeyAddress = [BTCPublicKeyAddress addressWithString:dictionary[@"address"]];
        
        BTCAmount amount = [self convertValueToAmount:dictionary[@"amount"]];
        
        totalAmount += amount;
        
        if (!toPublicKeyAddress) {
            return nil;
        }
        NSDictionary *newDictionary = @{@"address" : toPublicKeyAddress, @"amount" : @(amount)};
        [mutArray addObject:newDictionary];
    }
    return @{@"totalAmount" : @(totalAmount), @"amountsAndAddresses" : [mutArray copy]};
}


@end









