//
//  LPChatController.h
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
// A subclass of NSWindowController that manages each conversation window.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>


@class LPChat, LPContact, LPContactEntry;
@class LPAudiblesDrawerController, LPChatTextField, LPColorBackgroundView;
@class LPChatJavaScriptInterface, LPChatViewsController, LPChatWebView;
@class CTBadge;
@class LPFileTransfer;
@class LPJIDEntryView;


@interface LPChatController : NSWindowController
{
	IBOutlet LPChatWebView				*m_chatWebView;
	IBOutlet LPChatTextField			*m_inputTextField;
	IBOutlet LPChatViewsController		*m_chatViewsController;
	IBOutlet NSSegmentedControl			*m_segmentedButton;
	IBOutlet NSPopUpButton				*m_addressesPopUp;
	IBOutlet NSImageView				*m_unreadCountImageView;
	IBOutlet LPColorBackgroundView		*m_topControlsBar;
	IBOutlet LPColorBackgroundView		*m_inputControlsBar;
	IBOutlet LPAudiblesDrawerController	*m_audiblesController;
	
	// Pub
	IBOutlet NSView						*m_standardChatElementsView;
	IBOutlet LPColorBackgroundView		*m_pubElementsView;
	IBOutlet WebView					*m_pubBannerWebView;
	
	IBOutlet NSObjectController			*m_chatController;
	IBOutlet NSObjectController			*m_contactController;
	
	// JID Entry Panel
	IBOutlet NSPanel					*m_chooseJIDPanel;
	IBOutlet LPJIDEntryView				*m_chooseJIDPanelJIDEntryView;
	IBOutlet NSButton					*m_chooseJIDPanelOKButton;
	
	
	id									m_delegate;
	
	LPChat				*m_chat;
	LPContact			*m_contact;
	
	BOOL				m_hasAlreadyProcessedSomeMessages;
	float				m_collapsedHeightWhenLastWentOffline;
	BOOL				m_dontMakeKeyOnFirstShowWindow;
	
	// Unread messages
	unsigned int		m_nrUnreadMessages;
	CTBadge				*m_unreadMessagesBadge;
	
	/*
	 * When an audible is not available in local storage yet, we must start to download it. We don't output anything
	 * to the chat window and we keep a reference in the set defined below while we wait for it to finish loading.
	 * When we get notified that an audible has finished loading, we look into this set to know if we were waiting
	 * for it. If we were, we output it to the chat window and remove it from the set.
	 */
	NSMutableSet		*m_audibleResourceNamesWaitingForLoadCompletion;
	
	// Chat History
	BOOL				m_isAutoSavingChatTranscript;
	NSTimer				*m_autoSaveChatTranscriptTimer;
	
	// JavaScript Interface (so that the code in the WebView can invoke ObjC methods in the app)
	LPChatJavaScriptInterface *m_chatJSInterface;
	
	// Input line history
	NSMutableArray		*m_inputLineHistory;
	int					m_currentInputLineHistoryEntryIndex;
}

- initWithDelegate:(id)delegate;
// Designated Initializer
- initWithChat:(LPChat *)chat delegate:(id)delegate isIncoming:(BOOL)incomingFlag;
- initWithIncomingChat:(LPChat *)newChat delegate:(id)delegate;
- initOutgoingWithContact:(LPContact *)contact delegate:(id)delegate;
- initOutgoingWithContactEntry:(LPContactEntry *)contactEntry delegate:(id)delegate;

- (id)delegate;
- (void)setDelegate:(id)delegate;

- (LPChat *)chat;
- (LPContact *)contact;
- (void)setContact:(LPContact *)contact;

- (unsigned int)numberOfUnreadMessages;

- (void)setMessageTextEntryString:(NSString *)messageText;
- (void)sendAudibleWithResourceName:(NSString *)audibleName;
- (void)updateInfoForFileTransfer:(LPFileTransfer *)ft;

- (IBAction)segmentClicked:(id)sender;
- (IBAction)sendMessage:(id)sender;
- (IBAction)sendSMS:(id)sender;
- (IBAction)sendFile:(id)sender;
- (IBAction)editContact:(id)sender;
- (IBAction)selectChatAddress:(id)sender;

- (IBAction)saveDocumentTo:(id)sender;
- (IBAction)printDocument:(id)sender;

- (IBAction)showFindPanel:(id)sender;
- (IBAction)findNext:(id)sender;
- (IBAction)findPrevious:(id)sender;
- (IBAction)useSelectionForFind:(id)sender;

- (IBAction)chooseJIDPanelOK:(id)sender;
- (IBAction)chooseJIDPanelCancel:(id)sender;

@end


@interface NSObject (LPChatControllerDelegate)
- (void)chatController:(LPChatController *)chatCtrl orderChatWithContactEntryToFront:(LPContactEntry *)contactEntry;
- (void)chatController:(LPChatController *)chatCtrl editContact:(LPContact *)contact;
- (void)chatController:(LPChatController *)chatCtrl sendSMSToContact:(LPContact *)contact;
- (void)chatControllerWindowWillClose:(LPChatController *)chatCtrl;
- (void)chatControllerDidReceiveNewMessage:(LPChatController *)chatCtrl;
@end

