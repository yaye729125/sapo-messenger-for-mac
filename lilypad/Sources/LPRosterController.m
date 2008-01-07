//
//  LPRosterController.m
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Authors: Joao Pavao <jppavao@criticalsoftware.com>
//           Jason Kim <jason@512k.org>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//
//
// TODO:
//   - Honor the order of contacts from the other side (instead of using our own sortDescriptors)
//

#import <AddressBook/AddressBook.h>
#import "LPRosterController.h"
#import "LPRosterDragAndDrop.h"
#import "LPCommon.h"
#import "LPChatsManager.h"
#import "LPFileTransfersManager.h"
#import "LPAccount.h"
#import "LPRoster.h"
#import "LPGroup.h"
#import "LPContact.h"
#import "LPContactEntry.h"
#import "LPGroupChat.h"
#import "LPCapabilitiesPredicates.h"
#import "LPPubManager.h"
#import "LPRosterTextFieldCell.h"
#import "LPAvatarButton.h"
#import "LPAccountsController.h"
#import "LPAddContactController.h"
#import "LPEditGroupsController.h"
#import "LPEventNotificationsHandler.h"
#import "LPModelessAlert.h"
#import "LPAccountNameTextField.h"
#import "JKAnimatedGroupTableView.h"
#import "NSString+ConcatAdditions.h"
#import "LPStatusMenuController.h"
#import "LPSapoAgents.h"
#import "LPColorBackgroundView.h"
#import "LPEmoticonSet.h"
#import "NSxString+EmoticonAdditions.h"
#import "NSString+URLScannerAdditions.h"
#import "LPSapoAgents+MenuAdditions.h"
#import "LPRosterEventsBadgeView.h"


static NSString *LPRosterNeedsUpdateNotification	= @"LPRosterNeedsUpdateNotification";


// For the KVO context parameters
static void *LPRosterCollectionsChangeContext	= (void *)1000;
static void *LPRosterItemPropertyChangeContext	= (void *)1001;
static void *LPRosterGroupPropertyChangeContext	= (void *)1002;
static void *LPSMSCreditChangeContext			= (void *)1003;
static void *LPAccountsChangeContext			= (void *)1004;
static void *LPAccountIDChangeContext			= (void *)1005;
static void *LPAvatarChangeContext				= (void *)1006;
static void *LPPubChangeContext					= (void *)1007;

// Instant-Search menu tags
static const int LPRosterSearchAllMenuTag				= 100;
static const int LPRosterSearchContactNamesMenuTag		= 101;
static const int LPRosterSearchContactAddressesMenuTag	= 102;


// Keys for the user defaults
static NSString *LPRosterShowOfflineContactsKey			= @"RosterShowOfflineContacts";
static NSString *LPRosterShowGroupsKey					= @"RosterShowGroups";
static NSString *LPRosterListGroupsBesideContactsKey	= @"RosterListGroupsBesideContacts";
static NSString *LPRosterUseSmallRowHeightKey			= @"RosterUseSmallRowHeight";
static NSString *LPRosterSortOrderKey					= @"RosterSortOrder";
static NSString *LPRosterCollapsedGroupsKey				= @"RosterCollapsedGroups";
static NSString *LPRosterNotificationsGracePeriodKey	= @"RosterNotificationsGracePeriod";


// Extra margin added on the bottom of the window when the ads are hidden
#define COLLAPSED_PUB_PADDING	3.0


@interface LPRosterController (Private)
- (void)p_updateFullnameField;
- (void)p_startObservingAccounts:(NSArray *)accounts;
- (void)p_stopObservingAccounts:(NSArray *)accounts;
- (void)p_startObservingGroups:(NSArray *)groups;
- (void)p_stopObservingGroups:(NSArray *)groups;
- (void)p_startObservingContacts:(NSArray *)contacts;
- (void)p_stopObservingContacts:(NSArray *)contacts;
- (BOOL)p_contactPassesCurrentSearchFilter:(LPContact *)contact;
- (void)p_updateSortDescriptors;
- (void)p_rosterNeedsUpdateNotification:(NSNotification *)notif;
- (NSArray *)p_sortedRosterGroups;
- (void)p_updateRoster;
- (NSArray *)p_selectedContacts;
- (void)p_selectContacts:(NSArray *)contacts;
- (void)p_updateSMSCredits;
- (void)p_setupPubElements;
- (void)p_setPubElementsHidden:(BOOL)hideFlag animate:(BOOL)animateFlag;
- (LPPubManager *)p_currentPubManager;
- (void)p_setCurrentPubManager:(LPPubManager *)pubManager;
- (void)p_reloadPub;
@end


// Semi-private methods that allow us to have WebViews with transparent backgrounds
// See: http://lists.apple.com/archives/webkitsdk-dev/2005/Apr/msg00065.html
@interface WebView (TransparentBackgroundAdditions)
- (BOOL)drawsBackground;
- (void)setDrawsBackground:(BOOL)flag;
@end


#pragma mark -


@implementation LPRosterController


+ (void)initialize
{
	[[NSUserDefaults standardUserDefaults] registerDefaults:
		[NSDictionary dictionaryWithObjectsAndKeys:
			[NSNumber numberWithBool:NO], LPRosterShowOfflineContactsKey,
			[NSNumber numberWithBool:YES], LPRosterShowGroupsKey,
			[NSNumber numberWithBool:NO], LPRosterListGroupsBesideContactsKey,
			[NSNumber numberWithBool:NO], LPRosterUseSmallRowHeightKey,
			[NSNumber numberWithInt:LPRosterSortByAvailability], LPRosterSortOrderKey,
			[NSNumber numberWithFloat:30.0], LPRosterNotificationsGracePeriodKey,
			nil]];
}


- initWithRoster:(LPRoster *)roster delegate:(id)delegate
{
	if (self = [self initWithWindowNibName:@"Roster"]) {
		m_roster = [roster retain];
		[self setDelegate:delegate];
		
		m_flatRoster = [[NSMutableArray alloc] init];
		
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		m_showOfflineContacts = [defaults boolForKey:LPRosterShowOfflineContactsKey];
		m_showGroups = [defaults boolForKey:LPRosterShowGroupsKey];
		m_listGroupsBesideContacts = [defaults boolForKey:LPRosterListGroupsBesideContactsKey];
		m_useSmallRowHeight = [defaults boolForKey:LPRosterUseSmallRowHeightKey];
		m_currentSortOrder = [defaults integerForKey:LPRosterSortOrderKey];
		m_currentSearchCategoryTag = LPRosterSearchAllMenuTag;
		
		[self p_updateSortDescriptors];
		
		LPAccountsController *accountsController = [LPAccountsController sharedAccountsController];
		
		[accountsController addObserver:self
							 forKeyPath:@"accounts"
								options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld)
								context:LPAccountsChangeContext];
		[self p_startObservingAccounts:[accountsController accounts]];
		
		[accountsController addObserver:self
							 forKeyPath:@"name"
								options:0
								context:LPAccountIDChangeContext];
		[accountsController addObserver:self
							 forKeyPath:@"avatar"
								options:0
								context:LPAvatarChangeContext];
		[accountsController addObserver:self
							 forKeyPath:@"SMSCreditValues"
								options:0
								context:LPSMSCreditChangeContext];
		
		[m_roster addObserver:self
				   forKeyPath:@"allGroups"
					  options:( NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld )
					  context:LPRosterCollectionsChangeContext];
		[self p_startObservingGroups:[m_roster allGroups]];
		[m_roster addObserver:self
				   forKeyPath:@"allContacts"
					  options:( NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld )
					  context:LPRosterCollectionsChangeContext];
		[self p_startObservingContacts:[m_roster allContacts]];
				
		m_groupMenus = [[NSMutableArray alloc] init];
		
		
		NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
		
		[nc addObserver:self
			   selector:@selector(p_rosterNeedsUpdateNotification:)
				   name:LPRosterNeedsUpdateNotification
				 object:self];
	}
	return self;
}


- (void)dealloc
{
	[self p_stopObservingContacts:[m_roster allContacts]];
	[m_roster removeObserver:self forKeyPath:@"allContacts"];
	[self p_stopObservingGroups:[m_roster allGroups]];
	[m_roster removeObserver:self forKeyPath:@"allGroups"];
	
	LPAccountsController *accountsController = [LPAccountsController sharedAccountsController];
	[accountsController removeObserver:self forKeyPath:@"SMSCreditValues"];
	[accountsController removeObserver:self forKeyPath:@"avatar"];
	[accountsController removeObserver:self forKeyPath:@"name"];
	[self p_stopObservingAccounts:[accountsController accounts]];
	[accountsController removeObserver:self forKeyPath:@"accounts"];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[self setDelegate:nil];
	
	[self p_setCurrentPubManager:nil];
	
	[m_roster release];
	[m_flatRoster release];
	[m_sortDescriptors release];
	[m_addContactController release];
	[m_editGroupsController release];
	[m_groupMenus release];
	
	[super dealloc];
}


- (id)delegate
{
	return m_delegate;
}


- (void)setDelegate:(id)delegate
{
	m_delegate = delegate;
}


- (void)p_startObservingAccounts:(NSArray *)accounts
{
	NSEnumerator *accountsEnum = [accounts objectEnumerator];
	LPAccount *account;
	
	while (account = [accountsEnum nextObject]) {
		[account addObserver:self forKeyPath:@"enabled" options:0 context:LPAccountIDChangeContext];
		[account addObserver:self forKeyPath:@"name" options:0 context:LPAccountIDChangeContext];
		[account addObserver:self forKeyPath:@"JID" options:0 context:LPAccountIDChangeContext];
		[account addObserver:self forKeyPath:@"pubManager.mainPubURL" options:0 context:LPPubChangeContext];
		[account addObserver:self forKeyPath:@"pubManager.statusPhraseHTML" options:0 context:LPPubChangeContext];
		
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(accountWillChangeStatus:)
													 name:LPAccountWillChangeStatusNotification
												   object:account];
	}
}

- (void)p_stopObservingAccounts:(NSArray *)accounts
{
	NSEnumerator *accountsEnum = [accounts objectEnumerator];
	LPAccount *account;
	
	while (account = [accountsEnum nextObject]) {
		[[NSNotificationCenter defaultCenter] removeObserver:self name:LPAccountWillChangeStatusNotification object:account];
		
		[account removeObserver:self forKeyPath:@"pubManager.statusPhraseHTML"];
		[account removeObserver:self forKeyPath:@"pubManager.mainPubURL"];
		[account removeObserver:self forKeyPath:@"JID"];
		[account removeObserver:self forKeyPath:@"name"];
		[account removeObserver:self forKeyPath:@"enabled"];
	}
}

- (void)p_startObservingGroups:(NSArray *)groups
{
	NSEnumerator *groupEnumerator = [groups objectEnumerator];
	id group;
	while (group = [groupEnumerator nextObject]) {
		[group addObserver:self
				forKeyPath:@"name"
				   options:( NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld )
				   context:LPRosterGroupPropertyChangeContext];
		[group addObserver:self
				forKeyPath:@"type"
				   options:( NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld )
				   context:LPRosterGroupPropertyChangeContext];
		[group addObserver:self
				forKeyPath:@"contacts"
				   options:( NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld )
				   context:LPRosterCollectionsChangeContext];
	}
}


- (void)p_stopObservingGroups:(NSArray *)groups
{
	NSEnumerator *groupEnumerator = [groups objectEnumerator];
	id group;
	while (group = [groupEnumerator nextObject]) {
		[group removeObserver:self forKeyPath:@"name"];
		[group removeObserver:self forKeyPath:@"type"];
		[group removeObserver:self forKeyPath:@"contacts"];
	}
}


- (void)p_startObservingContacts:(NSArray *)contacts
{
	NSEnumerator *contactEnumerator = [contacts objectEnumerator];
	id contact;
	while (contact = [contactEnumerator nextObject]) {
		[contact addObserver:self forKeyPath:@"name" options:0 context:LPRosterItemPropertyChangeContext];
		[contact addObserver:self forKeyPath:@"avatar" options:0 context:LPRosterItemPropertyChangeContext];
		[contact addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionOld context:LPRosterItemPropertyChangeContext];
		[contact addObserver:self forKeyPath:@"statusMessage" options:0 context:LPRosterItemPropertyChangeContext];
	}
}


