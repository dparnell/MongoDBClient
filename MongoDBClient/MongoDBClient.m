//
//  MongoDBClient.m
//  MongoDBClient
//
//  Created by Daniel Parnell on 16/12/12.
//  Copyright (c) 2012 Automagic Software Pty Ltd. All rights reserved.
//

#import "MongoDBClient.h"
#import "mongo.h"

@implementation MongoDBClient {
    mongo conn;
}

+ (MongoDBClient*) newWithHost:(NSString*)host port:(NSUInteger)port andError:(NSError**)error {
    return [[MongoDBClient alloc] initWithHost: host port: port andError: error];
}

- (id) initWithHost:(NSString*)host port:(NSUInteger)port andError:(NSError**)error {
    self = [super init];
    if(self) {
        int status;
        
        mongo_init(&conn);
        
        status = mongo_client(&conn, [host cStringUsingEncoding: NSUTF8StringEncoding], (int)port);
        if(status != MONGO_OK) {
            if(error) {
                switch ( conn.err ) {
                    case MONGO_CONN_NO_SOCKET:
                        *error = [NSError errorWithDomain: @"No socket" code: conn.err userInfo: nil];
                        break;
                    case MONGO_CONN_FAIL:
                        *error = [NSError errorWithDomain: @"Connection failed" code: conn.err userInfo: nil];
                        break;
                    case MONGO_CONN_ADDR_FAIL:
                        *error = [NSError errorWithDomain: @"Could not resolve host name" code: conn.err userInfo: nil];
                        break;
                    case MONGO_CONN_NOT_MASTER:
                        *error = [NSError errorWithDomain: @"Database is not a master" code: conn.err userInfo: nil];
                        break;
                    default:
                        *error = [NSError errorWithDomain: @"Unknown connection error" code: conn.err userInfo: nil];                        
                }
                
            }
            
            return nil;
        }
    }
    return self;
}

- (void)dealloc
{
    mongo_destroy(&conn);
}

@end
