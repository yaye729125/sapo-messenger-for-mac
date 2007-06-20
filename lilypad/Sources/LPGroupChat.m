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
#import "LPGroupChatContact.h"


#define NSStringWithFormatIfNotEmpty(formatStr, argStr)	\
	([argStr length] > 0 ? [NSString stringWithFormat:formatStr, argStr] : @"")


@implementation LPGroupChat

+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key
{
	if ([key isEqualToString:@"nickname"] || [key isEqualToString:@"topic"]) {
		// Avoid triggering change notifications on calls to -[LPGroupChat setNickname:] or -[LPGroupChat setTopic:]
		return NO;
	} else {
		return YES;
	}
}

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
		
		m_participants = [[NSMutableSet alloc] init];
		m_participantsByNickname = [[NSMutableDictionary alloc] init];
	}
	return self;
}

- (void)dealloc
{
	[m_account release];
	[m_roomJID release];
	[m_nickname release];
	[m_topic release];
	[m_participants release];
	[m_participantsByNickname release];
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

- (void)setNickname:(NSString *)newNick
{
	[LFAppController groupChatSetNicknameOnRoom:[self ID] to:newNick];
}

- (BOOL)isActive
{
	return m_isActive;
}

- (NSString *)topic
{
	return [[m_topic copy] autorelease];
}

- (void)setTopic:(NSString *)newTopic
{
	[LFAppController groupChatSetTopicOnRoom:[self ID] to:newTopic];
}

- (void)inviteJID:(NSString *)jid
{
	[LFAppController groupChatInvite:jid :[self roomJID]];
}

- (NSSet *)participants
{
	return [[m_participants retain] autorelease];
}

- (void)sendPlainTextMessage:(NSString *)message
{
	[LFAppController groupChatMessageSend:[self ID] plain:message];
}

- (void)endGroupChat
{
	[m_account endGroupChat:self];
}

#pragma mark -

- (void)p_addParticipant:(LPGroupChatContact *)contact
{
	NSSet *changeSet = [NSSet setWithObject:contact];
	
	[self willChangeValueForKey:@"participants" withSetMutation:NSKeyValueUnionSetMutation usingObjects:changeSet];
	[m_participants addObject:contact];
	[self didChangeValueForKey:@"participants" withSetMutation:NSKeyValueUnionSetMutation usingObjects:changeSet];
	
	[m_participantsByNickname setObject:contact forKey:[contact nickname]];
}

- (void)p_removeParticipant:(LPGroupChatContact *)contact
{
	NSSet *changeSet = [NSSet setWithObject:contact];
	
	[self willChangeValueForKey:@"participants" withSetMutation:NSKeyValueMinusSetMutation usingObjects:changeSet];
	[m_participants removeObject:contact];
	[self didChangeValueForKey:@"participants" withSetMutation:NSKeyValueMinusSetMutation usingObjects:changeSet];
	
	[m_participantsByNickname removeObjectForKey:[contact nickname]];
}

- (LPGroupChatContact *)p_participantWithNickname:(NSString *)nickname
{
	return [m_participantsByNickname objectForKey:nickname];
}

- (void)p_updateParticipantNicknameFrom:(NSString *)oldNickname to:(NSString *)newNickname
{
	LPGroupChatContact *contact = [m_participantsByNickname objectForKey:oldNickname];
	
	[m_participantsByNickname removeObjectForKey:oldNickname];
	[contact handleChangedNickname:newNickname];
	[m_participantsByNickname setObject:contact forKey:newNickname];
}

- (void)p_doEmitUserSystemMessages
{
	m_emitUserSystemMessages = YES;
}


#pragma mark -

- (void)handleDidJoinGroupChatWithJID:(NSString *)roomJID nickname:(NSString *)nickname
{
	[self willChangeValueForKey:@"active"];
	m_isActive = YES;
	[self didChangeValueForKey:@"active"];
	
	if (![m_nickname isEqualToString:nickname]) {
		[self willChangeValueForKey:@"nickname"];
		[m_nickname release];
		m_nickname = [nickname copy];
		[self didChangeValueForKey:@"nickname"];
	}
	
	[self performSelector:@selector(p_doEmitUserSystemMessages) withObject:nil afterDelay:5.0];
}

- (void)handleDidLeaveGroupChat
{
	[self willChangeValueForKey:@"active"];
	m_isActive = NO;
	[self didChangeValueForKey:@"active"];
	
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(p_doEmitUserSystemMessages) object:nil];
}

- (void)handleDidCreateGroupChat
{
	if ([m_delegate respondsToSelector:@selector(groupChat:didReceivedSystemMessage:)]) {
		[m_delegate groupChat:self didReceivedSystemMessage:NSLocalizedString(@"Chat-room was created.",
																			  @"Chat room system message")];
	}
}