- (void)p_stopObservingContacts:(NSArray *)contacts
{
	NSEnumerator *contactEnumerator = [contacts objectEnumerator];
	id contact;
	while (contact = [contactEnumerator nextObject]) {
		[contact removeObserver:self forKeyPath:@"name"];
		[contact removeObserver:self forKeyPath:@"avatar"];
		[contact removeObserver:self forKeyPath:@"status"];
		[contact removeObserver:self forKeyPath:@"statusMessage"];
	}
}


- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if (context == LPRosterCollectionsChangeContext) {
		if ([keyPath isEqualToString:@"allGroups"]) {
			NSKeyValueChange changeKind = [[change objectForKey:NSKeyValueChangeKindKey] intValue];
			
			if (changeKind == NSKeyValueChangeInsertion) {
				NSArray *addedGroups = [change objectForKey:NSKeyValueChangeNewKey];
				[self p_startObservingGroups:addedGroups];
			}
			else if (changeKind == NSKeyValueChangeRemoval) {
				NSArray *removedGroups = [change objectForKey:NSKeyValueChangeOldKey];
				[self p_stopObservingGroups:removedGroups];
				
				// Remove deleted groups from the list of collapsed groups
				NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
				NSMutableArray *collapsedGroupNames = [[defaults arrayForKey:LPRosterCollapsedGroupsKey] mutableCopy];
				
				[collapsedGroupNames removeObjectsInArray:[removedGroups valueForKey:@"name"]];
				[defaults setObject:collapsedGroupNames forKey:LPRosterCollapsedGroupsKey];
				
				[collapsedGroupNames release];
			}
			
			// Update the group menus we have at our mercy
			[self updateAllGroupMenus];
			
			[self setNeedsToUpdateRoster:YES];
		}
		else if ([keyPath isEqualToString:@"allContacts"]) {
			NSKeyValueChange changeKind = [[change objectForKey:NSKeyValueChangeKindKey] intValue];
			
			if (changeKind == NSKeyValueChangeInsertion) {
				NSArray *addedContacts = [change objectForKey:NSKeyValueChangeNewKey];
				[self p_startObservingContacts:addedContacts];
			}
			else if (changeKind == NSKeyValueChangeRemoval) {
				NSArray *removedContacts = [change objectForKey:NSKeyValueChangeOldKey];
				[self p_stopObservingContacts:removedContacts];
			}
		}
		else {
			// We avoid reloading the table on changes to "allContacts". We will be notified when added/removed
			// contacts are added/removed to/from their respective groups, so we spare a useless repeated reload by
			// testing this.
			[self setNeedsToUpdateRoster:YES];
		}
	}
	else if (context == LPRosterItemPropertyChangeContext) {
		if ([keyPath isEqualToString:@"status"]) {
			// Notify the user about contact availability changes
			LPStatus oldStatus = (LPStatus)[[change objectForKey:NSKeyValueChangeOldKey] intValue];
			LPStatus newStatus = [object status];
			
			BOOL didChangeAvailability = (((oldStatus == LPStatusOffline) || (newStatus == LPStatusOffline))
										  && (oldStatus != newStatus));
			
			if (didChangeAvailability) {
				[[LPEventNotificationsHandler defaultHandler] notifyContactAvailabilityDidChange:object];
			}
		}
		[self setNeedsToUpdateRoster:YES];
	}
	else if (context == LPRosterGroupPropertyChangeContext) {
		if ([m_rosterTableView isGroupExpanded:[m_flatRoster indexOfObject:object]] == NO) {
			// Update the renamed group in the list of collapsed groups
			NSString *oldName = [change objectForKey:NSKeyValueChangeOldKey];
			NSString *newName = [change objectForKey:NSKeyValueChangeNewKey];
			
			NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
			NSMutableArray *collapsedGroupNames = [[defaults arrayForKey:LPRosterCollapsedGroupsKey] mutableCopy];
			
			[collapsedGroupNames removeObject:oldName];
			[collapsedGroupNames addObject:newName];
			[defaults setObject:collapsedGroupNames forKey:LPRosterCollapsedGroupsKey];
			
			[collapsedGroupNames release];
		}
		[self setNeedsToUpdateRoster:YES];
		
		// Update the group menus we have at our mercy
		[self updateAllGroupMenus];
	}
	else if (context == LPSMSCreditChangeContext) {
		[self p_updateSMSCredits];
	}
	else if (context == LPAccountsChangeContext) {
		// Were there any additions or removals done to the accounts list?
		int changeKind = [[change valueForKey:NSKeyValueChangeKindKey] intValue];
		
		if (changeKind == NSKeyValueChangeInsertion)
			[self p_startObservingAccounts:[change objectForKey:NSKeyValueChangeNewKey]];
		else if (changeKind == NSKeyValueChangeRemoval)
			[self p_stopObservingAccounts:[change objectForKey:NSKeyValueChangeOldKey]];
		
		[self p_updateFullnameField];
	}
	else if (context == LPAccountIDChangeContext) {
		[self p_updateFullnameField];
	}
	else if (context == LPAvatarChangeContext) {
		[m_avatarButton setImage:[object avatar]];
	}
	else if (context == LPPubChangeContext) {
		[self p_setCurrentPubManager:[object pubManager]];
		[self p_reloadPub];
	}
	else {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}


- (void)windowDidLoad
{
	[self p_setupPubElements];
	
	LPAccountsController *accountsController = [LPAccountsController sharedAccountsController];
	
	[m_accountController setContent:accountsController];
	
	// Set up a few things.
	[[self window] setExcludedFromWindowsMenu:YES];
	[self setWindowFrameAutosaveName:@"LPRosterWindow"];
	[m_infoButton setEnabled:NO];

	// We want to use our custom vertically centered cell for the roster.
	LPRosterTextFieldCell *cell = [[LPRosterTextFieldCell alloc] init];
	[[m_rosterTableView tableColumnWithIdentifier:@"ContactColumn"] setDataCell:cell];
	[cell release];
	
	// We want to receive the double-click action from the roster table.
	[m_rosterTableView setTarget:self];
	[m_rosterTableView setDoubleAction:@selector(startChatOrSMS:)];
	
	// Set up the table view for receiving drops
	[m_rosterTableView registerForDraggedTypes:
		[NSArray arrayWithObjects:
			LPRosterContactPboardType,
			LPRosterContactEntryPboardType,
			NSFilenamesPboardType, nil]];
	
	// Contextual menus on the table view
	[m_rosterTableView setGroupContextMenu:m_groupContextMenu];
	[m_rosterTableView setContactContextMenu:m_contactContextMenu];
	[self addGroupMenu:m_groupsListMenu];
	
	// Setup the table view row size
	[m_rosterTableView setRowHeight:(m_useSmallRowHeight ? 17.0 : 34.0)];
	
	[self p_updateFullnameField];
	[m_avatarButton setImage:[accountsController avatar]];

	// The window is always loaded from the NIB with all its elements visible, i.e., the ads start by
	// being inside the window frame. However, if they were hidden (and the window was shrunk) when
	// the frame was last saved to the defaults, then we're opening the window with the pub being shown
	// using the frame rect saved when the pub was hidden! The actual roster list would get shrunk each
	// time we instatiated the window this way. So we have to add the size of the ads if the frame was
	// last saved while they were hidden, so that we restore the window to its actual last size.
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"RosterPubWasCollapsed"]) {
		NSWindow *win = [self window];
		NSRect winFrame = [win frame];
		float heightDelta = (NSHeight([m_pubElementsContentView frame]) - COLLAPSED_PUB_PADDING);
		
		winFrame.size.height += heightDelta;
		winFrame.origin.y -= heightDelta;
		
		[win setFrame:winFrame display:NO];
	}
	
	//[m_pubBannerWebView setDrawsBackground:NO];
	[m_pubStatusWebView setDrawsBackground:NO];
	[self p_setPubElementsHidden:YES animate:NO];
	
	[self p_updateSMSCredits];
	[self setNeedsToUpdateRoster:YES];
	
	
	LPStatusMenuController *smc = nil;
	
	if ([m_delegate respondsToSelector:@selector(rosterControllerGlobalStatusMenuController:)]) {
		smc = [m_delegate rosterControllerGlobalStatusMenuController:self];
	} else {
		// The menucontroller is leaked.
		LPAccountsController *accountsController = [LPAccountsController sharedAccountsController];
		smc = [[LPStatusMenuController alloc] initWithControlledAccountStatusObject:accountsController];
	}
	
	[m_statusButton removeAllItems];
	[smc insertControlledStatusItemsIntoPopUpMenu:m_statusButton atIndex:0];
	
	
	[m_userIDBackground setBackgroundColor:[NSColor colorWithPatternImage:[NSImage imageNamed:@"buddyListIDBackground"]]];
}


- (void)showWindow:(id)sender
{
	NSWindow *win = [self window];
	BOOL wasVisible = [win isVisible];
	
	[super showWindow:sender];
	
	if (!wasVisible)
		[self p_reloadPub];
}


- (void)keyDown:(NSEvent *)theEvent
{
	unichar pressedKey = [[theEvent charactersIgnoringModifiers] characterAtIndex:0];
	
	switch (pressedKey) {
		case NSNewlineCharacter:
		case NSCarriageReturnCharacter:
		case NSEnterCharacter:
			[self startChatOrSMS:nil];
			break;
			
		default:
			[[self window] makeFirstResponder:m_searchField];
			[m_searchField selectText:nil];
			
			// Let's pass along the event to the new first responder (which isn't necessarily the search
			// field - hint, hint: Field Editor) so that the search field doesn't lose the first keystroke.
			[[[self window] firstResponder] keyDown:theEvent];
	}
}


#pragma mark -
#pragma mark Instance Methods


- (LPRoster *)roster
{
	return [[m_roster retain] autorelease];
}


- (void)setNeedsToUpdateRoster:(BOOL)flag
{
	NSNotification		*notif = [NSNotification notificationWithName:LPRosterNeedsUpdateNotification object:self];
	NSNotificationQueue	*q = [NSNotificationQueue defaultQueue];
	
	if (flag) {
		/*
		 * We're using NSPostWhenIdle to avoid repeatedly updating the roster (which is not cheap, due re-sorting and
																			   * rematching of the incremental search criteria) when there are several needed updates in a row, such as mass
		 * presence changes when we get online or offline. This will result in the roster update being performed only
		 * when all the heavy processing has finished and the main event loop becomes idle.
		 */
		[q enqueueNotification:notif postingStyle:NSPostWhenIdle];
	} else {
		[q dequeueNotificationsMatching:notif coalesceMask:( NSNotificationCoalescingOnName | NSNotificationCoalescingOnSender )];
	}
}


- (void)addGroupMenu:(NSMenu *)menu
{
	[m_groupMenus addObject:menu];
	[self updateGroupMenu:menu];
}

- (void)removeGroupMenu:(NSMenu *)menu
{
	[m_groupMenus removeObject:menu];
}

- (void)updateGroupMenu:(NSMenu *)menu
{
	NSArray		*groups = [[self roster] sortedUserGroups];
	int			initialOffset = 2;   // "None" and separator
	int			i;
	
	// Clear all dynamic items
	for (i = ([menu numberOfItems] - 3); i >= initialOffset; --i) {
		[menu removeItemAtIndex:i];
	}
	
	// Add the current items
	for (i = initialOffset; i < ([groups count] + initialOffset); ++i) {
		NSString *title;
		SEL action;
		id representedObj;
		
		title = [[groups objectAtIndex:(i - initialOffset)] name];
		if (title == nil) title = @"";
		action = @selector(moveContactsToGroup:);
		representedObj = [groups objectAtIndex:(i - initialOffset)];
		
		[menu insertItemWithTitle:title action:action keyEquivalent:@"" atIndex:i];
		
		NSMenuItem *menuItem = [menu itemAtIndex:i];
		[menuItem setTitle:title];
		[menuItem setTarget:nil];
		[menuItem setAction:action];
		[menuItem setRepresentedObject:representedObj];
	}
}

- (void)updateAllGroupMenus
{
	NSEnumerator *menuEnum = [m_groupMenus objectEnumerator];
	NSMenu *menu;
	
	while (menu = [menuEnum nextObject]) {
		[self updateGroupMenu:menu];
	}
}


#pragma mark -


