//
//  Spendable.h
//  qtum wallet
//
//  Created by Никита Федоренко on 19.04.17.
//  Copyright © 2017 Designsters. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Managerable.h"
#import "HistoryElementProtocol.h"
#import "HistoryDataStorage.h"

@protocol Managerable;

@protocol Spendable <NSObject>

@property (copy, nonatomic) NSString* name;
@property (assign, nonatomic) CGFloat balance;
@property (strong, nonatomic) HistoryDataStorage* historyStorage;
@property (copy, nonatomic)NSString* mainAddress;
@property (copy, nonatomic)NSString* symbol;
@property (weak, nonatomic)id <Managerable> manager;

-(void)updateBalanceWithHandler:(void(^)(BOOL success)) complete;
-(void)updateHistoryWithHandler:(void(^)(BOOL success)) complete andPage:(NSInteger) page;
-(void)loadToMemory;


@end
