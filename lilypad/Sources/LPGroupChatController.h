//
//  LPGroupChatController.h
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import <Cocoa/Cocoa.h>

@class LPGroupChat, LPAccount;


@interface LPGroupChatController : NSWindowController
{
	id				m_delegate;
	LPGroupChat		*m_groupChat;
}

- initForJoiningRoomWithJID:(NSString *)roomJID onAccount:(LPAccount *)account nickname:(NSString *)nickname password:(NSString *)password includeChatHistory:(BOOL)includeHistory delegate:(id)delegate;

- (LPGroupChat *)groupChat;
- (NSString *)roomJID;

@end


@interface NSObject (LPGroupChatControllerDelegate)
- (void)groupChatControllerWindowWillClose:(LPGroupChatController *)groupChatCtrl;
@end
