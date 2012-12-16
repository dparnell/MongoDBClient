//
//  MongoDBClient.h
//  MongoDBClient
//
//  Created by Daniel Parnell on 16/12/12.
//  Copyright (c) 2012 Automagic Software Pty Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MongoDBClient : NSObject {
    
}

+ (MongoDBClient*) newWithHost:(NSString*)host port:(NSUInteger)port andError:(NSError**)error;
- (id) initWithHost:(NSString*)host port:(NSUInteger)port andError:(NSError**)error;

@end
