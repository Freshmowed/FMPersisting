//
//  PersistenceManager.m
//
//  Created by Duke Browning on 10/08/2010.
//  Copyright (c) 2009-2015 freshmowed software. See included LICENSE file.
//

#import "FMPersistenceManager.h"
#import "FMPersistingModel.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "FMResultSet.h"

static FMPersistenceManager *_sharedInstance;
static NSMutableDictionary *persistencManagersByIdentifier;

@interface FMPersistenceManager ()
{
    NSMutableDictionary *insertHandlersByClassName;
    NSMutableDictionary *deleteHandlersByClassName;
    NSMutableDictionary *updateHandlersByClassName;
    
    NSMutableDictionary *columnNamesByTableName; // holds NSArray of column name NSStrings
}

@end

@implementation FMPersistenceManager

+(void)initialize
{
    _sharedInstance = nil;
    persistencManagersByIdentifier = [[NSMutableDictionary alloc] init];
}

+ (FMPersistenceManager *) sharedInstance;
{
    return _sharedInstance;
}

+ (void) setSharedInstance: (FMPersistenceManager *) psMgr;
{
    _sharedInstance = psMgr;
}

+ (FMPersistenceManager *) managerWithIdentifier: (NSString *) identifier;
{
    if (!identifier) return nil;
    
    return persistencManagersByIdentifier[identifier];
}

- (id) initWithIdentifier: (NSString *) identifier;
{
    if (identifier)
    {
        FMPersistenceManager *existing = persistencManagersByIdentifier[identifier];
        if (existing) {
            // NSLog(@"FMPersistenceManager.initWithIdentifier: instance already exists for identifier: %@", identifier);
            self = existing;
            return self;
        }
    }
    
    self = [super init];
    if (self != nil)
    {
        if (identifier ) persistencManagersByIdentifier[identifier] = self;
        
        _serialQueue = nil;
        insertHandlersByClassName = [[NSMutableDictionary alloc] init];
        deleteHandlersByClassName = [[NSMutableDictionary alloc] init];
        updateHandlersByClassName = [[NSMutableDictionary alloc] init];
        self.shouldRaiseExceptions = NO;
    }
    
    return self;
}

- (id) init
{
    return [self initWithIdentifier: nil];
}

- (BOOL) mainThreadCheck;
{
    BOOL onMainThread = [[NSThread currentThread] isMainThread];
    
    if ( onMainThread && _serialQueue )
        return NO;
    
    if ( !onMainThread && !_serialQueue )
        return NO;
    
    return YES;
}

- (BOOL) createTableIfNecessaryForClass: (Class) aClass;
{
    FMDatabase *aDB = [self database];
    
    if ( ![aDB tableExists: [aClass tableName] ] )
    {
        [self.database executeUpdate: [aClass schemaStatement] ];
        return YES;
    }
    
    return NO;
}

- (BOOL) columnExists:(NSString*)columnName inTableWithName:(NSString*)tableName
{
    tableName  = [tableName lowercaseString];
    columnName = [columnName lowercaseString];
    
    if ( !columnNamesByTableName ) columnNamesByTableName = [[NSMutableDictionary alloc] init];
    
    NSMutableArray *columnNames = columnNamesByTableName[tableName];
    
    if ( columnNames )
    {
        return [columnNames containsObject: columnName];
    }
    
    columnNames = [[NSMutableArray alloc] init];
    columnNamesByTableName[tableName] = columnNames;
    
    BOOL returnBool = NO;
    
    FMResultSet *rs = [_database getTableSchema:tableName];
    
    //check if column is present in table schema
    while ([rs next])
    {
        NSString *name = [[rs stringForColumn:@"name"] lowercaseString];
        [columnNames addObject: name];
        
        if ([ name isEqualToString:columnName])
        {
            returnBool = YES;
        }
    }
    
    //If this is not done FMDatabase instance stays out of pool
    [rs close];
    
    return returnBool;
}

