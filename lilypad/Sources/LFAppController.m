//
//  LFAppController.m
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Authors: Joao Pavao <jppavao@criticalsoftware.com>
//           Jason Kim <jason@512k.org>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "LFAppController.h"
#import "LFPlatformBridge.h"


// These defines are used to simplify repetitive type translation (using LFBoolean to represent
// BOOLs, etc.).
#define ArgBool(b)          ((b) ? [LFBoolean yes] : [LFBoolean no])
#define ArgInt(i)           ([NSNumber numberWithInt:i])
#define ArgString(s)        ((s != nil) ? s : @"")
#define ArgArray(a)         ((a != nil) ? a : [NSArray array])
#define ArgDictionary(d)    ((d != nil) ? d : [NSDictionary dictionary])
#define ArgData(d)          ((d != nil) ? d : [NSData data])


@implementation LFAppController


#pragma mark -
#pragma mark Application


+ (void)systemQuit
{
	[LFPlatformBridge invokeMethodWithName:@"systemQuit" isOneway:YES arguments:nil];
	[LFPlatformBridge shutdown];
}


+ (void)setClientName:(NSString *)name version:(NSString *)version OSName:(NSString *)OSName capsNode:(NSString *)capsNode capsVersion:(NSString *)capsVersion
{
	[LFPlatformBridge invokeMethodWithName:@"setClientInfo"
								  isOneway:YES
								 arguments:
		ArgString(name), ArgString(version), ArgString(OSName), ArgString(capsNode), ArgString(capsVersion), nil];
}


+ (void)setTimeZoneName:(NSString *)tzName timeZoneOffset:(int)offset
{
	[LFPlatformBridge invokeMethodWithName:@"setTimeZoneInfo"
								  isOneway:YES
								 arguments:ArgString(tzName), ArgInt(offset), nil];
}


+ (void)setSupportDataFolder:(NSString *)pathname
{
	[LFPlatformBridge invokeMethodWithName:@"setSupportDataFolder" isOneway:YES arguments:ArgString(pathname), nil];
}


+ (void)addCapsFeature:(NSString *)feature
{
	[LFPlatformBridge invokeMethodWithName:@"addCapsFeature" isOneway:YES arguments:ArgString(feature), nil];
}


#pragma mark -
#pragma mark Roster


+ (oneway void)rosterStart 
{
	[LFPlatformBridge invokeMethodWithName:@"rosterStart" isOneway:YES arguments:nil];
}


+ (NSArray *)profileList
{
	return [LFPlatformBridge invokeMethodWithName:@"profileList" isOneway:NO arguments:nil];
}


+ (id)rosterGroupAdd:(int)profileId name:(NSString *)groupName pos:(int)position 
{
	return [LFPlatformBridge invokeMethodWithName:@"rosterGroupAdd"
										 isOneway:NO
										arguments:ArgInt(profileId), ArgString(groupName), ArgInt(position), nil];
}


+ (void)rosterGroupRemove:(int)groupId
{
	[LFPlatformBridge invokeMethodWithName:@"rosterGroupRemove"
								  isOneway:YES
								 arguments:ArgInt(groupId), nil];
}


+ (void)rosterGroupRename:(int)groupId name:(NSString *)newName
{
	[LFPlatformBridge invokeMethodWithName:@"rosterGroupRename"
								  isOneway:YES
								 arguments:ArgInt(groupId), ArgString(newName), nil];	
}


+ (void)rosterGroupMove:(int)groupId pos:(int)position
{
	[LFPlatformBridge invokeMethodWithName:@"rosterGroupMove"
								  isOneway:YES
								 arguments:ArgInt(groupId), ArgInt(position), nil];	
}


+ (id)rosterGroupGetProps:(int)groupId
{
	return [LFPlatformBridge invokeMethodWithName:@"rosterGroupGetProps"
										 isOneway:NO
										arguments:ArgInt(groupId), nil];
}


+ (id)rosterContactAdd:(int)groupId name:(NSString *)contactName pos:(int)position
{
	return [LFPlatformBridge invokeMethodWithName:@"rosterContactAdd"
										 isOneway:NO
										arguments:ArgInt(groupId), ArgString(contactName), ArgInt(position), nil];
}


