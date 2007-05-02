//
//  LFObjectAdditions.m
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Authors: Joao Pavao <jppavao@criticalsoftware.com>
//           Jason Kim <jason@512k.org>
//
//	For more information on licensing, read the README file.
//	Para mais informa›es sobre o licenciamento, leia o ficheiro README.
//
//
// NOTE: The size of unsigned int is assumed to be 4 bytes. The Leapfrog bridge API specifies
// that sizes must be of this size; platforms with larger ints (i.e. 64-bit) should truncate as
// appropriate.
//
// TODO: Handle endianness issues.
//

#import "LFObjectAdditions.h"
#import "LFBoolean.h"


@implementation NSObject (LFObjectPlatformBridgeAdditions)

+ (id)decodeObjectWithBridgeData:(NSData *)data
{
	NSData *contentData;
	NSString *type, *name;
	unsigned int size, dataOffset, dataLength;
	const void *buf = [data bytes];
	
	// Extract object size.
	unsigned int sizeBytes;
	[data getBytes:&sizeBytes range:NSMakeRange(0, 4)];
	size = NSSwapBigIntToHost(sizeBytes);
	
	id decodedObject = nil;
	
	if (size > 0)
	{
		// Extract object type.
		buf += 4;
		type = [NSString stringWithUTF8String:buf];
		
		// Extract object name.
		buf += [type length] + 1;
		name = [NSString stringWithUTF8String:buf];
		
		// Extract content data.
		dataOffset = [type length] + [name length] + 6;    // 4 bytes for size, 2 bytes for null chars
		dataLength = [data length] - dataOffset;
		contentData = [data subdataWithRange:NSMakeRange(dataOffset, dataLength)];
		
		// Instantiate object, based on type.
		if ([type isEqualToString:[NSString objectTypeName]]) {
			decodedObject = [NSString decodeObjectWithContentData:contentData];
		}
		else if ([type isEqualToString:[NSNumber objectTypeName]]) {
			decodedObject = [NSNumber decodeObjectWithContentData:contentData];
		}
		else if ([type isEqualToString:[LFBoolean objectTypeName]]) {
			decodedObject = [LFBoolean decodeObjectWithContentData:contentData];
		}
		else if ([type isEqualToString:[NSArray objectTypeName]]) {
			decodedObject = [NSArray decodeObjectWithContentData:contentData];
		}
		else if ([type isEqualToString:[NSDictionary objectTypeName]]) {
			decodedObject = [NSDictionary decodeObjectWithContentData:contentData];
		}
		else if ([type isEqualToString:[NSData objectTypeName]]) {
			decodedObject = [NSData decodeObjectWithContentData:contentData];
		}
		else {
			[NSException raise:@"LFInvalidTypeException" format:@"Unrecognized object type (%@).", type];
		}
	}
	else
	{
		// If the size is zero, then the object is "null." For now, we choose to treat these
		// as NSNull instances ... but this could change in the future.
		decodedObject = [NSNull null];
	}
	
	return decodedObject;
}


- (NSData *)nullBridgeData
{
	// Used to represent a "null" (no object at all).
	// NOTE: This code assumes that ints are 32 bits. Naughty.
	unsigned int buf = 0;
	return [NSData dataWithBytes:&buf length:4];
}


- (NSData *)encodedBridgeData
{
	return [self encodedBridgeDataWithName:@""];
}


- (NSData *)encodedBridgeDataWithName:(NSString *)name
{
	NSString *type = [[self class] objectTypeName];
	NSData *contentData = [self encodedDataFromObjectContent];
	NSMutableData *data;
	unsigned int size;
	
	if (type == nil) 
	{
		[NSException raise:@"LFObjectEncodeException" 
				format:@"The receiver (%@) is not a recognized data type object.", [self class]];
	}
	
	size = ([type length] + 1) + ([name length] + 1) + [contentData length];
	data = [[NSMutableData alloc] initWithCapacity:size];
	
	// Add object size.
	unsigned int sizeBytes = NSSwapHostIntToBig(size);
	[data appendBytes:&sizeBytes length:4];
	
	// Add object type. Null-terminated.
	[data appendData:[type dataUsingEncoding:NSUTF8StringEncoding]];
	[data increaseLengthBy:1];
	
	// Add object name. Null-terminated.
	[data appendData:[name dataUsingEncoding:NSUTF8StringEncoding]];
	[data increaseLengthBy:1];
	
	// Add object data. (Note: Strings are not null-terminated here!)
	[data appendData:contentData];

	return [data autorelease];
}

