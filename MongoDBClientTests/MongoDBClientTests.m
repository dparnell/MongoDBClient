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

- (void)testInsert {
    NSError* error = nil;
    MongoDBClient* client = [MongoDBClient newWithHost: @"ubuntudev.local" port: 27017 andError: &error];
    STAssertNotNil(client, @"Connection failed: %@", error);
    
    BOOL result = [client insert: [NSDictionary dictionaryWithObjectsAndKeys:
                                   @"Foo", @"first_name",
                                   @"Bar", @"last_name",
                                   nil]
                  intoCollection: @"people"
                       withError: &error];
    
    STAssertTrue(result, @"Insert failed - %@", error);
}

- (void)testFind {
    NSError* error = nil;
    MongoDBClient* client = [MongoDBClient newWithHost: @"ubuntudev.local" port: 27017 andError: &error];
    STAssertNotNil(client, @"Connection failed: %@", error);
    
    MongoObjectId* object_id = [MongoObjectId new];
    
    BOOL result = [client insert: [NSDictionary dictionaryWithObjectsAndKeys:
                                   object_id, @"_id",
                                   @"Foo", @"first_name",
                                   @"Bar", @"last_name",
                                   nil]
                  intoCollection: @"people"
                       withError: &error];
    
    STAssertTrue(result, @"Insert failed - %@", error);
    
    NSArray* docs = [client find: object_id inCollection: @"people" withError: &error];
    STAssertNotNil(docs, @"Find failed - %@", error);
    STAssertTrue((int)[docs count] == 1, @"There should be 1 document in the result - %@", docs);
    
    NSDictionary* row = [docs objectAtIndex: 0];
    STAssertEqualObjects([row objectForKey: @"first_name"], @"Foo", @"it should be 'Foo'");
    STAssertEqualObjects([row objectForKey: @"last_name"], @"Bar", @"it should be 'Bar'");
    STAssertEqualObjects([row objectForKey: @"_id"], object_id, @"it should be equal");
}

@end
