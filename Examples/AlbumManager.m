#import "AlbumManager.h"
#import "Album.h"

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