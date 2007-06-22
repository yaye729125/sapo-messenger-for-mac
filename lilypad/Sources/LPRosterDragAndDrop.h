//
//  LPRosterDragAndDrop.h
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Authors: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import <Cocoa/Cocoa.h>


// Pasteboard types
extern NSString *LPRosterContactPboardType;
extern NSString *LPRosterContactEntryPboardType;


void		LPAddContactsToPasteboard			(NSPasteboard *pboard, NSArray *contacts);
void		LPAddContactEntriesToPasteboard		(NSPasteboard *pboard, NSArray *contactEntries);
NSArray *	LPRosterContactsBeingDragged		(id <NSDraggingInfo> info);
NSArray *	LPRosterContactEntriesBeingDragged	(id <NSDraggingInfo> info);
