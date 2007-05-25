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

@class LPAccount, LPGroupChatContact;


@interface LPGroupChat : NSObject
{
	int			m_ID;
	
	LPAccount	*m_account;
	id			m_delegate;
	
	NSString	*m_roomJID;
	NSString	*m_nickname;
	NSString	*m_topic;
	
	BOOL		m_isActive;
	BOOL		m_emitUserSystemMessages;
	
	NSMutableSet		*m_participants;
	NSMutableDictionary	*m_participantsByNickname;
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
- (BOOL)isActive;
- (NSString *)topic;

- (NSSet *)participants;

- (void)sendPlainTextMessage:(NSString *)message;
- (void)endGroupChat;

- (void)handleDidJoinGroupChatWithJID:(NSString *)roomJID nickname:(NSString *)nickname;
- (void)handleDidLeaveGroupChat;
- (void)handleDidCreateGroupChat;
- (void)handleDidDestroyGroupChatWithReason:(NSString *)reason alternateRoomJID:(NSString *)alternateRoomJID;
- (void)handleContactDidJoinGroupChatWithNickname:(NSString *)nickname JID:(NSString *)jid role:(NSString *)role affiliation:(NSString *)affiliation;
- (void)handleContactWithNickname:(NSString *)nickname didChangeRoleTo:(NSString *)role affiliationTo:(NSString *)affiliation;
- (void)handleContactWithNickname:(NSString *)nickname didChangeStatusTo:(LPStatus)status statusMessageTo:(NSString *)statusMsg;
- (void)handleContactWithNickname:(NSString *)nickname didChangeNicknameFrom:(NSString *)old_nickname to:(NSString *)new_nickname;
- (void)handleContactWithNickname:(NSString *)nickname wasKickedBy:(NSString *)actor reason:(NSString *)reason;
- (void)handleContactWithNickname:(NSString *)nickname wasBannedBy:(NSString *)actor reason:(NSString *)reason;
- (void)handleContactWithNickname:(NSString *)nickname wasRemovedFromChatBy:(NSString *)actor reason:(NSString *)reason dueTo:(NSString *)dueTo;
- (void)handleContactWithNickname:(NSString *)nickname didLeaveWithStatusMessage:(NSString *)status;
- (void)handleGroupChatErrorWithCode:(int)code message:(NSString *)msg;
- (void)handleTopicChangedTo:(NSString *)newTopic by:(NSString *)actor;
- (void)handleReceivedMessageFromNickname:(NSString *)nickname plainBody:(NSString *)plainBody;
@end

@interface NSObject (LPGroupChatDelegate)
- (void)groupChat:(LPGroupChat *)chat didReceivedMessage:(NSString *)msg fromContact:(LPGroupChatContact *)contact;
- (void)groupChat:(LPGroupChat *)chat didReceivedSystemMessage:(NSString *)msg;
@end