+ (void)rosterContactRemove:(int)contactId
{
	[LFPlatformBridge invokeMethodWithName:@"rosterContactRemove"
								  isOneway:YES
								 arguments:ArgInt(contactId), nil];
}


+ (void)rosterContactRename:(int)contactId name:(NSString *)newName
{
	[LFPlatformBridge invokeMethodWithName:@"rosterContactRename"
								  isOneway:YES
								 arguments:ArgInt(contactId), ArgString(newName), nil];
}


+ (void)rosterContactSetAlt:(int)contactId altName:(NSString *)altName
{
	[LFPlatformBridge invokeMethodWithName:@"rosterContactSetAlt"
								  isOneway:YES
								 arguments:ArgInt(contactId), ArgString(altName), nil];
}


+ (void)rosterContactMove:(int)contactId pos:(int)position
{
	[LFPlatformBridge invokeMethodWithName:@"rosterContactMove"
								  isOneway:YES
								 arguments:ArgInt(contactId), ArgInt(position), nil];
}


+ (void)rosterContactAddGroup:(int)contactId groupId:(int)groupId
{
	[LFPlatformBridge invokeMethodWithName:@"rosterContactAddGroup"
								  isOneway:YES
								 arguments:ArgInt(contactId), ArgInt(groupId), nil];
}


+ (void)rosterContactChangeGroup:(int)contactId origin:(int)oldGroupId destination:(int)newGroupId
{
	[LFPlatformBridge invokeMethodWithName:@"rosterContactChangeGroup"
								  isOneway:YES
								 arguments:ArgInt(contactId), ArgInt(oldGroupId), ArgInt(newGroupId), nil];
}


+ (void)rosterContactRemoveGroup:(int)contactId groupId:(int)groupId
{
	[LFPlatformBridge invokeMethodWithName:@"rosterContactRemoveGroup"
								  isOneway:YES
								 arguments:ArgInt(contactId), ArgInt(groupId), nil];
}


+ (id)rosterContactGetProps:(int)contactId
{
	return [LFPlatformBridge invokeMethodWithName:@"rosterContactGetProps"
										 isOneway:NO
										arguments:ArgInt(contactId), nil];
}


+ (id)rosterEntryAdd:(int)contactId address:(NSString *)addr pos:(int)position
{
	return [LFPlatformBridge invokeMethodWithName:@"rosterEntryAdd"
										 isOneway:NO
										arguments:ArgInt(contactId), /* account ID */ ArgInt(0), ArgString(addr), ArgInt(position), nil];
}

+ (void)rosterEntryRemove:(int)entryId
{
	[LFPlatformBridge invokeMethodWithName:@"rosterEntryRemove" isOneway:YES arguments:ArgInt(entryId), nil];
}

+ (void)rosterEntryChangeContact:(int)entryId origin:(int)oldContactId destination:(int)newContactId
{
	[LFPlatformBridge invokeMethodWithName:@"rosterEntryChangeContact"
								  isOneway:YES
								 arguments:ArgInt(entryId), ArgInt(oldContactId), ArgInt(newContactId), nil];
}

+ (id)rosterEntryGetProps:(int)entryId
{
	return [LFPlatformBridge invokeMethodWithName:@"rosterEntryGetProps"
										 isOneway:NO
										arguments:ArgInt(entryId), nil];
}


+ (id)rosterEntryGetFirstAvailableResource:(int)entry_id
{
	return [LFPlatformBridge invokeMethodWithName:@"rosterEntryGetFirstAvailableResource"
										 isOneway:NO
										arguments:ArgInt(entry_id), nil];
}


+ (id)rosterEntryGetResourceWithCapsFeature:(int)entry_id :(NSString *)feature
{
	return [LFPlatformBridge invokeMethodWithName:@"rosterEntryGetResourceWithCapsFeature"
										 isOneway:NO
										arguments:ArgInt(entry_id), ArgString(feature), nil];
}


+ (id)rosterEntry:(int)entry_id resource:(NSString *)resource hasCapsFeature:(NSString *)feature
{
	return [LFPlatformBridge invokeMethodWithName:@"rosterEntryResourceHasCapsFeature"
										 isOneway:NO
										arguments:ArgInt(entry_id), ArgString(resource), ArgString(feature), nil];
}


