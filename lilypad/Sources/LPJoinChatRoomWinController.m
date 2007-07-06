//
//  LPJoinChatRoomWinController.m
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "LPJoinChatRoomWinController.h"
#import "LPAccount.h"
#import "LPServerItemsInfo.h"


@implementation LPJoinChatRoomWinController


+ (void)initialize
{
	[self setKeys:[NSArray arrayWithObjects:@"host", @"room", @"nickname", nil]
		triggerChangeNotificationsForDependentKey:@"canJoin"];
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
	
	[m_account release];
	[m_host release];
    [m_room release];
    [m_nickname release];
    [m_password release];
    [super dealloc];
}


- (void)p_setDefaultHostFromAccountIfNeeded
{
	NSArray *mucProviders = [[[self account] serverItemsInfo] MUCServiceProviderItems];
	
	if ( [mucProviders count] > 0 &&
		 ( [[self host] length] == 0 || ![mucProviders containsObject:[self host]] ))
	{
		[self setHost:[mucProviders objectAtIndex:0]];
	}
	else if ([mucProviders count] == 0) {
		[self setHost:nil];
	}
}


- (LPAccount *)account
{
	return m_account;
}

- (void)setAccount:(LPAccount *)account
{
	if (account != m_account) {
		[m_account removeObserver:self forKeyPath:@"serverItemsInfo.MUCServiceProviderItems"];
		[m_account release];
		m_account = [account retain];
		[account addObserver:self forKeyPath:@"serverItemsInfo.MUCServiceProviderItems" options:0 context:NULL];
		
		[self p_setDefaultHostFromAccountIfNeeded];
	}
}


- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ([keyPath isEqualToString:@"serverItemsInfo.MUCServiceProviderItems"]) {
		[self p_setDefaultHostFromAccountIfNeeded];
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
		NSArray *oldJIDComponents = [m_room componentsSeparatedByString:@"@"];
		
		
        [m_room release];
        m_room = [aRoom copy];
		
		
		// Adjust the room host if needed
		NSArray *newJIDComponents = [m_room componentsSeparatedByString:@"@"];
		
		if ([newJIDComponents count] > 1) {
			[self setHost:[newJIDComponents objectAtIndex:1]];
		}
		else if ([newJIDComponents count] <= 1 && [oldJIDComponents count] > 1) {
			[self p_setDefaultHostFromAccountIfNeeded];
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
	
	NSString *roomJID = [self roomJID];
	
	// Are we already chatting in a room with this JID?
	LPGroupChat *groupChat = [[self account] groupChatForRoomJID:roomJID];
	
	if (groupChat == nil) {
		// Try to join the room right away to see if the parameters the user entered are valid.
		groupChat = [[self account] startGroupChatWithJID:roomJID
												 nickname:[self nickname]
												 password:[self password]
										   requestHistory:[self requestChatHistory]];
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


@end
