//
//  MongoDBClient.m
//  MongoDBClient
//
//  Created by Daniel Parnell on 16/12/12.
//  Copyright (c) 2012 Automagic Software Pty Ltd. All rights reserved.
//

#import "MongoDBClient.h"
#import "mongo.h"
#import "bson.h"

#pragma mark -
#pragma mark Special Mongo objects

@implementation MongoObjectId {
    bson_oid_t value;
}

+ (MongoObjectId*)newWithString:(NSString*)string {
    const char* chars = [string UTF8String];
    bson_oid_t oid;
    
    bson_oid_from_string(&oid, chars);
    
    return [[MongoObjectId alloc] initWithOid: &oid];
}

- (id) init {
    self = [super init];
    if(self) {
        bson_oid_gen(&value);
    }
    return self;
}

- (id) initWithOid:(bson_oid_t*)oid {
    self = [super init];
    if(self) {
        memcpy(&value, oid, sizeof(bson_oid_t));
    }
    return self;
}

- (NSString*) description {
    char buffer[25];
    bson_oid_to_string(&value, buffer);
    
    return [NSString stringWithFormat: @"ObjectId('%s')", buffer];
}

- (bson_oid_t*) oid {
    return &value;
}

- (BOOL) isEqual:(id)object {
    if(object == self) {
        return YES;
    } else if([object isKindOfClass: [MongoObjectId class]]) {
        return memcmp(&value, [object oid], sizeof(bson_oid_t)) == 0;
    }
    
    return NO;
}

@end

@implementation MongoTimestamp
@end

@implementation MongoSymbol
@end

@implementation MongoUndefined
@end

@implementation MongoRegex {
    NSString* _pattern;
    NSString* _options;
}

@synthesize pattern = _pattern, options = _options;

- (id) initWithPattern:(NSString*)pattern andOptions:(NSString*)options {
    self = [super init];
    if(self) {
        self.pattern = pattern;
        self.options = options;
    }
    return self;
}

@end

#pragma mark -
#pragma mark MongoDBCursor private interface

@interface MongoDbCursor(Private)

- (id) initWithClient:(MongoDBClient*)client query:(id) query columns: (NSDictionary*) columns skip:(NSInteger)toSkip returningNoMoreThan:(NSInteger)limit fromCollection:(NSString*)collection withError:(NSError**)error;

@end

#pragma mark -
#pragma mark BSON stuff

