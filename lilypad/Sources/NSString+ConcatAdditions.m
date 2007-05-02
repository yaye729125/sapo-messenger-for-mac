//
//  NSString+ConcatAdditions.m
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informa›es sobre o licenciamento, leia o ficheiro README.
//

#import "NSString+ConcatAdditions.h"


#define MAX_NR_OF_LISTED_ITEMS		10


@implementation NSString (HumanReadableObjectConcatenationAdditions)

+ (NSString *)concatenatedStringWithValuesForKey:(NSString *)key ofObjects:(NSArray *)objs useDoubleQuotes:(BOOL)useQuotes
{
	return [self concatenatedStringWithValuesForKey:key ofObjects:objs useDoubleQuotes:useQuotes maxNrListedItems:MAX_NR_OF_LISTED_ITEMS];
}

+ (NSString *)concatenatedStringWithValuesForKey:(NSString *)key ofObjects:(NSArray *)objs useDoubleQuotes:(BOOL)useQuotes maxNrListedItems:(int)maxNrItems
{
	int nrOfObjects = [objs count];
	NSMutableString *result = [NSMutableString string];
	
	if (nrOfObjects == 1) {
		if (useQuotes) [result appendString:@"\""];
		[result appendString:[[objs objectAtIndex:0] valueForKey:key]];
		if (useQuotes) [result appendString:@"\""];
	}
	else if (nrOfObjects > 1) {
		int i;
		for (i = 0; i < MIN(maxNrItems, nrOfObjects); ++i) {
			
			if (i > 0) {
				if (i == (nrOfObjects - 1)) {
					// We're about to write the last object
					[result appendString:NSLocalizedString(@" and ", @"multiple items description final separator")];
				}
				else {
					// We're about to write an object that lies in the middle
					[result appendString:NSLocalizedString(@", ", @"multiple items description separator")];
				}
			}
			
			if (useQuotes) [result appendString:@"\""];
			[result appendString:[[objs objectAtIndex:i] valueForKey:key]];
			if (useQuotes) [result appendString:@"\""];
		}
		
		if (nrOfObjects > maxNrItems) {
			[result appendString:
				[NSString stringWithFormat:NSLocalizedString(@" among others (total of %d items)", @"multiple items description final separator"),
					nrOfObjects]];
		}
	}
	
	return result;
}

@end
