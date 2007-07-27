//
//  LPStatusMenuController.m
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Authors: Joao Pavao <jppavao@criticalsoftware.com>
//           Jason Kim <jason@512k.org>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "LPStatusMenuController.h"
#import "LPCommon.h"
#import "LPAccount.h"
#import "LPCurrentITunesTrackMonitor.h"


@interface LPStatusMenuController (Private)
- (NSArray *)p_menuItemsIncludingITunesMonitoringItem:(BOOL)includeITunesMonitoringItem;
- (NSMenuItem *)p_menuItemTitled:(NSString *)title imageName:(NSString *)imageName tag:(LPStatus)tag;
- (int)p_menuItemTagForAccountStatus:(LPStatus)status;
- (void)p_updateITunesTrackMenuItemsState;
- (void)p_selectMenuItemsWithStatusTag:(int)tag;
- (void)p_statusMenuAction:(id)sender;
- (NSString *)p_statusStringFromITunes;
- (void)p_updateStatusFromITunesTrackMonitor;
@end


static const int kCurrentITunesTrackMenuTag = 1000;


@implementation LPStatusMenuController


#pragma mark -
#pragma mark Initialization


- initWithAccount:(LPAccount *)account
{
	if (self = [super init]) {
		// Initialize.
		m_account = [account retain];
		
		[m_account addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionOld context:NULL];
		[m_account addObserver:self forKeyPath:@"targetStatus" options:0 context:NULL];
		
		m_controlledMenus = [[NSMutableSet alloc] init];
		m_controlledPopUpButtons = [[NSMutableSet alloc] init];
		
		m_currentlySelectedStatusMenuTag = [self p_menuItemTagForAccountStatus:[account status]];
		
		BOOL useITunesTrackOnStatus = [[NSUserDefaults standardUserDefaults] boolForKey:@"UseCurrentITunesTrackAsStatus"];
		[self setUsesCurrentITunesTrackAsStatus:useITunesTrackOnStatus];
	}
	
	return self;
}


- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[m_account removeObserver:self forKeyPath:@"targetStatus"];
	[m_account removeObserver:self forKeyPath:@"status"];
	
	[m_statusMessageBeforeITunesMonitoring release];
	[m_iTunesTrackMonitor release];
	[m_account release];
	[m_controlledMenus release];
	[m_controlledPopUpButtons release];
	
	[super dealloc];
}


- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ([keyPath isEqualToString:@"status"]) {
		LPStatus oldStatus = [[change objectForKey:NSKeyValueChangeOldKey] intValue];
		
		if (oldStatus == LPStatusConnecting && [object isOnline] && [self usesCurrentITunesTrackAsStatus]) {
			[self p_updateStatusFromITunesTrackMonitor];
		}
		
		LPStatus selectedStatus = ([object isOffline] ? LPStatusOffline : [object targetStatus]);
		[self p_selectMenuItemsWithStatusTag:[self p_menuItemTagForAccountStatus:selectedStatus]];
	}
	else if ([keyPath isEqualToString:@"targetStatus"]) {
		LPStatus selectedStatus = ([object isOffline] ? LPStatusOffline : [object targetStatus]);
		[self p_selectMenuItemsWithStatusTag:[self p_menuItemTagForAccountStatus:selectedStatus]];
	}
	else {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}


#pragma mark -
#pragma mark Instance Methods


- (void)insertControlledStatusItemsIntoMenu:(NSMenu *)menu atIndex:(unsigned int)index;
{
	NSEnumerator *enumerator = [[self p_menuItemsIncludingITunesMonitoringItem:YES] objectEnumerator];
	id item;
	
	while ((item = [enumerator nextObject]))
		[menu insertItem:item atIndex:index++];
	
	[m_controlledMenus addObject:menu];
	[[menu itemWithTag:m_currentlySelectedStatusMenuTag] setState:NSOnState];
	[[menu itemWithTag:kCurrentITunesTrackMenuTag] setState:[self usesCurrentITunesTrackAsStatus]];
}

- (void)stopControllingStatusInMenu:(NSMenu *)menu
{
	[m_controlledMenus removeObject:menu];
}

