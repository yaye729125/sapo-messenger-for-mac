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


- (IBAction)join:(id)sender
{
	[[self window] makeFirstResponder:nil];
	[[self window] close];
	
	if ([m_delegate respondsToSelector:@selector(joinChatRoomWithParametersFromController:)]) {
		[m_delegate joinChatRoomWithParametersFromController:self];
	}
}

- (IBAction)cancel:(id)sender
{
	[[self window] close];
}


@end