@end


@implementation NSObject (LFObjectContentEncodingAdditions)

+ (NSString *)objectTypeName
{
	return nil;
}

+ (id)decodeObjectWithContentData:(NSData *)contentData
{
	return nil;
}

- (NSData *)encodedDataFromObjectContent
{
	return nil;
}

@end


#pragma mark -
#pragma mark NSString


@implementation NSString (LFObjectAdditions)

+ (NSString *)objectTypeName
{
	return @"string";
}

+ (id)decodeObjectWithContentData:(NSData *)contentData
{
	NSMutableData *stringData = [contentData mutableCopy];
	NSString *string;
	
	// Increasing the length by 1 adds a null byte to the end.
	[stringData increaseLengthBy:1];

	// Create the string, and free our temporary copy.
	string = [NSString stringWithUTF8String:[stringData bytes]];
	// Encoding error? Use a workaround, even if some characters get decoded in a wrong way.
	if (string == nil)
		string = [NSString stringWithCString:[stringData bytes] encoding:NSISOLatin1StringEncoding];
	
	[stringData release];
	return string;
}

- (NSData *)encodedDataFromObjectContent
{
	return [self dataUsingEncoding:NSUTF8StringEncoding];
}

@end


#pragma mark -
#pragma mark NSArray


@implementation NSArray (LFObjectAdditions)

+ (NSString *)objectTypeName
{
	return @"sequence";
}

+ (id)decodeObjectWithContentData:(NSData *)contentData
{
	NSMutableArray *array = [NSMutableArray array];
	int i, count, offset;
	
	// Extract number of items.
	unsigned int countBytes;
	[contentData getBytes:&countBytes range:NSMakeRange(0, 4)];
	count = NSSwapBigIntToHost(countBytes);

	// Extract items.
	offset = 4;
	for (i = 0; i < count; i++)
	{
		NSData *itemData;
		int itemSize, itemSizeBytes;
		
		// Extract item size.
		[contentData getBytes:&itemSizeBytes range:NSMakeRange(offset, 4)];
		itemSize = NSSwapBigIntToHost(itemSizeBytes) + 4;  // Include the size data itself.
		
		// Extract item data.
		itemData = [contentData subdataWithRange:NSMakeRange(offset, itemSize)];
		
		id decodedObject = [NSObject decodeObjectWithBridgeData:itemData];
		if (decodedObject == nil)
			decodedObject = [NSNull null];
		
		[array addObject:decodedObject];
		offset += itemSize;
	}
	
	return [[array copy] autorelease];
}

- (NSData *)encodedDataFromObjectContent
{
	NSMutableData *data = [NSMutableData data];
	NSEnumerator *enumerator = [self objectEnumerator];
	int count = [self count];
	id object;
	
	// Add number of items.
	int countBytes = NSSwapHostIntToBig(count);
	[data appendBytes:&countBytes length:4];
	
	// Add object data for each item.
	while ((object = [enumerator nextObject]))
	{
		[data appendData:[object encodedBridgeData]];
	}
	
	return data;
}

@end


#pragma mark -
#pragma mark NSDictionary


@implementation NSDictionary (LFObjectAdditions)

+ (NSString *)objectTypeName
{
	return @"map";
}

+ (id)decodeObjectWithContentData:(NSData *)contentData
{
	NSMutableDictionary *dict = [NSMutableDictionary dictionary];
	int i, count, countBytes, offset, itemSize, itemSizeBytes;
	
	// Extract number of items.
	[contentData getBytes:&countBytes range:NSMakeRange(0, 4)];
	count = NSSwapBigIntToHost(countBytes);

	// Extract items.
	offset = 4;
	for (i = 0; i < count; i++)
	{
		NSData *itemData;
		NSString *type, *name;
		const void *buf;
	
		// Extract item size.
		[contentData getBytes:&itemSizeBytes range:NSMakeRange(offset, 4)];
		itemSize = NSSwapBigIntToHost(itemSizeBytes) + 4;   // Include the size data itself.
		
		// Extract item data.
		itemData = [contentData subdataWithRange:NSMakeRange(offset, itemSize)];
		
		// Extract item name.
		buf = [itemData bytes];
		type = [NSString stringWithUTF8String:(buf + 4)];
		name = [NSString stringWithUTF8String:(buf + 4 + [type length] + 1)];
		
		id decodedObject = [NSObject decodeObjectWithBridgeData:itemData];
		if (decodedObject == nil)
			decodedObject = [NSNull null];
		
		[dict setObject:decodedObject forKey:name];
		offset += itemSize;
	}
	
	return [[dict copy] autorelease];	
}