- (void)updateGroupChatsMenu:(NSMenu *)menu
{
	NSArray *groupChats = [[LPChatsManager chatsManager] sortedGroupChats];
	unsigned int nrOfGroupChats = [groupChats count];
	
	unsigned int curNrOfMenuItems = [menu numberOfItems];
	unsigned int targetNrOfMenuItems = MAX(nrOfGroupChats, 1);
	
	if (targetNrOfMenuItems < curNrOfMenuItems) {
		// Remove extraneous items
		unsigned int idx;
		for (idx = curNrOfMenuItems - 1; idx >= targetNrOfMenuItems; --idx)
			[menu removeItemAtIndex:idx];
	}
	else if (targetNrOfMenuItems > curNrOfMenuItems) {
		// Add some more needed items
		unsigned int idx;
		for (idx = curNrOfMenuItems; idx < targetNrOfMenuItems; ++idx)
			[menu addItemWithTitle:@"" action:NULL keyEquivalent:@""];
	}
	
	if (nrOfGroupChats == 0) {
		NSMenuItem *item = [menu itemAtIndex:0];
		
		[item setRepresentedObject:nil];
		[item setTitle:NSLocalizedString(@"(none)", @"")];
		[item setAction:NULL];
		[item setEnabled:NO];
	}
	else {
		NSEnumerator *groupChatEnum = [groupChats objectEnumerator];
		LPGroupChat *groupChat;
		unsigned int idx = 0;
		
		while (groupChat = [groupChatEnum nextObject]) {
			NSMenuItem *item = [menu itemAtIndex:idx];
			
			[item setRepresentedObject:groupChat];
			[item setTitle:[groupChat roomName]];
			[item setAction:@selector(inviteContactToGroupChatMenuItemChosen:)];
			[item setEnabled:YES];
			
			++idx;
		}
	}
}


- (void)updateStatusMessageURLsMenu:(NSMenu *)menu
{
	NSArray *selectedContacts = [m_flatRoster objectsAtIndexes:[m_rosterTableView selectedRowIndexes]];
	
	// Get the URL descriptions for all the selected contacts
	NSMutableArray *urlDescriptions = [NSMutableArray array];
	
	NSEnumerator *contactEnum = [selectedContacts objectEnumerator];
	LPContact *contact;
	while (contact = [contactEnum nextObject]) {
		
		NSArray *foundURLDescriptions = [[contact statusMessage] allParsedURLDescriptions];
		
		if (foundURLDescriptions != nil) {
			[urlDescriptions addObjectsFromArray:foundURLDescriptions];
		}
	}
	
	
	// Build the menu
	
	// Start by removing all previous menu items
	while ([menu numberOfItems] > 0)
		[menu removeItemAtIndex:0];
	
	if ([urlDescriptions count] == 0) {
		NSMenuItem *menuItem = [menu addItemWithTitle:NSLocalizedString(@"No URLs were found", @"status message URLs list menu")
											   action:NULL keyEquivalent:@""];
		[menuItem setEnabled:NO];
	}
	else {
		NSEnumerator *urlDescriptionEnum = [urlDescriptions objectEnumerator];
		NSDictionary *urlDescription;
		
		// Add the "Open <URL>" menu items
		while (urlDescription = [urlDescriptionEnum nextObject]) {
			NSMenuItem *menuItem = [menu addItemWithTitle:[NSString stringWithFormat:NSLocalizedString(@"Open \"%@\"", @""),
														   [urlDescription objectForKey:@"OriginalURLText"]]
												   action:@selector(openURLMenuItemChosen:)
											keyEquivalent:@""];
			[menuItem setRepresentedObject:[urlDescription objectForKey:@"URL"]];
		}
		
		// Insert a separator item
		[menu addItem:[NSMenuItem separatorItem]];
		
		// Add the "Copy <URL>" menu items
		urlDescriptionEnum = [urlDescriptions objectEnumerator];
		
		while (urlDescription = [urlDescriptionEnum nextObject]) {
			NSMenuItem *menuItem = [menu addItemWithTitle:[NSString stringWithFormat:NSLocalizedString(@"Copy \"%@\"", @""),
														   [urlDescription objectForKey:@"OriginalURLText"]]
												   action:@selector(copyURLMenuItemChosen:)
											keyEquivalent:@""];
			[menuItem setRepresentedObject:[urlDescription objectForKey:@"URL"]];
		}
	}
}


#pragma mark -


- (void)interactiveRemoveContacts:(NSArray *)contacts
{
	NSString	*msg;
	
	if ([contacts count] == 1) {
		msg = [NSString stringWithFormat:
			NSLocalizedString(@"Do you really want to remove contact \"%@\" from the list?", @"warning for roster edits"),
			[[contacts objectAtIndex:0] name]];
	}
	else {
		msg = [NSString stringWithFormat:
			NSLocalizedString(@"Do you really want to remove contacts %@ from the list?", @"warning for roster edits"),
			[NSString concatenatedStringWithValuesForKey:@"name" ofObjects:contacts useDoubleQuotes:YES]];
	}
	
	NSAlert *alert = [[NSAlert alloc] init];
	
	[alert setMessageText:msg];
	[alert setInformativeText:NSLocalizedString(@"You can't undo this action.", @"")];
	[alert addButtonWithTitle:NSLocalizedString(@"Delete", @"button")];
	[alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"button")];
	
	[alert beginSheetModalForWindow:[self window]
					  modalDelegate:self
					 didEndSelector:@selector(interactiveRemoveContactsAlertDidEnd:returnCode:contextInfo:)
						contextInfo:(void *)[contacts retain]];
}

- (void)interactiveRemoveContactsAlertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	NSArray *contacts = (NSArray *)contextInfo;
	
	if (returnCode == NSAlertFirstButtonReturn) {
		NSEnumerator *contactsEnumerator = [contacts objectEnumerator];
		LPContact *contact;
		
		while ((contact = [contactsEnumerator nextObject])) {
			[m_roster removeContact:contact];
		}
	}
	
	[contacts release];
	[alert release];
}


- (void)interactiveRemoveGroups:(NSArray *)groups
{
	NSString	*msg, *infoFormatStr, *informativeText, *deleteGroupsOnly, *deleteGroupsAndContacts;
	
	// Determine the msg and informativeText
	if ([groups count] == 1) {
		msg = [NSString stringWithFormat:
			NSLocalizedString(@"Do you really want to remove group \"%@\" from the list?", @"warning for roster edits"),
			[[groups objectAtIndex:0] name]];
		
		infoFormatStr = NSLocalizedString(@"You can delete the group and keep the contacts that it contains by clicking \"%@\". If you click \"%@\", the contacts contained in the group will be deleted along with it. You can't undo this action.", @"warning for roster edits");
		
		deleteGroupsOnly = NSLocalizedString(@"Delete Group Only", @"button");
		deleteGroupsAndContacts = NSLocalizedString(@"Delete Group And Contacts", @"button");
	}
	else {
		msg = [NSString stringWithFormat:
			NSLocalizedString(@"Do you really want to remove groups %@ from the list?", @"warning for roster edits"),
			[NSString concatenatedStringWithValuesForKey:@"name" ofObjects:groups useDoubleQuotes:YES]];
		
		infoFormatStr = NSLocalizedString(@"You can delete the groups and keep the contacts that they contain by clicking \"%@\". If you click \"%@\", the contacts contained in the groups will be deleted along with them. You can't undo this action.", @"warning for roster edits");
		
		deleteGroupsOnly = NSLocalizedString(@"Delete Groups Only", @"button");
		deleteGroupsAndContacts = NSLocalizedString(@"Delete Groups And Contacts", @"button");
	}
	
	informativeText = [NSString stringWithFormat:infoFormatStr, deleteGroupsOnly, deleteGroupsAndContacts];
	
	NSAlert *alert = [[NSAlert alloc] init];
	
	[alert setMessageText:msg];
	[alert setInformativeText:informativeText];
	[alert addButtonWithTitle:deleteGroupsOnly];
	[alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"button")];
	[alert addButtonWithTitle:deleteGroupsAndContacts];
	
	[alert beginSheetModalForWindow:[self window]
					  modalDelegate:self
					 didEndSelector:@selector(interactiveRemoveGroups:returnCode:contextInfo:)
						contextInfo:(void *)[groups retain]];
}

- (void)interactiveRemoveGroups:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	NSArray *groups = (NSArray *)contextInfo;
	
	if (returnCode == NSAlertFirstButtonReturn) { // Delete Groups Only
		NSEnumerator *groupsEnumerator = [groups objectEnumerator];
		LPGroup *group;
		
		while ((group = [groupsEnumerator nextObject])) {
			[m_roster removeGroup:group];
		}
	}
	else if (returnCode == NSAlertThirdButtonReturn) { // Delete Groups And Contacts
		NSEnumerator *groupsEnumerator = [groups objectEnumerator];
		LPGroup *group;
		NSMutableSet *contacts = [NSMutableSet set];
		
		// Delete groups
		while ((group = [groupsEnumerator nextObject])) {
			[contacts addObjectsFromArray:[group contacts]];
			[m_roster removeGroup:group];
		}
		
		// Delete contacts
		NSEnumerator *contactsEnumerator = [contacts objectEnumerator];
		LPContact *contact;
		
		while ((contact = [contactsEnumerator nextObject])) {
			[m_roster removeContact:contact];
		}
	}
	
	[groups release];
	[alert release];
}


#pragma mark -


- (void)setStatusMessage
{
	[self showWindow:nil];
	[[self window] makeFirstResponder:m_statusMessageTextField];
}


#pragma mark -
#pragma mark Methods for changing properties of the events badge


- (BOOL)hasDebuggerBadge
{
	return [m_eventsBadgeImageView isDebugger];
}

- (void)setHasDebuggerBadge:(BOOL)flag
{
	[m_eventsBadgeImageView setIsDebugger:flag];
}


- (int)badgedUnreadOfflineMessagesCount
{
	return [m_eventsBadgeImageView unreadOfflineMessagesCount];
}

- (void)setBadgedUnreadOfflineMessagesCount:(int)count
{
	[m_eventsBadgeImageView setUnreadOfflineMessagesCount:count];
}


- (int)badgedPendingFileTransfersCount
{
	return [m_eventsBadgeImageView pendingFileTransfersCount];
}

- (void)setBadgedPendingFileTransfersCount:(int)count
{
	[m_eventsBadgeImageView setPendingFileTransfersCount:count];
}


- (NSMenu *)eventsBadgeMenu
{
	return [m_eventsBadgeImageView menu];
}

- (void)setEventsBadgeMenu:(NSMenu *)menu
{
	[m_eventsBadgeImageView setMenu:menu];
}


#pragma mark -
#pragma mark NSMenu Delegate (for dynamically building the "Contact" menu)

- (void)menuNeedsUpdate:(NSMenu *)menu
{
	if (menu == m_groupChatsListMenu) {
		[self updateGroupChatsMenu:menu];
	}
	else if (menu == m_statusMsgURLsListMenu) {
		[self updateStatusMessageURLsMenu:menu];
	}
	else {
		// Add contact menu
		NSMenuItem *menuItemForAddingContact = [menu itemWithTag:1000];
		if (menuItemForAddingContact) {
			LPSapoAgents *sapoAgents = [[[LPAccountsController sharedAccountsController] defaultAccount] sapoAgents];
			NSMenu *newSubmenu = [sapoAgents JIDServicesMenuForAddingJIDsWithTarget:self action:@selector(addContactMenuItemChosen:)];
			
			[menuItemForAddingContact setSubmenu:newSubmenu];
		}
		
		// Group Chats menu
		NSMenuItem *menuItemForGroupChatInvitations = [menu itemWithTag:2000];
		if (menuItemForGroupChatInvitations) {
			[self updateGroupChatsMenu:[menuItemForGroupChatInvitations submenu]];
		}
	}
}


#pragma mark -
#pragma mark Actions


- (IBAction)addContactButtonClicked:(id)sender
{
	// Update the popup menu
	LPSapoAgents *sapoAgents = [[[LPAccountsController sharedAccountsController] defaultAccount] sapoAgents];
	[sender setMenu:[sapoAgents JIDServicesMenuForAddingJIDsWithTarget:self action:@selector(addContactMenuItemChosen:)]];
	
	[NSMenu popUpContextMenu:[sender menu] withEvent:[NSApp currentEvent] forView:sender];
}