- (FMDatabase *) openDatabaseWithPath: (NSString *) aPath;
{
    FMDatabase *aDB = [FMDatabase databaseWithPath: aPath];
    if (![aDB open])
    {
        NSLog(@"Could not open db %@", aPath);
        return nil;
    }
    
    self.database = aDB;
    self.databasePath = aPath;
    [aDB setShouldCacheStatements: YES];
    
    return aDB;
}

- (void) closeDatabase;
{
    [self.database close];
}

- (NSError *) deleteDatabase;
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *anError = nil;
    [fileManager removeItemAtPath:self.databasePath error:&anError];
    
    return anError;
}

- (void) dropTableForClass: (Class) aClass;
{
    if ( [aClass isMemberOfClass: [FMPersistingModel class]] )
    {
        NSLog(@"Error: PersistenceManager dropTableForClass:... must be provided a FMPersistingModel subclass.");
        return;
    }
    
    NSLog(@"FMPersistenceManager: Dropping table %@!!!", [aClass tableName] );
    NSString *dropString = [[NSString alloc] initWithFormat:@"drop table if exists %@", [aClass tableName]];
    [_database executeUpdate: dropString ];
}

- (FMPersistingModel *) insertNewObjectOfClass: (Class) aClass withValues: (NSDictionary *) aDict;
{
    if ( [aClass isMemberOfClass: [FMPersistingModel class]] )
    {
        NSLog(@"Error: PersistenceManager insertNewObjectOfClass:... must be provided a FMPersistingModel subclass.");
        return nil;
    }
    
    NSDictionary *insertInfo = [aClass insertStatementWithValues: aDict];
    NSString *insertString = [insertInfo objectForKey:@"statement"];
    NSArray *values = [insertInfo objectForKey:@"valueArray"];
    NSString *primaryKeyKey = [aClass primaryKeyKey];
    
    NSString *stmt = [[aClass baseQueryString] stringByAppendingString:[NSString stringWithFormat:@" where %@ = last_insert_rowid()", primaryKeyKey]];
    
    FMPersistingModel *newObject = nil;
    BOOL hadInsertError = NO;
    BOOL hadFetchError = NO;
    
    FMDatabase *db = self.database;
    [db executeUpdate: insertString withArgumentsInArray: values];
    
    if ([self.database hadError])
    {
        hadInsertError = YES;
        int lastErrorCode = [self.database lastErrorCode];
        NSLog(@"fmdb error code %d: %@", lastErrorCode, [self.database lastErrorMessage]);
        return nil;
    }
    
    if ( [aClass primaryKeyAutoGenerated ] )
    {
        NSString *queryStmt = [[aClass baseQueryString] stringByAppendingString:[NSString stringWithFormat:@" where %@ = ?", primaryKeyKey]];
        FMResultSet *rs = [self.database executeQuery: queryStmt withArgumentsInArray: @[[NSNumber numberWithLongLong: [db lastInsertRowId]]] ];
        
        if ([rs next])
        {
            newObject = [aClass objectFromResultSet: rs];
            newObject.persistenceManager = self;
        }
        
        [rs close];
        
        if ([db hadError])
        {
            hadFetchError = YES;
        }
    }
    
    NSString *className = NSStringFromClass(aClass);
    if ( hadInsertError )
    {
        NSString *errorDescrip = [NSString stringWithFormat: @"Error inserting object for class: %@ using statement: %@",
                                  className, insertString];
        [self handleError: errorDescrip context: nil];
    }
    else if ( hadFetchError )
    {
        NSString *errorDescrip = [NSString stringWithFormat: @"Error retrieving last object for class: %@ using statement like: %@",
                                  className, stmt];
        [self handleError: errorDescrip context: nil];
    }
    else
    {
        void (^handler)() = [insertHandlersByClassName objectForKey: className];
        if ( handler ) handler();
    }
    
    return newObject;
}

