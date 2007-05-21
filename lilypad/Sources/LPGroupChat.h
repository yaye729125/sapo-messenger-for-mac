//
//  LPGroupChat.h
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import <Cocoa/Cocoa.h>

@class LPAccount;


@interface LPGroupChat : NSObject
{
	int			m_ID;
	
	LPAccount	*m_account;
	id			m_delegate;
	
	NSString	*m_roomJID;
	NSString	*m_nickname;
	
	BOOL		m_hasJoined;
}

+ groupChatForRoomWithJID:(NSString *)roomJID onAccount:(LPAccount *)account groupChatID:(int)ID nickname:(NSString *)nickname;
- initForRoomWithJID:(NSString *)roomJID onAccount:(LPAccount *)account groupChatID:(int)ID nickname:(NSString *)nickname;

- (id)delegate;
- (void)setDelegate:(id)delegate;

- (int)ID;
- (LPAccount *)account;
- (NSString *)roomJID;
- (NSString *)roomName;
- (NSString *)nickname;
- (BOOL)hasJoined;

- (void)leaveGroupChat;

- (void)handleDidJoinGroupChat;

@end
