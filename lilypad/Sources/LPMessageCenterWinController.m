//
//  LPMessageCenterWinController.m
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "LPMessageCenterWinController.h"
#import "LPMessageCenter.h"
#import "LPSourceListCell.h"

#import "LPPresenceSubscription.h"


@interface LPMessageCenterOutlineView : NSOutlineView {}
@end

@implementation LPMessageCenterOutlineView
/*
 * Don't allow the outline view of the source list to know when it's being live resized.
 *
 * When being live resized, table views (and outline views) enter a special drawing mode
 * where they don't redraw themselves immediately as they're being resized. This prevents
 * them from burning too much CPU cycles and the resize operation appears to be much more
 * responsive.
 *
 * However, our source list will always have only a few items and we'd rather have it
 * being redrawn in real-time instead, as the split view handle is dragged. Kind of like
 * Mail.app does with its source list.
 */
- (BOOL)inLiveResize { return NO; }
@end


static NSString *LPMCPresenceSubscriptionsItem	= @"Presence Subscriptions";
static NSString *LPMCSapoNotificationsItem		= @"Alerts / Notifications";
static NSString *LPMCOfflineChatMessagesItem	= @"Offline Chat Messages";
static NSString *LPMCUnreadChatMessagesItem		= @"Unread Chat Messages";


@implementation LPMessageCenterWinController

- initWithMessageCenter:(LPMessageCenter *)messageCenter
{
	if (self = [super initWithWindowNibName:@"MessageCenter"]) {
		m_messageCenter = [messageCenter retain];
		
		[m_messageCenter addObserver:self forKeyPath:@"presenceSubscriptions" options:0 context:NULL];
		
		// Set the first available "base displayed notifications filter" as the default
		NSPredicate *firstPredicate = [[[self allBaseDisplayedNotificationsFilters] objectAtIndex:0] objectForKey:@"predicate"];
		[self setBaseDisplayedNotificationsFilterPredicate:firstPredicate];
	}
	return self;
}

- (id)delegate
{
	return m_delegate;
}

- (void)setDelegate:(id)delegate
{
	m_delegate = delegate;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[m_messageCenter removeObserver:self forKeyPath:@"presenceSubscriptions"];
	[m_sapoNotificationsController removeObserver:self forKeyPath:@"selectedObjects"];
	[m_offlineMessagesController removeObserver:self forKeyPath:@"selectedObjects"];
	
	[m_baseDisplayedNotificationsPredicate release];
	[m_sapoNotificationsManagerURL release];
	
	[m_messageCenter release];
	[super dealloc];
}

