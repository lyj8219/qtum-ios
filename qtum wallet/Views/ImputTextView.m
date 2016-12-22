//
//  ImputTextView.m
//  qtum wallet
//
//  Created by Никита Федоренко on 22.12.16.
//  Copyright © 2016 Designsters. All rights reserved.
//

#import "ImputTextView.h"

@interface ImputTextView ()

@end

@implementation ImputTextView

-(instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self configBorder];
    }
    return self;
}

-(void)layoutSubviews {
    [super layoutSubviews];
}

#pragma makr - Config

-(void)configBorder{
    self.layer.borderColor = [UIColor colorWithRed:78/255. green:93/255. blue:111/255. alpha:0.2].CGColor;
    self.layer.borderWidth = 1;
}

#pragma mark - Drawing

- (void)drawRect:(CGRect)rect {
}

@end