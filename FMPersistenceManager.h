//
//  FMPersistenceManager.h
//
//  Created by Duke Browning on 10/08/2010.
//  Copyright (c) 2009-2015 freshmowed software. See included LICENSE file.
//

#import <Foundation/Foundation.h>

@class FMDatabase;
@class FMResultSet;
@class FMPersistingModel;

@interface FMPersistenceManager : NSObject

// This property allows clients of this persistenceManager to get/use a common serial queue in GCD.
// No enforcement of this is accomplished by this class, however if a serialQueue is set, and an
// operation is performed on the main thread, a warning log message is generated. Conversely, if
// no serialQueue is set, and a method is called NOT on the main thread, a warning log message is
// written.
@property (nonatomic, retain) dispatch_queue_t serialQueue;

@property (nonatomic, retain) FMDatabase *database;
@property (nonatomic, retain) NSString *databasePath;

@property BOOL shouldRaiseExceptions;
@property BOOL shouldUseMainThread;

/* optional default instance */
+ (FMPersistenceManager *) sharedInstance;
+ (void) setSharedInstance: (FMPersistenceManager *) psMgr;

+ (FMPersistenceManager *) managerWithIdentifier: (NSString *) identifier;

+ (void) runTestsWithClass: (Class) aClass;

- (id) initWithIdentifier: (NSString *) identifier;

- (FMDatabase *) openDatabaseWithPath: (NSString *) aPath;
- (void) closeDatabase;

/* Yes, this will really do it.  Exposed for sample data (re)loading */
- (NSError *) deleteDatabase;
/* For schema updates - DESTRUCTIVE */
- (void) dropTableForClass: (Class) aClass;

/* schema methods */
- (BOOL) columnExists:(NSString*)columnName inTableWithName:(NSString*)tableName;
- (BOOL) createTableIfNecessaryForClass: (Class) aClass;

/* CRUD - Create  methods */
- (FMPersistingModel *) insertNewObjectOfClass: (Class) aClass withValues: (NSDictionary *) aDict;
- (FMPersistingModel *) lastInsertedObjectOfClass: (Class) aClass;

/* CRUD - Retrieve  methods */

/*
 Criteria dictionaries contain object keys (KVC) and values to search on.
 The string "<NOT>" can be prepended to a key to use a not-equal-to rather than equal-to condition.
 
 Examples: @{@"employeeID" : @38845}, @{@"color" : @"red", @"<NOT>size" : @"large" }
 
 Where clauses are used as is, so they should include column names, not object (KVC) keys.
 
 For the single object queries, if more than one record is returned using criteria, only the first will be returned.
 
 NOTE: bitfields cannot be used in queries.
 */
- (FMPersistingModel *) fetchObjectOfClass: (Class) aClass
                              withCriteria: (NSDictionary *) aDict;
- (FMPersistingModel *) fetchObjectOfClass: (Class) aClass
                           withWhereClause: (NSString *) whereClause;
- (FMPersistingModel *) fetchObjectOfClass: (Class) aClass
                                    withID: (NSNumber *) anID;

- (NSArray *) fetchAllObjectsOfClass: (Class) aClass;

- (NSArray *) fetchObjectsOfClass: (Class) aClass withCriteria: (NSDictionary *) aDict;
- (NSArray *) fetchObjectsOfClass: (Class) aClass
                  withWhereClause: (NSString *) whereClause;
- (NSArray *) fetchObjectsOfClass: (Class) aClass
                  withWhereClause: (NSString *) whereClause
                       sortClause: (NSString *) sortClause;

/* CRUD - Update  methods */
- (BOOL) saveObject: (FMPersistingModel *) anObject;

/*
 These methods set the value on the object in addition to persisting,
 so instead of myObject.foo = aValue, then persisting value, just all this method to do both.
 */
- (BOOL) updateValue: (NSObject *) aValue forKey: (NSString *) aKey ofObject: (FMPersistingModel *) anObject;

/* CRUD - Delete  methods */
- (void) deleteObject: (FMPersistingModel *) anObject;
- (void) deleteAllObjectsOfClass: (Class) aClass; // yes, will empty a table

/* delegate style block handlers for CUD operations */
- (void)addInsertHandler:(void (^)())aHandler forClassName: (NSString *) className;
- (void)addDeleteHandler:(void (^)())aHandler forClassName: (NSString *) className;
- (void)addUpdateHandler:(void (^)())aHandler forClassName: (NSString *) className key: (NSString *) aKey; // only called by updateValue:forKey:ofObject methods

@end