+ (id)rosterEntryGetResourceList:(int)entry_id
{
	return [LFPlatformBridge invokeMethodWithName:@"rosterEntryGetResourceList"
										 isOneway:NO
										arguments:ArgInt(entry_id), nil];
}


+ (id)rosterEntryGetResourceProps:(int)entry_id :(NSString *)resource
{
	return [LFPlatformBridge invokeMethodWithName:@"rosterEntryGetResourceProps"
										 isOneway:NO
										arguments:ArgInt(entry_id), ArgString(resource), nil];
}


+ (void)rosterEntryResourceClientInfoGet:(int)entry_id :(NSString *)resource
{
	[LFPlatformBridge invokeMethodWithName:@"rosterEntryResourceClientInfoGet"
								  isOneway:YES
								 arguments:ArgInt(entry_id), ArgString(resource), nil];
}


#pragma mark -
#pragma mark Auth


+ (void)rosterEntryAuthRequest:(int)entry_id
{
	[LFPlatformBridge invokeMethodWithName:@"authRequest" isOneway:YES arguments:ArgInt(entry_id), nil];
}


+ (void)rosterEntryAuthGrant:(int)entry_id
{
	[LFPlatformBridge invokeMethodWithName:@"authGrant" isOneway:YES arguments:ArgInt(entry_id), ArgBool(YES), nil];
}


+ (void)rosterEntryAuthReject:(int)entry_id
{
	[LFPlatformBridge invokeMethodWithName:@"authGrant" isOneway:YES arguments:ArgInt(entry_id), ArgBool(NO), nil];
}


#pragma mark -
#pragma mark Chat


+ (id)chatStart:(int)contactId :(int)entryId
{
	return [LFPlatformBridge invokeMethodWithName:@"chatStart"
										 isOneway:NO
										arguments:ArgInt(contactId), ArgInt(entryId), nil];
}


+ (void)chatChangeEntry:(int)chatId :(int)entryId
{
	[LFPlatformBridge invokeMethodWithName:@"chatChangeEntry"
								  isOneway:YES
								 arguments:ArgInt(chatId), ArgInt(entryId), nil];
}


+ (void)chatEnd:(int)chatId
{
	[LFPlatformBridge invokeMethodWithName:@"chatEnd" isOneway:YES arguments:ArgInt(chatId), nil];			
}


+ (void)chatMessageSend:(int)chatId plain:(NSString *)textMessage xhtml:(NSString *)xhtmlMessage urls:(NSArray *)urls
{
	[LFPlatformBridge invokeMethodWithName:@"chatMessageSend"
								  isOneway:YES
								 arguments:ArgInt(chatId), ArgString(textMessage), ArgString(xhtmlMessage), ArgArray(urls), nil];			
}


+ (void)chatAudibleSend:(int)chatId audibleName:(NSString *)audibleName plainTextAlternative:(NSString *)textMsg HTMLAlternative:(NSString *)HTMLMsg
{
	[LFPlatformBridge invokeMethodWithName:@"chatAudibleSend"
								  isOneway:YES
								 arguments:ArgInt(chatId), ArgString(audibleName), ArgString(textMsg), ArgString(HTMLMsg),
		nil];
}


+ (void)chatTopicSet:(int)chatId topic:(NSString *)topic
{
	[LFPlatformBridge invokeMethodWithName:@"chatTopicSet"
								  isOneway:YES
								 arguments:ArgInt(chatId), ArgString(topic), nil];
}


+ (void)chatUserTyping:(int)chatId isTyping:(BOOL)isTyping
{
	[LFPlatformBridge invokeMethodWithName:@"chatUserTyping"
								  isOneway:YES
								 arguments:ArgInt(chatId), ArgBool(isTyping), nil];
}


#pragma mark -
#pragma mark Group Chat (MUC)


+ (void)fetchChatRoomsListOnHost:(NSString *)host
{
	[LFPlatformBridge invokeMethodWithName:@"fetchChatRoomsListOnHost"
								  isOneway:YES
								 arguments:ArgString(host), nil];
}

+ (void)fetchChatRoomInfo:(NSString *)roomJID
{
	[LFPlatformBridge invokeMethodWithName:@"fetchChatRoomInfo"
								  isOneway:YES
								 arguments:ArgString(roomJID), nil];
}