- (FMPersistingModel *) lastInsertedObjectOfClass: (Class) aClass;
{
    if ( [aClass isMemberOfClass: [FMPersistingModel class]] )
    {
        NSLog(@"Error: PersistenceManager lastInsertedObjectOfClass: must be provided a FMPersistingModel subclass.");
        return nil;
    }
    
    FMPersistingModel *newObject = nil;
    
    FMDatabase *db = self.database;
    NSString *stmt = [[aClass baseQueryString] stringByAppendingString:[NSString stringWithFormat:@" where %@ = last_insert_rowid()", [aClass primaryKeyKey]]];
    FMResultSet *rs = [self.database executeQuery: stmt ];
    
    if ([rs next])
    {
        newObject = [aClass objectFromResultSet: rs];
        newObject.persistenceManager = self;
    }
    
    [rs close];
    
    if ([db hadError])
    {
        NSString *errorDescrip = [NSString stringWithFormat: @"Error retrieving last object for class: %@ using statement: %@",
                                  NSStringFromClass(aClass), stmt];
        [self handleError: errorDescrip context: nil];
        return nil;
    }
    
    if ( !newObject ) NSLog(@"PersistenceManager: failed to find last inserted object of class %@", NSStringFromClass(aClass));
    
    return newObject;
}

- (BOOL) saveObject: (FMPersistingModel *) anObject;
{
    return [ self updateColumns: nil ofObject: anObject];
}

- (BOOL) updateValue: (NSObject *) aValue forKey: (NSString *) aKey ofObject: (FMPersistingModel *) anObject;
{
    if ( !aValue && !aKey && !anObject )
    {
        NSLog(@"No parameters for updateValue:forKey:ofObject:");
        return NO;
    }
    
    if ( !aValue )
    {
        NSLog(@"No value for updateValue:forKey: %@ ofObject: %@", aKey, [anObject class]);
        return NO;
    }
    
    if ( !anObject )
    {
        NSLog(@"No object for updateValue:forKey: %@ ofObject:", aKey);
        return NO;
    }
    
    [anObject setValue: aValue forKey: aKey];
    
    NSString *columnName = [[anObject class] columnNameForKey: aKey];
    
    if ( !columnName )
    {
        NSLog(@"PersistenceManager: updateValue:forKey:ofObject: no column for key: %@ of class: %@", aKey, [anObject class]);
        return NO;
    }
    
    BOOL success = [self updateColumns: [NSArray arrayWithObject: columnName]
                              ofObject: anObject ];
    
    NSDictionary *handlers = [updateHandlersByClassName objectForKey: NSStringFromClass([anObject class])];
    void (^handler)() = [handlers objectForKey: aKey];
    if ( handler ) handler();
    
    return success;
}

/*
 - (void) updateKeyValueObjectDict: (NSDictionary *) dict;
 {
 FMPersistingModel *anObject = dict[@"object"];
 NSString *aKey = dict[@"key"];
 NSObject *aValue = dict[@"value"];
 
 if ( !aKey || !aValue )
 {
 NSLog(@"PersistenceManager.updateKeyValueObjectDict: no key and/or value");
 return;
 }
 
 [anObject setValue: aValue forKey: aKey];
 
 [self updateColumns: [NSArray arrayWithObject: [[anObject class] columnNameForKey: aKey]]
 ofObject: anObject ];
 
 NSDictionary *handlers = [updateHandlersByClassName objectForKey: NSStringFromClass([anObject class])];
 void (^handler)() = [handlers objectForKey: aKey];
 if ( handler ) handler();
 
 }
 */

- (void)addInsertHandler:(void (^)())aHandler forClassName: (NSString *) className;
{
    if ( !aHandler || !className) return;
    
    void (^handlerCopy)() = [aHandler copy];
    
    [insertHandlersByClassName setObject: handlerCopy forKey: className];
}