- (void)windowDidLoad
{
	[m_presenceSubscriptionsController bind:@"contentArray"
								   toObject:m_messageCenter
								withKeyPath:@"presenceSubscriptions"
									options:nil];
	
	[m_sapoNotificationsController setManagedObjectContext:[m_messageCenter managedObjectContext]];
	[m_sapoNotifChannelsController setManagedObjectContext:[m_messageCenter managedObjectContext]];
	[m_offlineMessagesController setManagedObjectContext:[m_messageCenter managedObjectContext]];
	
	[m_sapoNotificationsController addObserver:self forKeyPath:@"selectedObjects" options:0 context:NULL];
	[m_offlineMessagesController addObserver:self forKeyPath:@"selectedObjects" options:0 context:NULL];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(p_sapoNotificationsContextObjectsDidChange:)
												 name:NSManagedObjectContextObjectsDidChangeNotification
											   object:[m_messageCenter managedObjectContext]];

	
	// Set the default sort descriptors for the array controllers
	NSSortDescriptor *channelsSortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"name"
																		   ascending:YES
																			selector:@selector(caseInsensitiveCompare:)];
	[m_sapoNotifChannelsController setSortDescriptors:[NSArray arrayWithObject:channelsSortDescriptor]];
	[channelsSortDescriptor release];
	
	NSSortDescriptor *notifsSortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"date" ascending:NO];
	[m_sapoNotificationsController setSortDescriptors:[NSArray arrayWithObject:notifsSortDescriptor]];
	[notifsSortDescriptor release];
	
	NSSortDescriptor *offlineMsgsSortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"timestamp" ascending:YES];
	[m_offlineMessagesController setSortDescriptors:[NSArray arrayWithObject:offlineMsgsSortDescriptor]];
	[offlineMsgsSortDescriptor release];

	
	
	LPSourceListCell *sourceListCell = [[LPSourceListCell alloc] initTextCell:@""];
	NSTableColumn *sourceListTableColumn = [[m_sourceListOutlineView tableColumns] objectAtIndex:0];
	
	[sourceListCell setFont:[[sourceListTableColumn dataCell] font]];
	[sourceListCell setLineBreakMode:NSLineBreakByTruncatingTail];
	
	[sourceListTableColumn setDataCell:sourceListCell];
	[sourceListCell release];
	
	
	
	[m_chatMessagesBottomBar setBackgroundColor:[NSColor colorWithCalibratedWhite:0.9
																			alpha:1.0]];
	[m_chatMessagesBottomBar setBorderColor:[NSColor colorWithCalibratedWhite:0.75
																		alpha:1.0]];
	[m_offlineMessagesBottomBar setBackgroundColor:[NSColor colorWithCalibratedWhite:0.9
																			   alpha:1.0]];
	[m_offlineMessagesBottomBar setBorderColor:[NSColor colorWithCalibratedWhite:0.75
																		   alpha:1.0]];
	
	[m_sapoNotificationsTableView setTarget:self];
	[m_sapoNotificationsTableView setDoubleAction:@selector(openSapoNotificationURL:)];
	[m_offlineMessagesTableView setTarget:self];
	[m_offlineMessagesTableView setDoubleAction:@selector(openChatForSelectedOfflineMessage:)];
}

- (NSArray *)allBaseDisplayedNotificationsFilters
{
	static NSArray *allBaseFilters = nil;
	
	if (allBaseFilters == nil) {
		NSCalendarDate *now = [NSCalendarDate calendarDate];
		NSCalendarDate *todaysMidnight = [NSCalendarDate dateWithYear:[now yearOfCommonEra]
																month:[now monthOfYear]
																  day:[now dayOfMonth]
																 hour:0 minute:0 second:0
															 timeZone:[NSTimeZone localTimeZone]];
		NSCalendarDate *midnightOneWeekAgo = [todaysMidnight dateByAddingYears:0 months:0 days:(-7) hours:0 minutes:0 seconds:0];
		
		allBaseFilters = [[NSArray alloc] initWithObjects:
			//		[NSDictionary dictionaryWithObjectsAndKeys:
			//			NSLocalizedString(@"Unread", @"Base Displayed Notifications Filter Names"), @"name",
			//			[NSPredicate predicateWithFormat:@"unread == YES"], @"predicate",
			//			nil],
			[NSDictionary dictionaryWithObjectsAndKeys:
				NSLocalizedString(@"Today", @"Base Displayed Notifications Filter Names"), @"name",
				[NSPredicate predicateWithFormat:@"date >= %@", todaysMidnight], @"predicate",
				nil],
			[NSDictionary dictionaryWithObjectsAndKeys:
				NSLocalizedString(@"Last 7 Days", @"Base Displayed Notifications Filter Names"), @"name",
				[NSPredicate predicateWithFormat:@"date >= %@", midnightOneWeekAgo], @"predicate",
				nil],
			[NSDictionary dictionaryWithObjectsAndKeys:
				NSLocalizedString(@"All", @"Base Displayed Notifications Filter Names"), @"name",
				[NSPredicate predicateWithFormat:@"TRUEPREDICATE"], @"predicate",
				nil],
			nil];
	}
	
	return allBaseFilters;
}


- (void)p_updateFetchPredicate
{
	NSArray *selectedChannels = [m_sapoNotifChannelsController selectedObjects];
	
	NSPredicate *channelPred = ([selectedChannels count] == 0 ?
								[NSPredicate predicateWithFormat:@"TRUEPREDICATE"] :
								[NSPredicate predicateWithFormat:@"channel IN %@", selectedChannels]);
	
	NSPredicate *fetchPred = [NSCompoundPredicate andPredicateWithSubpredicates:
		[NSArray arrayWithObjects: channelPred, [self baseDisplayedNotificationsFilterPredicate], nil]];
	
	[m_sapoNotificationsController setFetchPredicate:fetchPred];
	[m_sapoNotificationsController fetch:nil];
}


