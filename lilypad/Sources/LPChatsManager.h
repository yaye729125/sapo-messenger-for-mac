//
//  LPChatsManager.h
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
@class LPChat, LPGroupChat;
@class LPContact, LPContactEntry;


@interface LPChatsManager : NSObject
{
	id						m_delegate;
	
	// From LPAccount
	// To keep track of stuff that comes through the bridge
	NSMutableDictionary		*m_activeChatsByID;				// NSNumber with the chatID --> LPChat
	NSMutableDictionary		*m_activeChatsByContact;		// LPContact --> LPChat
	
	NSMutableDictionary		*m_activeGroupChatsByID;		// NSNumber with the chatID --> LPGroupChat
#warning MUC: Can we remove this dictionary from here? Or should we organize it by account and then by JID?
	NSMutableDictionary		*m_activeGroupChatsByRoomJID;	// NSString with the room JID --> LPGroupChat
}

+ (LPChatsManager *)chatsManager;

- (id)delegate;
- (void)setDelegate:(id)delegate;

// LPChat stuff
- (LPChat *)startChatWithContact:(LPContact *)contact;
- (LPChat *)startChatWithContactEntry:(LPContactEntry *)contactEntry;
- (LPChat *)startChatWithContactEntry:(LPContactEntry *)contactEntry ofContact:(LPContact *)contact;
- (LPChat *)existingChatOrMakeNewWithContact:(LPContact *)contact;
- (LPChat *)chatForID:(int)chatID;
- (LPChat *)chatForContact:(LPContact *)contact;
#warning CHAT: endChat: in LPChatsManager
- (void)endChat:(LPChat *)chat;

// LPGroupChat stuff
- (LPGroupChat *)startGroupChatWithJID:(NSString *)chatRoomJID nickname:(NSString *)nickname password:(NSString *)password requestHistory:(BOOL)reqHist onAccount:(LPAccount *)account;
- (LPGroupChat *)groupChatForID:(int)chatID;
- (LPGroupChat *)groupChatForRoomJID:(NSString *)roomJID;
- (void)endGroupChat:(LPGroupChat *)chat;
- (NSArray *)sortedGroupChats;

@end


@interface NSObject (LPChatsManagerDelegate)
- (void)chatsManager:(LPChatsManager *)manager didReceiveIncomingChat:(LPChat *)newChat;
- (void)chatsManager:(LPChatsManager *)manager didStartOutgoingChat:(LPChat *)newChat;
@end

