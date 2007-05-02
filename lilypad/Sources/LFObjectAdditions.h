//
//  LFObjectAdditions.h
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Authors: Joao Pavao <jppavao@criticalsoftware.com>
//           Jason Kim <jason@512k.org>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//
//
// A category on all objects that provides object serialization facilities for the bridge API.
// 
// For simplicity, this is implemented as an informal protocol, but the implementation provides
// all of the needed categories on specific object classes (NSArray, NSDictionary, NSString,
// NSNumber, and LFBoolean) to easily serialize them into the internal raw representation and
// back again.
//
// The methods have no effect or return 'nil' for all other objects, by default.
//

#import <Cocoa/Cocoa.h>


@interface NSObject (LFObjectPlatformBridgeAdditions)
+ (id)decodeObjectWithBridgeData:(NSData *)data;
- (NSData *)nullBridgeData;
- (NSData *)encodedBridgeData;
- (NSData *)encodedBridgeDataWithName:(NSString *)name;
@end

@interface NSObject (LFObjectContentEncodingAdditions)
+ (NSString *)objectTypeName;
+ (id)decodeObjectWithContentData:(NSData *)contentData;
- (NSData *)encodedDataFromObjectContent;
@end