- (IBAction)addContactMenuItemChosen:(id)sender
{
	if (m_addContactController == nil) {
		m_addContactController = [[LPAddContactController alloc] initWithRoster:[self roster] delegate:self];
	}
	
	[m_addContactController setHostOfJIDToBeAdded:[sender representedObject]];
	[m_addContactController runForAddingContactAsSheetForWindow:[self window]];
}

- (IBAction)removeContacts:(id)sender
{
	NSIndexSet *selectedRows = [m_rosterTableView selectedRowIndexes];
	NSAssert(([selectedRows count] > 0), @"There is no active selection in the roster table view");
	
	if ([selectedRows count] > 0) {
		[self interactiveRemoveContacts:[m_flatRoster objectsAtIndexes:selectedRows]];
	}
}


- (IBAction)editContact:(id)sender
{
	// Despite the name of the action method, we will process the several selected contacts all at once.
	if (([m_rosterTableView numberOfSelectedRows] > 0) && [m_delegate respondsToSelector:@selector(rosterController:editContacts:)]) {
		[m_delegate rosterController:self editContacts:[self p_selectedContacts]];
	}
}


- (IBAction)editGroups:(id)sender
{
	if (m_editGroupsController == nil) {
		m_editGroupsController = [[LPEditGroupsController alloc] initWithRoster:[self roster] delegate:self];
	}
	[m_editGroupsController runAsSheetForWindow:[self window]];
}


- (IBAction)removeContactsFromCurrentGroup:(id)sender
{
	NSIndexSet *selectedRows = [m_rosterTableView selectedRowIndexes];
	
	if ([selectedRows count] > 0) {
		unsigned currentIndex = [selectedRows firstIndex];
		while (currentIndex != NSNotFound) {
			LPContact *contact = [m_flatRoster objectAtIndex:currentIndex];
			[[contact groups] makeObjectsPerformSelector:@selector(removeContact:) withObject:contact];
			
			currentIndex = [selectedRows indexGreaterThanIndex:currentIndex];
		}
	}
}


- (IBAction)moveContactsToGroup:(id)sender
{
	LPGroup *targetGroup = [sender representedObject];
	NSIndexSet *selectedRows = [m_rosterTableView selectedRowIndexes];
	
	if ([selectedRows count] > 0) {
		unsigned currentIndex = [selectedRows firstIndex];
		while (currentIndex != NSNotFound) {
			LPContact *contact = [m_flatRoster objectAtIndex:currentIndex];
			LPGroup *sourceGroup = [[contact groups] objectAtIndex:0];
			
			[contact moveFromGroup:sourceGroup toGroup:targetGroup];
			
			currentIndex = [selectedRows indexGreaterThanIndex:currentIndex];
		}
	}
}


- (IBAction)moveContactsToNewGroup:(id)sender
{
	// Find an unused group name
	NSString *newGroupName = nil;
	int i = 0;
	do {
		++i;
		newGroupName = [NSString stringWithFormat:NSLocalizedString(@"<new group %d>", @"default name for newly inserted groups"), i];
	} while ([m_roster groupForName:newGroupName] != nil);
	
	
	LPGroup *targetGroup = [m_roster addNewGroupWithName:newGroupName];
	NSIndexSet *selectedRows = [m_rosterTableView selectedRowIndexes];
	
	if ([selectedRows count] > 0) {
		unsigned currentIndex = [selectedRows firstIndex];
		while (currentIndex != NSNotFound) {
			LPContact *contact = [m_flatRoster objectAtIndex:currentIndex];
			LPGroup *sourceGroup = [[contact groups] objectAtIndex:0];
			
			[contact moveFromGroup:sourceGroup toGroup:targetGroup];
			
			currentIndex = [selectedRows indexGreaterThanIndex:currentIndex];
		}
	}
}