- (NSData *)encodedDataFromObjectContent
{
	NSMutableData *data = [NSMutableData data];
	NSEnumerator *enumerator = [[self allKeys] objectEnumerator];
	int count = [[self allKeys] count];
	int countBytes = NSSwapHostIntToBig(count);
	id key;
	
	[data appendBytes:&countBytes length:4];
	
	while ((key = [enumerator nextObject]))
	{
		id object = [self objectForKey:key];
	
		if ([key isKindOfClass:[NSString class]])
		{
			[data appendData:[object encodedBridgeDataWithName:key]];
		}
		else
		{
			[NSException raise:@"LFObjectEncodeException" 
					format:@"Unexpected type of key (%@).", [self class]];
		}
	}
	
	return data;
}

@end


#pragma mark -
#pragma mark NSNumber


@implementation NSNumber (LFObjectAdditions)

// NOTE: Since NSNumber is used to represent the "int" type in the bridge framework, it is limited
//       to long long precision, despite the fact that the docs state that the integer data may
//       technically be "unbounded". Attempting to decode integers larger than 64 bits will not
//       produce the desired results.

+ (NSString *)objectTypeName
{
	return @"int";
}

+ (id)decodeObjectWithContentData:(NSData *)contentData
{
	int				dataLength = [contentData length];
	unsigned char	buf[sizeof(long long)];
	NSNumber		*retVal = nil;
	
	// Sanity check.
	if (dataLength > sizeof(long long))
	{
		[NSException raise:@"LFObjectDecodeException"
				format:@"Integer too large to decode (%d bytes, %d max).", dataLength, sizeof(long long)];
	}
	
	[contentData getBytes:(void *)buf length:dataLength];
	
	switch (dataLength) {
		case sizeof(short):
			retVal = [NSNumber numberWithShort:NSSwapBigShortToHost(*((short *)buf))];
			break;
		case sizeof(long):
			retVal = [NSNumber numberWithLong:NSSwapBigLongToHost(*((long *)buf))];
			break;
		case sizeof(long long):
			retVal = [NSNumber numberWithLongLong:NSSwapBigLongLongToHost(*((long long *)buf))];
			break;
	}

	return retVal;
}

- (NSData *)encodedDataFromObjectContent
{
	long long		value = [self longLongValue];
	unsigned char	buf[sizeof(long long)];
	int				valueSize;
	
	// Determine what type of int is this. Will we need 2 bytes? 4? 8?
	if (value <= SHRT_MAX && value >= SHRT_MIN) {
		valueSize = sizeof(short);
		*((short *)buf) = NSSwapHostShortToBig((short)value);
	}
	else if (value <= LONG_MAX && value >= LONG_MIN) {
		valueSize = sizeof(long);
		*((long *)buf) = NSSwapHostLongToBig((long)value);
	}
	else if (value <= LLONG_MAX && value >= LLONG_MIN) {
		valueSize = sizeof(long long);
		*((long long *)buf) = NSSwapHostLongLongToBig((long long)value);
	}
	
	return [NSData dataWithBytes:buf length:valueSize];
}

@end


#pragma mark -
#pragma mark LFBoolean


@implementation LFBoolean (LFObjectAdditions)

+ (NSString *)objectTypeName
{
	return @"bool";
}

+ (id)decodeObjectWithContentData:(NSData *)contentData
{
	int dataLength = [contentData length];
	unsigned char buf;
	
	// Sanity check. Boolean is only one byte.
	if (dataLength > 1)
	{
		[NSException raise:@"LFObjectDecodeException"
				format:@"Boolean too large (%d bytes, expected 1).", dataLength];
	}

	[contentData getBytes:&buf length:1];
	return ((buf) ? [LFBoolean yes] : [LFBoolean no]);
}

- (NSData *)encodedDataFromObjectContent
{
	unsigned char value = ([self boolValue]) ? 1 : 0;
	return [NSData dataWithBytes:&value length:1];
}

@end


#pragma mark -
#pragma mark NSData


@implementation NSData (LFObjectAdditions)

+ (NSString *)objectTypeName
{
	return @"bytearray";
}

+ (id)decodeObjectWithContentData:(NSData *)contentData
{
	return [[contentData copy] autorelease];
}

- (NSData *)encodedDataFromObjectContent
{
	return self;
}

@end


