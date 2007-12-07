//
//  LPGroupChatContact.h
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import <Cocoa/Cocoa.h>


@interface NSString (RoleComparison)
- (NSComparisonResult)roleCompare:(NSString *)aContact;
@end


@class LPGroupChat;


@interface LPGroupChatContact : NSObject
{
	NSString	*m_nickname;
	NSString	*m_userPresentableNickname;
	NSString	*m_realJID;
	NSString	*m_role;
	NSString	*m_affiliation;
	LPStatus	m_status;
	NSString	*m_statusMessage;
	BOOL		m_isGagged;
	
	LPGroupChat	*m_groupChat;
}

+ (LPGroupChatContact *)groupChatContactWithNickame:(NSString *)nickname realJID:(NSString *)jid role:(NSString *)role affiliation:(NSString *)affiliation groupChat:(LPGroupChat *)gc;
- initWithNickname:(NSString *)nickname realJID:(NSString *)jid role:(NSString *)role affiliation:(NSString *)affiliation groupChat:(LPGroupChat *)gc;

- (NSString *)nickname;
// Protects the user by replacing white-space characters present in the nickname with some other visible string
- (NSString *)userPresentableNickname;
- (NSString *)realJID;
- (NSString *)role;
- (NSString *)affiliation;
- (LPStatus)status;
- (NSString *)statusMessage;
- (NSString *)attributesDescription;

- (BOOL)isGagged;
- (void)setGagged:(BOOL)flag;

- (LPGroupChat *)groupChat;
- (NSString *)JIDInGroupChat;

- (void)handleChangedNickname:(NSString *)newNickname;
- (void)handleChangedRole:(NSString *)newRole orAffiliation:(NSString *)newAffiliation;
- (void)handleChangedStatus:(LPStatus)newStatus statusMessage:(NSString *)message;

@end
