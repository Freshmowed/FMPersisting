# FMPersisting
Lightweight, opinionated ORM over fmdb sqlite framework

This framework provides a straightforward mapping between Objective-C model classes and sqlite databases.
It consists of just two classes: FMPersistingModel and FMPersistenceManager. FMPersistingModel can be used 
as a superclass of "model" objects that get persisted using the fmdb sqlite framework.  In many situations, 
the model subclass need only implement two methods: -tableName and -columns, which define the mapping between
a class and table name, and properties-to-columns. The PersistenceManager class will handle table creation 
(if necessary), and the subclass-to-db-table mapping for fetching, inserting, updating.

The FMPersistenceManager class provides all the standard CRUD operations for FMPersistingModel subclasses.

The framework makes extensive use of key-value coding (KVC), and by default, constructs a database schema 
that converts the common camelcase format of obj-c properties to the common all-caps and underscores for
database column names.

Exmple:
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
        [_persistenceManager openDatabaseWithPath: @"<path to sqlite database>" ];
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