- (IBAction)startChatOrSMS:(id)sender
{
	BOOL delegateCanOpenChat = [m_delegate respondsToSelector:@selector(rosterController:openChatWithContact:)];
	BOOL delegateCanSendSMS = [m_delegate respondsToSelector:@selector(rosterController:sendSMSToContact:)];
	
	BOOL optionModifierIsDown = (([[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask) != 0);
	
	NSIndexSet *selectedIndexes = [m_rosterTableView selectedRowIndexes];
	unsigned currentIndex = [selectedIndexes firstIndex];
	
	while (currentIndex != NSNotFound) {
		LPContact *contact = [m_flatRoster objectAtIndex:currentIndex];
		
		if (contact != nil) {
			if (optionModifierIsDown) {
				/*
				 * Force SMS.
				 * If for any reason we can't open a window for sending SMSs, just beep instead of performing
				 * some alternative action. The user is intentionally pressing the option key because he specifically
				 * wants to send an SMS. If we can't do it, we shouldn't bother the user by doing something else instead.
				 */
				if ([contact canDoSMS] && delegateCanSendSMS) {
					[m_delegate rosterController:self sendSMSToContact:contact];
				}
				else {
					NSBeep();
				}
			}
			else {
				// Try to open a chat window. If that can't be done, try a window for sending SMSs instead.
				if ([contact canDoChat] && delegateCanOpenChat) {
					[m_delegate rosterController:self openChatWithContact:contact];
				}
				else if ([contact canDoSMS] && delegateCanSendSMS) {
					[m_delegate rosterController:self sendSMSToContact:contact];
				}
			}
		}
		
		currentIndex = [selectedIndexes indexGreaterThanIndex:currentIndex];
	}
}

- (IBAction)startChat:(id)sender
{
	if ([m_delegate respondsToSelector:@selector(rosterController:openChatWithContact:)]) {
		NSIndexSet *selectedIndexes = [m_rosterTableView selectedRowIndexes];
		unsigned currentIndex = [selectedIndexes firstIndex];

		while (currentIndex != NSNotFound) {
			LPContact *contact = [m_flatRoster objectAtIndex:currentIndex];
			
			if (contact != nil && [contact canDoChat])
				[m_delegate rosterController:self openChatWithContact:contact];
			
			currentIndex = [selectedIndexes indexGreaterThanIndex:currentIndex];
		}
	}
}


- (IBAction)startGroupChat:(id)sender
{
	if ([m_delegate respondsToSelector:@selector(rosterController:openGroupChatWithContacts:)]) {
		[m_delegate rosterController:self openGroupChatWithContacts:[self p_selectedContacts]];
	}
}


- (IBAction)inviteContactToGroupChatMenuItemChosen:(id)sender
{
	LPGroupChat *groupChat = [sender representedObject];
	
	NSEnumerator *contactsEnum = [[self p_selectedContacts] objectEnumerator];
	LPContact *contact;
	
	while (contact = [contactsEnum nextObject]) {
		LPContactEntry *entry = [[contact contactEntries] firstOnlineItemInArrayPassingCapabilitiesPredicate:@selector(canDoMUC)];
		if (entry)
			[groupChat inviteJID:[entry address] withReason:@""];
	}
}


- (IBAction)sendSMS:(id)sender
{
	if ([m_delegate respondsToSelector:@selector(rosterController:sendSMSToContact:)]) {
		NSIndexSet *selectedIndexes = [m_rosterTableView selectedRowIndexes];
		unsigned currentIndex = [selectedIndexes firstIndex];
		
		while (currentIndex != NSNotFound) {
			LPContact *contact = [m_flatRoster objectAtIndex:currentIndex];
			
			if (contact != nil && [contact canDoSMS])
				[m_delegate rosterController:self sendSMSToContact:contact];
			
			currentIndex = [selectedIndexes indexGreaterThanIndex:currentIndex];
		}
	}
}


- (IBAction)sendFile:(id)sender
{
	LPContact *selectedContact = [m_flatRoster objectAtIndex:[m_rosterTableView selectedRow]];
	
	if ([selectedContact canDoFileTransfer]) {
		NSOpenPanel *op = [NSOpenPanel openPanel];
		
		[op setPrompt:NSLocalizedString(@"Send", @"button for the file selection sheet")];
		
		[op setCanChooseFiles:YES];
		[op setCanChooseDirectories:NO];
		[op setResolvesAliases:YES];
		[op setAllowsMultipleSelection:NO];
		
		[op beginSheetForDirectory:nil
							  file:nil
							 types:nil
					modalForWindow:[self window]
					 modalDelegate:self
					didEndSelector:@selector(p_openPanelDidEnd:returnCode:contextInfo:)
					   contextInfo:(void *)[selectedContact retain]];
	}
}

- (void)p_openPanelDidEnd:(NSOpenPanel *)panel returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	LPContact *selectedContact = [(LPContact *)contextInfo autorelease];
	
	if (returnCode == NSOKButton) {
		LPContactEntry *targetContactEntry = [[selectedContact contactEntries] firstOnlineItemInArrayPassingCapabilitiesPredicate:@selector(canDoFileTransfer)];
		
		if (targetContactEntry)
			[[LPFileTransfersManager fileTransfersManager] startSendingFile:[panel filename]
															 toContactEntry:targetContactEntry];
	}
}


- (IBAction)renameGroup:(id)sender
{
	int groupIndex = [m_rosterTableView groupContextMenuLastHitRow];
	
	if (groupIndex >= 0 && groupIndex < [m_flatRoster count]) {
		LPGroup *group = [m_flatRoster objectAtIndex:groupIndex];
		
		[self editGroups:sender];
		[m_editGroupsController startRenameOfGroup:group];
	}
}

- (IBAction)deleteGroup:(id)sender
{
	int groupIndex = [m_rosterTableView groupContextMenuLastHitRow];
	
	if (groupIndex >= 0 && groupIndex < [m_flatRoster count]) {
		LPGroup *group = [m_flatRoster objectAtIndex:groupIndex];
		[self interactiveRemoveGroups:[NSArray arrayWithObject:group]];
	}
}

- (IBAction)toggleShowOfflineBuddies:(id)sender
{
	m_showOfflineContacts = (!m_showOfflineContacts);
	[[NSUserDefaults standardUserDefaults] setBool:m_showOfflineContacts forKey:LPRosterShowOfflineContactsKey];
	[self setNeedsToUpdateRoster:YES];
}

- (IBAction)toggleShowGroups:(id)sender
{
	m_showGroups = (!m_showGroups);
	[[NSUserDefaults standardUserDefaults] setBool:m_showGroups forKey:LPRosterShowGroupsKey];
	[self setNeedsToUpdateRoster:YES];
}

- (IBAction)toggleListGroupsBesideContacts:(id)sender
{
	m_listGroupsBesideContacts = (!m_listGroupsBesideContacts);
	[[NSUserDefaults standardUserDefaults] setBool:m_listGroupsBesideContacts forKey:LPRosterListGroupsBesideContactsKey];
	[self setNeedsToUpdateRoster:YES];
}

- (IBAction)toggleUseSmallRowHeight:(id)sender
{
	m_useSmallRowHeight = (!m_useSmallRowHeight);
	[m_rosterTableView setRowHeight:(m_useSmallRowHeight ? 17.0 : 34.0)];
	[[NSUserDefaults standardUserDefaults] setBool:m_useSmallRowHeight forKey:LPRosterUseSmallRowHeightKey];
	[self setNeedsToUpdateRoster:YES];
}

- (IBAction)sortByAvailability:(id)sender
{
	m_currentSortOrder = LPRosterSortByAvailability;
	[[NSUserDefaults standardUserDefaults] setInteger:m_currentSortOrder forKey:LPRosterSortOrderKey];
	[self p_updateSortDescriptors];
}

- (IBAction)sortByName:(id)sender
{
	m_currentSortOrder = LPRosterSortByName;
	[[NSUserDefaults standardUserDefaults] setInteger:m_currentSortOrder forKey:LPRosterSortOrderKey];
	[self p_updateSortDescriptors];
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	SEL action = [menuItem action];
	BOOL enabled = YES;
	
	if (action == @selector(toggleShowOfflineBuddies:)) {
		[menuItem setState:m_showOfflineContacts];
	}
	else if (action == @selector(toggleShowGroups:)) {
		[menuItem setState:m_showGroups];
	}
	else if (action == @selector(toggleListGroupsBesideContacts:)) {
		[menuItem setState:m_listGroupsBesideContacts];
	}
	else if (action == @selector(toggleUseSmallRowHeight:)) {
		[menuItem setState:m_useSmallRowHeight];
	}
	else if (action == @selector(sortByAvailability:)) {
		[menuItem setState:(m_currentSortOrder == LPRosterSortByAvailability)];
	}
	else if (action == @selector(sortByName:)) {
		[menuItem setState:(m_currentSortOrder == LPRosterSortByName)];
	}
	else if ((action == @selector(addContactMenuItemChosen:)) ||
			 (action == @selector(editGroups:))) {
		enabled = [[LPAccountsController sharedAccountsController] isOnline];
	}
	else if ((action == @selector(copy:)) ||
			 (action == @selector(copyStatusMessage:)) ||
			 (action == @selector(startChat:)) ||
			 (action == @selector(startGroupChat:)) ||
			 (action == @selector(inviteContactToGroupChatMenuItemChosen:)) ||
			 (action == @selector(sendSMS:)) ||
			 (action == @selector(sendFile:)) ||
			 (action == @selector(editContact:)) ||
			 (action == @selector(removeContacts:)) ||
			 (action == @selector(removeContactsFromCurrentGroup:)) ||
			 (action == @selector(moveContactsToGroup:)) ||
			 (action == @selector(moveContactsToNewGroup:)))
	{
		unsigned int nrSelectedItems = [m_rosterTableView numberOfSelectedRows];
		
		if (action == @selector(removeContacts:)) {
			[menuItem setTitle:( (nrSelectedItems > 1) ?
								 NSLocalizedString(@"Remove Contacts...", @"menu item title") :
								 NSLocalizedString(@"Remove Contact...", @"menu item title")      )];
			enabled = (nrSelectedItems > 0 && [[LPAccountsController sharedAccountsController] isOnline]);
		}
		else if ((action == @selector(removeContactsFromCurrentGroup:)) ||
				 (action == @selector(moveContactsToGroup:)) ||
				 (action == @selector(moveContactsToNewGroup:))) {
			enabled = (nrSelectedItems > 0 && [[LPAccountsController sharedAccountsController] isOnline]);
		}
		else if (action == @selector(startChat:))  {
			enabled = (nrSelectedItems > 0 &&
					   [[self p_selectedContacts] someItemInArrayPassesCapabilitiesPredicate:@selector(canDoChat)]);
		}
		else if (action == @selector(startGroupChat:) ||
				 action == @selector(inviteContactToGroupChatMenuItemChosen:)) {
			enabled = (nrSelectedItems > 0 &&
					   [[self p_selectedContacts] someItemInArrayPassesCapabilitiesPredicate:@selector(canDoMUC)]);
		}
		else if (action == @selector(sendSMS:)) {
			enabled = (nrSelectedItems > 0 &&
					   [[self p_selectedContacts] someItemInArrayPassesCapabilitiesPredicate:@selector(canDoSMS)]);
		}
		else if (action == @selector(sendFile:)) {
			enabled = ( (nrSelectedItems == 1) &&
						[[m_flatRoster objectAtIndex:[m_rosterTableView selectedRow]] canDoFileTransfer] &&
						[[m_flatRoster objectAtIndex:[m_rosterTableView selectedRow]] isOnline]);
		}
		else {
			enabled = (nrSelectedItems > 0);
		}
	}
	else if (action == @selector(changeSearchScope:)) {
		[menuItem setState:([menuItem tag] == m_currentSearchCategoryTag)];
	}
	else if (action == @selector(performFindPanelAction:)) {
		enabled = ([menuItem tag] == NSFindPanelActionShowFindPanel);
	}
	
	return enabled;
}

- (IBAction)performFindPanelAction:(id)sender
{
	if ([sender tag] == NSFindPanelActionShowFindPanel) {
		[[self window] makeFirstResponder:m_searchField];
		[m_searchField selectText:sender];
	}
}

- (IBAction)contactFilterStringDidChange:(id)sender
{
	[self setNeedsToUpdateRoster:YES];
}


- (IBAction)changeSearchScope:(id)sender
{
	m_currentSearchCategoryTag = [sender tag];
	[self setNeedsToUpdateRoster:YES];
}


- (void)copy:(id)sender
{
	NSArray			*contacts = [m_flatRoster objectsAtIndexes:[m_rosterTableView selectedRowIndexes]];
	NSPasteboard	*pboard = [NSPasteboard generalPasteboard];
	
	[pboard declareTypes:[NSArray arrayWithObjects:NSStringPboardType, nil] owner:nil];
	[pboard setString:[NSString concatenatedStringWithValuesForKey:@"name"
														 ofObjects:contacts
												   useDoubleQuotes:NO]
			  forType:NSStringPboardType];
}


- (IBAction)copyStatusMessage:(id)sender
{
	LPContact		*contact = [m_flatRoster objectAtIndex:[m_rosterTableView selectedRow]];
	NSPasteboard	*pboard = [NSPasteboard generalPasteboard];
	
	[pboard declareTypes:[NSArray arrayWithObjects:NSStringPboardType, nil] owner:nil];
	[pboard setString:[contact statusMessage] forType:NSStringPboardType];
}


- (IBAction)copyURLMenuItemChosen:(id)sender
{
	id theURL = [sender representedObject];
	
	if (theURL && [theURL isKindOfClass:[NSURL class]]) {
		NSPasteboard	*pboard = [NSPasteboard generalPasteboard];
		
		[pboard declareTypes:[NSArray arrayWithObjects:NSURLPboardType, NSStringPboardType, nil] owner:nil];
		[pboard setData:[NSArchiver archivedDataWithRootObject:theURL] forType:NSURLPboardType];
		[pboard setString:[theURL absoluteString] forType:NSStringPboardType];
	}
}


- (IBAction)openURLMenuItemChosen:(id)sender
{
	id theURL = [sender representedObject];
	
	if (theURL && [theURL isKindOfClass:[NSURL class]]) {
		[[NSWorkspace sharedWorkspace] openURL:theURL];
	}
}


#pragma mark -
#pragma mark Private Methods


- (void)p_updateFullnameField
{
	[m_fullNameField clearAllStringValues];
	
	// General Account Name
	LPAccountsController *accountsController = [LPAccountsController sharedAccountsController];
	if ([[accountsController name] length] > 0)
		[m_fullNameField addStringValue:[accountsController name]];
	
	NSEnumerator *accountsEnum = [[accountsController accounts] objectEnumerator];
	LPAccount *account;
	while (account = [accountsEnum nextObject]) {
		if ([[account JID] length] > 0 && [account isEnabled])
			[m_fullNameField addStringValue:[account JID]];
	}
}


- (BOOL)p_contactPassesCurrentSearchFilter:(LPContact *)contact
{
	BOOL		passesFilter = YES;
	NSString	*filterString = [m_searchField stringValue];
	
	if ([filterString length] > 0) {
		BOOL	searchInName = ((m_currentSearchCategoryTag == LPRosterSearchAllMenuTag) ||
								(m_currentSearchCategoryTag == LPRosterSearchContactNamesMenuTag));
		BOOL	searchInAddresses = ((m_currentSearchCategoryTag == LPRosterSearchAllMenuTag) ||
									 (m_currentSearchCategoryTag == LPRosterSearchContactAddressesMenuTag));
		NSRange filterStringRange;
		
		passesFilter = NO;

		if (searchInName) {
			filterStringRange = [[contact name] rangeOfString:filterString options:NSCaseInsensitiveSearch];
			if (filterStringRange.location != NSNotFound) {
				passesFilter = YES;
			}
		}
		if (!passesFilter && searchInAddresses) {
			// Iterate over all the addresses in the contact
			NSEnumerator *entriesEnumerator = [[contact contactEntries] objectEnumerator];
			LPContactEntry *entry;
			while (entry = [entriesEnumerator nextObject]) {
				// Search both the real JID and the pretty JID
				filterStringRange = [[entry humanReadableAddress] rangeOfString:filterString options:NSCaseInsensitiveSearch];
				if (filterStringRange.location != NSNotFound) {
					passesFilter = YES;
					break;
				}
				filterStringRange = [[entry address] rangeOfString:filterString options:NSCaseInsensitiveSearch];
				if (filterStringRange.location != NSNotFound) {
					passesFilter = YES;
					break;
				}
			}
		}
	}
	
	return passesFilter;
}


- (void)p_updateSortDescriptors
{
	static NSArray *sortDescriptorsForAvailabilityFirst = nil;
	static NSArray *sortDescriptorsForNameFirst = nil;
	
	if ((sortDescriptorsForAvailabilityFirst == nil) || (sortDescriptorsForNameFirst == nil)) {
		// Initialize our static variables
		NSSortDescriptor *sortDescrAvailability = [[NSSortDescriptor alloc] initWithKey:@"status"
																			  ascending:YES
																			   selector:@selector(compare:)];
		NSSortDescriptor *sortDescrName = [[NSSortDescriptor alloc] initWithKey:@"name"
																	  ascending:YES
																	   selector:@selector(caseInsensitiveCompare:)];
		
		if (sortDescriptorsForAvailabilityFirst == nil) {
			sortDescriptorsForAvailabilityFirst = [[NSArray alloc] initWithObjects: sortDescrAvailability, sortDescrName, nil];
		}
		if (sortDescriptorsForNameFirst == nil) {
			sortDescriptorsForNameFirst = [[NSArray alloc] initWithObjects: sortDescrName, sortDescrAvailability, nil];
		}
		
		[sortDescrAvailability release];
		[sortDescrName release];
	}
		
	[m_sortDescriptors release];
	if (m_currentSortOrder == LPRosterSortByAvailability) {
		m_sortDescriptors = [sortDescriptorsForAvailabilityFirst retain];
	}
	else if (m_currentSortOrder == LPRosterSortByName) {
		m_sortDescriptors = [sortDescriptorsForNameFirst retain];
	}
	
	[self setNeedsToUpdateRoster:YES];
}


- (void)p_rosterNeedsUpdateNotification:(NSNotification *)notif
{
	[self p_updateRoster];
}


- (NSArray *)p_sortedRosterGroups
{
	static NSArray *groupsSortDescriptors = nil;
	
	if (groupsSortDescriptors == nil) {
		NSSortDescriptor *byType = [[NSSortDescriptor alloc] initWithKey:@"type" ascending:YES];
		NSSortDescriptor *byName = [[NSSortDescriptor alloc] initWithKey:@"name"
															   ascending:YES
																selector:@selector(caseInsensitiveCompare:)];
		
		groupsSortDescriptors = [[NSArray alloc] initWithObjects: byType, byName, nil];
		
		[byType release];
		[byName release];
	}
	
	return [[[self roster] allGroups] sortedArrayUsingDescriptors:groupsSortDescriptors];
}


- (void)p_updateRoster
{
	// For restoring the selection at the end of this method
	NSArray *previouslySelectedContacts = [self p_selectedContacts];
	BOOL	hasSearchString = ([[m_searchField stringValue] length] > 0);
	
	[m_flatRoster removeAllObjects];
		
	// Setup the stuff we need to restore the collapsed groups at the end of this method
	// (JKGroupTableView's "reloadData" method resets all the groups to the expanded state)
	NSArray				*collapsedGroupNames = [[NSUserDefaults standardUserDefaults] arrayForKey:LPRosterCollapsedGroupsKey];
	NSMutableIndexSet	*groupIndexesToCollapse = [NSMutableIndexSet indexSet];
	
	NSUserDefaults	*defaults = [NSUserDefaults standardUserDefaults];
	BOOL			showDebugGroups = [defaults boolForKey:@"IncludeDebugGroups"];
	BOOL			showNonRosterContacts = [defaults boolForKey:@"ShowNonRosterContacts"];
	
	NSMutableArray	*arrayForAddingContacts = (m_showGroups ? [NSMutableArray array] : m_flatRoster);
	NSArray			*sortedGroups = [self p_sortedRosterGroups];
	NSEnumerator	*groupEnumerator = [sortedGroups objectEnumerator];
	LPGroup			*group;

	// Add each group iteratively.
	while (group = [groupEnumerator nextObject]) {
		
		if (([group type] == LPNotInListGroupType) && !showDebugGroups)
			continue;
		
		NSEnumerator	*contactEnumerator = [[group contacts] objectEnumerator];
		LPContact		*contact;
		
		while (contact = [contactEnumerator nextObject]) {
			if (( m_showOfflineContacts || hasSearchString || [contact isOnline] ||
				  ( [[LPAccountsController sharedAccountsController] isTryingToAutoReconnect] && [contact wasOnlineBeforeDisconnecting] ))
				&& (showNonRosterContacts || [contact isRosterContact])
				&& [self p_contactPassesCurrentSearchFilter:contact])
			{
				[arrayForAddingContacts addObject:contact];
			}
		}
		
		// Show by group?
		if (m_showGroups) {
			// If we have a search criteria string and no contacts of this group were selected, then don't list the group
			if (([arrayForAddingContacts count] > 0) || (m_showOfflineContacts && !hasSearchString) || showDebugGroups) {
				if (([group type] != LPNoGroupType) || showDebugGroups) {
					[m_flatRoster addObject:group];
				}
				
				// Expand all the groups if we have a search criteria string so that all the results of the search are visible
				if (!hasSearchString && [collapsedGroupNames containsObject:[group name]]) {
					unsigned int groupIndex = [m_flatRoster count] - 1;
					[groupIndexesToCollapse addIndex:groupIndex];
				}
				
				// Adding by group: sort and then clear the current batch of contacts
				[arrayForAddingContacts sortUsingDescriptors:m_sortDescriptors];
				[m_flatRoster addObjectsFromArray:arrayForAddingContacts];
				[arrayForAddingContacts removeAllObjects];
			}
		}
	}
	
	if (!m_showGroups)
		// Not showing by group: we have been adding contacts directly to the m_flatRoster. Sort it, finally!
		[m_flatRoster sortUsingDescriptors:m_sortDescriptors];
	
	[m_rosterTableView reloadData];
	
	// Restore the collapsed groups
    unsigned indexToCollapse = [groupIndexesToCollapse firstIndex];
    while (indexToCollapse != NSNotFound) {
        [m_rosterTableView collapseGroupAtIndex:indexToCollapse];
        indexToCollapse = [groupIndexesToCollapse indexGreaterThanIndex:indexToCollapse];
    }
	
	// Restore the selection
	[self p_selectContacts:previouslySelectedContacts];
}


- (NSArray *)p_selectedContacts
{
	NSIndexSet *selectedIndexes = [m_rosterTableView selectedRowIndexes];
	NSArray *selectedContacts = nil;
	
	if (selectedIndexes != nil) {
		selectedContacts = [m_flatRoster objectsAtIndexes:selectedIndexes];
	}
	
	return selectedContacts;
}


- (void)p_selectContacts:(NSArray *)contacts
{
	NSMutableIndexSet *contactIndexes = [NSMutableIndexSet indexSet];
	NSEnumerator *contactEnumerator = [contacts objectEnumerator];
	LPContact *contact;
	unsigned contactIndex;
	
	while (contact = [contactEnumerator nextObject]) {
		contactIndex = [m_flatRoster indexOfObject:contact];
		if (contactIndex != NSNotFound) {
			[contactIndexes addIndex:contactIndex];
		}
	}
	
	[m_rosterTableView selectRowIndexes:contactIndexes byExtendingSelection:NO];
}


- (void)p_updateSMSCredits
{
	LPAccountsController *accountsController = [LPAccountsController sharedAccountsController];
	
	if ([accountsController SMSCreditAvailable] != LPAccountSMSCreditUnknown) {
		[m_smsCreditTextField setStringValue:[NSString stringWithFormat:
			NSLocalizedString(@"SMS \\U25B8 Credit: %d (%d free) | Sent: %d",
							  @"SMS credit text field at the top of the roster window"),
			[accountsController SMSCreditAvailable] + [accountsController nrOfFreeSMSMessagesAvailable],
			[accountsController nrOfFreeSMSMessagesAvailable],
			[accountsController nrOfSMSMessagesSentThisMonth]]];
	}
	else {
		[m_smsCreditTextField setStringValue:NSLocalizedString(@"SMS \\U25B8 (unknown credit)",
															   @"SMS credit text field at the top of the roster window")];
	}
}


- (void)p_setupPubElements
{
	NSAssert((m_pubElementsContentView == nil && m_pubBannerWebView == nil && m_pubStatusWebView == nil),
			 @"m_pub* instance vars should all be nil upon setup!");
	
	NSWindow *win = [self window];
	float windowWidth = NSWidth([[win contentView] bounds]);
	float extraMargin = 20.0;
	
	m_pubElementsContentView = [[NSView alloc] initWithFrame:NSMakeRect(-extraMargin, 0.0, windowWidth + 2.0 * extraMargin, 100.0)];
	[m_pubElementsContentView setAutoresizingMask:( NSViewWidthSizable | NSViewMaxYMargin )];
	[[win contentView] addSubview:m_pubElementsContentView positioned:NSWindowAbove relativeTo:m_rosterElementsContentView];
	[m_pubElementsContentView release];
	
	NSBox *box = [[NSBox alloc] initWithFrame:NSMakeRect(0.0, 21.0, windowWidth + 2.0 * extraMargin, 78.0)];
	[box setAutoresizingMask:( NSViewWidthSizable | NSViewMaxYMargin )];
	[box setBorderType:NSBezelBorder];
	[box setBoxType:NSBoxPrimary];
	[box setTitlePosition:NSNoTitle];
	[m_pubElementsContentView addSubview:box];
	[box release];
	
	float bannerWidth = 234.0;
	float bannerMargin = (NSWidth([[box contentView] bounds]) - bannerWidth ) / 2.0;
	m_pubBannerWebView = [[WebView alloc] initWithFrame:NSMakeRect(bannerMargin, 2.0, bannerWidth, 60.0) frameName:nil groupName:nil];
	[m_pubBannerWebView setAutoresizingMask:( NSViewMinXMargin | NSViewMaxXMargin | NSViewMinYMargin | NSViewMaxYMargin )];
	[m_pubBannerWebView setUIDelegate:self];
	[box addSubview:m_pubBannerWebView];
	[m_pubBannerWebView release];
	
	float statusWidth = windowWidth - 40.0;
	float statusMargin = (NSWidth([m_pubElementsContentView bounds]) - statusWidth) / 2.0;
	m_pubStatusWebView = [[WebView alloc] initWithFrame:NSMakeRect(statusMargin, 0.0, statusWidth, 20.0) frameName:nil groupName:nil];
	[m_pubStatusWebView setAutoresizingMask:( NSViewWidthSizable | NSViewMaxYMargin )];
	[m_pubStatusWebView setUIDelegate:self];
	[m_pubElementsContentView addSubview:m_pubStatusWebView];
	[m_pubStatusWebView release];
}


- (void)p_setPubElementsHidden:(BOOL)hideFlag animate:(BOOL)animateFlag
{
	if (hideFlag != [m_pubElementsContentView isHidden]) {
		NSWindow *win = [self window];
		NSRect winFrame = [win frame];
		float heightDelta = (hideFlag ? -1.0 : 1.0) * (NSHeight([m_pubElementsContentView frame]) - COLLAPSED_PUB_PADDING);
		
		winFrame.size.height += heightDelta;
		winFrame.origin.y -= heightDelta;
		
		[m_pubElementsContentView setHidden:hideFlag];
		
		// Resize the window
		unsigned int savedRosterElementsMask = [m_rosterElementsContentView autoresizingMask];
		unsigned int savedPubElementsMask = [m_pubElementsContentView autoresizingMask];
		
		[m_rosterElementsContentView setAutoresizingMask:( NSViewWidthSizable | NSViewMinYMargin )];
		[m_pubElementsContentView setAutoresizingMask:( NSViewWidthSizable | NSViewMinYMargin )];
		
		[win setFrame:winFrame display:YES animate:animateFlag];
		
		[m_rosterElementsContentView setAutoresizingMask:savedRosterElementsMask];
		[m_pubElementsContentView setAutoresizingMask:savedPubElementsMask];
		
		// Save the current state in the preferences. This way we'll know whether the saved window frame
		// corresponds to the window having the ads view expanded or collapsed. See the comments in -windowDidLoad
		// for more info on how we use this when loading the window from the NIB.
		[[NSUserDefaults standardUserDefaults] setBool:hideFlag forKey:@"RosterPubWasCollapsed"];
	}
}


- (LPPubManager *)p_currentPubManager
{
	return [[m_currentPubManager retain] autorelease];
}

- (void)p_setCurrentPubManager:(LPPubManager *)pubManager
{
	if (m_currentPubManager != pubManager) {
		[m_currentPubManager release];
		m_currentPubManager = [pubManager retain];
	}
}


- (void)p_reloadPub
{
	// Don't load anything if the window isn't on-screen because the flash gets all screwed up.
	// See ticket #153: http://trac.intra.sapo.pt/projects/leapfrog/ticket/153
	
	if ([[self window] isVisible]) {
		LPPubManager	*pubManager = [self p_currentPubManager];
		NSURL			*mainPubURL = [pubManager mainPubURL];
		NSString		*statusHTML = [pubManager statusPhraseHTML];
		
		// Banner Ad
		if (mainPubURL) {
			[[m_pubBannerWebView mainFrame] loadRequest:[NSURLRequest requestWithURL:mainPubURL]];
			[self p_setPubElementsHidden:NO animate:YES];
		}
		
		// Status Text
		if (statusHTML) {
			[[m_pubStatusWebView mainFrame] loadHTMLString:statusHTML baseURL:nil];
			[self p_setPubElementsHidden:NO animate:YES];
		}
	}
}


- (NSString *)p_userGroupsStringListForContact:(LPContact *)contact
{
	NSPredicate		*userVisibleGroupsPred = [NSPredicate predicateWithFormat:@"type == %@", [NSNumber numberWithInt:LPUserGroupType]];
	NSArray			*allGroups = [contact groups];
	NSArray			*userGroupsList = [allGroups filteredArrayUsingPredicate:userVisibleGroupsPred];
	
	return ( [userGroupsList count] > 0 ?
			 [NSString concatenatedStringWithValuesForKey:@"name" ofObjects:userGroupsList useDoubleQuotes:NO] :
			 nil );
}


#pragma mark -
#pragma mark LPAccount Notifications


- (void)accountWillChangeStatus:(NSNotification *)notif
{
	LPAccount *account = [notif object];
	LPStatus newStatus = [[[notif userInfo] objectForKey:@"NewStatus"] intValue];
	
	BOOL isOnline = [account isOnline];
	BOOL willBeOnline = ((newStatus != LPStatusOffline) && (newStatus != LPStatusConnecting));
	
	if (isOnline != willBeOnline) {
		NSUserDefaults				*defaults = [NSUserDefaults standardUserDefaults];
		float						noNotifsDelay = [defaults floatForKey:LPRosterNotificationsGracePeriodKey];
		LPEventNotificationsHandler *handler = [LPEventNotificationsHandler defaultHandler];
		
		[handler disableContactAvailabilityNotificationsForAccount:account
														 untilDate:[NSDate dateWithTimeIntervalSinceNow:noNotifsDelay]];
	}
}


#pragma mark -
#pragma mark WebView Delegate Methods (Pub Stuff)


- (WebView *)webView:(WebView *)sender createWebViewWithRequest:(NSURLRequest *)request
{
	/*
	 * We always get a nil request parameter in this method, it's probably a bug in WebKit or the Flash plug-in.
	 * In order to intercept the URL that WebKit is trying to open (so that we can redirect it to the system default
	 * web browser) we give it a dummy WebView if it wants to open a new window and make ourselves the WebPolicyDelegate
	 * for that dummy view in order to be able to intercept the URL being opened.
	 */
	static WebView *myDummyPubViewAux = nil;
	if (myDummyPubViewAux == nil) {
		myDummyPubViewAux = [[WebView alloc] init];
		[myDummyPubViewAux setPolicyDelegate:self];
	}
	return myDummyPubViewAux;
}


- (void)webView:(WebView *)sender decidePolicyForNavigationAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request frame:(WebFrame *)frame decisionListener:(id<WebPolicyDecisionListener>)listener
{
	[[NSWorkspace sharedWorkspace] openURL:[request URL]];
	[listener ignore];
}


- (NSArray *)webView:(WebView *)sender contextMenuItemsForElement:(NSDictionary *)element defaultMenuItems:(NSArray *)defaultMenuItems
{
	return [NSArray array];
}


- (unsigned)webView:(WebView *)sender dragDestinationActionMaskForDraggingInfo:(id <NSDraggingInfo>)draggingInfo
{
	// We don't want the WebView to process anything dropped on it
	return WebDragDestinationActionNone;
}


- (unsigned)webView:(WebView *)sender dragSourceActionMaskForPoint:(NSPoint)point
{
	return WebDragSourceActionNone;
}


#pragma mark -
#pragma mark LPAvatarButton Delegate Methods


- (void)avatarButton:(LPAvatarButton *)bttn receivedDropWithPasteboard:(NSPasteboard *)pboard
{
	if ([[self delegate] respondsToSelector:@selector(rosterController:importAvatarFromPasteboard:)]) {
		[[self delegate] rosterController:self importAvatarFromPasteboard:pboard];
	}
}


#pragma mark -
#pragma mark LPEditGroupsController Delegate Methods


- (void)editGroupsController:(LPEditGroupsController *)ctrl deleteGroups:(NSArray *)groups
{
	[self interactiveRemoveGroups:groups];
}


#pragma mark -
#pragma mark NSTableView Delegate / Data Source Methods


- (int)numberOfRowsInTableView:(NSTableView *)tableView
{
	return [m_flatRoster count];
}


- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)rowIndex
{
	if (![self groupTableView:(JKGroupTableView *)tableView isGroupRow:rowIndex])
	{
		LPContact *contact = [m_flatRoster objectAtIndex:rowIndex];
	
		if ([[tableColumn identifier] isEqualToString:@"AvatarColumn"])
		{
			return [contact avatar];
		}
		else if ([[tableColumn identifier] isEqualToString:@"ContactColumn"])
		{
			NSMutableAttributedString *resultString = [[NSMutableAttributedString alloc] init];
			NSMutableParagraphStyle *paragraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
			NSString *statusMessage = [contact statusMessage];
			NSAttributedString *attributedString;
			
			// We want to truncate the tails of strings.
			[paragraphStyle setLineBreakMode:NSLineBreakByTruncatingTail];
			
			// Contact Name
			NSDictionary *contactNameAttrs = [NSDictionary dictionaryWithObjectsAndKeys:
				paragraphStyle, NSParagraphStyleAttributeName,
				[NSFont systemFontOfSize:(m_useSmallRowHeight ? [NSFont smallSystemFontSize] : 12.0)], NSFontAttributeName,
				( ([contact status] == LPStatusOffline) ?
				  [NSColor lightGrayColor] :
				  [NSColor blackColor] ), NSForegroundColorAttributeName,
				nil];
			
			attributedString = [[NSAttributedString alloc] initWithString:[contact name] attributes:contactNameAttrs];
			[resultString appendAttributedString:attributedString];
			[attributedString release];
			
			// Contact Groups
			if (m_listGroupsBesideContacts) {
				NSDictionary *contactGroupsAttrs = [NSDictionary dictionaryWithObjectsAndKeys:
					paragraphStyle, NSParagraphStyleAttributeName,
					[NSFont systemFontOfSize:(m_useSmallRowHeight ? [NSFont smallSystemFontSize] : 12.0)], NSFontAttributeName,
					[NSColor grayColor], NSForegroundColorAttributeName,
					nil];
				
				NSString *groupsStr = [NSString stringWithFormat:@" (%@)", [self p_userGroupsStringListForContact:contact]];
				
				attributedString = [[NSAttributedString alloc] initWithString:groupsStr attributes:contactGroupsAttrs];
				[resultString appendAttributedString:attributedString];
				[attributedString release];
			}
			
			// Contact Status
			if (statusMessage != nil && ![statusMessage isEqualToString:@""])
			{
				[[resultString mutableString] appendString:(m_useSmallRowHeight ? @"  " : @"\n")];
				
				NSAttributedString *attributedStatus =
					[statusMessage attributedStringByTranslatingEmoticonsToImagesUsingEmoticonSet:[LPEmoticonSet defaultEmoticonSet]
																				  emoticonsHeight:16.0
																				   baselineOffset:-5.0];
				
				NSRange attributedStatusFinalRange = NSMakeRange([resultString length], [attributedStatus length]);
				NSDictionary *statusMessageAttrs = [NSDictionary dictionaryWithObjectsAndKeys:
					paragraphStyle, NSParagraphStyleAttributeName,
					[NSColor grayColor], NSForegroundColorAttributeName,
					[NSFont labelFontOfSize:[NSFont labelFontSize]], NSFontAttributeName,
					nil];
				
				[resultString appendAttributedString:attributedStatus];
				[resultString addAttributes:statusMessageAttrs range:attributedStatusFinalRange];
			}

			[paragraphStyle release];

			return [resultString autorelease];
		}
		else if ([[tableColumn identifier] isEqualToString:@"StatusColumn"])
		{
			return LPStatusIconFromStatus([contact status]);
		}
		else
		{
			// Unknown table column
			return nil;
		}
	}
	else
	{
		// Ignored for group rows.
		return nil;
	}
}


