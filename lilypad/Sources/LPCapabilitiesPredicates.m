//
//  LPCapabilitiesPredicates.m
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informa›es sobre o licenciamento, leia o ficheiro README.
//

#import "LPCapabilitiesPredicates.h"


@implementation NSArray (LPCapabilitiesPredicates)

- (id)firstItemInArrayPassingCapabilitiesPredicate:(SEL)conditionSel
{
	id item = nil;
	
	if ([self count] > 0) {
		NSMethodSignature *methodSig = [[self objectAtIndex:0] methodSignatureForSelector:conditionSel];
		NSInvocation *inv = [NSInvocation invocationWithMethodSignature:methodSig];
		
		[inv setSelector:conditionSel];
		
		NSEnumerator *itemEnum = [self objectEnumerator];
		BOOL itemRet;
		
		while (item = [itemEnum nextObject]) {
			NSAssert1([item conformsToProtocol:@protocol(LPCapabilitiesPredicates)],
					  @"*** Object does not conform to LPCapabilitiesPredicates protocol: %@", item);
			
			[inv invokeWithTarget:item];
			[inv getReturnValue:&itemRet];
			
			if (itemRet) break;
		}
	}
	
	return item;
}

- (BOOL)someItemInArrayPassesCapabilitiesPredicate:(SEL)conditionSel
{
	return ([self firstItemInArrayPassingCapabilitiesPredicate:conditionSel] != nil);
}

@end
