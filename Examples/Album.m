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

@end