- (NSPredicate *)baseDisplayedNotificationsFilterPredicate
{
	return [[m_baseDisplayedNotificationsPredicate retain] autorelease];
}

- (void)setBaseDisplayedNotificationsFilterPredicate:(NSPredicate *)basePredicate
{
	if (basePredicate != m_baseDisplayedNotificationsPredicate) {
		[m_baseDisplayedNotificationsPredicate release];
		m_baseDisplayedNotificationsPredicate = [basePredicate retain];
		
		[self p_updateFetchPredicate];
	}
}

- (NSURL *)sapoNotificationsManagerURL
{
	return [[m_sapoNotificationsManagerURL retain] autorelease];
}

- (void)setSapoNotificationsManagerURL:(NSURL *)theURL
{
	if (m_sapoNotificationsManagerURL != theURL) {
		[m_sapoNotificationsManagerURL release];
		m_sapoNotificationsManagerURL = [theURL retain];
	}
}

- (void)keyDown:(NSEvent *)keyEvent
{
	unichar key = [[keyEvent characters] characterAtIndex:0];
	id firstResponder = [[self window] firstResponder];
	
	switch (key) {
		case NSEnterCharacter:
		case NSCarriageReturnCharacter:
		case NSNewlineCharacter:
			if (firstResponder == m_sapoNotificationsTableView) {
				[self openSapoNotificationURL:nil];
			}
			else if (firstResponder == m_offlineMessagesTableView) {
				[self openChatForSelectedOfflineMessage:nil];
			}
			break;
			
		default:
			break;
	}
}

