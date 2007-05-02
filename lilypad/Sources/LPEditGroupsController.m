//
//  LPEditGroupsController.m
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informa›es sobre o licenciamento, leia o ficheiro README.
//

#import "LPEditGroupsController.h"
#import "LPRoster.h"
#import "LPGroup.h"


@interface LPEditGroupsController (Private)
- (BOOL)p_groupNameWillAlreadyExist:(NSString *)name;
- (NSString *)p_newGroupName;
@end


@implementation LPEditGroupsController

- initWithRoster:(LPRoster *)roster delegate:(id)delegate
{
	if (self = [self init]) {
		m_roster = [roster retain];
		m_delegate = delegate;
	}
	return self;
}

- (void)dealloc
{
	[m_window release];
	
	[m_roster release];
	
	[m_groupsToBeRemoved release];
	[m_groupsToBeAdded release];
	[m_groupsToBeRenamed release];
	[m_listedGroups release];
	
	[super dealloc];
}

- (NSWindow *)window
{
	if (m_window == nil) {
		[NSBundle loadNibNamed:@"EditGroups" owner:self];
		
		[m_rosterController setContent:[self roster]];
		
		[m_removeGroupButton setEnabled:NO];
		[m_renameGroupButton setEnabled:NO];
	}
	return m_window;
}

- (LPRoster *)roster
{
	return [[m_roster retain] autorelease];
}

- (void)runAsSheetForWindow:(NSWindow *)parentWindow
{
	// Prepare the lists of groups
	[m_groupsToBeRemoved release];
	[m_groupsToBeAdded release];
	[m_groupsToBeRenamed release];
	m_groupsToBeRemoved = [[NSMutableArray alloc] init];
	m_groupsToBeAdded = [[NSMutableArray alloc] init];
	m_groupsToBeRenamed = [[NSMutableDictionary alloc] init];
	
	[m_listedGroups release];
	m_listedGroups = [[[self roster] sortedUserGroups] mutableCopy];
	
	// Display it all
	[m_groupsTable reloadData];
	[m_groupsTable deselectAll:nil];
	
	m_lastNewGroupNameIndex = 0;
	
	[NSApp beginSheet:[self window]
	   modalForWindow:parentWindow
		modalDelegate:self
	   didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
		  contextInfo:NULL];
}

- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	if (returnCode == NSOKButton) {
		// Let's commit the changes...
		NSEnumerator	*groupEnumerator;
		LPGroup			*someGroup;
		
		// Renamed Groups
		groupEnumerator = [m_groupsToBeRenamed keyEnumerator];
		while (someGroup = [groupEnumerator nextObject]) {
			NSString *newName = [m_groupsToBeRenamed objectForKey:someGroup];
			[someGroup setName:newName];
		}
		
		// Added Groups
		groupEnumerator = [m_groupsToBeAdded objectEnumerator];
		while (someGroup = [groupEnumerator nextObject]) {
			[m_roster addGroup:someGroup];
		}
	}
	
	[sheet orderOut:nil];
	
	if (returnCode == NSOKButton) {
		// Removed Groups
		if ([m_groupsToBeRemoved count] > 0
			&& [m_delegate respondsToSelector:@selector(editGroupsController:deleteGroups:)])
		{
			[m_delegate editGroupsController:self deleteGroups:m_groupsToBeRemoved];
		}
	}
	
	[m_groupsToBeRemoved release];
	[m_groupsToBeAdded release];
	[m_groupsToBeRenamed release];
	[m_listedGroups release];	
	m_groupsToBeRemoved = nil;
	m_groupsToBeAdded = nil;
	m_groupsToBeRenamed = nil;
	m_listedGroups = nil;
}

- (void)startRenameOfGroup:(LPGroup *)group
{
	int groupIndexInList = [m_listedGroups indexOfObject:group];
	
	if (groupIndexInList != NSNotFound) {
		[m_groupsTable selectRowIndexes:[NSIndexSet indexSetWithIndex:groupIndexInList] byExtendingSelection:NO];
		[m_groupsTable editColumn:0 row:groupIndexInList withEvent:nil select:YES];
	}
}


#pragma mark -
#pragma mark Actions


- (IBAction)ok:(id)sender
{
	// Make the field editor end whatever it is editing
	if ([[self window] makeFirstResponder:nil]) {
		[NSApp endSheet:[self window] returnCode:NSOKButton];
	}
}

- (IBAction)cancel:(id)sender
{
	[m_groupsTable abortEditing];
	[NSApp endSheet:[self window] returnCode:NSCancelButton];
}

