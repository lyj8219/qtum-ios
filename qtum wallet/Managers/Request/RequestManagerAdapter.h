//
//  RequestManagerAdapter.h
//  qtum wallet
//
//  Created by Vladimir Lebedevich on 21.03.17.
//  Copyright © 2017 PixelPlex. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol RequestManagerAdapter <NSObject>

@required
- (id)adaptiveDataForHistory:(id) data;
- (id)adaptiveDataForOutputs:(id) data;
- (id)adaptiveDataForBalance:(id) balance;


@end
