//
//  NSString+HTMLAdditions.m
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jpavao@co.sapo.pt>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "NSString+HTMLAdditions.h"


@implementation NSString (HTMLAdditions)


- (NSString *)stringByEscapingHTMLEntities
{
	NSMutableString *mutableCopy = [self mutableCopy];
	
	[mutableCopy replaceOccurrencesOfString:@"&"
								 withString:@"&amp;"
									options:NSLiteralSearch
									  range:NSMakeRange(0, [mutableCopy length])];
	[mutableCopy replaceOccurrencesOfString:@"<"
								 withString:@"&lt;"
									options:NSLiteralSearch
									  range:NSMakeRange(0, [mutableCopy length])];
	[mutableCopy replaceOccurrencesOfString:@">"
								 withString:@"&gt;"
									options:NSLiteralSearch
									  range:NSMakeRange(0, [mutableCopy length])];
	[mutableCopy replaceOccurrencesOfString:@"\""
								 withString:@"&quot;"
									options:NSLiteralSearch
									  range:NSMakeRange(0, [mutableCopy length])];
	[mutableCopy replaceOccurrencesOfString:@"\'"
								 withString:@"&apos;"
									options:NSLiteralSearch
									  range:NSMakeRange(0, [mutableCopy length])];
	
	return [mutableCopy autorelease];
}


- (NSString *)stringByUnescapingHTMLEntities
{
	NSMutableString *mutableCopy = [self mutableCopy];
	
	[mutableCopy replaceOccurrencesOfString:@"&apos;"
								 withString:@"\'"
									options:NSLiteralSearch
									  range:NSMakeRange(0, [mutableCopy length])];
	[mutableCopy replaceOccurrencesOfString:@"&quot;"
								 withString:@"\""
									options:NSLiteralSearch
									  range:NSMakeRange(0, [mutableCopy length])];
	[mutableCopy replaceOccurrencesOfString:@"&gt;"
								 withString:@">"
									options:NSLiteralSearch
									  range:NSMakeRange(0, [mutableCopy length])];
	[mutableCopy replaceOccurrencesOfString:@"&lt;"
								 withString:@"<"
									options:NSLiteralSearch
									  range:NSMakeRange(0, [mutableCopy length])];
	[mutableCopy replaceOccurrencesOfString:@"&amp;"
								 withString:@"&"
									options:NSLiteralSearch
									  range:NSMakeRange(0, [mutableCopy length])];
	
	return [mutableCopy autorelease];
}


@end
