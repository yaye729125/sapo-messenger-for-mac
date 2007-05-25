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
#import <WebKit/WebKit.h>

@class LPGroupChat, LPAccount;
@class LPChatViewsController;


@interface LPGroupChatController : NSWindowController
{
	IBOutlet LPChatViewsController	*m_chatViewsController;
	IBOutlet WebView				*m_chatWebView;
	IBOutlet NSTextField			*m_inputTextField;
	
	id				m_delegate;
	LPGroupChat		*m_groupChat;
}

- initForJoiningRoomWithJID:(NSString *)roomJID onAccount:(LPAccount *)account nickname:(NSString *)nickname password:(NSString *)password includeChatHistory:(BOOL)includeHistory delegate:(id)delegate;

- (LPGroupChat *)groupChat;
- (NSString *)roomJID;

- (IBAction)sendMessage:(id)sender;

@end


@interface NSObject (LPGroupChatControllerDelegate)
- (void)groupChatControllerWindowWillClose:(LPGroupChatController *)groupChatCtrl;
@end
