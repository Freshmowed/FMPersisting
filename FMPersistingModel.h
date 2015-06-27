//
//  FMPersistingModel.h
//
//  Created by Duke Browning on 10/08/2010.
//  Copyright (c) 2009-2015 freshmowed software. See included LICENSE file.
//

#import <Foundation/Foundation.h>

@class FMResultSet;

/* This class can be used as a superclass of "model" objects that get persisted using the 
 * fmdb sqlite framework to make life much easier.  In many situations, the model class need only
 * implement two methods: -tableName and -columns.  Then the PersistenceManager class will handle
 * table creation (if necessary), and object-to-db-table mapping for fetching, inserting, updating.
 *
 * The FMPersistenceManager class provides all the standard CRUD operations for FMPersistingModel subclasses.
 */

@interface FMPersistingModel : NSObject
{
}

@property (assign) BOOL hasPersisted;

/* These two methods should be overridden by subclasses */
+ (NSString *) tableName;

/* Should return a dictionary containing column name keys and column data type values. 
 * Datatypes are NSStrings of ObjC primitive types, values supported are: "int", "long", long long",
 * "bool", "float", "double", "string", "date", "data", "data nocopy".
 * An appropriate sqlite datatype affinity will be used when creating the schema.
 */
+ (NSDictionary *) columns;
/* end required subclass methods */

/* All of the remaining methods generally do the right thing, but can be overridden by subclasses for
 * special cases.
 */

/* Subclasses may provide a list of column names that aren't automatically fetched or inserted.  This
 * might be BLOB columns that should be lazily loaded.
 */
+ (NSArray *) excludedColumnNames;

+ (NSString *) primaryKeyColumnName; // @"ID" by default
+ (NSString *) primaryKeyKey;

/*
 * Subclasses can define one or more properties to hold bitfields. Then the bool properties persisted
 * by the bitfield can be updated using key-value coding, without dealing with the underlying bitfield column peristence.
 * For Example:
 * @property (nonatomic, retain) NSNumber *flags; // Persisted, defined in columns dict as an int, holds PodcastDownloadPrefFlags
 *
 * typedef NS_OPTIONS(NSUInteger, PodcastDownloadPrefFlags)
 * {
 *    PodcastPrefFlagAutoDownload       = 1 << 0,
 *    PodcastPrefFlagWiFiOnly           = 1 << 1
 * };
 *
 * + (NSArray *) bitFieldMappings;
 * {
 *   return @[ @{ @"bitFieldProperty" : @"flags",
 *             @"autoDownloadEnabled" : @(PodcastPrefFlagAutoDownload),
 *                    @"wifiRequired" : @(PodcastPrefFlagWiFiOnly) } ];
 * }
 *
 * BOOL downloadEnabled = [(NSNumber *)[_podcast valueForKey: @"autoDownloadEnabled"] boolValue];
 *
 */
+ (NSArray *) bitFieldMappings;

/* Returns YES by default. Subclasses that don't use database generated primary keys, should return NO, and provide the
 * primary key value in the data dictionary for inserts.
 */
+ (BOOL) primaryKeyAutoGenerated;

/*
 * You can force the persistence of a particular column whenever a property value changes (outside of the normal
 * mappings) by providing a mapping between the properties and column names using the columnNamesForKeys method.
 * For Example:
 * + (NSDictionary *) columnNamesForKeys;
 * {
 *    return @{ @"wasDeleted" : @"FLAGS",
 *              @"hasNewInfo" : @"FLAGS",
 *              @"hasNoImage" : @"FLAGS" };
 * }
 */
+ (NSDictionary *) columnNamesForKeys;

/* Convenience methods autogenerated by tableName and columns info.  */
+ (NSString *) schemaStatement;
+ (NSString *) baseQueryString;
+ (NSArray *) columnNames;
+ (NSString *) columnNamesCSV;

/* Returns a dictionary containing the statement (key: "statement") and 
 * values (key: "valueArray") to be used in an insert operation given
 * the passed columnName/value dictionary.  Insert statement will be of the form: 
 * "insert into <tablename> (<column1>, <column2>,...) values (<value1>, <value2>, ...)"
 */
+ (NSDictionary *) insertStatementWithValues: (NSDictionary *) aDict;

/* Returns a dictionary containing the statement (key: "statement") and 
 * values (key: "valueArray") to be used in an update operation given
 * the passed columnNames array.  If the columnNames array is nil, all columns will be
 * updated.  The receiver's ID value will be used in the where
 * clause.  Update statement will be of the form: 
 * "update <tablename> set <column1> = <value1>, <column2> = <value2> where ID = <ID_value>"
 */
- (NSDictionary *) updateStatementForColumns: (NSArray *) columnNames;

/* Returns the KVC key to be used for a database column.  The key will be autogenerated from the column name, converting
 * columns such as LAST_NAME to lastName by default, if a value is not explicitly set using 
 * setKey:forColumnName:, or addKeysForColumnNames:. The method convertColumnNameToKey: can be overridden if the default
 * conversion algorithm isn't acceptable.
 */
+ (NSString *) keyForColumnName: (NSString *) aName;

/* Provides algorithm for converting a column name to a KVC key.  For example:  FIRST_NAME -> firstName, DEPT_ID -> deptID.
 * Note, "ID" remains "ID", not Id -- because that's the way I like it
 */
+ (NSString *) convertColumnNameToKey: (NSString *) aName;

+ (NSString *) columnNameForKey: (NSString *) aKey;

/* If aValue for aKey is a string, returns a quote-wrapped aValue */
+ (NSString *) smartQuote: (NSString *) quote value: (id) aValue forKey: (NSString *) aKey;
+ (NSString *) smartQuoteValue: (id) aValue forKey: (NSString *) aKey; // convenience using double quotes

/*
 *  Set special key values for individual columns.  For example, you might want to use "firstName" for a column "GIVEN_NAME".
 */
+ (void) setKey: (NSString *) aKey forColumnName: (NSString *) aName;
+ (void) addKeysForColumnNames: (NSDictionary *) aDict;

/*
 * Use this when one column holds vales for more than one key, such as a bitfield.
 */
+ (void) setColumnName: (NSString *) aColumnName forKey: (NSString *) aKey;

+ (FMPersistingModel *) objectFromResultSet: (FMResultSet *) aResultSet;
+ (FMPersistingModel *) nonPersistedObjectFromDictionary: (NSDictionary *) dict;

/* shortcut for returning the value of the property defined to be the database table's primary key */
- (NSObject *) ID;

/* Default implementation compares primaryKeyColumnName values. */
- (BOOL)isEqual:(id)anObject;

/* Sets all persisted values from anotherObject to those of receiver (using KVC), except for the primary key. */
- (void) copyValuesFrom: (FMPersistingModel *) anotherObject;

/*
 *  Returns a key/value dictionary of persisted values suitable for conversion to JSON.
 */
- (NSMutableDictionary *) toDictionary;
- (NSMutableDictionary *) toDictionaryForKeys: (NSArray *) keys;

/*
 *  Convenience methods for getting/setting bit fields.
 */
- (BOOL) isBitSet: (NSUInteger) bitMask on: (NSNumber *) flags;
- (NSNumber *) setBit: (NSUInteger) bitMask on: (NSNumber *) bitField to: (BOOL) aBool;

@end
