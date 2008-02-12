//
//  LPCapabilitiesPredicates.m
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jpavao@co.sapo.pt>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "LPCapabilitiesPredicates.h"
#import "LPAccountStatus.h"

@implementation NSArray (LPCapabilitiesPredicates)

- (id)p_firstItemInArrayPassingCapabilitiesPredicate:(SEL)conditionSel checkOnlyOnlineItems:(BOOL)onlyOnlineItems
{
	id item = nil;
	
	if ([self count] > 0) {
		NSMethodSignature *methodSig = [[self objectAtIndex:0] methodSignatureForSelector:conditionSel];
		NSInvocation *inv = [NSInvocation invocationWithMethodSignature:methodSig];
		
		[inv setSelector:conditionSel];
		
		NSEnumerator *itemEnum = [self objectEnumerator];
		BOOL itemRet;
		
		while (item = [itemEnum nextObject]) {
			
			if (onlyOnlineItems && !([item respondsToSelector:@selector(isOnline)] && [item isOnline]))
				continue;
			
			NSAssert1([item conformsToProtocol:@protocol(LPCapabilitiesPredicates)],
					  @"*** Object does not conform to LPCapabilitiesPredicates protocol: %@", item);
			
			[inv invokeWithTarget:item];
			[inv getReturnValue:&itemRet];
			
			if (itemRet) break;
		}
	}
	
	return item;
}

- (BOOL)p_someItemInArrayPassesCapabilitiesPredicate:(SEL)conditionSel checkOnlyOnlineItems:(BOOL)onlyOnlineItems
{
	return ([self p_firstItemInArrayPassingCapabilitiesPredicate:conditionSel checkOnlyOnlineItems:onlyOnlineItems] != nil);
}

- (id)firstItemInArrayPassingCapabilitiesPredicate:(SEL)conditionSel
{
	return [self p_firstItemInArrayPassingCapabilitiesPredicate:conditionSel checkOnlyOnlineItems:NO];
}

- (id)firstOnlineItemInArrayPassingCapabilitiesPredicate:(SEL)conditionSel
{
	return [self p_firstItemInArrayPassingCapabilitiesPredicate:conditionSel checkOnlyOnlineItems:YES];
}

- (BOOL)someItemInArrayPassesCapabilitiesPredicate:(SEL)conditionSel
{
	return [self p_someItemInArrayPassesCapabilitiesPredicate:conditionSel checkOnlyOnlineItems:NO];
}

- (BOOL)someOnlineItemInArrayPassesCapabilitiesPredicate:(SEL)conditionSel
{
	return [self p_someItemInArrayPassesCapabilitiesPredicate:conditionSel checkOnlyOnlineItems:YES];
}

@end
