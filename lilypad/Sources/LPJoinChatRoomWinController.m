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


@implementation LPJoinChatRoomWinController


// init
- initWithDelegate:(id)delegate
{
    if (self = [self initWithWindowNibName:@"JoinChatRoom"]) {
		m_delegate = delegate;
		
        [self setHost:@""];
        [self setRoom:@""];
        [self setNickname:@""];
        [self setPassword:@""];
    }
    return self;
}


- (void)dealloc
{
    [m_host release];
    [m_room release];
    [m_nickname release];
    [m_password release];
    [super dealloc];
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
