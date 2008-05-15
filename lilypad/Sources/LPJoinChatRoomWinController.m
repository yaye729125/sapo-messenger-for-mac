//
//  LPJoinChatRoomWinController.m
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jpavao@co.sapo.pt>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "LPJoinChatRoomWinController.h"
#import "LPAccount.h"
#import "LPAccountsController.h"
#import "LPAccountsPopUpButtonController.h"
#import "LPServerItemsInfo.h"
#import "LPChatsManager.h"


@implementation LPJoinChatRoomWinController


+ (void)initialize
{
	if (self == [LPJoinChatRoomWinController class]) {
		[self setKeys:[NSArray arrayWithObjects:@"host", @"room", @"nickname", nil]
				triggerChangeNotificationsForDependentKey:@"canJoin"];
		
		NSDictionary *baseDefaults = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:5]
																 forKey:@"LPMaxRecentChatRooms"];
		[[NSUserDefaults standardUserDefaults] registerDefaults:baseDefaults];
	}
}


- initWithDelegate:(id)delegate
{
    if (self = [self initWithWindowNibName:@"JoinChatRoom"]) {
		m_delegate = delegate;
		
		id recentRooms = [[NSUserDefaults standardUserDefaults] objectForKey:@"LPRecentChatRooms"];
		m_recentChatRoomsPlist = (recentRooms == nil ?
								  [[NSMutableArray alloc] init] :
								  [recentRooms mutableCopy]);
		
        [self setRoom:@""];
        [self setNickname:@""];
        [self setPassword:@""];
    }
    return self;
}


- (void)dealloc
{
	[m_accountsPopUpController removeObserver:self forKeyPath:@"selectedAccount"];
	
	[m_account removeObserver:self forKeyPath:@"serverItemsInfo.MUCServiceProviderItems"];
	[m_account release];
	
	[m_host release];
    [m_room release];
    [m_nickname release];
    [m_password release];
	
	[m_recentChatRoomsPlist release];
	[m_advancedOptionsView release];	// was retained in -windowDidLoad
	
    [super dealloc];
}


- (void)p_syncRecentChatsMenu
{
	NSMenu *menu = [m_recentChatRoomsPopUp menu];
	
	// Add the "Clear Menu" item if it's not there already
	if ([m_recentChatRoomsPopUp numberOfItems] <= 1) {
		[menu addItem:[NSMenuItem separatorItem]];
		
		NSMenuItem *clearMenuItem = [menu addItemWithTitle:NSLocalizedString(@"Clear Menu", @"join chat room window")
													action:@selector(clearRecentChatRoomsMenu:)
											 keyEquivalent:@""];
		[clearMenuItem setTarget:self];
	}
	
	// Remove all the dynamic items from the menu. There's one extra item at the top that doesn't actually show
	// up in the menu. It just provides the label displayed by the popup button when idle.
	int i;
	for (i = [m_recentChatRoomsPopUp numberOfItems]; i > 3; --i) {
		[m_recentChatRoomsPopUp removeItemAtIndex:1];
	}
	
	// Insert items mirroring the contents of the recent chat rooms plist
	if ([m_recentChatRoomsPlist count] == 0) {
		[m_recentChatRoomsPopUp setEnabled:NO];
		[m_recentChatRoomsPopUp setToolTip:NSLocalizedString(@"Recent chat rooms list is empty.", @"join chat room window")];
	}
	else {
		[m_recentChatRoomsPopUp setEnabled:YES];
		[m_recentChatRoomsPopUp setToolTip:NSLocalizedString(@"Click to select one of the chat rooms that were joined recently.",
															 @"join chat room window")];
		
		NSEnumerator *recentChatRoomEnum = [m_recentChatRoomsPlist objectEnumerator];
		NSDictionary *recentChatRoomDict;
		int insertionIndex = 1;
		
		while (recentChatRoomDict = [recentChatRoomEnum nextObject]) {
			NSString *titleFmt = NSLocalizedString(@"Room \"%@\" as \"%@\" (%@)", @"join chat room window");
			NSString *title = [NSString stringWithFormat:titleFmt,
							   [recentChatRoomDict objectForKey:@"Room"],
							   [recentChatRoomDict objectForKey:@"Nickname"],
							   [recentChatRoomDict objectForKey:@"Host"]];
			
			NSMenuItem *menuItem = [menu insertItemWithTitle:title action:NULL keyEquivalent:@"" atIndex:insertionIndex];
			[menuItem setRepresentedObject:recentChatRoomDict];
			
			++insertionIndex;
		}
	}
}


