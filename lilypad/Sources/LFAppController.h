//
//  LFAppController.h
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Authors: Joao Pavao <jppavao@criticalsoftware.com>
//           Jason Kim <jason@512k.org>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//
//
// LFAppController is the Objective-C class that represents the Leapfrog core application 
// (i.e. the Qt side). All Mac-specific classes call methods on this class, which are then 
// transformed into the appropriate function calls and passed along.
//
// Notes:
// Initially, we had planned on using NSObject's forwardInvocation mechanism to dynamically
// wrap invocations and serialize them into our custom format, which meant that LFAppController
// itself wouldn't actually have to implement any methods at all. Each "failed" method call could
// dynamically get trapped, serialized as appropriate, then invoked. However, for both the sanity
// of code completion in the IDE and compile-time safety, it turns out to be nicer if we
// just write a bunch of simple method wrappers. 
//
// In the future, these wrappers could be generated, rather than hand-written; none of them
// currently contain any specialized code, nor should they ever. This is simply our mechanism
// to glue the Objective-C code to the Qt core via the C invocation functions.
//

#import <Cocoa/Cocoa.h>


@interface LFAppController : NSObject 

// Application
+ (void)systemQuit;
+ (void)setClientName:(NSString *)name version:(NSString *)version OSName:(NSString *)OSName capsNode:(NSString *)capsNode capsVersion:(NSString *)capsVersion;
+ (void)setTimeZoneName:(NSString *)tzName timeZoneOffset:(int)offset;
+ (void)setSupportDataFolder:(NSString *)pathname;
+ (void)addCapsFeature:(NSString *)feature;

// Roster
+ (void)rosterStart;
+ (NSArray *)profileList;

// Roster Groups
+ (id)rosterGroupAdd:(int)profileId name:(NSString *)groupName pos:(int)position;
+ (void)rosterGroupRemove:(int)groupId;
+ (void)rosterGroupRename:(int)groupId name:(NSString *)newName;
+ (void)rosterGroupMove:(int)groupId pos:(int)position;
+ (id)rosterGroupGetProps:(int)groupId;

// Roster Contacts
+ (id)rosterContactAdd:(int)groupId name:(NSString *)contactName pos:(int)position;
+ (void)rosterContactRemove:(int)contactId;
+ (void)rosterContactRename:(int)contactId name:(NSString *)newName;
+ (void)rosterContactSetAlt:(int)contactId altName:(NSString *)altName;
+ (void)rosterContactMove:(int)contactId pos:(int)position;
+ (void)rosterContactAddGroup:(int)contactId groupId:(int)groupId;
+ (void)rosterContactChangeGroup:(int)contactId origin:(int)oldGroupId destination:(int)newGroupId;
+ (void)rosterContactRemoveGroup:(int)contactId groupId:(int)groupId;
+ (id)rosterContactGetProps:(int)contactId;

// Roster Contact Entries
+ (id)rosterEntryAdd:(int)contactId address:(NSString *)addr pos:(int)position;
+ (void)rosterEntryRemove:(int)entryId;
+ (void)rosterEntryChangeContact:(int)entryId origin:(int)oldContactId destination:(int)newContactId;
+ (id)rosterEntryGetProps:(int)entryId;

// Roster Contact Entries Resources
+ (id)rosterEntryGetFirstAvailableResource:(int)entry_id;
+ (id)rosterEntryGetResourceWithCapsFeature:(int)entry_id :(NSString *)feature;
+ (id)rosterEntry:(int)entry_id resource:(NSString *)resource hasCapsFeature:(NSString *)feature;
+ (id)rosterEntryGetResourceList:(int)entry_id;
+ (id)rosterEntryGetResourceProps:(int)entry_id :(NSString *)resource;
+ (void)rosterEntryResourceClientInfoGet:(int)entry_id :(NSString *)resource;

// Auth
+ (void)rosterEntryAuthRequest:(int)entry_id;
+ (void)rosterEntryAuthGrant:(int)entry_id;
+ (void)rosterEntryAuthReject:(int)entry_id;

// Chat
+ (id)chatStart:(int)contactId :(int)entryId;
+ (void)chatChangeEntry:(int)chatId :(int)entryId;
+ (void)chatEnd:(int)chatId;
+ (void)chatMessageSend:(int)chatId plain:(NSString *)textMessage xhtml:(NSString *)xhtmlMessage urls:(NSArray *)urls;
+ (void)chatAudibleSend:(int)chatId audibleName:(NSString *)audibleName plainTextAlternative:(NSString *)textMsg HTMLAlternative:(NSString *)HTMLMsg;
+ (void)chatTopicSet:(int)chatId topic:(NSString *)topic;
+ (void)chatUserTyping:(int)chatId isTyping:(BOOL)isTyping;

// Group-Chat (MUC)
+ (void)fetchChatRoomsListOnHost:(NSString *)host;
+ (void)fetchChatRoomInfo:(NSString *)roomJID;
+ (id)groupChatJoin:(NSString *)room nick:(NSString *)nick password:(NSString *)password requestHistory:(BOOL)reqHist;
+ (void)groupChatMessageSend:(int)chat_id plain:(NSString *)message;
+ (void)groupChatSetNicknameOnRoom:(int)chat_id to:(NSString *)new_nick;
+ (void)groupChatSetTopicOnRoom:(int)chat_id to:(NSString *)new_topic;
+ (void)groupChatLeave:(int)chat_id;
+ (void)groupChatInvite:(NSString *)jid :(NSString *)roomJid :(NSString *)reason;
//+ (id)chatStartGroupPrivate:(int)chatId to:(NSString *)nick;


// Avatars
+ (void)avatarPublish:(NSData *)avatarData type:(NSString *)type;

// File Transfer
+ (id)fileStartTo:(int)entry_id sourcePath:(NSString *)path description:(NSString *)descr;
+ (id)fileCreatePendingTo:(int)entry_id;
+ (void)fileStartPendingID:(int)file_id To:(int)entry_id sourcePath:(NSString *)path description:(NSString *)descr;
+ (void)fileAccept:(int)file_id destinationPath:(NSString *)path;
+ (void)fileCancel:(int)file_id;
+ (id)fileGetProps:(int)file_id;

// SMS
+ (void)sendSMSToEntry:(int)entryID :(NSString *)text;

// Transport Registration
+ (void)transportRegister:(NSString *)host username:(NSString *)username password:(NSString *)password;
+ (void)transportUnregister:(NSString *)host;

// OLD
+ (oneway void)sendMessage:(NSString *)jid_to body:(NSString *)body;
+ (oneway void)setAccountJID:(NSString *)jid host:(NSString *)host password:(NSString *)pass resource:(NSString *)resource useSSL:(BOOL)flag;
+ (oneway void)rosterRemoveContact:(NSString *)jid;
+ (oneway void)rosterGrantAuth:(NSString *)jid;

// Accounts
+ (oneway void)accountSendXml:(int)accountID :(NSString *)xml;
+ (void)setCustomDataTransferProxy:(NSString *)proxy;

// TEMP. The following are subject to change.
+ (oneway void)setStatus:(NSString *)status message:(NSString *)message saveToServer:(BOOL)saveFlag;
+ (oneway void)rosterAddContact:(NSString *)jid name:(NSString *)name group:(NSString *)group;
+ (oneway void)rosterUpdateContact:(NSString *)jid name:(NSString *)name group:(NSString *)group;
+ (oneway void)groupchatJoin:(NSString *)roomjid;
+ (oneway void)groupchatSendMessage:(NSString *)roomjid body:(NSString *)body;
@end