- (BOOL)tableView:(NSTableView *)aTableView writeRows:(NSArray *)rows toPasteboard:(NSPasteboard *)pboard
{
	// This method is deprecated in 10.4, but the alternative doesn't exist on 10.3, so we have to use this one.
	
	BOOL			acceptDrag = YES;
	NSMutableArray	*draggedContactsList = [NSMutableArray arrayWithCapacity:[rows count]];
	NSEnumerator	*rowNrEnum = [rows objectEnumerator];
	NSNumber		*rowNr;
	
	while (rowNr = [rowNrEnum nextObject]) {
		id contact = [m_flatRoster objectAtIndex:[rowNr unsignedIntValue]];
		
		if (![contact isKindOfClass:[LPContact class]]) {
			acceptDrag = NO;
			break;
		} else {
			[draggedContactsList addObject:contact];
		}
	}
	
	if (acceptDrag)
		LPAddContactsToPasteboard(pboard, draggedContactsList);
	
	return acceptDrag;
}


- (NSDragOperation)tableView:(NSTableView *)aTableView validateDrop:(id <NSDraggingInfo>)info proposedRow:(int)row proposedDropOperation:(NSTableViewDropOperation)operation
{
	NSDragOperation		resultOp = NSDragOperationNone;
	NSDragOperation		sourceOpMask = [info draggingSourceOperationMask];
	NSArray				*draggedTypes = [[info draggingPasteboard] types];
	unsigned int		flatRosterCount = [m_flatRoster count];
	id					targetRosterItem = ( (row >= 0 && row < flatRosterCount) ?
											 [m_flatRoster objectAtIndex:row] : nil );
	
	if ([draggedTypes containsObject:LPRosterContactPboardType] && row < flatRosterCount) {
		if		(sourceOpMask & NSDragOperationMove		) resultOp = NSDragOperationMove;
		else if (sourceOpMask & NSDragOperationGeneric	) resultOp = NSDragOperationGeneric;
#warning Only allow "moves" while we don't support multiple groups per contact
		else resultOp = NSDragOperationGeneric;
		//else if (sourceOpMask & NSDragOperationCopy		) resultOp = NSDragOperationCopy;
		
		JKGroupTableView	*groupTableView = (JKGroupTableView *)aTableView;
		int					targetGroupIndex = [groupTableView groupIndexForRow:row];
		NSArray				*contactsBeingDragged = LPRosterContactsBeingDragged(info);
		
		if (row == targetGroupIndex) {
			[groupTableView showDropHighlightAroundGroupOfRow:targetGroupIndex];
			[groupTableView setDropRow:targetGroupIndex dropOperation:NSTableViewDropOn];
		}
		else if (![contactsBeingDragged containsObject:targetRosterItem]) {
			[groupTableView clearGroupDropHighlight];
			[groupTableView setDropRow:row dropOperation:NSTableViewDropOn];
		}
		else {
			resultOp = NSDragOperationNone;
		}
	}
	else if ([draggedTypes containsObject:LPRosterContactEntryPboardType]) {
		if (row < flatRosterCount && [targetRosterItem isKindOfClass:[LPContact class]]) {
			resultOp = NSDragOperationGeneric;
			[aTableView setDropRow:row dropOperation:NSTableViewDropOn];
		}
		else if (row >= flatRosterCount) {
			// Retarget the drop to the entire table view
			resultOp = NSDragOperationGeneric;
			[aTableView setDropRow: -1 dropOperation: NSTableViewDropOn];
		}
		else {
			resultOp = NSDragOperationNone;
		}
	}
	else if ([draggedTypes containsObject:NSFilenamesPboardType] && operation == NSTableViewDropOn) {
		if ([targetRosterItem isKindOfClass:[LPContact class]] && [targetRosterItem canDoFileTransfer]) {
			
			[aTableView setDropRow:row dropOperation:NSTableViewDropOn];
			// Always a copy, ignore the source mask
			resultOp = NSDragOperationCopy;
		}
	}
	
	return resultOp;
}


