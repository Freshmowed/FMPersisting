# FMPersisting
Lightweight, opinionated ORM over fmdb sqlite framework

This framework provides a straightforward mapping between Objective-C model classes and sqlite databases. It is
for people that like sqlite and fmdb, and understand sql and relational database concepts. It makes development
easier by eliminating the mental shift between classes/objects/properties and relational tables/columns. It does
not try to hide or replace the underlying fmdb or sqlite functionality -- they are still accessible, and can be
used without conflict. This code has been in production for several years in the iOS app, Bookmobile Audiobook and
Podcast Player, and in several other Mac OS X and iOS projects.

The framework consists of just two classes: FMPersistingModel and FMPersistenceManager. FMPersistingModel can be used 
as a superclass of "model" objects that get persisted to a single table in sqlite.  In many situations, 
the model subclass need only implement two methods: -tableName and -columns, which define the mapping between
a class and table name, and properties-to-columns. The PersistenceManager class will handle table creation 
(if necessary), and the subclass-to-db-table mapping for fetching, inserting, updating.

The FMPersistenceManager class provides all the standard CRUD operations for FMPersistingModel subclasses.

The framework makes extensive use of key-value coding (KVC), and by default, constructs a database schema 
that converts the common camelcase format of obj-c properties to the common all-caps and underscores for
database column names.

# Example Class-to-Table mapping:
<pre><code>
//////////////  Album.h  //////////////
#import <Foundation/Foundation.h>
#import "FMPersistingModel.h"

@interface Album : FMPersistingModel
{
}

// Persisted properties
@property (nonatomic, retain) NSNumber *ID;
@property (nonatomic, retain) NSString *mediaKey;
@property (nonatomic, retain) NSDate *lastPlayedDate;
@property (nonatomic, retain) NSData *coverImageData;
@property (nonatomic, retain) NSNumber *mediaType;
@property (nonatomic, retain) NSString *title;
@property (nonatomic, retain) NSString *artist;
@property (nonatomic, retain) NSString *descrip;
@property (nonatomic, retain) NSString *publishDate;
@property (nonatomic, retain) NSNumber *flags;

@end

//////////////  Album.m  /////////////
#import "Album.h"

@implementation Album 

+ (NSString *) tableName;
{
    return @"ALBUM";
}

+ (NSDictionary *) columns;
{
    return @{@"ID" : @"int",
             @"MEDIA_KEY" : @"string",
             @"LAST_PLAYED_DATE" : @"date",
             @"COVER_IMAGE_DATA" : @"data",
             @"TITLE" : @"string",
             @"ARTIST" : @"string",
             @"DESCRIP" : @"string",
             @"PUBLISH_DATE" : @"date",
             @"FLAGS" : @"int" };
}
</code></pre>

That's it. There are additional options for mapping to different names, defining primary key columns, using bit-fields,
and more, but for the most common situations, that's all you have to do.

# Performing CRUD Operations

Before any database operations can be performed a FMPersistenceManager instance needs to be created, 
a database path defined, and table(s) created if necessary. After that, rows are created from attribute
dictionaries, objects are created from database rows, and property values are accessed using KVC. A LOT
of boilerplate database access code is eliminated.

The example below is a data manager class that wraps the CRUD operations for the Album FMPersistingModel
subclass defined above.

<pre><code>

//////////////  AlbumManager.m  ////////////
#import "AlbumManager.h"

@interface AlbumManager ()
{
}

@property (retain, nonatomic) FMPersistenceManager *persistenceManager;

@end

@implementation AlbumManager

- (instancetype) init;
{
    self = [super init];
    if (self != nil)
    {
        self.persistenceManager = [[FMPersistenceManager alloc] init];
        [_persistenceManager openDatabaseWithPath: @"YOUR DATABASE PATH HERE" ];
    	[_persistenceManager createTableIfNecessaryForClass:[Album class]];
    }
    return self;
}

- (Album *) createNewAlbumWithTitle: (NSString *) title artist: (NSString *) artist
{
    return (Album *) [self.persistenceManager insertNewObjectOfClass: [Album class]
                                  withValues: @{@"title": title, @"artist" : artist}]; 
}

- (Album *) fetchAlbumWithTitle: (NSString *) title
{
    return (Album *) [self.persistenceManager fetchObjectOfClass: [Album class]
                                                    withCriteria: @{@"title" : title }];
}

- (NSArray *) allAlbums
{
    return [self.persistenceManager fetchAllObjectsOfClass: [Album class] ];
}

- (void) albumDidBeginPlaying: (Album *) album
{
    [self.persistenceManager updateValue: [NSDate date]
                                  forKey: @"lastPlayedDate" 
                                ofObject: album];
}

- (void) deleteAlbum: (Album *) album
{
    [self.persistenceManager deleteObject: album];
}

@end
</code></pre>
