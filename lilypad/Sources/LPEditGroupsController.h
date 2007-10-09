//
//  LPEditGroupsController.h
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import <Cocoa/Cocoa.h>


@class LPRoster, LPGroup;


@interface LPEditGroupsController : NSObject
{
	IBOutlet NSWindow		*m_window;
	IBOutlet NSTableView	*m_groupsTable;
	IBOutlet NSButton		*m_removeGroupButton;
	IBOutlet NSButton		*m_renameGroupButton;
	
	LPRoster				*m_roster;
	id						m_delegate;
	
	NSMutableArray			*m_groupsToBeRemoved;
	NSMutableArray			*m_groupsToBeAdded;
	NSMutableDictionary		*m_groupsToBeRenamed;	// LPGroup --> NSString (new name for the group)
	
	NSMutableArray			*m_listedGroups;
	
	int						m_lastNewGroupNameIndex;
}

- initWithRoster:(LPRoster *)roster delegate:(id)delegate;

- (NSWindow *)window;
- (LPRoster *)roster;

- (void)runAsSheetForWindow:(NSWindow *)parentWindow;
- (void)startRenameOfGroup:(LPGroup *)group;

- (IBAction)ok:(id)sender;
- (IBAction)cancel:(id)sender;

- (IBAction)addGroup:(id)sender;
- (IBAction)removeGroup:(id)sender;
- (IBAction)renameGroup:(id)sender;

@end

@interface NSObject (LPEditGroupsControllerDelegate)
- (void)editGroupsController:(LPEditGroupsController *)ctrl deleteGroups:(NSArray *)groups;
@end
