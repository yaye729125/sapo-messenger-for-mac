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
#import "LPServerItemsInfo.h"
#import "LPChatsManager.h"


@implementation LPJoinChatRoomWinController


+ (void)initialize
{
	if (self == [LPJoinChatRoomWinController class]) {
		[self setKeys:[NSArray arrayWithObjects:@"host", @"room", @"nickname", nil]
				triggerChangeNotificationsForDependentKey:@"canJoin"];
	}
}


// init
- initWithDelegate:(id)delegate
{
    if (self = [self initWithWindowNibName:@"JoinChatRoom"]) {
		m_delegate = delegate;
		
        [self setRoom:@""];
        [self setNickname:@""];
        [self setPassword:@""];
    }
    return self;
}


- (void)dealloc
{
	[m_account removeObserver:self forKeyPath:@"serverItemsInfo.MUCServiceProviderItems"];
	[m_accountsCtrl removeObserver:self forKeyPath:@"selectedObjects"];
	
	[m_account release];
	[m_host release];
    [m_room release];
    [m_nickname release];
    [m_password release];
	[m_advancedOptionsView release];
    [super dealloc];
}


- (void)windowDidLoad
{
	if ([self account] == nil) {
		[self setAccount:[[self accountsController] defaultAccount]];
	}
	[m_accountsCtrl setSelectedObjects:[NSArray arrayWithObject:[self account]]];
	[m_accountsCtrl addObserver:self forKeyPath:@"selectedObjects" options:0 context:NULL];
	
	// Get the advanced options box out of the parent view
	[m_advancedOptionsView retain];
	[m_advancedOptionsView removeFromSuperview];
}


- (IBAction)showWindow:(id)sender
{
	// Reset to the default account everytime the window is put onscreen
	if (![[self window] isVisible]) {
		[self setAccount:[[LPAccountsController sharedAccountsController] defaultAccount]];
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
		
		[m_accountsCtrl setSelectedObjects:[NSArray arrayWithObject:account]];
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
	else if ([keyPath isEqualToString:@"selectedObjects"]) {
		[self setAccount:[[object selectedObjects] objectAtIndex:0]];
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