static void add_object_to_bson(bson* b, NSString* key, id obj) {
    const char* key_name = [key cStringUsingEncoding: NSUTF8StringEncoding];
    
    if([obj isKindOfClass: [NSNumber class]]) {
        const char *objCType = [obj objCType];
        switch (*objCType) {
            case 'd':
            case 'f':
                bson_append_double(b, key_name, [obj doubleValue]);
                break;
            case 'l':
            case 'L':
                bson_append_long(b, key_name, [obj longValue]);
                break;
            case 'q':
            case 'Q':
                bson_append_long(b, key_name, [obj longLongValue]);
                break;
            case 'B':
                bson_append_bool(b, key_name, [obj boolValue]);
                break;
            default:
                bson_append_int(b, key_name, [obj intValue]);
                break;
        }
    } else if([obj isKindOfClass: [NSDictionary class]]) {
        bson_append_start_object(b, key_name);
        for(NSString* k in obj) {
            id val = [obj objectForKey: k];
            add_object_to_bson(b, k, val);
        }
        bson_append_finish_object(b);
    } else if([obj isKindOfClass: [NSArray class]]) {
        bson_append_start_array(b, key_name);
        int C = (int)[obj count];
        for(int i=0; i<C; i++) {
            add_object_to_bson(b, [NSString stringWithFormat: @"%d", i], [obj objectAtIndex: i]);
        }
        bson_append_finish_array(b);
    } else if([obj isKindOfClass: [NSDate class]]) {
        bson_date_t millis = (bson_date_t) ([obj timeIntervalSince1970] * 1000.0);
        bson_append_date(b, key_name, millis);
    } else if([obj isKindOfClass: [NSData class]]) {
        bson_append_binary(b, key_name, 0, [obj bytes], (int)[obj length]);
    } else if([obj isKindOfClass: [NSNull class]]) {
        bson_append_null(b, key_name);
    } else if([obj isKindOfClass: [MongoObjectId class]]) {
        bson_append_oid(b, key_name, [obj oid]);
    } else if([obj isKindOfClass: [MongoTimestamp class]]) {
        bson_append_timestamp2(b, key_name, [obj timeIntervalSince1970], 0);
    } else if([obj isKindOfClass: [MongoSymbol class]]) {
        bson_append_symbol(b, key_name, [obj cStringUsingEncoding: NSUTF8StringEncoding]);
    } else if([obj isKindOfClass: [MongoUndefined class]]) {
        bson_append_undefined(b, key_name);
    } else if([obj isKindOfClass: [MongoRegex class]]) {
        MongoRegex* regex = obj;
        bson_append_regex(b, key_name, [[regex pattern] cStringUsingEncoding: NSUTF8StringEncoding], [[regex options] cStringUsingEncoding: NSUTF8StringEncoding]);
    } else if([obj respondsToSelector: @selector(cStringUsingEncoding:)]) {
        bson_append_string(b, key_name, [obj cStringUsingEncoding: NSUTF8StringEncoding]);
    } else {
        @throw [NSException exceptionWithName: @"CRASH" reason: @"Unhandled object type in BSON serialization" userInfo: [NSDictionary dictionaryWithObject: obj forKey: @"object"]];
    }
}

static void bsonFromDictionary(bson* b, NSDictionary*dict) {
    bson_init(b);
    for (NSString* key in dict) {
        id obj = [dict objectForKey: key];
        add_object_to_bson(b, key, obj);
    }
    bson_finish(b);
}

static void fill_object_from_bson(id object, bson_iterator* it);

static id object_from_bson(bson_iterator* it) {
    id value = nil;
    bson_iterator it2;
    bson subobject;
    bson_timestamp_t timestamp;
    const char* pattern;
    const char* options;
    
    switch(bson_iterator_type(it)) {
        case BSON_EOO:
            value = [NSError errorWithDomain: @"Unhandled object type: EOO" code: 0 userInfo: nil];
            break;
        case BSON_DOUBLE:
            value = [NSNumber numberWithDouble: bson_iterator_double(it)];
            break;
        case BSON_STRING:
            value = [[NSString alloc] initWithCString: bson_iterator_string(it)
                                             encoding: NSUTF8StringEncoding];
            break;
        case BSON_OBJECT:
            value = [NSMutableDictionary dictionary];
            bson_iterator_subobject(it, &subobject);
            bson_iterator_init(&it2, &subobject);
            fill_object_from_bson(value, &it2);
            break;
        case BSON_ARRAY:
            value = [NSMutableArray array];
            bson_iterator_subobject(it, &subobject);
            bson_iterator_init(&it2, &subobject);
            fill_object_from_bson(value, &it2);
            break;
        case BSON_BINDATA:
            value = [NSData dataWithBytes:bson_iterator_bin_data(it)
                                   length:bson_iterator_bin_len(it)];
            break;
        case BSON_UNDEFINED:
            value = [MongoUndefined new];
            break;
        case BSON_OID:
            value = [[MongoObjectId alloc] initWithOid: bson_iterator_oid(it)];
            break;
        case BSON_BOOL:
            value = [NSNumber numberWithBool:bson_iterator_bool(it)];
            break;
        case BSON_DATE:
            value = [NSDate dateWithTimeIntervalSince1970:(0.001 * bson_iterator_date(it))];
            break;
        case BSON_NULL:
            value = [NSNull null];
            break;
        case BSON_REGEX:
            pattern = bson_iterator_regex(it);
            options = bson_iterator_regex_opts(it);
            
            value = [[MongoRegex alloc] initWithPattern: [NSString stringWithCString: pattern encoding: NSUTF8StringEncoding]
                                             andOptions: [NSString stringWithCString: options encoding: NSUTF8StringEncoding]];
            break;
        case BSON_CODE:
            value = [NSError errorWithDomain: @"Unhandled object type: CODE" code: 0 userInfo: nil];
            break;
        case BSON_SYMBOL:
            value = [[MongoSymbol alloc] initWithCString: bson_iterator_string(it)
                                                encoding: NSUTF8StringEncoding];
            break;
        case BSON_CODEWSCOPE:
            value = [NSError errorWithDomain: @"Unhandled object type: CODEWSCOPE" code: 0 userInfo: nil];
            break;
        case BSON_INT:
            value = [NSNumber numberWithInt: bson_iterator_int(it)];
            break;
        case BSON_TIMESTAMP:
            timestamp = bson_iterator_timestamp(it);
            value = [MongoTimestamp dateWithTimeIntervalSince1970: timestamp.t];
            break;
        case BSON_LONG:
            value = [NSNumber numberWithLong: bson_iterator_long(it)];
            break;
        default:
            break;
    }
    
    return value;
}

