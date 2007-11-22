//
//  LPChatsManager.m
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "LPChatsManager.h"
#import "LPAccountsController.h"
#import "LPAccount.h"
#import "LPRoster.h"
#import "LPChat.h"
#import "LPGroupChat.h"
#import "LPContact.h"
#import "LPContactEntry.h"


static LPChatsManager *s_chatsManager = nil;


@implementation LPChatsManager

+ (LPChatsManager *)chatsManager
{
	if (s_chatsManager == nil) {
		s_chatsManager = [[LPChatsManager alloc] init];
	}
	return s_chatsManager;
}

- init
{
	if (self = [super init]) {
		// From LPAccount
		m_activeChatsByID = [[NSMutableDictionary alloc] init];
		m_activeChatsByContact = [[NSMutableDictionary alloc] init];
		
		m_activeGroupChatsByID = [[NSMutableDictionary alloc] init];
		m_activeGroupChatsByAccountUUIDAndRoomJID = [[NSMutableDictionary alloc] init];
		
		[LFPlatformBridge registerNotificationsObserver:self];
	}
	return self;
}

- (void)dealloc
{
	[LFPlatformBridge unregisterNotificationsObserver:self];
	
	// From LPAccount
	[m_activeChatsByID release];
	[m_activeChatsByContact release];
	
	[m_activeGroupChatsByID release];
	[m_activeGroupChatsByAccountUUIDAndRoomJID release];
	
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


#pragma mark -
#pragma mark LPChats (from LPAccount)

#pragma mark Private


- (void)p_addChat:(LPChat *)chat
{
	// Allow the registration of chats that don't have valid IDs (>= 0). This allows us to create chats in addition to the ones
	// created by the core (the latter have valid IDs).
	
	if ([chat ID] >= 0) {
		NSAssert(([m_activeChatsByID objectForKey:[NSNumber numberWithInt:[chat ID]]] == nil),
				 @"There is already a registered chat for this ID");
		
		[m_activeChatsByID setObject:chat forKey:[NSNumber numberWithInt:[chat ID]]];
	}
	
	NSAssert(([m_activeChatsByContact objectForKey:[chat contact]] == nil),
			 @"There is already a registered chat for this contact");
	
	[m_activeChatsByContact setObject:chat forKey:[chat contact]];
}


- (void)p_removeChat:(LPChat *)chat
{
	[m_activeChatsByID removeObjectForKey:[NSNumber numberWithInt:[chat ID]]];
	[m_activeChatsByContact removeObjectForKey:[chat contact]];
}


- (LPChat *)p_prepareNewChatWithContactEntry:(LPContactEntry *)contactEntry ofContact:(LPContact *)contact
{
	NSAssert((contactEntry != nil || contact != nil),
			 @"At least one parameter must be provided.");
	NSAssert((contactEntry == nil || contact == nil || [contactEntry contact] == contact),
			 @"The provided entry doesn't belong to the provided contact.");
	NSAssert(([self chatForContact:contact] == nil),
			 @"A chat with this contact already exists.");
	
	LPContactEntry	*actualEntry = (contactEntry ? contactEntry : [contact mainContactEntry]);
	LPContact		*actualContact = (contact ? contact : [contactEntry contact]);
	
	int initialEntryID = ( actualEntry ? [actualEntry ID] :
						   // There's no JID available for chat.
						   // We're probably just opening a chat to show feedback from a non-chat contact entry.
						   -1 );
	
	NSDictionary *ret = [LFAppController chatStart:[actualContact ID] :initialEntryID];
	
	int			chatID = [[ret objectForKey:@"chat_id"] intValue];
	NSString	*fullJID = [ret objectForKey:@"address"];
	LPChat		*newChat = [LPChat chatWithContact:actualContact entry:actualEntry chatID:chatID JID:fullJID];
	
	[self p_addChat:newChat];
	
	return newChat;
}


//- (LPChat *)p_existingChatOrMakeNewForJID:(NSString *)theJID
//{
//	NSString		*address = [theJID bareJIDComponent];
//	LPContactEntry	*entry = [[self roster] contactEntryForAddress:address];
//	
//	NSAssert1(entry != nil, @"p_existingChatOrMakeNewForJID: JID <%@> isn't in the roster (not even invisible).", theJID);
//	
//	LPContact		*contact = [entry contact];
//	LPChat			*theChat = [self chatForContact:contact];
//	
//	if (theChat == nil) {
//		theChat = [self startChatWithContact:contact];
//		
//		/*
//		 * If we had to create a new chat, then notify the GUI as if it was a new incoming chat. We're
//		 * creating a new chat most probably because there was a need to display something that has
//		 * just arrived from the server to the user. So it is very reasonable to consider it as being
//		 * an incoming chat. It is a chat that is being created to fulfill the need of showing something
//		 * to the user, as opposed to being a chat created/started by a direct user action.
//		 */
//		if (theChat && [m_delegate respondsToSelector:@selector(roster:didReceiveIncomingChat:)]) {
//			[m_delegate roster:self didReceiveIncomingChat:theChat];
//		}
//	}
//	
//	return theChat;
//}


#pragma mark Public


- (LPChat *)startChatWithContact:(LPContact *)contact
{
	return [self startChatWithContactEntry:nil ofContact:contact];
}

- (LPChat *)startChatWithContactEntry:(LPContactEntry *)contactEntry
{
	return [self startChatWithContactEntry:contactEntry ofContact:nil];
}

- (LPChat *)startChatWithContactEntry:(LPContactEntry *)contactEntry ofContact:(LPContact *)contact
{
	// p_prepareNewChatWithContactEntry: will check the consistency of the parameters
	LPChat *newChat = [self p_prepareNewChatWithContactEntry:contactEntry ofContact:contact];
	
	if (newChat != nil && [m_delegate respondsToSelector:@selector(chatsManager:didStartOutgoingChat:)])
		[m_delegate chatsManager:self didStartOutgoingChat:newChat];
	
	return newChat;
}


- (LPChat *)existingChatOrMakeNewWithContact:(LPContact *)contact
{
	LPChat *theChat = [self chatForContact:contact];
	
	if (theChat == nil) {
		theChat = [self p_prepareNewChatWithContactEntry:nil ofContact:contact];
		
		/*
		 * If we had to create a new chat, then notify the GUI as if it was a new incoming chat. We're
		 * creating a new chat most probably because there was a need to display something that has
		 * just arrived from the server to the user. So it is very reasonable to consider it as being
		 * an incoming chat. It is a chat that is being created to fulfill the need of showing something
		 * to the user, as opposed to being a chat created/started by a direct user action.
		 */
		if (theChat != nil && [m_delegate respondsToSelector:@selector(chatsManager:didReceiveIncomingChat:)])
			[m_delegate chatsManager:self didReceiveIncomingChat:theChat];
	}
	
	return theChat;
}

- (LPChat *)chatForID:(int)chatID
{
	LPChat *chat = [m_activeChatsByID objectForKey:[NSNumber numberWithInt:chatID]];
	NSAssert1((chat != nil), @"No LPChat having ID == %d exists", chatID);
	return chat;
}


- (LPChat *)chatForContact:(LPContact *)contact
{
	return [m_activeChatsByContact objectForKey:contact];
}


#warning CHAT: endChat: in LPChatsManager
- (void)endChat:(LPChat *)chat
{
	if ([chat isActive]) {
		[LFAppController chatEnd:[chat ID]];
		[chat handleEndOfChat];
		[self p_removeChat:chat];
	}
}


#pragma mark Bridge Notifications


- (void)leapfrogBridge_chatIncoming:(int)chatID :(int)contactID :(int)entryID :(NSString *)address
{
	LPRoster *roster = [LPRoster roster];
	LPChat *newChat = [LPChat chatWithContact:[roster contactForID:contactID]
										entry:[roster contactEntryForID:entryID]
									   chatID:chatID
										  JID:address];
	[self p_addChat:newChat];
	
	if (newChat != nil && [m_delegate respondsToSelector:@selector(chatsManager:didReceiveIncomingChat:)])
		[m_delegate chatsManager:self didReceiveIncomingChat:newChat];
}


//- (void)leapfrogBridge_chatIncomingPrivate:(int)chatID :(int)groupChatID :(NSString *)nick :(NSString *)address
//{
//	NSLog(@"%@: not implemented yet", NSStringFromSelector(_cmd));
//}


- (void)leapfrogBridge_chatEntryChanged:(int)chatID :(int)entryID
{
	LPChat *chat = [self chatForID:chatID];
	LPContactEntry *entry = [[LPRoster roster] contactEntryForID:entryID];
	
	[chat handleActiveContactEntryChanged:entry];
}


- (void)leapfrogBridge_chatJoined:(int)chatID
{
	NSLog(@"%@: not implemented yet", NSStringFromSelector(_cmd));
}


- (void)leapfrogBridge_chatError:(int)chatID :(NSString *)message
{
	[[self chatForID:chatID] handleReceivedErrorMessage:message];
}


- (void)leapfrogBridge_chatPresence:(int)chatID :(NSString *)nick :(NSString *)status :(NSString *)statusMessage
{
	NSLog(@"%@: not implemented yet", NSStringFromSelector(_cmd));
}


- (void)leapfrogBridge_chatMessageReceived:(int)chatID :(NSString *)nick :(NSString *)subject :(NSString *)plainTextMessage :(NSString *)XHTMLMessage :(NSArray *)URLs
{
	LPChat *chat = [self chatForID:chatID];
	
	LPContactEntry *entry = [chat activeContactEntry];
	[entry handleReceivedMessageActivity];
	
	[[self chatForID:chatID] handleReceivedMessageFromNick:nick
													 subject:subject
											plainTextVariant:plainTextMessage
												XHTMLVariant:XHTMLMessage
														URLs:URLs];
}


- (void)leapfrogBridge_chatAudibleReceived:(int)chatID :(NSString *)audibleResourceName :(NSString *)body :(NSString *)htmlBody
{
	[[self chatForID:chatID] handleReceivedAudibleWithName:audibleResourceName msgBody:body msgHTMLBody:htmlBody];
}


- (void)leapfrogBridge_chatSystemMessageReceived:(int)chatID :(NSString *)plainTextMessage
{
	[[self chatForID:chatID] handleReceivedSystemMessage:plainTextMessage];
}


- (void)leapfrogBridge_chatTopicChanged:(int)chatID :(NSString *)newTopic
{
	NSLog(@"%@: not implemented yet", NSStringFromSelector(_cmd));
}


- (void)leapfrogBridge_chatContactTyping:(int)chatID :(NSString *)nick :(BOOL)isTyping
{
	[[self chatForID:chatID] handleContactTyping:(BOOL)isTyping];
}


#pragma mark -
#pragma mark LPGroupChats (from LPAccount)
#pragma mark Private


- (void)p_addGroupChat:(LPGroupChat *)groupChat
{
	NSAssert(([m_activeGroupChatsByID objectForKey:[NSNumber numberWithInt:[groupChat ID]]] == nil),
			 @"There is already a registered group chat for this ID");
	[m_activeGroupChatsByID setObject:groupChat forKey:[NSNumber numberWithInt:[groupChat ID]]];
	
	NSString				*accountUUID = [[groupChat account] UUID];
	NSMutableDictionary		*groupChatsDict = [m_activeGroupChatsByAccountUUIDAndRoomJID objectForKey:accountUUID];
	if (groupChatsDict == nil) {
		groupChatsDict = [[NSMutableDictionary alloc] init];
		[m_activeGroupChatsByAccountUUIDAndRoomJID setObject:groupChatsDict forKey:accountUUID];
		[groupChatsDict release];
	}
		
	NSAssert(([groupChatsDict objectForKey:[groupChat roomJID]] == nil),
			 @"There is already a registered group chat for this room JID");
	[groupChatsDict setObject:groupChat forKey:[groupChat roomJID]];
}


- (void)p_removeGroupChat:(LPGroupChat *)groupChat
{
	int			groupChatID = [groupChat ID];
	NSString	*accountUUID = [[groupChat account] UUID];
	NSString	*roomJID = [groupChat roomJID];
	
	[m_activeGroupChatsByID removeObjectForKey:[NSNumber numberWithInt:groupChatID]];
	
	NSMutableDictionary *groupChatsDict = [m_activeGroupChatsByAccountUUIDAndRoomJID objectForKey:accountUUID];
	[groupChatsDict removeObjectForKey:roomJID];
	if ([groupChatsDict count] == 0) {
		[m_activeGroupChatsByAccountUUIDAndRoomJID removeObjectForKey:accountUUID];
	}
}


#pragma mark Public


- (LPGroupChat *)startGroupChatWithJID:(NSString *)chatRoomJID nickname:(NSString *)nickname password:(NSString *)password requestHistory:(BOOL)reqHist onAccount:(LPAccount *)account
{
	NSParameterAssert(chatRoomJID);
	NSParameterAssert(account);
	
	NSString *sanitizedNickname = nickname;
	if ([sanitizedNickname length] == 0)
		sanitizedNickname = [account name];
	if ([sanitizedNickname length] == 0)
		sanitizedNickname = [[LPAccountsController sharedAccountsController] name];
	if ([sanitizedNickname length] == 0)
		sanitizedNickname = [account JID];
	
	id ret = [LFAppController groupChatJoin:chatRoomJID
								accountUUID:[account UUID]
									   nick:sanitizedNickname
								   password:password
							 requestHistory:reqHist];
	int groupChatID = [ret intValue];
	
	if (groupChatID >= 0) {
		LPGroupChat *newGroupChat = [LPGroupChat groupChatForRoomWithJID:chatRoomJID
															   onAccount:account
															 groupChatID:groupChatID
																nickname:sanitizedNickname
																password:password];
		[self p_addGroupChat:newGroupChat];
		return newGroupChat;
	}
	else {
		return nil;
	}
}


- (LPGroupChat *)groupChatForID:(int)chatID
{
	LPGroupChat *chat = [m_activeGroupChatsByID objectForKey:[NSNumber numberWithInt:chatID]];
	NSAssert1((chat != nil), @"No LPGroupChat having ID == %d exists", chatID);
	return chat;
}


- (LPGroupChat *)groupChatForRoomJID:(NSString *)roomJID onAccount:(LPAccount *)account
{
	return [[m_activeGroupChatsByAccountUUIDAndRoomJID objectForKey:[account UUID]] objectForKey:roomJID];
}


- (void)endGroupChat:(LPGroupChat *)chat
{
	[LFAppController groupChatEnd:[chat ID]];
}


- (NSArray *)sortedGroupChats
{
	static NSArray *groupChatsSortDescriptors = nil;
	if (groupChatsSortDescriptors == nil) {
		NSSortDescriptor *descr = [[NSSortDescriptor alloc] initWithKey:@"roomName" ascending:YES selector:@selector(caseInsensitiveCompare:)];
		groupChatsSortDescriptors = [[NSArray alloc] initWithObjects:descr, nil];
		[descr release];
	}
	
	return [[m_activeGroupChatsByID allValues] sortedArrayUsingDescriptors:groupChatsSortDescriptors];
}


#pragma mark Bridge Notifications


- (void)leapfrogBridge_groupChatJoined:(int)groupChatID :(NSString *)roomJID :(NSString *)nickname
{
	[[self groupChatForID:groupChatID] handleDidJoinGroupChatWithJID:roomJID nickname:nickname];
}


- (void)leapfrogBridge_groupChatLeft:(int)groupChatID
{
	LPGroupChat *chat = [self groupChatForID:groupChatID];
	if (chat) {
		[chat handleDidLeaveGroupChat];
		[self p_removeGroupChat:chat];
	}
}


- (void)leapfrogBridge_groupChatCreated:(int)groupChatID
{
	[[self groupChatForID:groupChatID] handleDidCreateGroupChat];
}


- (void)leapfrogBridge_groupChatDestroyed:(int)groupChatID :(NSString *)reason :(NSString *)alternateRoomJID
{
	[[self groupChatForID:groupChatID] handleDidDestroyGroupChatWithReason:reason alternateRoomJID:alternateRoomJID];
}


- (void)leapfrogBridge_groupChatContactJoined:(int)groupChatID :(NSString *)nickname :(NSString *)jid :(NSString *)role :(NSString *)affiliation
{
	[[self groupChatForID:groupChatID] handleContactDidJoinGroupChatWithNickname:nickname JID:jid role:role affiliation:affiliation];
}


- (void)leapfrogBridge_groupChatContactRoleOrAffiliationChanged:(int)groupChatID :(NSString *)nickname :(NSString *)role :(NSString *)affiliation
{
	[[self groupChatForID:groupChatID] handleContactWithNickname:nickname didChangeRoleTo:role affiliationTo:affiliation];
}


- (void)leapfrogBridge_groupChatContactStatusChanged:(int)groupChatID :(NSString *)nickname :(NSString *)show :(NSString *)status
{
	[[self groupChatForID:groupChatID] handleContactWithNickname:nickname didChangeStatusTo:LPStatusFromStatusString(show) statusMessageTo:status];
}


- (void)leapfrogBridge_groupChatContactNicknameChanged:(int)groupChatID :(NSString *)old_nickname :(NSString *)new_nickname
{
	[[self groupChatForID:groupChatID] handleContactWithNickname:old_nickname didChangeNicknameFrom:old_nickname to:new_nickname];
}


- (void)leapfrogBridge_groupChatContactBanned:(int)groupChatID :(NSString *)nickname :(NSString *)actor :(NSString *)reason
{
	[[self groupChatForID:groupChatID] handleContactWithNickname:nickname wasBannedBy:actor reason:reason];
}


- (void)leapfrogBridge_groupChatContactKicked:(int)groupChatID :(NSString *)nickname :(NSString *)actor :(NSString *)reason
{
	[[self groupChatForID:groupChatID] handleContactWithNickname:nickname wasKickedBy:actor reason:reason];
}


- (void)leapfrogBridge_groupChatContactRemoved:(int)groupChatID :(NSString *)nickname :(NSString *)dueTo :(NSString *)actor :(NSString *)reason
{
	// dueTo in { "affiliation_change" , "members_only" }
	[[self groupChatForID:groupChatID] handleContactWithNickname:nickname wasRemovedFromChatBy:actor reason:reason dueTo:dueTo];
}


- (void)leapfrogBridge_groupChatContactLeft:(int)groupChatID :(NSString *)nickname :(NSString *)status
{
	[[self groupChatForID:groupChatID] handleContactWithNickname:nickname didLeaveWithStatusMessage:status];
}


- (void)leapfrogBridge_groupChatError:(int)groupChatID :(int)code :(NSString *)msg
{
	LPGroupChat *chat = [self groupChatForID:groupChatID];
	[chat handleGroupChatErrorWithCode:code message:msg];
}


- (void)leapfrogBridge_groupChatTopicChanged:(int)groupChatID :(NSString *)actor :(NSString *)newTopic
{
	[[self groupChatForID:groupChatID] handleTopicChangedTo:newTopic by:actor];
}


- (void)leapfrogBridge_groupChatMessageReceived:(int)groupChatID :(NSString *)fromNickname :(NSString *)plainBody
{
	[[self groupChatForID:groupChatID] handleReceivedMessageFromNickname:fromNickname plainBody:plainBody];
}


- (void)leapfrogBridge_groupChatConfigurationFormReceived:(int)groupChatID :(NSString *)configurationFormXML :(NSString *)errorMsg
{
	[[self groupChatForID:groupChatID] handleReceivedConfigurationForm:configurationFormXML errorMessage:errorMsg];
}

- (void)leapfrogBridge_groupChatConfigurationModificationResult:(int)groupChatID :(BOOL)succeeded :(NSString *)errorMsg
{
	[[self groupChatForID:groupChatID] handleResultOfConfigurationModification:succeeded errorMessage:errorMsg];
}


@end
