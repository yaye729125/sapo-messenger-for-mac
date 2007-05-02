//
//  LFBoolean.m
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Authors: Joao Pavao <jppavao@criticalsoftware.com>
//           Jason Kim <jason@512k.org>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "LFBoolean.h"


@implementation LFBoolean


+ (LFBoolean *)yes
{
	return [[[LFBoolean alloc] initWithValue:YES] autorelease];
}


+ (LFBoolean *)no
{
	return [[[LFBoolean alloc] initWithValue:NO] autorelease];
}


- (id)initWithValue:(BOOL)value
{
	self = [super init];
	_value = value;
	return self;
}


- (BOOL)boolValue
{
	return _value;
}


- (NSString *)description
{
	return (_value) ? @"YES" : @"NO";
}


@end
