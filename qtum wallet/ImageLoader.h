//
//  TCAImageLoader.h
//  TCA2016
//
//  Created by Nikita on 20.08.16.
//  Copyright © 2016 PixelPlex. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ImageLoader : UITableViewCell

+ (instancetype)sharedInstance;

- (id)init __attribute__((unavailable("cannot use init for this class, use sharedInstance instead")));
+ (instancetype)alloc __attribute__((unavailable("alloc not available, call sharedInstance instead")));
+ (instancetype) new __attribute__((unavailable("new not available, call sharedInstance instead")));

- (void)getImageWithUrl:(NSString *)url withResultHandler:(void (^)(UIImage *image))complete;
-(void)getCropImageWithUrl:(NSString*)url withResultHandler:(void(^)(UIImage* image)) complete;

@end
