//
//  LPRosterDragAndDrop.m
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Authors: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "LPRosterDragAndDrop.h"
#import "LPContact.h"
#import "LPContactEntry.h"
#import "NSString+ConcatAdditions.h"


// Pasteboard types
NSString *LPRosterContactPboardType			= @"LPRosterContactPboardType";
NSString *LPRosterContactEntryPboardType	= @"LPRosterContactEntryPboardType";


void LPAddContactsToPasteboard(NSPasteboard *pboard, NSArray *contacts)
{
	NSMutableArray	*contactsPtrList = [NSMutableArray arrayWithCapacity:[contacts count]];
	NSEnumerator	*contactEnum = [contacts objectEnumerator];
	LPContact		*contact;
	
	while (contact = [contactEnum nextObject])
		[contactsPtrList addObject:[NSNumber numberWithUnsignedInt:(unsigned int)contact]];
	
	[pboard declareTypes:[NSArray arrayWithObjects:LPRosterContactPboardType, NSStringPboardType, nil] owner:nil];
	[pboard setPropertyList:contactsPtrList forType:LPRosterContactPboardType];
	[pboard setString:[NSString concatenatedStringWithValuesForKey:@"name" ofObjects:contacts useDoubleQuotes:NO] forType:NSStringPboardType];
}


void LPAddContactEntriesToPasteboard(NSPasteboard *pboard, NSArray *contactEntries)
{
	NSMutableArray	*entriesPtrList = [NSMutableArray arrayWithCapacity:[contactEntries count]];
	NSEnumerator	*entriesEnum = [contactEntries objectEnumerator];
	LPContactEntry	*entry;
	
	while (entry = [entriesEnum nextObject])
		[entriesPtrList addObject:[NSNumber numberWithUnsignedInt:(unsigned int)entry]];
	
	[pboard declareTypes:[NSArray arrayWithObjects:LPRosterContactEntryPboardType, NSStringPboardType, nil] owner:nil];
	[pboard setPropertyList:entriesPtrList forType:LPRosterContactEntryPboardType];
	[pboard setString:[NSString concatenatedStringWithValuesForKey:@"address" ofObjects:contactEntries useDoubleQuotes:NO] forType:NSStringPboardType];
}


NSArray * LPRosterContactsBeingDragged(NSPasteboard *pboard)
{
	NSArray				*draggedTypes = [pboard types];
	
	if ([draggedTypes containsObject:LPRosterContactPboardType]) {
		NSArray			*contactsPtrsList = [pboard propertyListForType:LPRosterContactPboardType];
		NSMutableArray	*contactsList = [NSMutableArray arrayWithCapacity:[contactsPtrsList count]];
		
		NSEnumerator	*contactsPtrsEnum = [contactsPtrsList objectEnumerator];
		NSNumber		*contactPtrValue;
		
		while (contactPtrValue = [contactsPtrsEnum nextObject]) {
			LPContact *contact = (LPContact *)[contactPtrValue unsignedIntValue];
			[contactsList addObject:contact];
		}
		return contactsList;
	}
	else {
		return nil;
	}
}


NSArray * LPRosterContactEntriesBeingDragged(NSPasteboard *pboard)
{
	NSArray				*draggedTypes = [pboard types];
	
	if ([draggedTypes containsObject:LPRosterContactEntryPboardType]) {
		NSArray			*entriesPtrsList = [pboard propertyListForType:LPRosterContactEntryPboardType];
		NSMutableArray	*entriesList = [NSMutableArray arrayWithCapacity:[entriesPtrsList count]];
		
		NSEnumerator	*entriesPtrsEnum = [entriesPtrsList objectEnumerator];
		NSNumber		*entryPtrValue;
		
		while (entryPtrValue = [entriesPtrsEnum nextObject]) {
			LPContactEntry *entry = (LPContactEntry *)[entryPtrValue unsignedIntValue];
			[entriesList addObject:entry];
		}
		return entriesList;
	}
	else {
		return nil;
	}
}