- (void)addDeleteHandler:(void (^)())aHandler forClassName: (NSString *) className;
{
    if ( !aHandler || !className) return;
    
    void (^handlerCopy)() = [aHandler copy];
    
    [deleteHandlersByClassName setObject: handlerCopy forKey: className];
}

- (void)addUpdateHandler:(void (^)())aHandler forClassName: (NSString *) className key: (NSString *) aKey;
{
    if ( !aKey || !aHandler || !className) return;
    
    void (^handlerCopy)() = [aHandler copy];
    
    NSMutableDictionary *handlers = [updateHandlersByClassName objectForKey: aKey];
    if ( !handlers )
    {
        handlers = [[NSMutableDictionary alloc] init];
        [updateHandlersByClassName setObject: handlers forKey: className];
    }
    
    [handlers setObject: handlerCopy forKey: aKey];
}

- (BOOL) updateColumn: (NSString *) columnName ofObject: (FMPersistingModel *) anObject;
{
    if ( !columnName ) return NO;
    
    return [self updateColumns: [NSArray arrayWithObject: columnName]
                      ofObject: anObject];
}

- (BOOL) updateColumns: (NSArray *) columnNames ofObject: (FMPersistingModel *) anObject;
{
    if ( !anObject ) return NO;
    
    if ( [[anObject class] isMemberOfClass: [FMPersistingModel class]] )
    {
        NSLog(@"Error: PersistenceManager update methods must be provided a FMPersistingModel subclass.");
        return NO;
    }
    
    NSDictionary *updateInfo = [anObject updateStatementForColumns: columnNames ];
    NSString *sqlString = [updateInfo objectForKey:@"statement"];
    NSArray *values = [updateInfo objectForKey:@"valueArray"];
    
    BOOL success = [self.database executeUpdate: sqlString withArgumentsInArray: values];
    
    if ([self.database hadError] && [self.database lastErrorCode] != 0 )
    {
        NSString *errorDescrip = [NSString stringWithFormat: @"Error updating object for class: %@ using statement: %@",
                                  NSStringFromClass([anObject class]), sqlString];
        [self handleError: errorDescrip context: nil];
        return NO;
    }
    else if ( !success )
    {
        NSLog(@"SQL failure: %@", sqlString);
    }
    
    return success;
}

- (NSArray *) objectsOfClass: (Class) aClass fromResultSet: (FMResultSet *) rs;
{
    NSMutableArray *objects = [NSMutableArray array];
    while ([rs next])
    {
        FMPersistingModel *modelObject = [aClass objectFromResultSet: rs];
        if (modelObject)
        {
            modelObject.persistenceManager = self;
            [objects addObject: modelObject];
        }
    }
    [rs close];
    
    if ([self.database hadError])
    {
        [self handleError: [NSString stringWithFormat: @"Error creating objects of type %@ from result set", NSStringFromClass(aClass) ] context: nil];
        return nil;
    }
    
    return objects;
}

- (NSArray *) fetchAllObjectsOfClass: (Class) aClass;
{
    if ( [aClass isMemberOfClass: [FMPersistingModel class]] )
    {
        NSLog(@"Error: PersistenceManager fetchAllObjectsOfClass: must be provided a FMPersistingModel subclass.");
        return nil;
    }
    
    NSArray *objects = nil;
    
    FMResultSet *rs = [self.database executeQuery: [aClass baseQueryString] ];
    
    objects = [self objectsOfClass: aClass fromResultSet: rs];
    [rs close];
    
    return objects;
}

- (FMPersistingModel *) fetchObjectOfClass: (Class) aClass withCriteria: (NSDictionary *) aDict;
{
    NSArray *allObjects = [ self fetchObjectsOfClass: aClass withCriteria: aDict];
    
    if ( !allObjects || [allObjects count] == 0 ) return nil;
    
    return (FMPersistingModel *) [allObjects objectAtIndex: 0 ];
}

