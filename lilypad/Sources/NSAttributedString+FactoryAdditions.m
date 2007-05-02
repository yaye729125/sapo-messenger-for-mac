//
//  NSAttributedString+FactoryAdditions.m
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Authors: Joao Pavao <jppavao@criticalsoftware.com>
//           Jason Kim <jason@512k.org>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "NSAttributedString+FactoryAdditions.h"


@implementation NSAttributedString (FactoryAdditions)

+ (NSAttributedString *)attributedStringFromString:(NSString *)string font:(NSFont *)font color:(NSColor *)color
{
	NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
			font, NSFontAttributeName, 
			color, NSForegroundColorAttributeName,
			nil];
	return [[[NSAttributedString alloc] initWithString:string attributes:attributes] autorelease];
}

+ (NSAttributedString *)attributedStringFromString:(NSString *)string
{
	return [[[NSAttributedString alloc] initWithString:string] autorelease];
}

@end