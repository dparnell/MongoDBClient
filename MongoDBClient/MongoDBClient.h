//
//  MongoDBClient.h
//  MongoDBClient
//
//  Created by Daniel Parnell on 16/12/12.
//  Copyright (c) 2012 Automagic Software Pty Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MongoObjectId : NSObject {
    
}

@end

@interface MongoDBClient : NSObject {
    
}

+ (MongoDBClient*) newWithHost:(NSString*)host port:(NSUInteger)port andError:(NSError**)error;
- (id) initWithHost:(NSString*)host port:(NSUInteger)port andError:(NSError**)error;

- (BOOL) insert:(NSDictionary*) object intoCollection:(NSString*)collection withError:(NSError**)error;
- (NSArray*) find:(id) query inCollection:(NSString*)collection withError:(NSError**)error;

@property (copy) NSString* database;

@end
