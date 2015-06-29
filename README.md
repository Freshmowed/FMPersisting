# FMPersisting

The simplest alternative to Core Data. There is not a faster, simpler way to persist your classes.

Lightweight, opinionated* ORM over fmdb sqlite framework by Duke Browning. 

FMPersisting is simple, open, and straightforward. It maps Objective-C model classes to sqlite database tables, and allows operations to be performed using objects/methods rather than sql in the vast majority of cases. It makes development easier by eliminating the mental shift between classes/objects/properties and relational tables/columns. It is
for people that like sqlite and fmdb, and are comfortable with sql and relational database concepts. 

FMPersisting does not try to hide or replace the underlying fmdb or sqlite functionality -- they are still accessible, and can be used without conflict. There is no attempt to "automatically" synchronize an object graph with the database. 

This code has been in production for several years in the iOS app, Bookmobile Audiobook and Podcast Player, and in several other Mac OS X and iOS projects.

*everyone's got one. I've used many object-relational mapping frameworks extensively over my career (NeXT's DBKit and EOF, Apple's CoreData, Java Hibernate, PHP Symfony/Doctrine, ...) and (IMO) are more trouble than they are worth for most projects. 

# FMPersisting Framework Classes

The framework consists of just two classes: FMPersistingModel and FMPersistenceManager. FMPersistingModel must be used as the superclass of "model" objects that get persisted to a single table in sqlite.  In many situations, the model subclass need only implement one method: -columns, which defines the mapping between properties and columns. The PersistenceManager class will handle table creation (if necessary), and the subclass-to-db-table mapping for fetching, inserting, updating.

The FMPersistenceManager class provides all the standard CRUD operations for FMPersistingModel subclasses.

The framework makes extensive use of key-value coding (KVC), and by default, constructs a database schema 
that converts the common camelcase format of obj-c properties to the common all-caps and underscores for
database column names.

# Example Class-to-Table mapping:
<pre><code>
//////////////  Album.h  //////////////
#import &lt;Foundation/Foundation.h&gt;
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
@property (nonatomic, retain) NSNumber *artistID;
@property (nonatomic, retain) NSString *descrip;
@property (nonatomic, retain) NSString *publishDate;
@property (nonatomic, retain) NSNumber *flags;

@end
</code></pre>

<pre><code>
//////////////  Album.m  /////////////
#import "Album.h"

@implementation Album 

+ (NSDictionary *) columns;
{
    return @{@"ID" : @"int",
             @"MEDIA_KEY" : @"string",
             @"LAST_PLAYED_DATE" : @"date",
             @"COVER_IMAGE_DATA" : @"data",
             @"TITLE" : @"string",
             @"ARTIST_ID" : @"int",
             @"DESCRIP" : @"string",
             @"PUBLISH_DATE" : @"date",
             @"FLAGS" : @"int" };
}
</code></pre>

That's it. There are additional options for mapping to different names, defining primary key columns, using bit-fields,
and more, but for the most common situations, that's all you have to do.

Relationships between objects/tables are managed by the direct manipulation of foreign ID properties. In the example above, an Artist class would be defined and the artistID property in Album would hold the reference. No magic, no object graphs. 

You decide what you want to cache and when.

# Performing CRUD Operations

Before any database operations can be performed a FMPersistenceManager instance needs to be created, 
a database path defined, and table(s) created if necessary. After that, rows are created from attribute
dictionaries, objects are created from database rows, and property values are accessed using KVC. A LOT
of boilerplate database access code is eliminated.

There is no attempt to synchronize the database with an object graph. There are a relatively small number of
methods available in FMPersistenceManager that you use to fetch from or modify the database. When and why this
happens is explicitly and intentionally controlled by the overlying application.

The example below is a data manager class that wraps the CRUD operations for the Album FMPersistingModel
subclass defined above.

<pre><code>

//////////////  AlbumManager.m  ////////////
#import "AlbumManager.h"
#import "Album.h"
#import "Artist.h"

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

- (Album *) createNewAlbumWithTitle: (NSString *) title artist: (Artist *) artist
{
    return (Album *) [self.persistenceManager insertNewObjectOfClass: [Album class]
                                  withValues: @{@"title": title, @"artistID" : artist.ID}]; 
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

- (NSArray *) albumsByArtist: (Artist *) artist
{
    return [self.persistenceManager fetchAllObjectsOfClass: [Album class] 
                                              withCriteria: @{"artistID" : artist.ID}];
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
