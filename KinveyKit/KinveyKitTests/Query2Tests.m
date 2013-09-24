//
//  Query2Tests.m
//  KinveyKit
//
//  Created by Michael Katz on 8/19/13.
//  Copyright (c) 2013 Kinvey. All rights reserved.
//
// This software is licensed to you under the Kinvey terms of service located at
// http://www.kinvey.com/terms-of-use. By downloading, accessing and/or using this
// software, you hereby accept such terms of service  (and any agreement referenced
// therein) and agree that you have read, understand and agree to be bound by such
// terms of service and are of legal age to agree to such terms with Kinvey.
//
// This software contains valuable confidential and proprietary information of
// KINVEY, INC and is subject to applicable licensing agreements.
// Unauthorized reproduction, transmission or distribution of this file and its
// contents is a violation of applicable laws.
//


#import <SenTestingKit/SenTestingKit.h>
#import "KinveyDataStoreInternal.h"
#import "TestUtils.h"

@interface Query2Tests : SenTestCase

@end

@implementation Query2Tests

- (void)setUp
{
    [super setUp];
    // Put setup code here; it will be run once, before the first test case.
}

- (void)tearDown
{
    // Put teardown code here; it will be run once, after the last test case.
    [super tearDown];
}

- (void)testPredicateBasic
{
    NSPredicate* basicPredicate = [NSPredicate predicateWithFormat:@"foo=X"];
    KCSQuery2* query = [KCSQuery2 queryWithPredicate:basicPredicate error:NULL];
    
    STAssertNotNil(query, @"should be valid");
    STAssertEqualObjects([query queryString], @"query={\"foo\":\"X\"}", @"basic");
}



@end