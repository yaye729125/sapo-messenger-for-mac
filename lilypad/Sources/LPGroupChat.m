//
//  LPGroupChat.m
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "LPGroupChat.h"
#import "LPAccount.h"


@implementation LPGroupChat

+ groupChatForRoomWithJID:(NSString *)roomJID onAccount:(LPAccount *)account groupChatID:(int)ID nickname:(NSString *)nickname
{
	return [[[[self class] alloc] initForRoomWithJID:roomJID onAccount:account groupChatID:ID nickname:nickname] autorelease];
}

- initForRoomWithJID:(NSString *)roomJID onAccount:(LPAccount *)account groupChatID:(int)ID nickname:(NSString *)nickname
{
	if (self = [super init]) {
		m_ID = ID;
		m_account = [account retain];
		m_roomJID = [roomJID copy];
		m_nickname = [nickname copy];
	}
	return self;
}

- (void)dealloc
{
	[m_account release];
	[m_roomJID release];
	[m_nickname release];
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

- (int)ID
{
	return m_ID;
}

- (LPAccount *)account
{
	return [[m_account retain] autorelease];
}

- (NSString *)roomJID
{
	return [[m_roomJID copy] autorelease];
}

- (NSString *)roomName
{
	return [m_roomJID JIDUsernameComponent];
}

- (NSString *)nickname
{
	return [[m_nickname copy] autorelease];
}

- (BOOL)hasJoined
{
	return m_hasJoined;
}

- (void)leaveGroupChat
{
	[m_account leaveGroupChat:self];
}

- (void)handleDidJoinGroupChat
{
	[self willChangeValueForKey:@"hasJoined"];
	m_hasJoined = YES;
	[self didChangeValueForKey:@"hasJoined"];
}

@end