- (void)handleDidDestroyGroupChatWithReason:(NSString *)reason alternateRoomJID:(NSString *)alternateRoomJID
{
#warning This notification could be handled in a more user-friendly way. Simply showing a chat-room JID to the user is lame!
	
	NSString *sysMsg = ( ([alternateRoomJID length] > 0) ?
						 [NSString stringWithFormat:
							 NSLocalizedString(@"Chat-room was destroyed. Please join the alternative chat-room at \"%@\".",
											   @"Chat room system message"), alternateRoomJID] :
						 NSLocalizedString(@"Chat-room was destroyed.", @"Chat room system message") );
	
	if ([m_delegate respondsToSelector:@selector(groupChat:didReceivedSystemMessage:)]) {
		[m_delegate groupChat:self didReceivedSystemMessage:sysMsg];
	}
}

- (void)handleContactDidJoinGroupChatWithNickname:(NSString *)nickname JID:(NSString *)jid role:(NSString *)role affiliation:(NSString *)affiliation
{
	[self p_addParticipant:[LPGroupChatContact groupChatContactWithNickame:nickname realJID:jid
																	  role:role affiliation:affiliation]];
	
	if (m_emitUserSystemMessages) {
		// Send a system message to our delegate
		NSString *sysMsg = [NSString stringWithFormat:
			NSLocalizedString(@"\"%@\"%@ has joined the chat. <%@, %@>", @"Chat room system message"),
			nickname,
			NSStringWithFormatIfNotEmpty(@" (%@)", jid),
			role, affiliation];
		
		if ([m_delegate respondsToSelector:@selector(groupChat:didReceivedSystemMessage:)]) {
			[m_delegate groupChat:self didReceivedSystemMessage:sysMsg];
		}
	}
}

- (void)handleContactWithNickname:(NSString *)nickname didChangeRoleTo:(NSString *)role affiliationTo:(NSString *)affiliation
{
	LPGroupChatContact *contact = [self p_participantWithNickname:nickname];
	NSString *jid = [contact realJID];
	
	[contact handleChangedRole:role orAffiliation:affiliation];
	
	if (m_emitUserSystemMessages) {
		// Send a system message to our delegate
		NSString *sysMsg = [NSString stringWithFormat:
			NSLocalizedString(@"\"%@\"%@ is now <%@, %@>.", @"Chat room system message"),
			nickname,
			NSStringWithFormatIfNotEmpty(@" (%@)", jid),
			role, affiliation];
		
		if ([m_delegate respondsToSelector:@selector(groupChat:didReceivedSystemMessage:)]) {
			[m_delegate groupChat:self didReceivedSystemMessage:sysMsg];
		}
	}
}

- (void)handleContactWithNickname:(NSString *)nickname didChangeStatusTo:(LPStatus)status statusMessageTo:(NSString *)statusMsg
{
	[[self p_participantWithNickname:nickname] handleChangedStatus:status statusMessage:statusMsg];
}

- (void)handleContactWithNickname:(NSString *)nickname didChangeNicknameFrom:(NSString *)old_nickname to:(NSString *)new_nickname
{
	[self p_updateParticipantNicknameFrom:old_nickname to:new_nickname];
	
	if ([m_nickname isEqualToString:nickname]) {
		[self willChangeValueForKey:@"nickname"];
		[m_nickname release];
		m_nickname = [new_nickname copy];
		[self didChangeValueForKey:@"nickname"];
	}
	
	// Send a system message to our delegate
	NSString *sysMsg = [NSString stringWithFormat:
		NSLocalizedString(@"\"%@\" is now known as \"%@\".", @"Chat room system message"),
		old_nickname, new_nickname];
	
	if ([m_delegate respondsToSelector:@selector(groupChat:didReceivedSystemMessage:)]) {
		[m_delegate groupChat:self didReceivedSystemMessage:sysMsg];
	}
}

- (void)handleContactWithNickname:(NSString *)nickname wasKickedBy:(NSString *)actor reason:(NSString *)reason
{
	LPGroupChatContact *contact = [self p_participantWithNickname:nickname];
	NSString *jid = [contact realJID];
	
	[self p_removeParticipant:contact];
	
	// Send a system message to our delegate
	NSString *sysMsg = [NSString stringWithFormat:
		NSLocalizedString(@"\"%@\"%@ was kicked%@%@.", @"Chat room system message"),
		nickname,
		NSStringWithFormatIfNotEmpty(@" (%@)", jid),
		NSStringWithFormatIfNotEmpty(@" by \"%@\"", actor),
		NSStringWithFormatIfNotEmpty(@" (reason: %@)", reason)];
	
	if ([m_delegate respondsToSelector:@selector(groupChat:didReceivedSystemMessage:)]) {
		[m_delegate groupChat:self didReceivedSystemMessage:sysMsg];
	}
	
	
	if ([m_nickname isEqualToString:nickname])
		; // Do something different if we're the one being kicked?
}