+ (id)groupChatJoin:(NSString *)roomJID nick:(NSString *)nick password:(NSString *)password requestHistory:(BOOL)reqHist
{
	return [LFPlatformBridge invokeMethodWithName:@"groupChatJoin"
										 isOneway:NO
										arguments:ArgString(roomJID), ArgString(nick), ArgString(password), ArgBool(reqHist), nil];
}


+ (void)groupChatMessageSend:(int)chat_id plain:(NSString *)message
{
	[LFPlatformBridge invokeMethodWithName:@"groupChatSendMessage"
								  isOneway:YES
								 arguments:ArgInt(chat_id), ArgString(message), nil];
}


+ (void)groupChatSetNicknameOnRoom:(int)chat_id to:(NSString *)new_nick
{
	[LFPlatformBridge invokeMethodWithName:@"groupChatChangeNick"
								  isOneway:YES
								 arguments:ArgInt(chat_id), ArgString(new_nick), nil];
}


+ (void)groupChatSetTopicOnRoom:(int)chat_id to:(NSString *)new_topic
{
	[LFPlatformBridge invokeMethodWithName:@"groupChatChangeTopic"
								  isOneway:YES
								 arguments:ArgInt(chat_id), ArgString(new_topic), nil];
}


+ (void)groupChatLeave:(int)chat_id
{
	[LFPlatformBridge invokeMethodWithName:@"groupChatLeave"
								  isOneway:YES
								 arguments:ArgInt(chat_id), nil];
}


+ (void)groupChatInvite:(NSString *)jid :(NSString *)roomJid :(NSString *)reason
{
	[LFPlatformBridge invokeMethodWithName:@"groupChatInvite"
								  isOneway:YES
								 arguments:ArgString(jid), ArgString(roomJid), ArgString(reason), nil];
}


//+ (id)chatStartGroupPrivate:(int)chatId to:(NSString *)nick {}


#pragma mark -
#pragma mark Avatars


+ (void)avatarPublish:(NSData *)avatarData type:(NSString *)type
{
	[LFPlatformBridge invokeMethodWithName:@"avatarPublish"
								  isOneway:YES
								 arguments:ArgString(type), ArgData(avatarData), nil];
}


#pragma mark -
#pragma mark File Transfer


+ (id)fileStartTo:(int)entry_id sourcePath:(NSString *)path description:(NSString *)descr
{
//	return [[LFBridgeHelperOOBFileTransferModule sharedModule] startOutgoingFileTransferToContactWithID:contact_id
//																					 sourceFilePathname:path
//																							description:descr];

	return [LFPlatformBridge invokeMethodWithName:@"fileStart"
										 isOneway:NO
										arguments:ArgInt(entry_id), ArgString(path), ArgString(descr), nil];
}


+ (id)fileCreatePendingTo:(int)entry_id
{
	return [LFPlatformBridge invokeMethodWithName:@"fileCreatePending"
										 isOneway:NO
										arguments:ArgInt(entry_id), nil];
}


+ (void)fileStartPendingID:(int)file_id To:(int)entry_id sourcePath:(NSString *)path description:(NSString *)descr
{
	[LFPlatformBridge invokeMethodWithName:@"fileStartPending"
								  isOneway:YES
								 arguments:ArgInt(file_id), ArgInt(entry_id), ArgString(path), ArgString(descr), nil];
}


+ (void)fileAccept:(int)file_id destinationPath:(NSString *)path
{
//	[[LFBridgeHelperOOBFileTransferModule sharedModule] acceptFileTransferWithID:file_id localDestinationPathname:path];
	
	[LFPlatformBridge invokeMethodWithName:@"fileAccept" isOneway:YES arguments:ArgInt(file_id), ArgString(path), nil];
}


+ (void)fileCancel:(int)file_id
{
//	[[LFBridgeHelperOOBFileTransferModule sharedModule] cancelFileTransferWithID:file_id];

	[LFPlatformBridge invokeMethodWithName:@"fileCancel" isOneway:YES arguments:ArgInt(file_id), nil];
}


