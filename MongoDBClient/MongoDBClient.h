//
//  MongoDBClient.h
//  MongoDBClient
//
//  Created by Daniel Parnell on 16/12/12.
//  Copyright (c) 2012 Automagic Software Pty Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MongoObjectId : NSObject

+ (MongoObjectId*)newWithString:(NSString*)string;

@end

@interface MongoTimestamp : NSDate
@end

@interface MongoSymbol : NSString
@end

@interface MongoUndefined : NSObject
@end

@interface MongoRegex : NSObject

- (id) initWithPattern:(NSString*)pattern andOptions:(NSString*)options;

@property (strong) NSString* pattern;
@property (strong) NSString* options;

@end

@interface MongoDbCursor : NSObject

- (BOOL) nextDocumentIntoDictionary:(NSMutableDictionary*)doc withKeys:(NSMutableArray*)keys andError:(NSError**)error;

@end

@interface MongoDBClient : NSObject

+ (MongoDBClient*) newWithHost:(NSString*)host port:(NSUInteger)port andError:(NSError**)error;
- (id) initWithHost:(NSString*)host port:(NSUInteger)port andError:(NSError**)error;

- (BOOL) authenticateForDatabase:(NSString*)database withUsername:(NSString*)username password:(NSString*)password andError:(NSError**)error;

- (BOOL) insert:(NSDictionary*) object intoCollection:(NSString*)collection withError:(NSError**)error;
- (NSArray*) find:(id) query inCollection:(NSString*)collection withError:(NSError**)error;
- (NSArray*) find:(id) query columns: (NSDictionary*) columns skip:(NSInteger)toSkip returningNoMoreThan:(NSInteger)limit fromCollection:(NSString*)collection withError:(NSError**)error;
- (BOOL) update:(id) query withOperation:(NSDictionary*)operation inCollection:(NSString*)collection andError:(NSError**)error;
- (BOOL) upsert:(id) query withOperation:(NSDictionary*)operation inCollection:(NSString*)collection andError:(NSError**)error;
- (BOOL) updateAll:(id) query withOperation:(NSDictionary*)operation inCollection:(NSString*)collection andError:(NSError**)error;
- (BOOL) remove:(id)query fromCollection:(NSString*)collection withError:(NSError**)error;
- (NSUInteger) count:(id)query inCollection:(NSString*)collection withError:(NSError**)error;

- (MongoDbCursor*) cursorWithFind:(id) query columns: (NSDictionary*) columns skip:(NSInteger)toSkip returningNoMoreThan:(NSInteger)limit fromCollection:(NSString*)collection withError:(NSError**)error;

@property (copy) NSString* database;

@end