- (void)handleContactWithNickname:(NSString *)nickname wasBannedBy:(NSString *)actor reason:(NSString *)reason
{
	LPGroupChatContact *contact = [self p_participantWithNickname:nickname];
	NSString *jid = [contact realJID];
	
	[self p_removeParticipant:contact];
	
	// Send a system message to our delegate
	NSString *sysMsg = [NSString stringWithFormat:
		NSLocalizedString(@"\"%@\"%@ was banned%@%@.", @"Chat room system message"),
		nickname,
		NSStringWithFormatIfNotEmpty(@" (%@)", jid),
		NSStringWithFormatIfNotEmpty(@" by \"%@\"", actor),
		NSStringWithFormatIfNotEmpty(@" (reason: %@)", reason)];
	
	if ([m_delegate respondsToSelector:@selector(groupChat:didReceivedSystemMessage:)]) {
		[m_delegate groupChat:self didReceivedSystemMessage:sysMsg];
	}
	
	
	if ([m_nickname isEqualToString:nickname])
		; // Do something different if we're the one being banned?
}

- (void)handleContactWithNickname:(NSString *)nickname wasRemovedFromChatBy:(NSString *)actor reason:(NSString *)reason dueTo:(NSString *)dueTo
{
	LPGroupChatContact *contact = [self p_participantWithNickname:nickname];
	NSString *jid = [contact realJID];
	
	[self p_removeParticipant:contact];
	
	// Send a system message to our delegate
	NSString *sysMsg = [NSString stringWithFormat:
		NSLocalizedString(@"\"%@\"%@ was removed from the room%@ (due to: \"%@\"%@).", @"Chat room system message"),
		nickname,
		NSStringWithFormatIfNotEmpty(@" (%@)", jid),
		NSStringWithFormatIfNotEmpty(@" by \"%@\"", actor),
		dueTo,
		NSStringWithFormatIfNotEmpty(@", reason: %@", reason)];
	
	if ([m_delegate respondsToSelector:@selector(groupChat:didReceivedSystemMessage:)]) {
		[m_delegate groupChat:self didReceivedSystemMessage:sysMsg];
	}
	
	
	if ([m_nickname isEqualToString:nickname])
		; // Do something different if we're the one being removed?
}

- (void)handleContactWithNickname:(NSString *)nickname didLeaveWithStatusMessage:(NSString *)status
{
	LPGroupChatContact *contact = [self p_participantWithNickname:nickname];
	NSString *jid = [contact realJID];
	
	[self p_removeParticipant:contact];
	
	if (m_emitUserSystemMessages) {
		// Send a system message to our delegate
		NSString *sysMsg = [NSString stringWithFormat:
			NSLocalizedString(@"\"%@\"%@ has left the room%@.", @"Chat room system message"),
			nickname,
			NSStringWithFormatIfNotEmpty(@" (%@)", jid),
			NSStringWithFormatIfNotEmpty(@" (%@)", status)];
		
		if ([m_delegate respondsToSelector:@selector(groupChat:didReceivedSystemMessage:)]) {
			[m_delegate groupChat:self didReceivedSystemMessage:sysMsg];
		}
	}
	
	
	if ([m_nickname isEqualToString:nickname])
		; // Do something different if we're the one leaving?
}

- (void)handleGroupChatErrorWithCode:(int)code message:(NSString *)msg
{
	// Send a system message to our delegate
	NSString *sysMsg = [NSString stringWithFormat:
		NSLocalizedString(@"Chat room error: %@ (%d)", @"Chat room system message"),
		msg, code];
	
	if ([m_delegate respondsToSelector:@selector(groupChat:didReceivedSystemMessage:)]) {
		[m_delegate groupChat:self didReceivedSystemMessage:sysMsg];
	}
}

- (void)handleTopicChangedTo:(NSString *)newTopic by:(NSString *)actor
{
	[self willChangeValueForKey:@"topic"];
	[m_topic release];
	m_topic = [newTopic copy];
	[self didChangeValueForKey:@"topic"];
	
	// Send a system message to our delegate
	LPGroupChatContact *contact = [self p_participantWithNickname:actor];
	NSString *jid = [contact realJID];
	
	NSString *sysMsg;
	
	if ([actor length] > 0) {
		sysMsg = [NSString stringWithFormat:
			NSLocalizedString(@"\"%@\"%@ has changed the topic to: \"%@\"", @"Chat room system message"),
			actor,
			NSStringWithFormatIfNotEmpty(@" (%@)", jid),
			newTopic];
	}
	else {
		sysMsg = [NSString stringWithFormat:
			NSLocalizedString(@"The topic has been set to: \"%@\"", @"Chat room system message"),
			newTopic];
	}
	
	if ([m_delegate respondsToSelector:@selector(groupChat:didReceivedSystemMessage:)]) {
		[m_delegate groupChat:self didReceivedSystemMessage:sysMsg];
	}
}

- (void)handleReceivedMessageFromNickname:(NSString *)nickname plainBody:(NSString *)plainBody
{
	if ([m_delegate respondsToSelector:@selector(groupChat:didReceivedMessage:fromContact:)]) {
		LPGroupChatContact *contact = [m_participantsByNickname objectForKey:nickname];
		[m_delegate groupChat:self didReceivedMessage:plainBody fromContact:contact];
	}
}

@end