static void fill_object_from_bson_ext(id object, NSMutableArray* keys, bson_iterator* it) {
    if([object isKindOfClass: [NSDictionary class]]) {
        [keys removeAllObjects];
        
        while(bson_iterator_next(it)) {
            NSString* key = [NSString stringWithCString: bson_iterator_key(it) encoding: NSUTF8StringEncoding];
            [keys addObject: key];
            
            id val = object_from_bson(it);
            [object setObject: val forKey: key];
        }
    } else if([object isKindOfClass: [NSArray class]]) {
        
    } else {
        @throw [NSException exceptionWithName: @"CRASH" reason: @"Attempt to deserialize BSON into unhandled object type" userInfo: [NSDictionary dictionaryWithObject: object forKey: @"object"]];
    }
}

static void fill_object_from_bson(id object, bson_iterator* it) {
    fill_object_from_bson_ext(object, nil, it);
}

#pragma mark -
#pragma mark client code

@implementation MongoDBClient {
    mongo conn;
}

#pragma mark -
#pragma mark Initialization and destruction

static void build_error(mongo* conn, NSError** error) {
    if(error) {
        switch ( conn->err ) {
            case MONGO_CONN_NO_SOCKET:
                *error = [NSError errorWithDomain: @"No socket" code: conn->err userInfo: nil];
                break;
            case MONGO_CONN_FAIL:
                *error = [NSError errorWithDomain: @"Connection failed" code: conn->err userInfo: nil];
                break;
            case MONGO_CONN_ADDR_FAIL:
                *error = [NSError errorWithDomain: @"Could not resolve host name" code: conn->err userInfo: nil];
                break;
            case MONGO_CONN_NOT_MASTER:
                *error = [NSError errorWithDomain: @"Database is not a master" code: conn->err userInfo: nil];
                break;
            default:
                *error = [NSError errorWithDomain: [NSString stringWithCString: conn->lasterrstr encoding: NSUTF8StringEncoding] code: conn->err userInfo: nil];
        }
    }
    
    mongo_clear_errors(conn);
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
            build_error(&conn, error);
            
            return nil;
        }
        
        self.database = @"test";
    }
    return self;
}

- (void)dealloc
{
    mongo_destroy(&conn);
}

#pragma mark -
#pragma mark Query Stuff