- (void)insertControlledStatusItemsIntoPopUpMenu:(NSPopUpButton *)button atIndex:(unsigned int)index
{
	NSMenu *menu = [button menu];
	NSEnumerator *enumerator = [[self p_menuItemsIncludingITunesMonitoringItem:NO] objectEnumerator];
	id item;
	
	while ((item = [enumerator nextObject]))
		[menu insertItem:item atIndex:index++];
	
	[m_controlledPopUpButtons addObject:button];
	[button selectItemWithTag:m_currentlySelectedStatusMenuTag];
}

- (void)stopControllingStatusInPopUpMenu:(NSPopUpButton *)button
{
	[m_controlledPopUpButtons removeObject:button];
}


- (BOOL)usesCurrentITunesTrackAsStatus
{
	return m_isSettingStatusFromITunes;
}

- (void)setUsesCurrentITunesTrackAsStatus:(BOOL)flag
{
	if (flag != m_isSettingStatusFromITunes) {
		
		m_isSettingStatusFromITunes = flag;
		[[NSUserDefaults standardUserDefaults] setBool:flag forKey:@"UseCurrentITunesTrackAsStatus"];
		
		if (flag) {
			// Start observing iTunes state changes
			if (m_iTunesTrackMonitor == nil) {
				m_iTunesTrackMonitor = [[LPCurrentITunesTrackMonitor alloc] init];
				[[NSNotificationCenter defaultCenter] addObserver:self
														 selector:@selector(currentITunesTrackDidChange:)
															 name:LPCurrentITunesTrackDidChange
														   object:m_iTunesTrackMonitor];
			}
			
			// Save the current status message
			[m_statusMessageBeforeITunesMonitoring release];
			m_statusMessageBeforeITunesMonitoring = [[m_account statusMessage] copy];
			
			// Force the first update
			[self p_updateStatusFromITunesTrackMonitor];
		}
		else {
			if (m_iTunesTrackMonitor) {
				// Stop observing iTunes state changes
				[[NSNotificationCenter defaultCenter] removeObserver:self
																name:LPCurrentITunesTrackDidChange
															  object:m_iTunesTrackMonitor];
				[m_iTunesTrackMonitor release];
				m_iTunesTrackMonitor = nil;
				
				[m_account setStatusMessage:m_statusMessageBeforeITunesMonitoring saveToServer:YES];
				
				[m_statusMessageBeforeITunesMonitoring release];
				m_statusMessageBeforeITunesMonitoring = nil;
			}
		}
		
		[self p_updateITunesTrackMenuItemsState];
	}
}


#pragma mark -
#pragma mark Private Methods


- (NSArray *)p_menuItemsIncludingITunesMonitoringItem:(BOOL)includeITunesMonitoringItem
{
	// NOTE: This menu returns an array of NEW NSMenuItem instances each time (because NSMenuItems 
	// can only belong to one menu, otherwise AppKit complains loudly). 
	NSMutableArray *items = [NSMutableArray array];

	[items addObject:[self p_menuItemTitled:NSLocalizedStringFromTable(LPStatusStringFromStatus(LPStatusAvailable), @"Status", @"")
								  imageName:@"iconAvailable16x16"
										tag:LPStatusAvailable]];
	[items addObject:[self p_menuItemTitled:NSLocalizedStringFromTable(LPStatusStringFromStatus(LPStatusAway), @"Status", @"")
								  imageName:@"iconAway16x16"
										tag:LPStatusAway]];
	[items addObject:[self p_menuItemTitled:NSLocalizedStringFromTable(LPStatusStringFromStatus(LPStatusExtendedAway), @"Status", @"")
								  imageName:@"iconXA16x16"
										tag:LPStatusExtendedAway]];
	[items addObject:[self p_menuItemTitled:NSLocalizedStringFromTable(LPStatusStringFromStatus(LPStatusDoNotDisturb), @"Status", @"")
								  imageName:@"iconDND16x16"
										tag:LPStatusDoNotDisturb]];
	[items addObject:[self p_menuItemTitled:NSLocalizedStringFromTable(LPStatusStringFromStatus(LPStatusInvisible), @"Status", @"")
								  imageName:@"iconInvisible16x16"
										tag:LPStatusInvisible]];
	[items addObject:[self p_menuItemTitled:NSLocalizedStringFromTable(LPStatusStringFromStatus(LPStatusOffline), @"Status", @"")
								  imageName:@"iconOffline16x16"
										tag:LPStatusOffline]];
	
	if (includeITunesMonitoringItem) {
		[items addObject:[NSMenuItem separatorItem]];
		
		// Current iTunes Track menu item
		[items addObject:[self p_menuItemTitled:NSLocalizedString(@"Current iTunes Track", @"status")
									  imageName:nil
											tag:kCurrentITunesTrackMenuTag]];
	}
	
	return items;
}


