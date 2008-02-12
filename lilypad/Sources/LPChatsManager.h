//
//  LPChatsManager.h
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jpavao@co.sapo.pt>
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
	
	NSMutableDictionary		*m_activeGroupChatsByID;					// NSNumber with the chatID --> LPGroupChat
	NSMutableDictionary		*m_activeGroupChatsByAccountUUIDAndRoomJID;	// NSString with the account UUID -->
																		//    --> NSMutableDictionary with room JID NSStrings as keys -->
																		//    --> LPGroupChat
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
- (LPGroupChat *)groupChatForRoomJID:(NSString *)roomJID onAccount:(LPAccount *)account;
- (void)endGroupChat:(LPGroupChat *)chat;
- (NSArray *)sortedGroupChats;

@end


@interface NSObject (LPChatsManagerDelegate)
- (void)chatsManager:(LPChatsManager *)manager didReceiveIncomingChat:(LPChat *)newChat;
- (void)chatsManager:(LPChatsManager *)manager didStartOutgoingChat:(LPChat *)newChat;
@end

