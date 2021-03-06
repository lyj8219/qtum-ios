//
//  TransactionManager.h
//  qtum wallet
//
//  Created by Sharaev Vladimir on 02.11.16.
//  Copyright © 2016 PixelPlex. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, TransactionManagerErrorType) {
    TransactionManagerErrorTypeNone,
    TransactionManagerErrorTypeNoInternetConnection,
    TransactionManagerErrorTypeServer,
    TransactionManagerErrorTypeOups,
    TransactionManagerErrorTypeNotEnoughMoney,
    TransactionManagerErrorTypeInvalidAddress
};

@interface TransactionManager : NSObject

+ (instancetype)sharedInstance;
- (id)init __attribute__((unavailable("cannot use init for this class, use sharedInstance instead")));
+ (instancetype)alloc __attribute__((unavailable("alloc not available, call sharedInstance instead")));
+ (instancetype) new __attribute__((unavailable("new not available, call sharedInstance instead")));

- (void)sendTransactionWalletKeys:(NSArray<BTCKey*>*) walletKeys
               toAddressAndAmount:(NSArray*) amountsAndAddresses
                       andHandler:(void(^)(TransactionManagerErrorType errorType, id response)) completion;


- (void)createSmartContractWithKeys:(NSArray<BTCKey*>*) walletKeys
                         andBitcode:(NSData*) bitcode
                         andHandler:(void(^)(NSError* error, BTCTransaction * transaction, NSString* hashTransaction)) completion;

- (void)callTokenWithAddress:(NSData*) contractAddress
                andBitcode:(NSData*) bitcode
               fromAddresses:(NSArray<NSString*>*) fromAddresses
                 toAddress:(NSString*) toAddress
                  walletKeys:(NSArray<BTCKey*>*) walletKeys
                andHandler:(void(^)(NSError* error, BTCTransaction * transaction, NSString* hashTransaction)) completion;

- (void)sendTransactionToToken:(Contract*) token
                     toAddress:(NSString*) toAddress
                        amount:(NSNumber*) amount
                    andHandler:(void(^)(TransactionManagerErrorType errorType, BTCTransaction * transaction, NSString* hashTransaction)) completion;

- (void)sendToken:(Contract*) token
        fromAddress:(NSString*) frommAddress
         toAddress:(NSString*) toAddress
            amount:(NSDecimalNumber*) amount
        andHandler:(void(^)(TransactionManagerErrorType errorType, BTCTransaction * transaction, NSString* hashTransaction)) completion;

@end