- (void)p_saveCurrentSettingsToRecentChatRoomsPlist
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	NSDictionary *recentChatRoomDict = [NSDictionary dictionaryWithObjectsAndKeys:
										[[self account] UUID], @"AccountUUID",
										[self host], @"Host",
										[self room], @"Room",
										[self nickname], @"Nickname", nil];
	
	if ([m_recentChatRoomsPlist containsObject:recentChatRoomDict]) {
		// Just move it to the top
		[m_recentChatRoomsPlist removeObject:recentChatRoomDict];
		[m_recentChatRoomsPlist insertObject:recentChatRoomDict atIndex:0];
	}
	else {
		[m_recentChatRoomsPlist insertObject:recentChatRoomDict atIndex:0];
		if ([m_recentChatRoomsPlist count] > [defaults integerForKey:@"LPMaxRecentChatRooms"]) {
			[m_recentChatRoomsPlist removeLastObject];
		}
	}
	
	[defaults setObject:m_recentChatRoomsPlist forKey:@"LPRecentChatRooms"];
}


- (void)windowDidLoad
{
	if ([self account] == nil) {
		[self setAccount:[[self accountsController] defaultAccount]];
	}
	
	// Get the advanced options box out of the parent view
	[m_advancedOptionsView retain];
	[m_advancedOptionsView removeFromSuperview];
	
	[m_recentChatRoomsPopUp setAutoenablesItems:NO];
	
	[m_accountsPopUpController addObserver:self forKeyPath:@"selectedAccount" options:0 context:NULL];
}


- (IBAction)showWindow:(id)sender
{
	// Reset to the default account and nickname everytime the window is put onscreen
	if (![[self window] isVisible]) {
		[self setNickname:[[NSUserDefaults standardUserDefaults] stringForKey:@"DefaultNickname"]];
		[self p_syncRecentChatsMenu];
	}
	[super showWindow:sender];
}


- (BOOL)p_shouldSyncWithDefaultMUCHostForAccount:(LPAccount *)account
{
	return ([[self host] length] == 0 || [[[account serverItemsInfo] MUCServiceProviderItems] containsObject:[self host]]);
}


- (LPAccountsController *)accountsController
{
	return [LPAccountsController sharedAccountsController];
}


- (LPAccount *)account
{
	return m_account;
}

- (void)setAccount:(LPAccount *)account
{
	if (account != m_account) {
		BOOL shouldUpdateHost = [self p_shouldSyncWithDefaultMUCHostForAccount:m_account];
		
		[m_account removeObserver:self forKeyPath:@"serverItemsInfo.MUCServiceProviderItems"];
		[m_account release];
		m_account = [account retain];
		[account addObserver:self forKeyPath:@"serverItemsInfo.MUCServiceProviderItems" options:0 context:NULL];
		
		if (shouldUpdateHost) {
			NSArray *mucProviders = [[account serverItemsInfo] MUCServiceProviderItems];
			[self setHost:([mucProviders count] > 0 ? [mucProviders objectAtIndex:0] : @"")];
		}
		
		[m_accountsPopUpController setSelectedAccount:account];
	}
}


- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ([keyPath isEqualToString:@"serverItemsInfo.MUCServiceProviderItems"]) {
		if ([self p_shouldSyncWithDefaultMUCHostForAccount:[self account]]) {
			NSArray *mucProviders = [[[self account] serverItemsInfo] MUCServiceProviderItems];
			[self setHost:([mucProviders count] > 0 ? [mucProviders objectAtIndex:0] : @"")];
		}
	}
	else if ([keyPath isEqualToString:@"selectedAccount"]) {
		[self setAccount:[object selectedAccount]];
	}
	else {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}


- (NSString *)host
{
    return [[m_host copy] autorelease]; 
}

- (void)setHost:(NSString *)aHost
{
    if (m_host != aHost) {
        [m_host release];
        m_host = [aHost copy];
		
		
		// Adjust the room name if needed
		NSArray *roomNameJIDComponents = [m_room componentsSeparatedByString:@"@"];
		
		if ([roomNameJIDComponents count] > 1 && ![m_host isEqualToString:[roomNameJIDComponents objectAtIndex:1]]) {
			[self setRoom:[roomNameJIDComponents objectAtIndex:0]];
		}
    }
}


- (NSString *)room
{
    return [[m_room copy] autorelease]; 
}

- (void)setRoom:(NSString *)aRoom
{
    if (m_room != aRoom) {
        [m_room release];
        m_room = [aRoom copy];
		
		// Adjust the room host if needed
		NSArray *newJIDComponents = [m_room componentsSeparatedByString:@"@"];
		if ([newJIDComponents count] > 1) {
			[self setHost:[newJIDComponents objectAtIndex:1]];
		}
    }
}

- (NSString *)nickname
{
    return [[m_nickname copy] autorelease]; 
}

- (void)setNickname:(NSString *)aNickname
{
    if (m_nickname != aNickname) {
        [m_nickname release];
        m_nickname = [aNickname copy];
    }
}

- (NSString *)password
{
    return [[m_password copy] autorelease]; 
}