+ (NSDictionary*)buildQuery:(id)query {
    if(query == nil ) {
        return [NSDictionary dictionary];
    } else if([query isKindOfClass: [MongoObjectId class]]) {
        return [NSDictionary dictionaryWithObject: query forKey: @"_id"];
    } else if([query isKindOfClass: [NSDictionary class]]) {
        return query;
    }
    
    @throw [NSException exceptionWithName: @"CRASH" reason: @"Illegal query object type" userInfo: [NSDictionary dictionaryWithObject: query forKey: @"query"]];
}


#pragma mark -
#pragma mark Database commands

- (BOOL) authenticateForDatabase:(NSString*)database withUsername:(NSString*)username password:(NSString*)password andError:(NSError**)error {
    if(mongo_cmd_authenticate(&conn, [database cStringUsingEncoding: NSUTF8StringEncoding], [username cStringUsingEncoding: NSUTF8StringEncoding], [password cStringUsingEncoding: NSUTF8StringEncoding])) {
        self.database = database;
        
        return YES;
    }
    
    build_error(&conn, error);
    return NO;
}

#pragma mark -
#pragma mark Object manipulation

- (BOOL) insert:(NSDictionary*) object intoCollection:(NSString*)collection withError:(NSError**)error {
    bson doc;
    bsonFromDictionary(&doc, object);
    int result = mongo_insert(&conn, [[NSString stringWithFormat: @"%@.%@", self.database, collection] cStringUsingEncoding: NSUTF8StringEncoding], &doc, nil);
    bson_destroy(&doc);
    
    if(result == MONGO_OK) {
        return YES;
    }
    
    build_error(&conn, error);
    return NO;
}

- (NSArray*) find:(id) query inCollection:(NSString*)collection withError:(NSError**)error {
    return [self find: query columns: nil skip: 0 returningNoMoreThan: 0 fromCollection: collection withError: error];
}

- (NSArray*) find:(id) query columns: (NSDictionary*) columns skip:(NSInteger)toSkip returningNoMoreThan:(NSInteger)limit fromCollection:(NSString*)collection withError:(NSError**)error {
    
    MongoDbCursor* cursor = [self cursorWithFind: query columns: columns skip: toSkip returningNoMoreThan: limit fromCollection: collection withError: error];
    if(cursor) {
        NSMutableArray* result = [NSMutableArray new];

        while(YES) {
            NSMutableDictionary* doc = [NSMutableDictionary new];
            if([cursor nextDocumentIntoDictionary: doc withKeys: nil andError: error]) {
                [result addObject: doc];
            } else {
                break;
            }
        }
    }
    
    return nil;
}


- (BOOL) update:(id) query flag:(int)flag withOperation:(NSDictionary*)operation inCollection:(NSString*)collection andError:(NSError**)error {
    bson mongo_query;
    bson mongo_op;
    NSDictionary* to_update = [MongoDBClient buildQuery: query];

    bsonFromDictionary(&mongo_query, to_update);
    bsonFromDictionary(&mongo_op, operation);
    
    int result = mongo_update(&conn, [[NSString stringWithFormat: @"%@.%@", self.database, collection] cStringUsingEncoding: NSUTF8StringEncoding], &mongo_query, &mongo_op, flag, nil);
    
    bson_destroy(&mongo_op);
    bson_destroy(&mongo_query);
    
    if(result == MONGO_OK) {
        return YES;
    }
    
    build_error(&conn, error);
    return NO;
}

- (BOOL) update:(id) query withOperation:(NSDictionary*)operation inCollection:(NSString*)collection andError:(NSError**)error {
    return [self update: query flag: MONGO_UPDATE_BASIC withOperation: operation inCollection: collection andError: error];
}

- (BOOL) upsert:(id) query withOperation:(NSDictionary*)operation inCollection:(NSString*)collection andError:(NSError**)error {
    return [self update: query flag: MONGO_UPDATE_UPSERT withOperation: operation inCollection: collection andError: error];
}

- (BOOL) updateAll:(id) query withOperation:(NSDictionary*)operation inCollection:(NSString*)collection andError:(NSError**)error {
    return [self update: query flag: MONGO_UPDATE_MULTI withOperation: operation inCollection: collection andError: error];
}

