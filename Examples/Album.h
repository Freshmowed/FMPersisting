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