- (void)setPassword:(NSString *)aPassword
{
    if (m_password != aPassword) {
        [m_password release];
        m_password = [aPassword copy];
    }
}

- (BOOL)requestChatHistory
{
	return m_requestChatHistory;
}

- (void)setRequestChatHistory:(BOOL)flag
{
	m_requestChatHistory = flag;
}


- (NSString *)roomJID
{
	NSString	*roomName = [self room];
	NSString	*roomHost = [self host];
	NSArray		*jidComponents = [roomName componentsSeparatedByString:@"@"];
	
	return ( [jidComponents count] < 2 ?
			 [NSString stringWithFormat:@"%@@%@", (roomName ? roomName : @""), (roomHost ? roomHost : @"")] :
			 (roomName ? roomName : @"") );
}


- (BOOL)canJoin
{
	return ( [[self host] length] > 0 &&
			 [[self room] length] > 0 &&
			 [[self nickname] length] > 0 );
}


- (IBAction)join:(id)sender
{
	// Force the controls to commit their values
	[[self window] makeFirstResponder:nil];
	
	NSString		*roomJID = [self roomJID];
	LPAccount		*account = [self account];
	LPChatsManager	*chatsManager = [LPChatsManager chatsManager];
	
	// Are we already chatting in a room with this JID?
	LPGroupChat *groupChat = [chatsManager groupChatForRoomJID:roomJID onAccount:account];
	
	if (groupChat == nil) {
		// Try to join the room right away to see if the parameters the user entered are valid.
		groupChat = [chatsManager startGroupChatWithJID:roomJID
											   nickname:[self nickname]
											   password:[self password]
										 requestHistory:[self requestChatHistory]
											  onAccount:account];
	}
	
	if (groupChat) {
		[self p_saveCurrentSettingsToRecentChatRoomsPlist];
		[[self window] close];
		
		if ([m_delegate respondsToSelector:@selector(joinController:showWindowForChatRoom:)]) {
			[m_delegate joinController:self showWindowForChatRoom:groupChat];
		}
	}
	else {
		NSBeginAlertSheet(NSLocalizedString(@"Invalid Parameters!", @"join chat room error messages"),
						  NSLocalizedString(@"OK", @""), nil, nil,
						  [self window], self, NULL, NULL, NULL,
						  NSLocalizedString(@"Some of the parameters you entered are not valid.", @"join group chat window"));
	}
}


- (IBAction)cancel:(id)sender
{
	[[self window] close];
}


- (IBAction)autoFillWithRecentChatRoomsSelectedItem:(id)sender
{
	NSDictionary *recentChatRoomDict = [[m_recentChatRoomsPopUp selectedItem] representedObject];
	
	LPAccountsController *accountsController = [self accountsController];
	LPAccount *account = [accountsController accountForUUID:[recentChatRoomDict objectForKey:@"AccountUUID"]];
	
	if (account == nil)
		account = [accountsController defaultAccount];
	
	[self setAccount:account];
	[self setHost:[recentChatRoomDict objectForKey:@"Host"]];
	[self setRoom:[recentChatRoomDict objectForKey:@"Room"]];
	[self setNickname:[recentChatRoomDict objectForKey:@"Nickname"]];
}


- (IBAction)clearRecentChatRoomsMenu:(id)sender
{
	[m_recentChatRoomsPlist removeAllObjects];
	[[NSUserDefaults standardUserDefaults] setObject:m_recentChatRoomsPlist forKey:@"LPRecentChatRooms"];
	[self p_syncRecentChatsMenu];
}


- (IBAction)toggleAdvancedOptionsView:(id)sender
{
	NSWindow *win = [self window];
	
	NSRect advancedOptionsViewFrame = [m_advancedOptionsView frame];
	NSRect windowFrame = [win frame];
	
	if ([sender state] == NSOnState) {
		// Get the advanced options view into the window
		
		windowFrame.origin.y -= NSHeight(advancedOptionsViewFrame);
		windowFrame.size.height += NSHeight(advancedOptionsViewFrame);
		
		[win setFrame:windowFrame display:YES animate:YES];
		
		advancedOptionsViewFrame.origin.x = 20.0;
		advancedOptionsViewFrame.origin.y = [sender frame].origin.y - 4.0 - NSHeight(advancedOptionsViewFrame);
		[m_advancedOptionsView setFrame:advancedOptionsViewFrame];
		
		[[win contentView] addSubview:m_advancedOptionsView];
	}
	else {
		// Get the advanced options view out of the window
		
		[m_advancedOptionsView removeFromSuperview];
		
		windowFrame.origin.y += NSHeight(advancedOptionsViewFrame);
		windowFrame.size.height -= NSHeight(advancedOptionsViewFrame);
		
		[win setFrame:windowFrame display:YES animate:YES];
	}
}


@end