+ (id)fileGetProps:(int)file_id
{
//	return [[LFBridgeHelperOOBFileTransferModule sharedModule] propertiesDictionaryForFileTransferWithID:file_id];
	
	return [LFPlatformBridge invokeMethodWithName:@"fileGetProps" isOneway:NO arguments:ArgInt(file_id), nil];
}


#pragma mark -
#pragma mark SMS


+ (void)sendSMSToEntry:(int)entryID :(NSString *)text
{
	[LFPlatformBridge invokeMethodWithName:@"sendSMS" isOneway:YES arguments:ArgInt(entryID), ArgString(text), nil];
}


#pragma mark -
#pragma mark Transport Registration


+ (void)transportRegister:(NSString *)host username:(NSString *)username password:(NSString *)password
{
	[LFPlatformBridge invokeMethodWithName:@"transportRegister"
								  isOneway:YES
								 arguments:ArgString(host), ArgString(username), ArgString(password), nil];
}

+ (void)transportUnregister:(NSString *)host
{
	[LFPlatformBridge invokeMethodWithName:@"transportUnregister" isOneway:YES arguments:ArgString(host), nil];
}


// OLD ONES //////////////////////////////////////////////////////////////////////


#pragma mark -
#pragma mark Proxy Methods


+ (oneway void)sendMessage:(NSString *)jid_to body:(NSString *)body {
	[LFPlatformBridge invokeMethodWithName:@"sendMessage"
								  isOneway:YES
								 arguments:ArgString(jid_to), ArgString(body), nil];
}


+ (oneway void)setAccountJID:(NSString *)jid host:(NSString *)host password:(NSString *)pass resource:(NSString *)resource useSSL:(BOOL)flag
{
	[LFPlatformBridge invokeMethodWithName:@"setAccount"
								  isOneway:YES
								 arguments:ArgString(jid), ArgString(host), ArgString(pass), ArgString(resource), ArgBool(flag), nil];
}

+ (oneway void)rosterRemoveContact:(NSString *)jid 
{
	[LFPlatformBridge invokeMethodWithName:@"rosterRemoveContact" isOneway:YES arguments:ArgString(jid), nil];
}


+ (oneway void)rosterGrantAuth:(NSString *)jid
{
	[LFPlatformBridge invokeMethodWithName:@"rosterGrantAuth" isOneway:YES arguments:ArgString(jid), nil];
}


#pragma mark -


+ (oneway void)accountSendXml:(int)accountID :(NSString *)xml
{
	[LFPlatformBridge invokeMethodWithName:@"accountSendXml"
								  isOneway:YES
								 arguments:ArgInt(accountID), ArgString(xml), nil];
}


+ (void)setCustomDataTransferProxy:(NSString *)proxy
{
	[LFPlatformBridge invokeMethodWithName:@"setCustomDataTransferProxy" isOneway:YES arguments:ArgString(proxy), nil];
}


#pragma mark -
// TEMP. The following are subject to change.


+ (oneway void)setStatus:(NSString *)status message:(NSString *)message saveToServer:(BOOL)saveFlag
{
	[LFPlatformBridge invokeMethodWithName:@"setStatus"
								  isOneway:YES
								 arguments:ArgString(status), ArgString(message), ArgBool(saveFlag), nil];
}


+ (oneway void)rosterAddContact:(NSString *)jid name:(NSString *)name group:(NSString *)group
{
	[LFPlatformBridge invokeMethodWithName:@"rosterAddContact"
								  isOneway:YES
								 arguments:ArgString(jid), ArgString(name), ArgString(group), nil];
}


+ (oneway void)rosterUpdateContact:(NSString *)jid name:(NSString *)name group:(NSString *)group 
{
	[LFPlatformBridge invokeMethodWithName:@"rosterUpdateContact"
								  isOneway:YES
								 arguments:ArgString(jid), ArgString(name), ArgString(group), nil];
}


+ (oneway void)groupchatJoin:(NSString *)roomjid
{
	[LFPlatformBridge invokeMethodWithName:@"groupchatJoin" isOneway:YES arguments:ArgString(roomjid), nil];	
}


+ (oneway void)groupchatSendMessage:(NSString *)roomjid body:(NSString *)body
{
	[LFPlatformBridge invokeMethodWithName:@"groupchatSendMessage"
								  isOneway:YES
								 arguments:ArgString(roomjid), ArgString(body), nil];	
}


@end
