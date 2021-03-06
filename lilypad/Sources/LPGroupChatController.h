//
//  LPGroupChatController.h
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jpavao@co.sapo.pt>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

@class LPGroupChat, LPAccount, LPContactEntry;
@class LPChatViewsController;
@class LPColorBackgroundView;
@class LPGrowingTextField;
@class LPGroupChatConfigController;


@interface LPGroupChatParticipantsTableView : NSTableView 
{}
- (NSMenu *)menuForEvent:(NSEvent *)theEvent;
@end


@interface LPGroupChatController : NSWindowController
{
	// IB Stuff
	IBOutlet WebView				*m_chatWebView;
	IBOutlet LPGrowingTextField		*m_inputTextField;
	IBOutlet LPChatViewsController	*m_chatViewsController;
	IBOutlet NSSegmentedControl		*m_segmentedButton;
	IBOutlet LPColorBackgroundView	*m_topControlsBar;
	IBOutlet NSView					*m_inputControlsBar;
	IBOutlet NSSplitView			*m_chatTranscriptSplitView;
	IBOutlet NSTableView			*m_participantsTableView;
	IBOutlet NSArrayController		*m_participantsController;
	IBOutlet NSMenu					*m_participantsListContextMenu;
	
	// Change Topic Sheet
	IBOutlet NSWindow				*m_changeTopicWindow;
	IBOutlet NSTextField			*m_changeTopicTextField;
	
	// Change Nickname Sheet
	IBOutlet NSWindow				*m_changeNicknameWindow;
	IBOutlet NSTextField			*m_changeNicknameTextField;
	
	// Invitation Sheet
	IBOutlet NSWindow				*m_inviteContactWindow;
	IBOutlet NSTextField			*m_inviteContactTextField;
	IBOutlet NSTextField			*m_inviteContactReasonTextField;
	
	// Password prompt
	IBOutlet NSWindow				*m_passwordPromptWindow;
	IBOutlet NSTextField			*m_passwordPromptTextField;
	
	// Nickname Already In Use sheet
	IBOutlet NSWindow				*m_alternateNicknamePromptWindow;
	IBOutlet NSTextField			*m_alternateNicknamePromptLabel;
	IBOutlet NSTextField			*m_alternateNicknamePromptTextField;
	
	IBOutlet NSView					*m_overlayView;
	IBOutlet NSTextField			*m_overlayTitleLabel;
	IBOutlet NSTextField			*m_overlayMessageLabel;
	
	
	id								m_delegate;
	LPGroupChat						*m_groupChat;
	
	// Configuration Sheet
	LPGroupChatConfigController		*m_configController;
	
	NSMutableSet					*m_gaggedContacts;
	
	// Input line history
	NSMutableArray					*m_inputLineHistory;
	int								m_currentInputLineHistoryEntryIndex;
	
	float							m_collapsedHeightWhenLastWentOffline;
	
	NSWindow						*m_overlayWindow;
}

- initWithGroupChat:(LPGroupChat *)groupChat delegate:(id)delegate;

- (LPGroupChat *)groupChat;
- (NSString *)roomJID;

- (IBAction)segmentClicked:(id)sender;
- (IBAction)sendMessage:(id)sender;

- (IBAction)changeTopic:(id)sender;
- (IBAction)changeTopicOKClicked:(id)sender;
- (IBAction)changeNickname:(id)sender;
- (IBAction)changeNicknameOKClicked:(id)sender;
- (IBAction)inviteContact:(id)sender;
- (IBAction)inviteContactOKClicked:(id)sender;
- (IBAction)startPrivateChat:(id)sender;
- (IBAction)configureChatRoom:(id)sender;
- (IBAction)actionSheetCancelClicked:(id)sender;
- (IBAction)passwordPromptOKClicked:(id)sender;
- (IBAction)alternateNicknameOKClicked:(id)sender;

- (IBAction)rejoinChatRoom:(id)sender;

- (IBAction)gagContact:(id)sender;
- (IBAction)ungagContact:(id)sender;
- (IBAction)toggleGagContact:(id)sender;

- (IBAction)saveDocumentTo:(id)sender;
- (IBAction)printDocument:(id)sender;

- (IBAction)showFindPanel:(id)sender;
- (IBAction)findNext:(id)sender;
- (IBAction)findPrevious:(id)sender;
- (IBAction)useSelectionForFind:(id)sender;

@end


@interface NSObject (LPGroupChatControllerDelegate)
- (void)groupChatControllerWindowWillClose:(LPGroupChatController *)groupChatCtrl;
- (void)groupChatController:(LPGroupChatController *)groupChatCtrl openChatWithContactEntry:(LPContactEntry *)contactEntry;
@end