- (NSMenuItem *)p_menuItemTitled:(NSString *)title imageName:(NSString *)imageName tag:(LPStatus)tag;
{
	NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:@selector(p_statusMenuAction:) keyEquivalent:@""];
	
	if (imageName)
		[item setImage:[NSImage imageNamed:imageName]];
	[item setTag:tag];
	[item setTarget:self];

	return [item autorelease];
}


- (int)p_menuItemTagForAccountStatus:(LPStatus)status
{
	// Select the appropriate menu item
	int menuItemTag = 0;
	
	if (status == LPStatusConnecting)
		menuItemTag = [m_account targetStatus];
	else
		menuItemTag = status;
	
	return menuItemTag;
}


- (void)p_updateITunesTrackMenuItemsState
{
	// Update the menus only. PopUp menus don't contain this switch item.
	NSEnumerator *menuEnum = [m_controlledMenus objectEnumerator];
	NSMenu *aMenu;
	
	while (aMenu = [menuEnum nextObject]) {
		[[aMenu itemWithTag:kCurrentITunesTrackMenuTag] setState:[self usesCurrentITunesTrackAsStatus]];
	}
}


- (void)p_selectMenuItemsWithStatusTag:(int)tag
{
	if (tag != m_currentlySelectedStatusMenuTag) {
		// Update the menus
		NSEnumerator *menuEnum = [m_controlledMenus objectEnumerator];
		NSMenu *aMenu;
		
		while (aMenu = [menuEnum nextObject]) {
			[[aMenu itemWithTag:m_currentlySelectedStatusMenuTag] setState:NSOffState];
			[[aMenu itemWithTag:tag] setState:NSOnState];
		}
		
		// Update the popup menus
		NSEnumerator *popUpButtonsEnum = [m_controlledPopUpButtons objectEnumerator];
		NSPopUpButton *aPopUpButton;
		
		while (aPopUpButton = [popUpButtonsEnum nextObject]) {
			[aPopUpButton selectItemWithTag:tag];
		}
		
		m_currentlySelectedStatusMenuTag = tag;
	}
}


- (void)p_statusMenuAction:(id)sender
{
	int tag = [sender tag];
	
	if (tag == kCurrentITunesTrackMenuTag) {
		[self setUsesCurrentITunesTrackAsStatus:(![self usesCurrentITunesTrackAsStatus])];
	}
	else {
		[m_account setTargetStatus:tag];
		[self p_selectMenuItemsWithStatusTag:tag];
	}
}


- (NSString *)p_statusStringFromITunes
{
	NSString *trackDescription = @"";
	
	if (![m_iTunesTrackMonitor isPlaying]) {
		trackDescription = NSLocalizedString(@"(not playing)", @"");
	}
	else {
		NSString *artist = [m_iTunesTrackMonitor artist];
		NSString *title = [m_iTunesTrackMonitor title];
		
		if (title && artist)
			trackDescription = [NSString stringWithFormat:@"%@ - %@", title, artist];
		else if (title)
			trackDescription = title;
	}
	
	return [NSString stringWithFormat:@"%C %@", LPCurrentTuneStatusUnicharPrefix, trackDescription];
}


- (void)p_updateStatusFromITunesTrackMonitor
{
	[m_account setStatusMessage:[self p_statusStringFromITunes] saveToServer:NO];
}


#pragma mark -
#pragma LPCurrentITunesTrackMonitor Notifications


- (void)currentITunesTrackDidChange:(NSNotification *)notif
{
	if ([m_account isOnline]) {
		// Only pay attention to these notifications if the account is actually online
		[self p_updateStatusFromITunesTrackMonitor];
	}
}


@end