- (void)p_saveManagedObjectContext:(NSManagedObjectContext *)context
{
	NSError *error;
	[context save:&error];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ([keyPath isEqualToString:@"presenceSubscriptions"]) {
		// Force an update to the displayed new items counts
		[m_sourceListOutlineView setNeedsDisplay:YES];
	}
	else if ([keyPath isEqualToString:@"selectedObjects"]) {
		// It's one of the controllers managing objects that can be in either a read or unread state
		[[object selectedObjects] makeObjectsPerformSelector:@selector(markAsRead)];
		
		// If we saved the context right away it would go into an infinite loop. Save it with a delayed perform.
		[self performSelector:@selector(p_saveManagedObjectContext:) withObject:[object managedObjectContext] afterDelay:0.0];
		
		// Force an update to the displayed new items counts
		[m_sourceListOutlineView setNeedsDisplay:YES];
	}
	else {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}

- (IBAction)presenceSubscriptionButton1Clicked:(id)sender
{
	int selectedRow = [m_presenceSubscriptionsTableView selectedRow];
	
	LPPresenceSubscription *presSub = [[m_presenceSubscriptionsController arrangedObjects] objectAtIndex:selectedRow];
	LPPresenceSubscriptionState state = [presSub state];
	
	if (state == LPAuthorizationRequested) {
		[presSub approveRequest];
	}
	else if (state == LPAuthorizationLost) {
		[presSub sendRequest];
	}
	
	// Redisplay the current row as the buttons may have become disabled
	[m_presenceSubscriptionsTableView setNeedsDisplayInRect:[m_presenceSubscriptionsTableView rectOfRow:selectedRow]];
	
	// The count of unanswered presence subscriptions requests has probably also been changed
	[m_sourceListOutlineView reloadItem:LPMCPresenceSubscriptionsItem];
}

- (IBAction)presenceSubscriptionButton2Clicked:(id)sender
{
	int selectedRow = [m_presenceSubscriptionsTableView selectedRow];
	
	LPPresenceSubscription *presSub = [[m_presenceSubscriptionsController arrangedObjects] objectAtIndex:selectedRow];
	LPPresenceSubscriptionState state = [presSub state];
	
	if (state == LPAuthorizationRequested) {
		[presSub rejectRequest];
	}
	else if (state == LPAuthorizationLost) {
		[presSub removeContactEntry];
	}
	
	// Redisplay the current row as the buttons may have become disabled
	[m_presenceSubscriptionsTableView setNeedsDisplayInRect:[m_presenceSubscriptionsTableView rectOfRow:selectedRow]];
	
	// The count of unanswered presence subscriptions requests has probably also been changed
	[m_sourceListOutlineView reloadItem:LPMCPresenceSubscriptionsItem];
}

- (IBAction)openSapoNotificationURL:(id)sender
{
	NSArray *selection = [m_sapoNotificationsController selectedObjects];
	NSEnumerator *notifEnum = [selection objectEnumerator];
	id sapoNotification;
	
	while (sapoNotification = [notifEnum nextObject]) {
		NSURL *url = [NSURL URLWithString:[sapoNotification valueForKey:@"itemURL"]];
		if (url) {
			[[NSWorkspace sharedWorkspace] openURL:url];
		}
	}
}


- (IBAction)openChatForSelectedOfflineMessage:(id)sender
{
	if ([m_delegate respondsToSelector:@selector(messageCenterWinCtrl:openNewChatWithJID:)]) {
		NSEnumerator *msgEnum = [[m_offlineMessagesController selectedObjects] objectEnumerator];
		id msg;
		while (msg = [msgEnum nextObject]) {
			[m_delegate messageCenterWinCtrl:self openNewChatWithJID:[msg valueForKey:@"jid"]];
		}
	}
}


- (IBAction)openSapoNotificationsManagerURL:(id)sender
{
	if (m_sapoNotificationsManagerURL) {
		[[NSWorkspace sharedWorkspace] openURL:m_sapoNotificationsManagerURL];
	}
}


- (void)p_sapoNotificationChannelWasSelected:(id)channel
{
	[m_mainContentTabView selectTabViewItemWithIdentifier:@"alerts"];
	
	[m_sapoNotifChannelsController setSelectedObjects:(channel ?
													   [NSArray arrayWithObject:channel] :
													   [NSArray array])];
	[self p_updateFetchPredicate];
	[m_sapoNotificationsController setSelectedObjects:nil];
}


- (void)p_selectNotificationMessage:(id)message
{
	[m_sapoNotificationsController setSelectedObjects:[NSArray arrayWithObject:message]];
}


- (void)revealSapoNotificationWithURI:(NSString *)messageURI
{
	NSManagedObjectContext *context = [m_sapoNotificationsController managedObjectContext];
	NSPersistentStoreCoordinator *persistentStoreCoord = [context persistentStoreCoordinator];
	
	NSManagedObjectID *objectID = [persistentStoreCoord managedObjectIDForURIRepresentation:[NSURL URLWithString:messageURI]];
	
	id message = [context objectWithID:objectID];
	
	
	if (![[[m_mainContentTabView selectedTabViewItem] identifier] isEqualToString:@"alerts"] ||
		![[m_sapoNotificationsController arrangedObjects] containsObject:message])
	{
		int channelsHeadIndex = [m_sourceListOutlineView rowForItem:LPMCSapoNotificationsItem];
		[m_sourceListOutlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:channelsHeadIndex] byExtendingSelection:NO];
	}
	
	// Delayed perform to allow the controller to fetch the objects
	[self performSelector:@selector(p_selectNotificationMessage:) withObject:message afterDelay:0.0];
}


- (void)revealOfflineMessages
{
	int index = [m_sourceListOutlineView rowForItem:LPMCOfflineChatMessagesItem];
	[m_sourceListOutlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:index] byExtendingSelection:NO];
}


- (void)revealPresenceSubscriptions
{
	int index = [m_sourceListOutlineView rowForItem:LPMCPresenceSubscriptionsItem];
	[m_sourceListOutlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:index] byExtendingSelection:NO];
}


#pragma mark -
#pragma mark Presence Subscriptions NSTableView Data Source and Delegate


- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return [[m_messageCenter presenceSubscriptions] count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
	if ([[aTableColumn identifier] isEqualToString:@"kind"]) {
		LPPresenceSubscription *presSub = [[m_presenceSubscriptionsController arrangedObjects] objectAtIndex:rowIndex];
		LPPresenceSubscriptionState state = [presSub state];
		
		if (state == LPAuthorizationGranted)
			return NSLocalizedString(@"Granted", @"presence subscriptions message center table column");
		else if (state == LPAuthorizationRequested)
			return NSLocalizedString(@"Requested", @"presence subscriptions message center table column");
		else if (state == LPAuthorizationLost)
			return NSLocalizedString(@"Lost", @"presence subscriptions message center table column");
	}
	
	return @"";
}

- (void)tableView:(NSTableView *)aTableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
	if (aTableView == m_presenceSubscriptionsTableView) {
		NSString *colID = [aTableColumn identifier];
		BOOL isBtn1 = [colID isEqualToString:@"button1"];
		BOOL isBtn2 = [colID isEqualToString:@"button2"];
		
		if (isBtn1 || isBtn2) {
			LPPresenceSubscription *presSub = [[m_presenceSubscriptionsController arrangedObjects] objectAtIndex:rowIndex];
			LPPresenceSubscriptionState state = [presSub state];
			
			if (state == LPAuthorizationGranted) {
				[aCell setBordered:NO];
				[aCell setTitle:@""];
				[aCell setEnabled:NO];
			}
			else {
				[aCell setBordered:YES];
				[aCell setEnabled:[presSub requiresUserIntervention]];
				
				if (state == LPAuthorizationRequested) {
					[aCell setTitle:( isBtn1 ?
									  NSLocalizedString(@"Accept", @"presence subscriptions message center table buttons") :
									  NSLocalizedString(@"Reject", @"presence subscriptions message center table buttons") )];
				}
				else if (state == LPAuthorizationLost) {
					[aCell setTitle:( isBtn1 ?
									  NSLocalizedString(@"Renew", @"presence subscriptions message center table buttons") :
									  NSLocalizedString(@"Remove", @"presence subscriptions message center table buttons") )];
				}
			}
		}
	}
}


#pragma mark -
#pragma mark Source List NSOutlineView Data Source and Delegate


- (id)outlineView:(NSOutlineView *)outlineView child:(int)index ofItem:(id)item
{
	id child = nil;
	
	// Level 1 items:
	if (item == nil) {
		if (index == 0) {
			child = LPMCPresenceSubscriptionsItem;
		} else if (index == 1) {
			child = LPMCSapoNotificationsItem;
		} else if (index == 2) {
			child = LPMCOfflineChatMessagesItem;
		} else if (index == 3) {
			child = LPMCUnreadChatMessagesItem;
		}
	}
	else if ([item isEqualTo: LPMCSapoNotificationsItem]) {
		child = [[m_sapoNotifChannelsController arrangedObjects] objectAtIndex:index];
	}
	
	return child;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
	if ([item isEqualTo: LPMCSapoNotificationsItem] ||
		[item isEqualTo: LPMCUnreadChatMessagesItem]) {
		return YES;
	}
	else {
		return NO;
	}
}

- (int)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
	if (item == nil)
		return 3;
	else if ([item isEqualTo: LPMCSapoNotificationsItem])
		return [[m_sapoNotifChannelsController arrangedObjects] count];
	else
		return 0;
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	if ([outlineView levelForItem:item] == 0) {
		// Level 1 categories
		return NSLocalizedString(item, @"message center source list");
	}
	else if ([item isKindOfClass:[LPSapoNotificationChannel class]]) {
		return [item valueForKey:@"name"];
	}
	else {
		return nil;
	}
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item
{
	return YES;
}

