//
//  MongoDBClientTests.m
//  MongoDBClientTests
//
//  Created by Daniel Parnell on 16/12/12.
//  Copyright (c) 2012 Automagic Software Pty Ltd. All rights reserved.
//

#import "MongoDBClientTests.h"
#import "MongoDBClient.h"

@implementation MongoDBClientTests

- (void)setUp
{
    [super setUp];
    
    // Set-up code here.
}

- (void)tearDown
{
    // Tear-down code here.
    
    [super tearDown];
}

- (void)testConnection
{
    NSError* error = nil;
    MongoDBClient* client = [MongoDBClient newWithHost: @"ubuntudev.local" port: 27017 andError: &error];
    STAssertNotNil(client, @"Connection failed: %@", error);
}

@end