- (IBAction)addGroup:(id)sender
{
	LPGroup *newGroup = [LPGroup groupWithName:[self p_newGroupName]];
	
	[m_groupsToBeAdded addObject:newGroup];
	[m_listedGroups addObject:newGroup];
	
	int newGroupRow = ([m_listedGroups count] - 1);
	
	[m_groupsTable reloadData];
	[m_groupsTable selectRowIndexes:[NSIndexSet indexSetWithIndex:newGroupRow] byExtendingSelection:NO];
	[m_groupsTable editColumn:0 row:newGroupRow withEvent:nil select:YES];
}

- (IBAction)removeGroup:(id)sender
{
	int selectedRow = [m_groupsTable selectedRow];
	
	if (selectedRow < 0) {
		NSBeep();
	}
	else {
		if ([m_groupsTable editedRow] == selectedRow) {
			NSCell *cell = [[[m_groupsTable tableColumns] objectAtIndex:0] dataCellForRow:selectedRow];
			[cell endEditing:[m_groupsTable currentEditor]];
		}
		
		LPGroup *selectedGroup = [m_listedGroups objectAtIndex:selectedRow];
		
		if ([m_groupsToBeAdded containsObject:selectedGroup]) {
			// It's one of the groups that was supposed to be created.
			[m_groupsToBeAdded removeObject:selectedGroup];
		}
		else {
			// It's one of the groups that was already available in the roster.
			[m_groupsToBeRemoved addObject:selectedGroup];
			[m_groupsToBeRenamed removeObjectForKey:selectedGroup];
		}

		[m_listedGroups removeObject:selectedGroup];
		[m_groupsTable reloadData];
	}
}

- (IBAction)renameGroup:(id)sender
{
	int selectedRow = [m_groupsTable selectedRow];
	
	if (selectedRow < 0) {
		NSBeep();
	}
	else {
		[m_groupsTable editColumn:0 row:selectedRow withEvent:nil select:YES];
	}
}


#pragma mark -
#pragma mark Private Methods


- (BOOL)p_groupNameWillAlreadyExist:(NSString *)name
{
	// Search the currently listed groups considering their final names after having been added/removed/renamed.
	NSEnumerator	*groupsEnumerator = [m_listedGroups objectEnumerator];
	LPGroup			*group;
	NSString		*groupName;
	BOOL			exists = NO;
	
	while (group = [groupsEnumerator nextObject]) {
		groupName = [m_groupsToBeRenamed objectForKey:group];
		if (groupName == nil) {
			// It's not shceduled to be renamed
			groupName = [group name];
		}
		
		if ([groupName caseInsensitiveCompare:name] == NSOrderedSame) {
			exists = YES;
			break;
		}
	}
	
	return exists;
}

- (NSString *)p_newGroupName
{
	NSString *newGroupName = nil;
	
	do {
		++m_lastNewGroupNameIndex;
		newGroupName = [NSString stringWithFormat:
			NSLocalizedString(@"<new group %d>", @"default name for newly inserted groups"), m_lastNewGroupNameIndex];
	} while ([self p_groupNameWillAlreadyExist:newGroupName]);
	
	return newGroupName;
}


#pragma mark -
#pragma mark NSTableView Data Source & Delegate Methods


- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return [m_listedGroups count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
	LPGroup *group = [m_listedGroups objectAtIndex:rowIndex];
	NSString *groupName = [m_groupsToBeRenamed objectForKey:group];
	
	if (groupName == nil) {
		// It isn't going to be renamed. Provide the current name.
		groupName = [group name];
	}
	
	return groupName;
}

- (BOOL)control:(NSControl *)control textShouldEndEditing:(NSText *)fieldEditor
{
	NSString *newName = [fieldEditor string];
	return ([newName length] > 0 && [self p_groupNameWillAlreadyExist:newName] == NO);
}

- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)newName forTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
	LPGroup *modifiedGroup = [m_listedGroups objectAtIndex:rowIndex];
	
	// Was the name really modified?
	if ([[modifiedGroup name] isEqualToString:newName] == NO) {
		if ([m_groupsToBeAdded containsObject:modifiedGroup]) {
			// It's one of the fresh new groups. Simply create another one with the chosen name.
			LPGroup *newGroupWithNewName = [LPGroup groupWithName:newName];
			
			[m_groupsToBeAdded removeObject:modifiedGroup];
			[m_groupsToBeAdded addObject:newGroupWithNewName];
			[m_listedGroups replaceObjectAtIndex:rowIndex withObject:newGroupWithNewName];
		}
		else {
			// It's one of the groups that was already present in the roster.
			[m_groupsToBeRenamed setObject:newName forKey:modifiedGroup];
		}
	}
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
	BOOL thereIsSomethingSelected = ([m_groupsTable numberOfSelectedRows] > 0);
	
	[m_removeGroupButton setEnabled:thereIsSomethingSelected];
	[m_renameGroupButton setEnabled:thereIsSomethingSelected];
}


@end