- (void)outlineViewSelectionDidChange:(NSNotification *)notification
{
	NSOutlineView *ov = [notification object];
	int selectedRow = [ov selectedRow];
	id selectedItem = (selectedRow >= 0 ? [ov itemAtRow:selectedRow] : nil);
	
	// Level 1 items:
	if ([ov levelForItem:selectedItem] == 0) {
		if ([selectedItem isEqualTo: LPMCPresenceSubscriptionsItem]) {
			[m_mainContentTabView selectTabViewItemWithIdentifier:@"pres sub"];
		}
		else if ([selectedItem isEqualTo: LPMCSapoNotificationsItem]) {
			[self p_sapoNotificationChannelWasSelected:nil];
		}
		else if ([selectedItem isEqualTo: LPMCOfflineChatMessagesItem]) {
			[m_mainContentTabView selectTabViewItemWithIdentifier:@"offline msgs"];
		}
		else if ([selectedItem isEqualTo: LPMCUnreadChatMessagesItem]) {
			[m_mainContentTabView selectTabViewItemWithIdentifier:@"chat msgs"];
		}
	}
	else if ([ov levelForItem:selectedItem] == 1 && [selectedItem isKindOfClass:[LPSapoNotificationChannel class]]) {
		[self p_sapoNotificationChannelWasSelected:selectedItem];
	}
}

- (void)outlineView:(NSOutlineView *)outlineView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	if (outlineView == m_sourceListOutlineView && [cell isKindOfClass:[LPSourceListCell class]]) {
		
		unsigned int newItemsCount = 0;
		
		if ([outlineView levelForItem:item] == 0) {
			if ([item isEqualTo: LPMCPresenceSubscriptionsItem]) {
				NSPredicate *unansweredPresSubPred = [NSPredicate predicateWithFormat:@"requiresUserIntervention == YES"];
				NSArray *unansweredPresSubs = [[m_messageCenter presenceSubscriptions] filteredArrayUsingPredicate:unansweredPresSubPred];
				
				newItemsCount = [unansweredPresSubs count];
			}
			else if ([item isEqualTo: LPMCSapoNotificationsItem]) {
				NSEnumerator *channelEnum = [[m_messageCenter sapoNotificationsChannels] objectEnumerator];
				LPSapoNotificationChannel *channel;
				
				while (channel = [channelEnum nextObject])
					newItemsCount += [[channel valueForKey:@"unreadCount"] intValue];
			}
			else if ([item isEqualTo: LPMCOfflineChatMessagesItem]) {
				NSFetchRequest *fetchReq = [[[NSFetchRequest alloc] init] autorelease];
				[fetchReq setPredicate:[NSPredicate predicateWithFormat:@"unread == YES"]];
				[fetchReq setEntity:[NSEntityDescription entityForName:@"LPOfflineMessage"
												inManagedObjectContext:[m_messageCenter managedObjectContext]]];
				NSError *error;
				NSArray *unreadOfflineMsgs = [[m_messageCenter managedObjectContext] executeFetchRequest:fetchReq error:&error];
				
				newItemsCount = [unreadOfflineMsgs count];
			}
		}
		else if ([outlineView levelForItem:item] == 1 && [item isKindOfClass:[LPSapoNotificationChannel class]]) {
			newItemsCount = [[item valueForKey:@"unreadCount"] intValue];
		}
		
		[cell setImage:[NSImage imageNamed:@"InfoButton"]];
		[cell setNewItemsCount:newItemsCount];
	}
}

- (float)outlineView:(NSOutlineView *)outlineView heightOfRowByItem:(id)item
{
	if (outlineView == m_sourceListOutlineView && [outlineView levelForItem:item] == 0)
		return (2.0 * [outlineView rowHeight]);
	else
		return [outlineView rowHeight];
}


#pragma mark -
#pragma mark NSManagedObjectContext Notifications

- (void)p_sapoNotificationsContextObjectsDidChange:(NSNotification *)notif
{
	// Preserve the selection
	int selectedRow = [m_sourceListOutlineView selectedRow];
	id selectedItem = (selectedRow >= 0 ? [m_sourceListOutlineView itemAtRow:selectedRow] : nil);
	
	
	[m_sourceListOutlineView reloadItem:LPMCSapoNotificationsItem reloadChildren:YES];
	[m_sourceListOutlineView reloadItem:LPMCOfflineChatMessagesItem];
	[m_sourceListOutlineView setNeedsDisplay:YES];
	
	
	// Preserve the selection
	if (selectedItem) {
		int newSelectedRow = [m_sourceListOutlineView rowForItem:selectedItem];
		if (newSelectedRow) {
			[m_sourceListOutlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:newSelectedRow]
								 byExtendingSelection:NO];
		}
	}
}

@end
