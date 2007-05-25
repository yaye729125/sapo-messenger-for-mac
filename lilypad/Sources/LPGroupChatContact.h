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


@interface LPGroupChatContact : NSObject
{
	NSString	*m_nickname;
	NSString	*m_realJID;
	NSString	*m_role;
	NSString	*m_affiliation;
	LPStatus	m_status;
	NSString	*m_statusMessage;
}

+ (LPGroupChatContact *)groupChatContactWithNickame:(NSString *)nickname realJID:(NSString *)jid role:(NSString *)role affiliation:(NSString *)affiliation;
- initWithNickname:(NSString *)nickname realJID:(NSString *)jid role:(NSString *)role affiliation:(NSString *)affiliation;

- (NSString *)nickname;
- (NSString *)realJID;
- (NSString *)role;
- (NSString *)affiliation;
- (LPStatus)status;
- (NSString *)statusMessage;

- (void)handleChangedNickname:(NSString *)newNickname;
- (void)handleChangedRole:(NSString *)newRole orAffiliation:(NSString *)newAffiliation;
- (void)handleChangedStatus:(LPStatus)newStatus statusMessage:(NSString *)message;

@end