- (FMPersistingModel *) fetchObjectOfClass: (Class) aClass withID: (NSNumber *) anID;
{
    if ( !anID) return nil;
    
    return [self fetchObjectOfClass: aClass
                       withCriteria: @{@"ID" : anID}];
}

- (FMPersistingModel *) fetchObjectOfClass: (Class) aClass withWhereClause: (NSString *) whereClause;
{
    NSArray *allObjects = [ self fetchObjectsOfClass: aClass
                                     withWhereClause: whereClause
                                          sortClause: nil ];
    
    if ( !allObjects || [allObjects count] == 0 ) return nil;
    
    return (FMPersistingModel *) [allObjects objectAtIndex: 0 ];
}

- (NSArray *) fetchObjectsOfClass: (Class) aClass withCriteria: (NSDictionary *) aDict;
{
    if ( !aDict || [aDict count] == 0 ) return nil;
    
    if ( [aClass isMemberOfClass: [FMPersistingModel class]] )
    {
        NSLog(@"Error: PersistenceManager fetchObjectsOfClass:... must be provided a FMPersistingModel subclass.");
        return nil;
    }
    
    NSMutableArray *whereValues = [NSMutableArray array];
    NSMutableString *stmt = [NSMutableString stringWithFormat: @"%@ where ",[aClass baseQueryString]];
    NSArray *keyNames = [aDict allKeys];
    
    int keyCnt = 1;
    for (NSString *aKey in keyNames)
    {
        if ( keyCnt > 1 ) [stmt appendString: @" and "];
        keyCnt++;
        
        NSString *columnKey = [aKey stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        BOOL negate = NO;
        if ( [columnKey rangeOfString: @"<NOT>"].location == 0 )
        {
            columnKey = [columnKey substringFromIndex:5];
            columnKey = [columnKey stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            negate = YES;
        }
        
        [whereValues addObject:[aDict objectForKey: columnKey]];
        [stmt appendFormat: @"%@ %@ ?", [aClass columnNameForKey: columnKey], (negate ? @"!=" : @"=")];
    }
    
    NSMutableArray *result = [NSMutableArray array];
    
    FMDatabase *db = self.database; // instead of block
    FMResultSet *rs = [db executeQuery: stmt withArgumentsInArray: whereValues];
    while ([rs next])
    {
        FMPersistingModel *modelObject = [aClass objectFromResultSet: rs];
        if (modelObject)
        {
            modelObject.persistenceManager = self;
            [result addObject: modelObject];
        }
    }
    [rs close];
    
    if ([db hadError])
    {
        NSString *errorDescrip = [NSString stringWithFormat: @"Error fetching object of class %@ with criteria.", NSStringFromClass(aClass)];
        [self handleError: errorDescrip context: nil];
    }
    
    return result;
}

- (NSArray *) fetchObjectsOfClass: (Class) aClass
                  withWhereClause: (NSString *) whereClause;
{
    return [self fetchObjectsOfClass: aClass withWhereClause: whereClause sortClause: nil];
}

- (NSArray *) fetchObjectsOfClass: (Class) aClass
                  withWhereClause: (NSString *) whereClause
                       sortClause: (NSString *) sortClause;
{
    if ( [aClass isMemberOfClass: [FMPersistingModel class]] )
    {
        NSLog(@"Error: PersistenceManager fetchObjectsOfClass:... must be provided a FMPersistingModel subclass.");
        return nil;
    }
    
    NSMutableString *stmt = [NSMutableString stringWithString: [aClass baseQueryString]];
    
    if ( whereClause && [whereClause length] > 0 ) [stmt appendFormat: @" where %@", whereClause];
    if ( sortClause && [sortClause length] > 0 ) [stmt appendFormat: @" order by %@", sortClause];
    
    NSMutableArray *result = [NSMutableArray array];
    FMDatabase *db = self.database;
    FMResultSet *rs = [db executeQuery: stmt];
    while ([rs next])
    {
        FMPersistingModel *modelObject = [aClass objectFromResultSet: rs];
        if (modelObject)
        {
            modelObject.persistenceManager = self;
            [result addObject: modelObject];
        }
    }
    [rs close];
    
    if ([db hadError])
    {
        NSString *errorDescrip = [NSString stringWithFormat: @"Error fetching object of class %@ with criteria.", NSStringFromClass(aClass)];
        [self handleError: errorDescrip context: nil];
    }
    
    return result;
}

-(void) deleteObject: (FMPersistingModel *) anObject;
{
    if ( anObject == nil )
    {
        // NSLog(@"Warning: attempt to delete non-existent object.");
        return;
    }
    
    if ( [[anObject class] isMemberOfClass: [FMPersistingModel class]] )
    {
        NSLog(@"Error: attempt to delete object of FMPersistingModel class (must be subclass).");
        return;
    }
    
    anObject.persistenceManager = nil;
    
    NSString *primaryKeyKey = [[anObject class] primaryKeyKey];
    NSString *deleteString = [[NSString alloc] initWithFormat:@"delete from %@ where %@ = ?", [[anObject class] tableName], primaryKeyKey];
    
    [self.database executeUpdate: deleteString withArgumentsInArray: @[ [anObject primaryKeyValue] ] ];
    
    NSString *className = NSStringFromClass([anObject class]);
    if ([self.database hadError])
    {
        NSString *errorDescrip = [@"Error deleting object of class " stringByAppendingString: className];
        [self handleError: errorDescrip context: deleteString];
    }
    else
    {
        void (^handler)() = [deleteHandlersByClassName objectForKey: className];
        if ( handler ) handler();
    }
}


-(void) deleteAllObjectsOfClass: (Class) aClass;
{
    if ( [aClass isMemberOfClass: [FMPersistingModel class]] )
    {
        NSLog(@"Error: attempt to delete object of FMPersistingModel class (must be subclass).");
        return;
    }
    
    NSString *deleteString = [[NSString alloc] initWithFormat:@"delete from %@", [aClass tableName]];
    
    [self.database executeUpdate: deleteString ];
    
    if ([self.database hadError])
    {
        NSString *errorDescrip = [@"Error deleting all objects of class " stringByAppendingString:NSStringFromClass(aClass)];
        [self handleError: errorDescrip context: deleteString];
    }
    else
    {
        void (^handler)() = [deleteHandlersByClassName objectForKey: NSStringFromClass(aClass)];
        if ( handler ) handler();
    }
}


- (void) handleError: (NSString *) errorDescrip context: (NSString *) contextDescrip;
{
    if ( !errorDescrip ) errorDescrip = @"Unspecified Error";
    
    NSLog(@"Error during %@ fmdb code: %d (%@)", errorDescrip, [self.database lastErrorCode], [self.database lastErrorMessage]);
    
    if ( [self shouldRaiseExceptions] )
    {
        
        NSDictionary *errDict = [[self class] errorDictionaryForErrorInFmdb: self.database
                                                            duringOperation:errorDescrip
                                                                    context:contextDescrip];
        
        [[ NSException exceptionWithName: errorDescrip
                                  reason: contextDescrip
                                userInfo: errDict] raise ];
    }
    else
    {
        NSLog(@"Error: %@", errorDescrip );
        if ( contextDescrip ) NSLog(@"     : %@", contextDescrip );
        NSLog(@"fmdb error code %d: %@", [self.database lastErrorCode], [self.database lastErrorMessage]);
    }
    
}

+ (NSDictionary *) errorDictionaryForErrorInFmdb: (FMDatabase *) fmdb
                                 duringOperation: (NSString *) anOperationDescription
                                         context: (NSString *) aContextDescription;
{
    NSMutableDictionary *errDict = [ NSMutableDictionary dictionary];
    if ( fmdb )[errDict setObject:[NSNumber numberWithInt: [fmdb lastErrorCode]] forKey: @"fmdb_error_code"];
    if ( fmdb && [fmdb lastErrorMessage ] ) [errDict setObject: [fmdb lastErrorMessage] forKey: @"fmdb_error_message"];
    [errDict setObject: [NSString stringWithFormat: @"fmdb error %d (%@)", [fmdb lastErrorCode], [fmdb lastErrorMessage]] forKey: @"details"];
    if (anOperationDescription) [errDict setObject: anOperationDescription forKey: @"operation"];
    if (aContextDescription) [errDict setObject: aContextDescription forKey: @"context"];
    [errDict setObject: @"fmdb" forKey: @"type"];
    
    return errDict;
}


/* TODO: write more robust tests. */
+ (void) runTestsWithClass: (Class) aClass;
{
    if ( [aClass isMemberOfClass: [FMPersistingModel class]] )
    {
        NSLog(@"Error: attempt to delete object of FMPersistingModel class (must be subclass).");
        return;
    }
    
    FMPersistenceManager *aMgr = [[self alloc] init];
    NSString *tmpDBPath = [NSString stringWithFormat: @"%@db%d.sqlite", NSTemporaryDirectory(), (int) [NSDate timeIntervalSinceReferenceDate]];
    NSLog(@"opening tmp database at path: %@", tmpDBPath);
    [aMgr openDatabaseWithPath: tmpDBPath];
    //[aMgr.database setLogsErrors: YES];
    //[aMgr.database setTraceExecution: YES];
    [aMgr createTableIfNecessaryForClass: aClass];
    FMPersistingModel *anObject = [aMgr insertNewObjectOfClass: aClass withValues: [NSDictionary dictionaryWithObject:@"Node1234" forKey:@"name"]]; //! assuming name column
    if ( !anObject )
        NSLog(@"TEST: Fail: Did not get inserted object of class %@", NSStringFromClass([aClass class]));
    else
        NSLog(@"TEST: Success: newly inserted object: %@", anObject);
    
    NSObject *fetchedObject = [aMgr fetchObjectOfClass: aClass withID: (NSNumber *) [anObject primaryKeyValue] ];
    
    if ( !fetchedObject )
        NSLog(@"TEST: Fail: could not fetch object of class %@", NSStringFromClass(aClass));
    else
        NSLog(@"TEST: Success: fetch object by primary key value: %@ %@ same object", fetchedObject, (anObject == fetchedObject ? @"is" : @"is not" ));
    
    [aMgr insertNewObjectOfClass: aClass withValues: [NSDictionary dictionaryWithObjectsAndKeys:@"Node5678", @"name", @"windowsLaptop", @"type", nil]]; //! assuming Node class
    
    NSObject *insertedObject = [aMgr lastInsertedObjectOfClass:aClass];
    
    if ( !insertedObject )
        NSLog(@"TEST: Fail: could not fetch last inserted object of class %@", NSStringFromClass(aClass));
    else
        NSLog(@"TEST: Success: fetch last inserted object");
    
    FMPersistingModel *fetchedObjectByName = [aMgr fetchObjectOfClass: aClass withCriteria: [NSDictionary dictionaryWithObject:@"Node1234" forKey:@"name"] ];
    
    if ( !fetchedObjectByName )
        NSLog(@"TEST: Fail: could not fetch object of class %@ with criteria.", NSStringFromClass(aClass));
    else
    {
        NSLog(@"TEST: Success: fetch object by criteria");
    }
    
    [aMgr deleteObject: fetchedObjectByName];
    NSObject *deletedObject = [aMgr fetchObjectOfClass: aClass withCriteria: [NSDictionary dictionaryWithObject:@"Node1234" forKey:@"name"] ];
    
    if ( deletedObject )
        NSLog(@"TEST: Fail: deleted object still fetchable.");
    else
    {
        NSLog(@"TEST: Success: object deleted. ");
    }
}


@end