- (BOOL)tableView:(NSTableView *)aTableView acceptDrop:(id <NSDraggingInfo>)info row:(int)row dropOperation:(NSTableViewDropOperation)operation
{
	NSPasteboard		*pboard = [info draggingPasteboard];
	NSArray				*draggedTypes = [pboard types];
	NSDragOperation		dragOpMask = [info draggingSourceOperationMask];
	id					targetRosterItem = ( (row >= 0 && row < [m_flatRoster count]) ?
											 [m_flatRoster objectAtIndex:row] : nil );
	
	if ([draggedTypes containsObject:LPRosterContactPboardType]) {
		NSArray			*contactsBeingDragged = LPRosterContactsBeingDragged(info);
		
		if ([targetRosterItem isKindOfClass:[LPGroup class]]) {

			NSEnumerator	*contactsEnum = [contactsBeingDragged objectEnumerator];
			LPContact		*contact;
			
			while (contact = [contactsEnum nextObject]) {
				if ((dragOpMask & NSDragOperationMove) || (dragOpMask & NSDragOperationGeneric)) {
					if (![[targetRosterItem contacts] containsObject:contact]) {
						LPGroup *prevGroup = [[contact groups] objectAtIndex:0];
						[contact moveFromGroup:prevGroup toGroup:targetRosterItem];
					}
				}
				else if (dragOpMask & NSDragOperationCopy) {
					if (![[targetRosterItem contacts] containsObject:contact]) {
						[targetRosterItem addContact:contact];
					}
				}
			}
			
		}
		else if ([targetRosterItem isKindOfClass:[LPContact class]]) {
			NSString *msg, *infoMsg;
			
			if ([contactsBeingDragged count] == 1) {
				msg = [NSString stringWithFormat:
					NSLocalizedString(@"Do you really want to dissolve contact \"%@\" into contact \"%@\"?", @"roster edit warning"),
					[[contactsBeingDragged objectAtIndex:0] name],
					[targetRosterItem name]];
				
				infoMsg = [NSString stringWithFormat:
					NSLocalizedString(@"The contact being dragged will be merged with the destination contact. "
									  @"The result will be a single contact named \"%1$@\" containing all the addresses "
									  @"from \"%1$@\" and \"%2$@\".", @"roster edit warning"),
					[targetRosterItem name],
					[[contactsBeingDragged objectAtIndex:0] name]];
			}
			else {
				msg = [NSString stringWithFormat:
					NSLocalizedString(@"Do you really want to dissolve %d contacts into contact \"%@\"?", @"roster edit warning"),
					[contactsBeingDragged count],
					[targetRosterItem name]];
				
				infoMsg = [NSString stringWithFormat:
					NSLocalizedString(@"The contacts being dragged will be merged together into the destination contact. "
									  @"The result will be a single contact named \"%1$@\" containing all the addresses from "
									  @"\"%1$@\", %2$@.", @"roster edit warning"),
					[targetRosterItem name],
					[NSString concatenatedStringWithValuesForKey:@"name" ofObjects:contactsBeingDragged useDoubleQuotes:YES]];
			}
			
			NSAlert *alert = [NSAlert alertWithMessageText:msg
											 defaultButton:NSLocalizedString(@"OK", @"")
										   alternateButton:nil
											   otherButton:NSLocalizedString(@"Cancel", @"")
								 informativeTextWithFormat:@"%@", infoMsg];  // avoid interpreting % chars that may exist in the info message
			
			[alert beginSheetModalForWindow:[self window]
							  modalDelegate:self
							 didEndSelector:@selector(mergeContactsAlertDidEnd:returnCode:contextInfo:)
								contextInfo:(void *)[[NSArray alloc] initWithObjects:contactsBeingDragged, targetRosterItem, nil]];
		}
	}
	else if ([draggedTypes containsObject:LPRosterContactEntryPboardType]) {
		NSArray	*entriesBeingDragged = LPRosterContactEntriesBeingDragged(info);
		
		if ([targetRosterItem isKindOfClass:[LPContact class]]) {
			
			NSEnumerator	*entriesEnum = [entriesBeingDragged objectEnumerator];
			LPContactEntry	*entry;
			
			while (entry = [entriesEnum nextObject]) {
				if (dragOpMask & NSDragOperationGeneric) {
					if (![[targetRosterItem contactEntries] containsObject:entry]) {
						[entry moveToContact:targetRosterItem];
					}
				}
			}
		}
		else if (row < 0) {
			// The drop was targeted at the entire table view. Create a new contact with the contact entries being dragged.
			LPContact	*oldContact = [[entriesBeingDragged objectAtIndex:0] contact];
			NSString	*newContactName = [[self roster] uniqueNameForCopyOfContact:oldContact];
			LPContact	*newContact = [[[self roster] groupForName:nil] addNewContactWithName:newContactName];
			
			targetRosterItem = newContact;
			
			NSEnumerator	*entriesEnum = [entriesBeingDragged objectEnumerator];
			LPContactEntry	*entry;
			
			while (entry = [entriesEnum nextObject]) {
				if (dragOpMask & NSDragOperationGeneric) {
					if (![[targetRosterItem contactEntries] containsObject:entry]) {
						[entry moveToContact:targetRosterItem];
					}
				}
			}
		}
	}
	else if ([draggedTypes containsObject:NSFilenamesPboardType]) {
        NSArray		*files = [pboard propertyListForType:NSFilenamesPboardType];
		
		NSEnumerator *filePathEnumerator = [files objectEnumerator];
		NSString *filePath;
		
		while (filePath = [filePathEnumerator nextObject]) {
			LPContactEntry *targetContactEntry = [[targetRosterItem contactEntries] firstOnlineItemInArrayPassingCapabilitiesPredicate:@selector(canDoFileTransfer)];
			
			if (targetContactEntry)
				[[LPFileTransfersManager fileTransfersManager] startSendingFile:filePath
																 toContactEntry:targetContactEntry];
		}
	}
	
    return YES;
}

