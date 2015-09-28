//
//  KCSTestCase.h
//  KinveyKit
//
//  Created by Victor Barros on 2015-08-14.
//  Copyright (c) 2015 Kinvey. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "KCSAssert.h"
#import "KinveyUser.h"

@interface KCSTestCase : XCTestCase

-(void)setupKCS;
-(KCSUser*)createAutogeneratedUser;

@property (nonatomic) NSString* masterSecret;

@end
