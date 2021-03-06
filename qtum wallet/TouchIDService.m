//
//  TouchIDService.m
//  qtum wallet
//
//  Created by Vladimir Lebedevich on 20.07.17.
//  Copyright © 2017 PixelPlex. All rights reserved.
//

#import "TouchIDService.h"
@import LocalAuthentication;

@implementation TouchIDService

+ (instancetype)sharedInstance {
    
    static TouchIDService *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[super alloc] initUniqueInstance];
    });
    return instance;
}

- (instancetype)initUniqueInstance {
    
    self = [super init];
    
    if (self != nil) {}
    return self;
}

- (BOOL)hasTouchId {
    
    LAContext *la = [[LAContext alloc] init];
    if ([la respondsToSelector:@selector(canEvaluatePolicy:error:)] && SYSTEM_VERSION_GRATERTHAN_OR_EQUALTO(@"9.0")) {
        return [la canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:nil];
    } else {
        return NO;
    }
}

- (void)checkTouchId:(void (^)(TouchIDCompletionType type))completion {
    
    CGFloat touchIdDelayAnimation = 0.25;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        
        LAContext *la = [[LAContext alloc] init];
        if ([self hasTouchId]) {
            [la evaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics localizedReason:NSLocalizedString(@"Login", nil) reply:^(BOOL success, NSError *error) {
                if (completion) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (success) {
                            
                            completion(TouchIDSuccessed);
                        } else {
                            
                            switch (error.code) {
                                case kLAErrorSystemCancel:
                                case kLAErrorAuthenticationFailed:
                                case kLAErrorUserCancel: {
                                    
                                    completion(TouchIDCanceled);
                                    break;
                                }
                                default: {
                                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(touchIdDelayAnimation * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                                        completion(TouchIDDenied);
                                    });
                                    break;
                                }
                            }
                            
                        }
                    });
                }
            }];
        } else {
            
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(TouchIDDenied);
            });
        }
    });
}

@end