- (void)mergeContactsAlertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	NSArray *args = [(NSArray *)contextInfo autorelease];
	
	if (returnCode == NSAlertDefaultReturn) {
		NSArray *contactsBeingDragged = [args objectAtIndex:0];
		id targetRosterItem = [args objectAtIndex:1];
		
		NSEnumerator *contactEnum = [contactsBeingDragged objectEnumerator];
		LPContact *contact;
		
		while (contact = [contactEnum nextObject]) {
			NSEnumerator *entryEnum = [[contact contactEntries] objectEnumerator];
			LPContactEntry *entry;
			
			while (entry = [entryEnum nextObject]) {
				[entry moveToContact:targetRosterItem];
			}
			
			[[self roster] removeContact:contact];
		}
	}
}


- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
	[m_infoButton setEnabled:([[aNotification object] numberOfSelectedRows] > 0)];
}


- (BOOL)tableView:(NSTableView *)tableView shouldShowCellExpansionForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
	return NO;
}


- (NSString *)tableView:(NSTableView *)aTableView toolTipForCell:(NSCell *)aCell rect:(NSRectPointer)rect tableColumn:(NSTableColumn *)aTableColumn row:(int)row mouseLocation:(NSPoint)mouseLocation
{
	NSString *toolTip = nil;
	
	if (![self groupTableView:(JKGroupTableView *)aTableView isGroupRow:row]) {
		LPContact		*contact = [m_flatRoster objectAtIndex:row];
		
		// Chat entries
		NSMutableString		*JIDsStringsByStatusKind[LPStatusTypesCount];
		NSMutableSet		*alreadyProcessedJIDStrings = [NSMutableSet set];
		
		NSArray			*chatEntries = [contact chatContactEntries];
		LPStatus		statusKindIterator;
		
		for (statusKindIterator = (LPStatus)0; statusKindIterator < LPStatusTypesCount; ++statusKindIterator) {
			NSPredicate	*entriesWithThisStatusPred = [NSPredicate predicateWithFormat:@"status == %@", [NSNumber numberWithInt:statusKindIterator]];
			NSArray		*entriesWithThisStatus = [chatEntries filteredArrayUsingPredicate:entriesWithThisStatusPred];
			
			unichar bullet;
			switch (statusKindIterator) {
				case LPStatusAway:
				case LPStatusExtendedAway:
				case LPStatusDoNotDisturb:
					bullet = 0x2013; // dash
					break;
				case LPStatusInvisible:
				case LPStatusOffline:
					bullet = 0x00d7; // cross
					break;
				default:
					bullet = 0x2022; // bullet
					break;
			}
			
			JIDsStringsByStatusKind[statusKindIterator] = nil;
			
			NSEnumerator *chatEntriesEnum = [entriesWithThisStatus objectEnumerator];
			LPContactEntry *chatEntry;
			
			while (chatEntry = [chatEntriesEnum nextObject]) {
				NSString *humanReadableJID = [chatEntry humanReadableAddress];
				if (![alreadyProcessedJIDStrings containsObject:humanReadableJID]) {
					
					// Only add the header if we need to
					if (JIDsStringsByStatusKind[statusKindIterator] == nil)
						JIDsStringsByStatusKind[statusKindIterator] = [NSMutableString stringWithFormat:@"\n%@:",
							NSLocalizedStringFromTable( LPStatusStringFromStatus(statusKindIterator), @"Status", @"" )];
					
					[JIDsStringsByStatusKind[statusKindIterator] appendFormat:@"\n   %C %@", bullet, humanReadableJID];
					[alreadyProcessedJIDStrings addObject:humanReadableJID];
				}
			}
		}
		
		// Phone entries
		NSMutableSet	*alreadyProcessedPhoneStrings = [NSMutableSet set];
		NSMutableString *phoneJIDsStr = nil;
		
		NSEnumerator *smsEntriesEnum = [[contact smsContactEntries] objectEnumerator];
		LPContactEntry *smsEntry;
		
		while (smsEntry = [smsEntriesEnum nextObject]) {
			NSString *humanReadablePhone = [smsEntry humanReadableAddress];
			if (![alreadyProcessedPhoneStrings containsObject:humanReadablePhone]) {
				
				// Only add the header if we need to
				if (phoneJIDsStr == nil)
					phoneJIDsStr = [NSMutableString stringWithFormat:@"\n\n%@",
						NSLocalizedString(@"Phone Number(s):", @"roster tooltip")];
				
				[phoneJIDsStr appendFormat:@"\n   %C %@", 0x260e /* telephone */, humanReadablePhone];
				/* alternative telephone unicode char: 0x2706 */
				
				[alreadyProcessedPhoneStrings addObject:humanReadablePhone];
			}
		}
		
		// Tool Tip
		NSMutableString *toolTipText = [NSMutableString stringWithFormat:@"%@\n", [contact name]];
		
		NSString *statusMessage = [contact statusMessage];
		if (statusMessage && [statusMessage length] > 0)
			[toolTipText appendFormat:@"\"%@\"\n", statusMessage];
		
		// Groups
		NSString *userGroupsListString = [self p_userGroupsStringListForContact:contact];
		if ([userGroupsListString length] > 0)
			[toolTipText appendFormat:@"\n%@ %@\n", NSLocalizedString(@"Groups:", @"roster tooltip"), userGroupsListString];
		
		// Chat entries
		for (statusKindIterator = (LPStatus)0; statusKindIterator < LPStatusTypesCount; ++statusKindIterator)
			if (JIDsStringsByStatusKind[statusKindIterator])
				[toolTipText appendString: JIDsStringsByStatusKind[statusKindIterator]];
		
		// Phone entries
		if (phoneJIDsStr)
			[toolTipText appendString: phoneJIDsStr];
		
		toolTip = toolTipText;
	}
	
	return toolTip;
}


#pragma mark -
#pragma mark JKGroupTableDataSource Methods


- (void)groupTableView:(JKGroupTableView *)tableView deleteRows:(NSIndexSet *)rowSet
{
	NSAssert(([rowSet count] > 0), @"There is no active selection in the roster table view");
	
	if ([rowSet count] > 0) {
		[self interactiveRemoveContacts:[m_flatRoster objectsAtIndexes:rowSet]];
	}
}


- (BOOL)groupTableView:(JKGroupTableView *)tableView isGroupRow:(int)rowIndex
{
	if ([[m_flatRoster objectAtIndex:rowIndex] isKindOfClass:[LPGroup class]])
		return YES;
	else
		return NO;
}


- (NSString *)groupTableView:(JKGroupTableView *)tableView titleForGroupRow:(int)rowIndex
{
	// WARNING: We assume that rowIndex is a value group row!
	return [[m_flatRoster objectAtIndex:rowIndex] name];
}


- (void)groupTableView:(JKGroupTableView *)tableView groupRowClicked:(int)rowIndex
{
	NSUserDefaults	*defaults = [NSUserDefaults standardUserDefaults];
	NSMutableArray	*collapsedGroupNames = [[defaults arrayForKey:LPRosterCollapsedGroupsKey] mutableCopy];
	
	if (collapsedGroupNames == nil) {
		collapsedGroupNames = [[NSMutableArray alloc] init];
	}
	
	NSString *groupName = [[m_flatRoster objectAtIndex:rowIndex] name];
	
	if ([m_rosterTableView isGroupExpanded:rowIndex]) {
		[m_rosterTableView collapseGroupAtIndex:rowIndex animate:YES];
		[collapsedGroupNames addObject:groupName];
	} else {
		[m_rosterTableView expandGroupAtIndex:rowIndex animate:YES];
		[collapsedGroupNames removeObject:groupName];
	}
	
	[defaults setObject:collapsedGroupNames forKey:LPRosterCollapsedGroupsKey];
	[collapsedGroupNames release];
}


#pragma mark -
#pragma mark Status Msg NSTextField Delegate Methods


- (void)controlTextDidEndEditing:(NSNotification *)aNotification
{
	if ([aNotification object] == m_statusMessageTextField) {
		// We don't need to set anything because the text field is already bound to the status message in the account.
		// Just finish the editing session.
		[[self window] performSelector:@selector(makeFirstResponder:)
							withObject:m_rosterTableView
							afterDelay:0.0];
	}
}


#pragma mark -
#pragma mark Roster Search Field Delegate Methods


- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)command
{
	BOOL handled = NO;
	
	if (control == m_searchField) {
		if (command == @selector(insertTab:) ||
			command == @selector(insertNewline:) || command == @selector(insertNewlineIgnoringFieldEditor:) ||
			command == @selector(moveUp:) || command == @selector(moveDown:))
		{
			[self performSelector:@selector(p_makeRosterTableViewTheFirstResponderWithArgs:)
					   withObject:[NSArray arrayWithObjects:[NSValue valueWithPointer:command], [NSApp currentEvent], nil]
					   afterDelay:0.0];
			handled = YES;
		}
	}
	
	return handled;
}


- (void)p_makeRosterTableViewTheFirstResponderWithArgs:(NSArray *)args
{
	[[self window] makeFirstResponder:m_rosterTableView];
	
	SEL		command = [[args objectAtIndex:0] pointerValue];
	NSEvent	*keyEvent = [args objectAtIndex:1];
	
	// Change the selection
	if (command == @selector(moveUp:) || command == @selector(moveDown:)) {
		// Forward the key event to the table view
		[m_rosterTableView keyDown:keyEvent];
	}
	else if ([m_rosterTableView numberOfSelectedRows] == 0) {
		[m_rosterTableView selectFirstNonGroupRow:nil];
	}
	
	// Default action for RETURN/ENTER
	if (command == @selector(insertNewline:) || command == @selector(insertNewlineIgnoringFieldEditor:)) {
		// Do we have a single contact being shown?
		NSEnumerator *rosterItemsEnum = [m_flatRoster objectEnumerator];
		id rosterItem = nil;
		int contactsCount = 0;
		
		while (rosterItem = [rosterItemsEnum nextObject]) {
			if ([rosterItem isKindOfClass:[LPContact class]]) {
				++contactsCount;
			}
			if (contactsCount > 1) {
				// OK, we have more than one, we can stop counting.
				break;
			}
		}
		
		if (contactsCount == 1) {
			// Forward the RETURN/ENTER key event to the table view
			[m_rosterTableView keyDown:keyEvent];
		}
	}
}


@end
