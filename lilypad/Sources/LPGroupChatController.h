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
@class LPColorBackgroundView;
@class LPGrowingTextField;


@interface LPGroupChatController : NSWindowController
{
	// IB Stuff
	IBOutlet WebView				*m_chatWebView;
	IBOutlet LPGrowingTextField		*m_inputTextField;
	IBOutlet LPChatViewsController	*m_chatViewsController;
	IBOutlet NSSegmentedControl		*m_segmentedButton;
	IBOutlet LPColorBackgroundView	*m_topControlsBar;
	IBOutlet LPColorBackgroundView	*m_inputControlsBar;
	IBOutlet NSSplitView			*m_chatTranscriptSplitView;
	IBOutlet NSTableView			*m_participantsTableView;
	IBOutlet NSArrayController		*m_participantsController;
	
	// Change Topic Sheet
	IBOutlet NSWindow				*m_changeTopicWindow;
	IBOutlet NSTextField			*m_changeTopicTextField;
	
	// Change Nickname Sheet
	IBOutlet NSWindow				*m_changeNicknameWindow;
	IBOutlet NSTextField			*m_changeNicknameTextField;
	
	
	id				m_delegate;
	LPGroupChat		*m_groupChat;
}

- initForJoiningRoomWithJID:(NSString *)roomJID onAccount:(LPAccount *)account nickname:(NSString *)nickname password:(NSString *)password includeChatHistory:(BOOL)includeHistory delegate:(id)delegate;

- (LPGroupChat *)groupChat;
- (NSString *)roomJID;

- (IBAction)segmentClicked:(id)sender;
- (IBAction)sendMessage:(id)sender;

- (IBAction)changeTopic:(id)sender;
- (IBAction)changeTopicOKClicked:(id)sender;
- (IBAction)changeTopicCancelClicked:(id)sender;
- (IBAction)changeNickname:(id)sender;
- (IBAction)changeNicknameOKClicked:(id)sender;
- (IBAction)changeNicknameCancelClicked:(id)sender;

@end


@interface NSObject (LPGroupChatControllerDelegate)
- (void)groupChatControllerWindowWillClose:(LPGroupChatController *)groupChatCtrl;
@end
