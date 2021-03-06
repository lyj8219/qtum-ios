//
//  AddressLibruaryCoordinator.h
//  qtum wallet
//
//  Created by Vladimir Lebedevich on 02.08.17.
//  Copyright © 2017 PixelPlex. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AddressLibruaryCoordinator;

@protocol AddressLibruaryCoordinatorDelegate <NSObject>

- (void)coordinatorLibraryDidEnd:(AddressLibruaryCoordinator*)coordinator;

@end

@interface AddressLibruaryCoordinator : BaseCoordinator <Coordinatorable>

@property (weak,nonatomic) id <AddressLibruaryCoordinatorDelegate> delegate;

-(instancetype)initWithNavigationViewController:(UINavigationController*)navigationController;

@end
