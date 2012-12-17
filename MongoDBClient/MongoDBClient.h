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

- (BOOL) authenticateForDatabase:(NSString*)database withUsername:(NSString*)username password:(NSString*)password andError:(NSError**)error;

- (BOOL) insert:(NSDictionary*) object intoCollection:(NSString*)collection withError:(NSError**)error;
- (NSArray*) find:(id) query inCollection:(NSString*)collection withError:(NSError**)error;
- (BOOL) update:(id) query withOperation:(NSDictionary*)operation inCollection:(NSString*)collection andError:(NSError**)error;
- (BOOL) upsert:(id) query withOperation:(NSDictionary*)operation inCollection:(NSString*)collection andError:(NSError**)error;
- (BOOL) updateAll:(id) query withOperation:(NSDictionary*)operation inCollection:(NSString*)collection andError:(NSError**)error;
- (BOOL) remove:(id)query fromCollection:(NSString*)collection withError:(NSError**)error;
- (NSUInteger) count:(id)query inCollection:(NSString*)collection withError:(NSError**)error;

@property (copy) NSString* database;

@end