- (BOOL) remove:(id)query fromCollection:(NSString*)collection withError:(NSError**)error {
    NSDictionary* to_remove = [MongoDBClient buildQuery: query];
    bson mongo_query;
    
    bsonFromDictionary(&mongo_query, to_remove);
    int result = mongo_remove(&conn, [[NSString stringWithFormat: @"%@.%@", self.database, collection] cStringUsingEncoding: NSUTF8StringEncoding], &mongo_query, nil);
    bson_destroy(&mongo_query);
    
    if(result == MONGO_OK) {
        return YES;
    }
    
    build_error(&conn, error);
    return NO;    
}

- (NSUInteger) count:(id)query inCollection:(NSString*)collection withError:(NSError**)error {
    bson mongo_query;
    NSDictionary* to_count = [MongoDBClient buildQuery: query];
    
    bsonFromDictionary(&mongo_query, to_count);
    
    int result = mongo_count(&conn, [self.database cStringUsingEncoding: NSUTF8StringEncoding], [collection cStringUsingEncoding: NSUTF8StringEncoding], &mongo_query);
    
    if(result == MONGO_ERROR) {
        build_error(&conn, error);
    }
    
    return result;
}

#pragma mark -
#pragma mark Cursor creation methods

- (MongoDbCursor*) cursorWithFind:(id) query columns: (NSDictionary*) columns skip:(NSInteger)toSkip returningNoMoreThan:(NSInteger)limit fromCollection:(NSString*)collection withError:(NSError**)error {
    return [[MongoDbCursor alloc] initWithClient:self query: query columns: columns skip: toSkip returningNoMoreThan:limit fromCollection: collection withError: error];
}


#pragma mark -
#pragma mark Private methods

- (mongo*) mongoConnection {
    return &conn;
}

@end


@implementation MongoDbCursor {
    bson mongo_query;
    BOOL had_columns;
    bson mongo_columns;
    mongo_cursor cursor;
    mongo* conn;
}

- (id) initWithClient:(MongoDBClient*)client query:(id) query columns: (NSDictionary*) columns skip:(NSInteger)toSkip returningNoMoreThan:(NSInteger)limit fromCollection:(NSString*)collection withError:(NSError**)error {

    self = [super init];
    
    if(self) {
        NSDictionary* to_find = [MongoDBClient buildQuery: query];
        conn = [client mongoConnection];
        bsonFromDictionary(&mongo_query, to_find);
        mongo_cursor_init(&cursor, conn, [[NSString stringWithFormat: @"%@.%@", client.database, collection] cStringUsingEncoding: NSUTF8StringEncoding]);
        if(columns) {
            bsonFromDictionary(&mongo_columns, columns);
            mongo_cursor_set_fields(&cursor, &mongo_columns);
            had_columns = YES;
        } else {
            had_columns = NO;
        }
        if(toSkip>0) {
            mongo_cursor_set_skip(&cursor, (int)toSkip);
        }
        if(limit>0) {
            mongo_cursor_set_limit(&cursor, (int)limit);
        }
        mongo_cursor_set_query(&cursor, &mongo_query);
    }
    
    return self;
}

- (void)dealloc
{
    bson_destroy(&mongo_query);
    if(had_columns) {
        bson_destroy(&mongo_columns);
    }
}

- (BOOL) nextDocumentIntoDictionary:(NSMutableDictionary*)doc withKeys:(NSMutableArray*)keys andError:(NSError**)error {
    if( mongo_cursor_next( &cursor ) == MONGO_OK ) {
        bson_iterator it;
        
        [doc removeAllObjects];
        [keys removeAllObjects];
        
        bson_iterator_init(&it, &cursor.current);
        fill_object_from_bson_ext(doc, keys, &it);
        
        return YES;
    }
    
    build_error(conn, error);
    return NO;
}

@end