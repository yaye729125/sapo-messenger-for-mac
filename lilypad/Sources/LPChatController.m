//
//  LPChatController.m
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Authors: Joao Pavao <jpavao@co.sapo.pt>
//           Jason Kim <jason@512k.org>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "LPChatController.h"

#import "LPCommon.h"
#import "LPAccount.h"
#import "LPRoster.h"
#import "LPContact.h"
#import "LPContactEntry.h"
#import "LPChat.h"
#import "LPChatsManager.h"
#import "LPFileTransfersManager.h"

#import "NSString+HTMLAdditions.h"
#import "LPChatWebView.h"
#import "LPChatTextField.h"
#import "LPChatViewsController.h"
#import "LPColorBackgroundView.h"
#import "NSxString+EmoticonAdditions.h"
#import "LPAccountsController.h"
#import "LPAudiblesDrawerController.h"
#import "LPAudibleSet.h"
#import "LPChatJavaScriptInterface.h"
#import "LPPubManager.h"
#import "LPEventNotificationsHandler.h"
#import "CTBadge.h"
#import "LPRecentMessagesStore.h"
#import "LPFileTransfer.h"

#import "LPJIDEntryView.h"
#import "LPSapoAgents+MenuAdditions.h"

#import <AddressBook/AddressBook.h>


#define INPUT_LINE_HISTORY_ITEMS_MAX	10


// Toolbar item identifiers
static NSString *ToolbarInfoIdentifier				= @"ToolbarInfoIdentifier";
static NSString *ToolbarFileSendIdentifier			= @"ToolbarFileSendIdentifier";
static NSString *ToolbarSendSMSIdentifier			= @"ToolbarSendSMSIdentifier";
static NSString *ToolbarHistoryIdentifier			= @"ToolbarHistoryIdentifier";


@interface LPChatController ()  // Private Methods
- (void)p_syncChatOwnerName;
- (void)p_syncViewsWithContact;

- (void)p_setChat:(LPChat *)chat;

- (NSAttributedString *)p_attributedTitleOfJIDMenuItemForContactEntry:(LPContactEntry *)entry withFont:(NSFont *)font;
- (NSMenuItem *)p_popupMenuHeaderItemForAccount:(LPAccount *)account;
- (NSMenuItem *)p_popupMenuItemForEntry:(LPContactEntry *)entry;
- (void)p_moveJIDMenuItem:(NSMenuItem *)menuItem toIndex:(int)targetIndex inMenu:(NSMenu *)menu;
- (void)p_syncJIDsPopupMenu;

- (void)p_setSendFieldHidden:(BOOL)hiddenFlag animate:(BOOL)animateFlag;
- (void)p_fixResizeIndicator;

- (NSMutableSet *)p_pendingAudiblesSet;
- (void)p_appendStandardMessageBlockWithInnerHTML:(NSString *)innerHTML timestamp:(NSDate *)timestamp inbound:(BOOL)isInbound saveInHistory:(BOOL)shouldSave scrollMode:(LPScrollToVisibleMode)scrollMode;

- (void)p_appendMessageToWebView:(NSString *)message subject:(NSString *)subject timestamp:(NSDate *)timestamp inbound:(BOOL)isInbound;
- (void)p_appendAudibleWithResourceName:(NSString *)resourceName inbound:(BOOL)inbound;
- (void)p_appendStoredRecentMessagesToWebView;

- (void)p_resizeInputFieldToContentsSize:(NSSize)newSize;
- (void)p_updateChatBackgroundColorFromDefaults;
- (void)p_setupToolbar;

- (void)p_setupChatDocumentTitle;

- (void)p_setSaveChatTranscriptEnabled:(BOOL)flag;

- (void)p_checkIfPubBannerIsNeeded;

- (void)p_incrementUnreadMessagesCount;
- (void)p_resetUnreadMessagesCount;
- (void)p_updateMiniwindowImage;
- (void)p_notifyUserAboutReceivedMessage:(NSString *)msgText notificationsHandlerSelector:(SEL)selector;

- (void)p_reevaluateJIDPanelOKButtonEnabled;
@end


#pragma mark -


@implementation LPChatController

+ (void)initialize
{
	if (self == [LPChatController class]) {
		[self setKeys:[NSArray arrayWithObject:@"numberOfUnreadMessages"]
				triggerChangeNotificationsForDependentKey:@"windowTitleSuffix"];
	}
}


- initWithDelegate:(id)delegate
{
	return [self initWithChat:nil delegate:delegate isIncoming:NO];
}


// Designated Initializer
- initWithChat:(LPChat *)chat delegate:(id)delegate isIncoming:(BOOL)incomingFlag
{
	if (self = [self initWithWindowNibName:@"Chat"]) {
		[self p_setChat:chat];
		[self setContact:[chat contact]];
		
		[self setDelegate:delegate];
		
		m_collapsedHeightWhenLastWentOffline = 0.0;
		
		// Setup KVO
		NSUserDefaultsController	*prefsCtrl = [NSUserDefaultsController sharedUserDefaultsController];
		
		[prefsCtrl addObserver:self forKeyPath:@"values.ChatBackgroundColor" options:0 context:NULL];
		[prefsCtrl addObserver:self forKeyPath:@"values.DisplayEmoticonImages" options:0 context:NULL];
		
		
		NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
		LPAudibleSet *as = [LPAudibleSet defaultAudibleSet];
		[nc addObserver:self
			   selector:@selector(audibleSetDidFinishLoadingAudible:)
				   name:LPAudibleSetAudibleDidFinishLoadingNotification
				 object:as];
		[nc addObserver:self
			   selector:@selector(audibleSetDidFinishLoadingAudible:)
				   name:LPAudibleSetAudibleDidFailLoadingNotification
				 object:as];
		
		// File Transfers status messages
		[nc addObserver:self
			   selector:@selector(fileTransferStateDidChange:)
				   name:LPFileTransferDidChangeStateNotification
				 object:nil];
		
		// Chat History
		[prefsCtrl addObserver:self forKeyPath:@"values.SaveChatTranscripts" options:0 context:NULL];
		[self p_setSaveChatTranscriptEnabled:[[prefsCtrl valueForKeyPath:@"values.SaveChatTranscripts"] boolValue]];
		
		// Input line history
		m_inputLineHistory = [[NSMutableArray alloc] init];
		
		LPAccountsController *accountsController = [LPAccountsController sharedAccountsController];
		[accountsController addObserver:self forKeyPath:@"name" options:0 context:NULL];
		[accountsController addObserver:self forKeyPath:@"online" options:0 context:NULL];
		
		m_dontMakeKeyOnFirstShowWindow = incomingFlag;
	}
	
	return self;
}


- initWithIncomingChat:(LPChat *)newChat delegate:(id)delegate
{
	return [self initWithChat:newChat delegate:delegate isIncoming:YES];
}


- initOutgoingWithContact:(LPContact *)contact delegate:(id)delegate
{
	LPChat *newChat = [[LPChatsManager chatsManager] startChatWithContact:contact];
	
	if (newChat) {
		self = [self initWithChat:newChat delegate:delegate isIncoming:NO];
	}
	else {
		[self release];
		self = nil;
	}
	return self;
}


- initOutgoingWithContactEntry:(LPContactEntry *)contactEntry delegate:(id)delegate
{
	LPChat *newChat = [[LPChatsManager chatsManager] startChatWithContactEntry:contactEntry];
	
	if (newChat) {
		self = [self initWithChat:newChat delegate:delegate isIncoming:NO];
	}
	else {
		[self release];
		self = nil;
	}
	return self;
}


- (void)dealloc
{
	NSUserDefaultsController *prefsCtrl = [NSUserDefaultsController sharedUserDefaultsController];
	[prefsCtrl removeObserver:self forKeyPath:@"values.ChatBackgroundColor"];
	[prefsCtrl removeObserver:self forKeyPath:@"values.DisplayEmoticonImages"];
	[prefsCtrl removeObserver:self forKeyPath:@"values.SaveChatTranscripts"];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	LPAccountsController *accountsController = [LPAccountsController sharedAccountsController];
	[accountsController removeObserver:self forKeyPath:@"name"];
	[accountsController removeObserver:self forKeyPath:@"online"];
	
	[self p_setChat:nil];
	[self setContact:nil];
	[self setDelegate:nil];
	
	[m_inputLineHistory release];
	
	[m_autoSaveChatTranscriptTimer invalidate];
	[m_autoSaveChatTranscriptTimer release];
	
	[m_unreadMessagesBadge release];
	
	[m_audibleResourceNamesWaitingForLoadCompletion release];
	[m_chatJSInterface release];
	[super dealloc];
}


- (void)p_syncChatOwnerName
{
	
	NSString	*currentOwnerName = [m_chatViewsController ownerName];
	NSString	*globalName = [[LPAccountsController sharedAccountsController] name];
	NSString	*newOwnerName = ( [globalName length] > 0 ?
								  globalName :
								  [[[m_chat activeContactEntry] account] JID] );
	
	if (![currentOwnerName isEqualToString:newOwnerName])
		[m_chatViewsController setOwnerName:newOwnerName];
}


- (void)p_syncViewsWithContact
{
	if ([self isWindowLoaded]) {
		[m_chatController setContent:[self chat]];
		[m_contactController setContent:[self contact]];
		
		[m_chatWebView setChat:m_chat];
		[self p_syncChatOwnerName];
		
		[m_topControlsBar setBackgroundColor:
			[NSColor colorWithPatternImage:( [[m_chat activeContactEntry] isOnline] ?
											 [NSImage imageNamed:@"chatIDBackground"] :
											 [NSImage imageNamed:@"chatIDBackground_Offline"] )]];
		
		// Update the addresses popup
		[self p_syncJIDsPopupMenu];
		[m_addressesPopUp setEnabled:([[m_contact chatContactEntries] count] > 0)];
		
		[self p_setSendFieldHidden:(![[[[self chat] activeContactEntry] account] isOnline] || [[self chat] activeContactEntry] == nil) animate:YES];
		[self p_updateMiniwindowImage];
		
		// Make sure the toolbar items are correctly enabled/disabled
		[[self window] update];
	}
}


- (void)windowDidLoad
{
	[self p_setupToolbar];
	
	[m_audiblesController setChatController:self];
	
	// Workaround for centering the icons.
	[m_segmentedButton setLabel:nil forSegment:0];
	[m_segmentedButton setLabel:nil forSegment:1];
	[[m_segmentedButton cell] setToolTip:NSLocalizedString(@"Choose Emoticon", @"") forSegment:0];
	[[m_segmentedButton cell] setToolTip:NSLocalizedString(@"Toggle Audibles Drawer", @"") forSegment:1];
	// IB displays a round segmented button that apparently needs less space than the on that ends up
	// showing in the app (the flat segmented button used in metal windows).
	[m_segmentedButton sizeToFit];
	
	[m_topControlsBar setBorderColor:[NSColor colorWithCalibratedWhite:0.60 alpha:1.0]];
	
	
	[m_pubElementsView setShadedBackgroundWithOrientation:LPVerticalBackgroundShading
											 minEdgeColor:[NSColor colorWithCalibratedWhite:0.79 alpha:1.0]
											 maxEdgeColor:[NSColor colorWithCalibratedWhite:0.49 alpha:1.0]];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(p_JIDsMenuWillPop:)
												 name:NSPopUpButtonWillPopUpNotification
											   object:m_addressesPopUp];
	
	[m_addressesPopUp setAutoenablesItems:NO];
	[self p_syncViewsWithContact];
	
	// Post the saved recent messages
	[self p_appendStoredRecentMessagesToWebView];
	
	if ([m_chat activeContactEntry]) {
		// Post a "system message" to start
		NSString *initialSystemMessage = nil;
		
		if ([[[LPAccountsController sharedAccountsController] accounts] count] > 1) {
			initialSystemMessage = [NSString stringWithFormat:NSLocalizedString(@"Chat started with contact \"%@\" thru account \"%@\"",
																				@"status message written to the text transcript of a chat window"),
				[[m_chat activeContactEntry] humanReadableAddress],
				[[[m_chat activeContactEntry] account] description]];
		}
		else {
			initialSystemMessage = [NSString stringWithFormat:NSLocalizedString(@"Chat started with contact \"%@\"",
																				@"status message written to the text transcript of a chat window"),
				[[m_chat activeContactEntry] humanReadableAddress]];
		}
		
		[m_chatViewsController appendDIVBlockToWebViewWithInnerHTML:[initialSystemMessage stringByEscapingHTMLEntities]
														   divClass:@"systemMessage"
												scrollToVisibleMode:LPScrollWithJump];
	}
}


- (void)showWindow:(id)sender
{
	if (m_contact == nil) {
		NSWindow *win = [self window];
		BOOL wasVisible = [win isVisible];
		
		[super showWindow:sender];
		
		if (!wasVisible) {
			[self p_reevaluateJIDPanelOKButtonEnabled];
			[m_chooseJIDPanelJIDEntryView addObserver:self forKeyPath:@"account.online" options:0 context:NULL];
			
			[NSApp beginSheet:m_chooseJIDPanel modalForWindow:win modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
		}
	}
	else if (![self isWindowLoaded] && m_dontMakeKeyOnFirstShowWindow) {
		NSWindow *win = [self window];
		
		// Make it float above all other windows until it gains focus for the first time.
		// The level is restored to the normal value on -windowDidBecomeKey:
		[win setLevel:NSFloatingWindowLevel];
		[win setAlphaValue:0.90];
		[win orderFront:sender];
	}
	else {
		[super showWindow:sender];
	}
}


- (id)delegate
{
	return m_delegate;
}

- (void)setDelegate:(id)delegate
{
	m_delegate = delegate;
}


- (LPChat *)chat
{
	return [[m_chat retain] autorelease];
}


- (void)p_setChat:(LPChat *)chat
{
	if (m_chat != chat) {
		[m_chat endChat];
		
		[self willChangeValueForKey:@"chat"];
		
		[m_chat removeObserver:self forKeyPath:@"activeContactEntry.account.online"];
		[m_chat removeObserver:self forKeyPath:@"activeContactEntry.online"];
		[m_chat removeObserver:self forKeyPath:@"activeContactEntry"];
		
		[m_chat release];
		m_chat = [chat retain];
		[chat setDelegate:self];
		
		[m_chat addObserver:self forKeyPath:@"activeContactEntry" options:0 context:NULL];
		[m_chat addObserver:self forKeyPath:@"activeContactEntry.online" options:0 context:NULL];
		[m_chat addObserver:self forKeyPath:@"activeContactEntry.account.online" options:0 context:NULL];
		
		// Post a "system message" to start
		NSString *systemMessage;
		if ([m_chat activeContactEntry]) {
			if ([[[LPAccountsController sharedAccountsController] accounts] count] > 1) {
				systemMessage = [NSString stringWithFormat:NSLocalizedString(@"Chat changed to contact \"%@\" thru account \"%@\"",
																			 @"status message written to the text transcript of a chat window"),
					[[m_chat activeContactEntry] humanReadableAddress],
					[[[m_chat activeContactEntry] account] description]];
			}
			else {
				systemMessage = [NSString stringWithFormat:NSLocalizedString(@"Chat changed to contact \"%@\"",
																			 @"status message written to the text transcript of a chat window"),
					[[m_chat activeContactEntry] humanReadableAddress]];
			}
		}
		else {
			systemMessage = [NSString stringWithFormat:NSLocalizedString(@"Chat ended.", @"status message written to the text transcript of a chat window")];
		}
		[m_chatViewsController appendDIVBlockToWebViewWithInnerHTML:[systemMessage stringByEscapingHTMLEntities]
														   divClass:@"systemMessage"
												scrollToVisibleMode:LPScrollWithAnimationIfAtBottom];
		
		[m_chatJSInterface setAccount:[[m_chat activeContactEntry] account]];
		
		[self didChangeValueForKey:@"chat"];
	}
}


- (LPContact *)contact
{
    return [[m_contact retain] autorelease]; 
}


- (void)setContact:(LPContact *)contact
{
	if (m_contact != contact) {
		BOOL hadContact = (m_contact != nil);
		
		[m_contact removeObserver:self forKeyPath:@"avatar"];
		[m_contact removeObserver:self forKeyPath:@"chatContactEntries"];
		[m_contact removeObserver:self forKeyPath:@"contactEntries"];
		
		[m_contact release];
		m_contact = [contact retain];
		
		[m_contact addObserver:self forKeyPath:@"contactEntries" options:0 context:NULL];
		[m_contact addObserver:self forKeyPath:@"chatContactEntries" options:0 context:NULL];
		[m_contact addObserver:self forKeyPath:@"avatar" options:0 context:NULL];
		
		[self p_syncViewsWithContact];
		if (!hadContact)
			[self p_setupChatDocumentTitle];
		
		if (contact != nil) {
			// Show the PUB banner only for contacts with the corresponding capability.
			// Check only some seconds from now so that the core has time to fetch the capabilities of the contact.
			[self performSelector:@selector(p_checkIfPubBannerIsNeeded) withObject:nil afterDelay:3.0];
		}
		else {
			// Make sure that the delayed perform of p_checkIfPubBannerIsNeeded doesn't fire
			[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(p_checkIfPubBannerIsNeeded) object:nil];
		}
	}
}


- (unsigned int)numberOfUnreadMessages
{
	return m_nrUnreadMessages;
}


- (NSString *)windowTitleSuffix
{
	return (m_nrUnreadMessages > 0 ?
			[NSString stringWithFormat:NSLocalizedString(@" (%d unread)", @"chat window title suffix"), m_nrUnreadMessages] :
			@"");
}


- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ([keyPath isEqualToString:@"values.ChatBackgroundColor"]) {
		[self p_updateChatBackgroundColorFromDefaults];
	}
	else if ([keyPath isEqualToString:@"values.DisplayEmoticonImages"]) {
		BOOL displayImages = [[object valueForKeyPath:keyPath] boolValue];
		[m_chatViewsController showEmoticonsAsImages:displayImages];
	}
	else if ([keyPath isEqualToString:@"values.SaveChatTranscripts"]) {
		NSUserDefaultsController *prefsCtrl = [NSUserDefaultsController sharedUserDefaultsController];
		[self p_setSaveChatTranscriptEnabled:[[prefsCtrl valueForKeyPath:@"values.SaveChatTranscripts"] boolValue]];
	}
	else if ([keyPath isEqualToString:@"online"]) {
		// [LPAccountsController sharedAccountsController] online status
		[[self window] update];
	}
	else if ([keyPath isEqualToString:@"name"]) {
		// [LPAccountsController sharedAccountsController] name
		[self p_syncChatOwnerName];
	}
	else if ([keyPath isEqualToString:@"contactEntries"]) {
		// Check whether all JIDs have been removed.
		if ([[m_contact contactEntries] count] == 0) {
			[self performSelector:@selector(close) withObject:nil afterDelay:0.0];
		}
	}
	else if ([keyPath isEqualToString:@"chatContactEntries"]) {
		[self p_syncJIDsPopupMenu];
		[m_addressesPopUp setEnabled:([[m_contact chatContactEntries] count] > 0)];
	}
	else if ([keyPath isEqualToString:@"avatar"]) {
		[self p_updateMiniwindowImage];
	}
	else if ([keyPath isEqualToString:@"activeContactEntry.online"]) {
		// Changes to the activeContactEntry will also trigger a change notification for the activeContactEntry.online
		// keypath. So, everything that must be done when any of these two keypaths change is being taken care of in here.
		[self p_syncViewsWithContact];
	}
	else if ([keyPath isEqualToString:@"activeContactEntry"]) {
		LPContactEntry *entry = [m_chat activeContactEntry];
		
		int idx = [m_addressesPopUp indexOfItemWithRepresentedObject:entry];
		if (idx >= 0)
			[m_addressesPopUp selectItemAtIndex:[m_addressesPopUp indexOfItemWithRepresentedObject:entry]];
		
		// Post a "system message" to signal the change
		NSString *systemMessage;
		if (entry) {
			if ([[[LPAccountsController sharedAccountsController] accounts] count] > 1) {
				systemMessage = [NSString stringWithFormat:NSLocalizedString(@"Chat changed to contact \"%@\" thru account \"%@\"",
																			 @"status message written to the text transcript of a chat window"),
					[[m_chat activeContactEntry] humanReadableAddress],
					[[[m_chat activeContactEntry] account] description]];
			}
			else {
				systemMessage = [NSString stringWithFormat:NSLocalizedString(@"Chat changed to contact \"%@\"",
																			 @"status message written to the text transcript of a chat window"),
					[[m_chat activeContactEntry] humanReadableAddress]];
			}
		}
		else {
			systemMessage = [NSString stringWithFormat:NSLocalizedString(@"Chat ended.", @"status message written to the text transcript of a chat window")];
		}
		
		[m_chatViewsController appendDIVBlockToWebViewWithInnerHTML:[systemMessage stringByEscapingHTMLEntities]
														   divClass:@"systemMessage"
												scrollToVisibleMode:LPScrollWithAnimationIfAtBottom];
		
		[m_chatJSInterface setAccount:[entry account]];
	}
	else if ([keyPath isEqualToString:@"activeContactEntry.account.online"]) {
		// Account online status (Chat window)
		[self p_setSendFieldHidden:(![[object valueForKeyPath:keyPath] boolValue] || [m_chat activeContactEntry] == nil)
						   animate:YES];
	}
	else if ([keyPath isEqualToString:@"account.online"]) {
		// Account online status (JID Entry Panel)
		[self p_reevaluateJIDPanelOKButtonEnabled];
	}
	else {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}


- (void)setMessageTextEntryString:(NSString *)messageText
{
	[m_inputTextField setStringValue:messageText];
	[m_inputTextField performSelector:@selector(calcContentSize) withObject:nil afterDelay:0.0];
	
	m_lastInputTextFieldStringLength = [messageText length];
}


- (void)sendAudibleWithResourceName:(NSString *)audibleName
{
	[self p_appendAudibleWithResourceName:audibleName inbound:NO];
	[m_chat sendAudibleWithResourceName:audibleName];
}


- (NSString *)p_fileNameHTMLForFileTransfer:(LPFileTransfer *)ft
{
	int	transferID = [ft ID];
	
	NSString *fileNameWithLink = [NSString stringWithFormat:
									 @"<a href=\"javascript:window.chatJSInterface.openFileOfTransfer(%d);\" title=\"%@\">%@</a>",
		transferID,
		NSLocalizedString(@"Open file", @""),
		[[ft filename] stringByEscapingHTMLEntities]];
	NSString *revealLink = [NSString stringWithFormat:
							   @"<a href=\"javascript:window.chatJSInterface.revealFileOfTransfer(%d);\" title=\"%@\"><img src=\"file://%@\"/></a>",
		transferID,
		NSLocalizedString(@"Reveal in Finder", @""),
		[[NSBundle mainBundle] pathForImageResource:@"TransferReveal"]];
	
	return [NSString stringWithFormat:@"\"%@\" %@", fileNameWithLink, revealLink];
}


- (void)updateInfoForFileTransfer:(LPFileTransfer *)ft
{
	LPContactEntry			*peerContactEntry = [ft peerContactEntry];
	LPFileTransferState		newState = [ft state];
	LPFileTransferType		type = [ft type];
	int						transferID = [ft ID];
	
	if ([peerContactEntry contact] == [self contact]) {
		
		NSString *htmlText = nil;
		NSString *divClass = nil;
		
		switch (newState) {
			case LPFileTransferPackaging:
			case LPFileTransferWaitingToBeAccepted:
			{
				NSString *elementID = [NSString stringWithFormat:@"fileTransfer_%d", transferID];
				
				if (![m_chatViewsController existsElementWithID:elementID]) {
					if (type == LPIncomingTransfer)
					{
						// Links for JavaScript -> Objective-C actions
						NSString *acceptLink = [NSString stringWithFormat:
												   @"<a href=\"javascript:window.chatJSInterface.acceptTransfer(%d);\">%@</a>",
							transferID,
							[NSLocalizedString(@"accept", @"for file transfers listed in chat windows") stringByEscapingHTMLEntities]];
						NSString *rejectLink = [NSString stringWithFormat:
												   @"<a href=\"javascript:window.chatJSInterface.rejectTransfer(%d);\">%@</a>",
							transferID,
							[NSLocalizedString(@"reject", @"for file transfers listed in chat windows") stringByEscapingHTMLEntities]];
						
						// Message text
						NSString *str1 = [NSString stringWithFormat:NSLocalizedString(@"Receiving file %@.",
																					  @"for file transfers listed in chat windows"),
							[self p_fileNameHTMLForFileTransfer:ft]];
						NSString *str2 = [NSString stringWithFormat:NSLocalizedString(@"You may %@ or %@ the transfer.",
																					  @"for file transfers listed in chat windows"),
							acceptLink, rejectLink];
						
						htmlText = [NSString stringWithFormat:@"%@<br/><span id=\"%@\">%@</span>",
							str1, elementID, str2];
					}
					else
					{
						NSString *str1 = [NSString stringWithFormat: NSLocalizedString(@"Sending file %@.",
																					   @"for file transfers listed in chat windows"),
							[self p_fileNameHTMLForFileTransfer:ft]];
						
						NSString *str2 = ( newState == LPFileTransferPackaging ?
										   NSLocalizedString(@"<b>(packaging...)</b>", @"") :
										   @"" );
						
						htmlText = [NSString stringWithFormat:@"%@<br/><span id=\"%@\">%@</span>",
							str1, elementID, str2];
					}
					divClass = @"smsReceivedReplyBlock";
				}
				else if (newState == LPFileTransferWaitingToBeAccepted) {
					[m_chatViewsController setInnerHTML:NSLocalizedString(@"", @"") forElementWithID:elementID];
				}
					
				break;
			}
				
			case LPFileTransferWasNotAccepted:
			{
				NSString *elementID = [NSString stringWithFormat:@"fileTransfer_%d", transferID];
				[m_chatViewsController setInnerHTML:NSLocalizedString(@"<b>(rejected)</b>", @"") forElementWithID:elementID];
				break;
			}
				
			case LPFileTransferRunning:
			{
				NSString *elementID = [NSString stringWithFormat:@"fileTransfer_%d", transferID];
				[m_chatViewsController setInnerHTML:NSLocalizedString(@"<b>(transferring...)</b>", @"") forElementWithID:elementID];
				break;
			}
				
			case LPFileTransferAbortedWithError:
			{
				NSString *elementID = [NSString stringWithFormat:@"fileTransfer_%d", transferID];
				NSString *formatStr = NSLocalizedString(@"<b>(error: %@)</b>", @"");
				NSString *html = [NSString stringWithFormat:formatStr, [[ft lastErrorMessage] stringByEscapingHTMLEntities]];
				[m_chatViewsController setInnerHTML:html forElementWithID:elementID];
				
				divClass = @"systemMessage";
				htmlText = [NSString stringWithFormat:
					NSLocalizedString(@"Transfer of file %@ was <b>aborted</b> with an error: %@.", @""),
					[self p_fileNameHTMLForFileTransfer:ft], [[ft lastErrorMessage] stringByEscapingHTMLEntities]];
				break;
			}
				
			case LPFileTransferCancelled:
			{
				NSString *elementID = [NSString stringWithFormat:@"fileTransfer_%d", transferID];
				[m_chatViewsController setInnerHTML:NSLocalizedString(@"<b>(cancelled)</b>", @"") forElementWithID:elementID];
				
				divClass = @"systemMessage";
				htmlText = [NSString stringWithFormat:
					NSLocalizedString(@"Transfer of file %@ was <b>cancelled</b>.", @""),
					[self p_fileNameHTMLForFileTransfer:ft]];
				break;
			}
				
			case LPFileTransferCompleted:
			{
				NSString *elementID = [NSString stringWithFormat:@"fileTransfer_%d", transferID];
				[m_chatViewsController setInnerHTML:NSLocalizedString(@"<b>(completed)</b>", @"") forElementWithID:elementID];
				
				divClass = @"systemMessage";
				htmlText = [NSString stringWithFormat:
					NSLocalizedString(@"Transfer of file %@ has <b>completed successfully</b>.", @""),
					[self p_fileNameHTMLForFileTransfer:ft]];
				break;
			}
				
			default:
				break;
		}
		
		if (htmlText) {
			[m_chatViewsController appendDIVBlockToWebViewWithInnerHTML:htmlText
															   divClass:divClass
													scrollToVisibleMode:LPScrollWithAnimationIfAtBottom];
		}
	}
}


#pragma mark -
#pragma mark Actions


- (IBAction)segmentClicked:(id)sender
{
	int clickedSegment = [sender selectedSegment];
    int clickedSegmentTag = [[sender cell] tagForSegment:clickedSegment];
	
	if (clickedSegmentTag == 0) {    // emoticons
		NSWindow *win = [self window];
		NSRect  buttonFrame = [sender frame];
		NSPoint topRight = [win convertBaseToScreen:[[sender superview] convertPoint:buttonFrame.origin
																			 toView:nil]];
		
		[sender setImage:[NSImage imageNamed:@"emoticonIconPressed"] forSegment:clickedSegment];
		[(NSView *)sender display];
		[m_chatViewsController pickEmoticonWithMenuTopRightAt:NSMakePoint(topRight.x + [sender widthForSegment:clickedSegment], topRight.y)
												 parentWindow:[self window]];
		[sender setImage:[NSImage imageNamed:@"emoticonIconUnpressed"] forSegment:clickedSegment];
		[(NSView *)sender display];
	}
	else if (clickedSegmentTag == 1) {  // audibles
		NSDrawerState state = [m_audiblesController drawerState];
		
		if (state == NSDrawerClosedState || state == NSDrawerClosingState) {
			// Will be open afterwards
			[sender setImage:[NSImage imageNamed:@"bocasIconPressed"] forSegment:clickedSegment];
		}
		else {
			// Will be closed afterwards
			[sender setImage:[NSImage imageNamed:@"bocasIconUnpressed"] forSegment:clickedSegment];
		}
		
		[m_audiblesController toggleDrawer:sender];
	}
}

- (IBAction)sendMessage:(id)sender
{
	NSAttributedString *attributedMessage = [m_inputTextField attributedStringValue];
	NSString *message = [attributedMessage stringByFlatteningAttachedEmoticons];
	
	// Check if the text is all made of whitespace.
	static NSCharacterSet *requiredCharacters = nil;
	if (requiredCharacters == nil) {
		requiredCharacters = [[[NSCharacterSet whitespaceAndNewlineCharacterSet] invertedSet] retain];
	}
	
	if ([message rangeOfCharacterFromSet:requiredCharacters].location != NSNotFound) {
		[self p_appendMessageToWebView:message subject:nil timestamp:[NSDate date] inbound:NO];
		[m_chat sendMessageWithPlainTextVariant:message XHTMLVariant:nil URLs:nil];
		m_hasAlreadyProcessedSomeMessages = YES;
	}
	
	// Store it in the input line history
	if ([m_inputLineHistory count] > 0)
		[m_inputLineHistory replaceObjectAtIndex:0 withObject:attributedMessage];
	else
		[m_inputLineHistory addObject:attributedMessage];
	
	if ([m_inputLineHistory count] > INPUT_LINE_HISTORY_ITEMS_MAX)
		[m_inputLineHistory removeObjectsInRange:NSMakeRange(INPUT_LINE_HISTORY_ITEMS_MAX, [m_inputLineHistory count] - INPUT_LINE_HISTORY_ITEMS_MAX)];
	[m_inputLineHistory insertObject:@"" atIndex:0];
	m_currentInputLineHistoryEntryIndex = 0;
	
	// Prepare the window to take another message from the user
	[[self window] makeFirstResponder:m_inputTextField];
	[self setMessageTextEntryString:@""];
}


- (IBAction)sendSMS:(id)sender
{
	if ([m_delegate respondsToSelector:@selector(chatController:sendSMSToContact:)]) {
		[m_delegate chatController:self sendSMSToContact:[self contact]];
	}
}


- (IBAction)sendFile:(id)sender
{
	NSOpenPanel *op = [NSOpenPanel openPanel];
	
	[op setPrompt:NSLocalizedString(@"Send", @"button for the file selection sheet")];
	
	[op setCanChooseFiles:YES];
	[op setCanChooseDirectories:NO];
	[op setResolvesAliases:YES];
	[op setAllowsMultipleSelection:NO];
	
	[op beginSheetForDirectory:nil
						  file:nil
						 types:nil
				modalForWindow:[self window]
				 modalDelegate:self
				didEndSelector:@selector(p_openPanelDidEnd:returnCode:contextInfo:)
				   contextInfo:NULL];
}

- (void)p_openPanelDidEnd:(NSOpenPanel *)panel returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	if (returnCode == NSOKButton) {
		LPContactEntry *contactEntry = [m_chat activeContactEntry];
		
		if (contactEntry && [contactEntry canDoFileTransfer])
			[[LPFileTransfersManager fileTransfersManager] startSendingFile:[panel filename]
															 toContactEntry:[m_chat activeContactEntry]];
	}
}


- (IBAction)editContact:(id)sender
{
	if ([m_delegate respondsToSelector:@selector(chatController:editContact:)]) {
		[m_delegate chatController:self editContact:[self contact]];
	}
}


- (IBAction)selectChatAddress:(id)sender
{
	LPContactEntry *selectedEntry = [sender representedObject];
	[m_chat setActiveContactEntry:selectedEntry];
	[m_contact setPreferredContactEntry:selectedEntry];
}


- (IBAction)saveDocumentTo:(id)sender
{
	NSSavePanel *sp = [NSSavePanel savePanel];
	
	[sp setCanSelectHiddenExtension:YES];
	[sp setRequiredFileType:@"webarchive"];
	
	[sp beginSheetForDirectory:nil
						  file:[m_chatViewsController chatDocumentTitle]
				modalForWindow:[self window]
				 modalDelegate:self
				didEndSelector:@selector(p_savePanelDidEnd:returnCode:contextInfo:)
				   contextInfo:NULL];
}


- (void)p_savePanelDidEnd:(NSSavePanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	if (returnCode == NSOKButton) {
		NSError *error;
		if (![m_chatViewsController saveDocumentToFile:[sheet filename] hideExtension:[sheet isExtensionHidden] error:&error]) {
			[self presentError:error];
		}
	}
}


- (IBAction)printDocument:(id)sender
{
	NSPrintOperation *op = [NSPrintOperation printOperationWithView:[[[m_chatWebView mainFrame] frameView] documentView]];
	[op runOperationModalForWindow:[self window]
						  delegate:nil
					didRunSelector:NULL
					   contextInfo:NULL];
}


#pragma mark Searching

- (IBAction)showFindPanel:(id)sender
{
	[[LPChatFindPanelController sharedFindPanel] showWindow:sender];
}

- (IBAction)findNext:(id)sender
{
	LPChatFindPanelController *findPanel = [LPChatFindPanelController sharedFindPanel];
	NSString *searchStr = [findPanel searchString];
	BOOL found = NO;
	
	if ([searchStr length] > 0)
		found = [m_chatWebView searchFor:searchStr direction:YES caseSensitive:NO wrap:YES];
	
	[findPanel searchStringWasFound:found];
}

- (IBAction)findPrevious:(id)sender
{
	LPChatFindPanelController *findPanel = [LPChatFindPanelController sharedFindPanel];
	NSString *searchStr = [findPanel searchString];
	BOOL found = NO;
	
	if ([searchStr length] > 0)
		found = [m_chatWebView searchFor:searchStr direction:NO caseSensitive:NO wrap:YES];
	
	[findPanel searchStringWasFound:found];
}

- (IBAction)useSelectionForFind:(id)sender
{
	NSString *selectedString = nil;
	id firstResponder = [[self window] firstResponder];
	
	if ([firstResponder isKindOfClass:[NSText class]])
		selectedString = [[firstResponder string] substringWithRange:[firstResponder selectedRange]];
	else if ([firstResponder isDescendantOf:m_chatWebView])
		selectedString = [[m_chatWebView selectedDOMRange] toString];
	
	if ([selectedString length] > 0)
		[[LPChatFindPanelController sharedFindPanel] setSearchString:selectedString];
}


#pragma mark Action Validation

- (BOOL)p_validateAction:(SEL)action
{
	// The sendSMS: action is not validated in here so that its menu item is always enabled. This makes it easier for the user to
	// get a window for sending SMS messages regardless of the current state of the GUI. If the contact supports sending SMS
	// it will be added automatically to the list of recipients for the message. Otherwise, the Send SMS window will show up
	// without any recipients. OTOH, the toolbar button for sending SMS messages is validated in the toolbar item validation method
	// and is disabled if the contact doesn't support sending SMS messages. This way we get an easy to check visual cue for the
	// capabilities of the contact.
	
	if (action == @selector(sendFile:)) {
		return ([[m_chat activeContactEntry] canDoFileTransfer] &&
				[[m_chat activeContactEntry] isOnline]);
	}
	else if (action == @selector(useSelectionForFind:)) {
		id firstResponder = [[self window] firstResponder];
		
		if ([firstResponder isKindOfClass:[NSText class]])
			return ([firstResponder selectedRange].length > 0);
		else if ([firstResponder isDescendantOf:m_chatWebView])
			return ([[[m_chatWebView selectedDOMRange] toString] length] > 0);
		else
			return NO;
	}
	else {
		return YES;
	}
}


- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	return [self p_validateAction:[menuItem action]];
}


#pragma mark Choose JID Panel


- (void)p_reevaluateJIDPanelOKButtonEnabled
{
	[m_chooseJIDPanelOKButton setEnabled:([[[m_chooseJIDPanelJIDEntryView JIDEntryTextField] stringValue] length] > 0
										  && [[m_chooseJIDPanelJIDEntryView account] isOnline])];
}

- (IBAction)chooseJIDPanelOK:(id)sender
{
	// Cleanup the sheet
	NSWindow *sheet = [[self window] attachedSheet];
	
	[NSApp endSheet:sheet];
	[sheet orderOut:nil];
	[m_chooseJIDPanelJIDEntryView removeObserver:self forKeyPath:@"account.online"];

	
	LPAccount		*account = [m_chooseJIDPanelJIDEntryView account];
	NSString		*jid = [m_chooseJIDPanelJIDEntryView enteredJID];
	
	LPContactEntry	*contactEntry = [[LPRoster roster] contactEntryForAddress:jid
																	  account:account
											createNewHiddenWithNameIfNotFound:jid];
	
	LPChatsManager	*chatsManager = [LPChatsManager chatsManager];
	LPChat			*chat = [chatsManager chatForContact:[contactEntry contact]];
	
	if (chat == nil) {
		chat = [chatsManager startChatWithContactEntry:contactEntry];
		
		[self p_setChat:chat];
		[self setContact:[chat contact]];
	}
	else {
		if ([m_delegate respondsToSelector:@selector(chatController:orderChatWithContactEntryToFront:)]) {
			[m_delegate chatController:self orderChatWithContactEntryToFront:contactEntry];
		} else {
			NSBeep();
			NSLog(@"%@'s delegate should implement the method %@",
				  NSStringFromClass([self class]), @"chatController:orderChatWithContactEntryToFront:");
		}
		
		[self close];
	}
}


- (IBAction)chooseJIDPanelCancel:(id)sender
{
	NSWindow *sheet = [[self window] attachedSheet];
	
	[NSApp endSheet:sheet];
	[sheet orderOut:nil];
	[m_chooseJIDPanelJIDEntryView removeObserver:self forKeyPath:@"account.online"];
	
	[self close];
}


- (IBAction)copyStatusMessage:(id)sender
{
	NSPasteboard	*pboard = [NSPasteboard generalPasteboard];
	
	[pboard declareTypes:[NSArray arrayWithObjects:NSStringPboardType, nil] owner:nil];
	[pboard setString:[[self contact] statusMessage] forType:NSStringPboardType];
}


#pragma mark -
#pragma mark LPChat Delegate Methods


- (void)chat:(LPChat *)chat didReceiveErrorMessage:(NSString *)message
{
	// Post a "system message"
	NSString *systemMessage = [NSString stringWithFormat:@"ERROR: %@", message];
	[m_chatViewsController appendDIVBlockToWebViewWithInnerHTML:[systemMessage stringByEscapingHTMLEntities]
													   divClass:@"systemMessage"
											scrollToVisibleMode:LPScrollWithAnimationIfAtBottom];
}


- (void)chat:(LPChat *)chat didReceiveMessageFromNick:(NSString *)nick subject:(NSString *)subject plainTextVariant:(NSString *)plainTextMessage XHTMLVariant:(NSString *)XHTMLMessage URLs:(NSArray *)URLs
{
	// DEBUG: this is useful for testing the code that handles the display of
	// received SMS messages without having to actually waste SMS messages.
//	if ([plainTextMessage hasPrefix:@"sms: "]) {
//		[self chat:chat didReceiveSMSFrom:@"00351964301673@phone.im.sapo.pt" withBody:plainTextMessage date:[NSDate date] newCredit:99 newFreeMessages:88 newTotalSentThisMonth:77];
//		return;
//	}
	
	// Add in the URLs
	NSString *messageBody = plainTextMessage;
	
	if (URLs && [URLs count] > 0) {
		NSMutableString *messageWithURLs = [NSMutableString stringWithString:messageBody];
		
		NSEnumerator *urlEnum = [URLs objectEnumerator];
		NSString *url;
		while (url = [urlEnum nextObject]) {
			[messageWithURLs appendFormat:@" | %@", url];
		}
		messageBody = messageWithURLs;
	}
	
	// Don't do everything at the same time. Allow the scroll animation to run first so that it doesn't appear choppy.
	[[m_chatViewsController grabMethodForAfterScrollingWithTarget:self]
			p_notifyUserAboutReceivedMessage:messageBody
				notificationsHandlerSelector:( !m_hasAlreadyProcessedSomeMessages ?
											   @selector(notifyReceptionOfFirstMessage:fromContact:) :
											   @selector(notifyReceptionOfMessage:fromContact:)      )];

	[self p_appendMessageToWebView:messageBody subject:subject timestamp:[NSDate date] inbound:YES];
	m_hasAlreadyProcessedSomeMessages = YES;
}


- (void)chat:(LPChat *)chat didReceiveSystemMessage:(NSString *)message
{
	// Post a "system message"
	NSString *systemMessage = [NSString stringWithFormat:@"System Message: %@", message];
	[m_chatViewsController appendDIVBlockToWebViewWithInnerHTML:[systemMessage stringByEscapingHTMLEntities]
													   divClass:@"systemMessage"
											scrollToVisibleMode:LPScrollWithAnimationIfAtBottom];
}


- (void)chat:(LPChat *)chat didReceiveResultOfSMSSentTo:(NSString *)destinationPhoneNr withBody:(NSString *)msgBody resultCode:(int)result nrUsedMsgs:(int)nrUsedMsgs nrUsedChars:(int)nrUsedChars newCredit:(int)newCredit newFreeMessages:(int)newFreeMessages newTotalSentThisMonth:(int)newTotalSentThisMonth
{
	//	DEBUG:
	//	NSString *text = [NSString stringWithFormat:@"SMS SENT to %@ (message: \"%@\"). Result: %d , %d msgs used, %d chars used, new credit: %d , new free msgs: %d , new total sent: %d", destinationPhoneNr, msgBody, result, nrUsedMsgs, nrUsedChars, newCredit, newFreeMessages, newTotalSentThisMonth];
	
	NSString *phoneNr = ( [destinationPhoneNr isPhoneJID] ?
						  [destinationPhoneNr userPresentablePhoneNrRepresentation] :
						  destinationPhoneNr );
	NSString *htmlText = nil;
	
	if (result == 1) {
		// Success
		htmlText = [NSString stringWithFormat:
			NSLocalizedString(@"SMS <b>sent</b> to \"%@\" at %@<br/>Used: %d message(s), total of %d characters.<p>\"<b>%@</b>\"</p>", @""),
			[phoneNr stringByEscapingHTMLEntities],
			[[NSDate date] descriptionWithCalendarFormat:@"%H:%M:%S" timeZone:nil locale:nil],
			nrUsedMsgs, nrUsedChars,
			[msgBody stringByEscapingHTMLEntities]
			//newCredit, newFreeMessages, newTotalSentThisMonth
			];
	}
	else {
		// Failure
		htmlText = [NSString stringWithFormat:
			NSLocalizedString(@"<b>Failed</b> to send SMS to \"%@\" at %@.<p>\"<b>%@</b>\"</p>", @""),
			[phoneNr stringByEscapingHTMLEntities],
			[[NSDate date] descriptionWithCalendarFormat:@"%H:%M:%S" timeZone:nil locale:nil],
			[msgBody stringByEscapingHTMLEntities]];
	}
	
	[m_chatViewsController appendDIVBlockToWebViewWithInnerHTML:htmlText
													   divClass:@"smsSentReplyBlock"
											scrollToVisibleMode:LPScrollWithAnimationIfAtBottom];
}


- (void)chat:(LPChat *)chat didReceiveSMSFrom:(NSString *)sourcePhoneNr withBody:(NSString *)msgBody date:(NSDate *)date newCredit:(int)newCredit newFreeMessages:(int)newFreeMessages newTotalSentThisMonth:(int)newTotalSentThisMonth
{
	// DEBUG:
	//	NSString *text = [NSString stringWithFormat:@"SMS RECEIVED on %@ from %@: \"%@\". New credit: %d , new free msgs: %d , new total sent: %d", date, sourcePhoneNr, msgBody, newCredit, newFreeMessages, newTotalSentThisMonth];
	
	NSString *phoneNr = ( [sourcePhoneNr isPhoneJID] ?
						  [sourcePhoneNr userPresentablePhoneNrRepresentation] :
						  sourcePhoneNr );
	NSString *htmlText = [NSString stringWithFormat:
		NSLocalizedString(@"SMS <b>received</b> from \"%@\" at %@<p>\"<b>%@</b>\"</p>", @""),
		// We don't use the date provided by the server because it is nil sometimes
		[phoneNr stringByEscapingHTMLEntities],
		[[NSDate date] descriptionWithCalendarFormat:@"%H:%M:%S" timeZone:nil locale:nil],
		[m_chatViewsController HTMLifyRawMessageString:msgBody]];
	
	// Don't do everything at the same time. Allow the scroll animation to run first so that it doesn't appear choppy.
	[[m_chatViewsController grabMethodForAfterScrollingWithTarget:self]
			p_notifyUserAboutReceivedMessage:msgBody
				notificationsHandlerSelector:@selector(notifyReceptionOfSMSMessage:fromContact:)];
	
	[m_chatViewsController appendDIVBlockToWebViewWithInnerHTML:htmlText
													   divClass:@"smsReceivedReplyBlock"
											scrollToVisibleMode:LPScrollWithAnimationIfAtBottom];
	
	LPContactEntry *activeEntry = [m_chat activeContactEntry];
	[[LPRecentMessagesStore sharedMessagesStore] storeRawHTMLBlock:htmlText
													  withDIVClass:@"smsReceivedReplyBlock"
															forJID:[activeEntry address]
													thruAccountJID:[[activeEntry account] JID]];
}


- (void)chat:(LPChat *)chat didReceiveAudibleWithResourceName:(NSString *)resourceName msgBody:(NSString *)body msgHTMLBody:(NSString *)htmlBody
{
	LPAudibleSet *set = [LPAudibleSet defaultAudibleSet];
	
	if ([set isValidAudibleResourceName:resourceName]) {
		NSString *localPath = [set filepathForAudibleWithName:resourceName];
		
		if (localPath == nil) {
			// We don't have this audible in local storage yet. Start loading it and insert it into the webview later.
			
			[[self p_pendingAudiblesSet] addObject:resourceName];
			[set startLoadingAudibleFromServer:resourceName];
		} else {
			[self p_appendAudibleWithResourceName:resourceName inbound:YES];
		}
	}
	else {
		[self chat:chat didReceiveErrorMessage:[NSString stringWithFormat:@"Received an unknown audible: \"%@\"",
			resourceName]];
		// Send an error back to the other contact
		[m_chat sendInvalidAudibleErrorWithMessage:@"Bad Request: the audible that was sent is unknown!"
							  originalResourceName:resourceName
									  originalBody:body
								  originalHTMLBody:htmlBody];
	}
}


#pragma mark -
#pragma mark LPJIDEntryView Notifications


- (void)JIDEntryViewEnteredJIDDidChange:(LPJIDEntryView *)view;
{
	[self p_reevaluateJIDPanelOKButtonEnabled];
}


#pragma mark -
#pragma mark LPAudibleSet Notifications


- (void)audibleSetDidFinishLoadingAudible:(NSNotification *)notification
{
	NSString *audibleResourceName = [[notification userInfo] objectForKey:@"LPAudibleName"];
	
	if ([[self p_pendingAudiblesSet] containsObject:audibleResourceName]) {
		[[self p_pendingAudiblesSet] removeObject:audibleResourceName];
		[self p_appendAudibleWithResourceName:audibleResourceName inbound:YES];
	}
}


#pragma mark -
#pragma mark LPFileTransfer Notifications


- (void)fileTransferStateDidChange:(NSNotification *)notification
{
	LPFileTransfer	*ft = [notification object];
	LPContactEntry	*peerContactEntry = [ft peerContactEntry];
	
	if ([peerContactEntry contact] == [self contact]) {
		[self updateInfoForFileTransfer:ft];
	}
}


#pragma mark -
#pragma mark NSResponder Methods


- (void)keyDown:(NSEvent *)theEvent
{
	/* If a keyDown event reaches this low in the responder chain then it means that no text field is
	active to process the event. Activate the input text field and reroute the event that was received
	back to it. */
	if ([m_inputTextField canBecomeKeyView]) {
		NSWindow *window = [self window];
		[window makeFirstResponder:m_inputTextField];
		[[window firstResponder] keyDown:theEvent];
	} else {
		[super keyDown:theEvent];
	}
}


#pragma mark -
#pragma mark Private Methods


#pragma mark ** JIDs Popup Menu

- (NSAttributedString *)p_attributedTitleOfJIDMenuItemForContactEntry:(LPContactEntry *)entry withFont:(NSFont *)font
{
	LPStatus entryStatus = [entry status];
	
	NSString *menuItemTitle = ( (entryStatus == LPStatusInvisible || entryStatus == LPStatusOffline) ?
								[NSString stringWithFormat:@"%@  %C  %@",
									[entry humanReadableAddress], 0x2014 /* em-dash */,
									NSLocalizedStringFromTable(LPStatusStringFromStatus([entry status]), @"Status", @"")] :
								[entry humanReadableAddress] );
	
	NSDictionary *attribs = ( [entry isOnline] ?
							  [NSDictionary dictionaryWithObject:font forKey:NSFontAttributeName] :
							  [NSDictionary dictionaryWithObjectsAndKeys:
								  font, NSFontAttributeName,
								  [NSColor grayColor], NSForegroundColorAttributeName, nil] );
	
	return ( (menuItemTitle != nil && attribs != nil) ?
			 [[[NSAttributedString alloc] initWithString:menuItemTitle attributes:attribs] autorelease] :
			 nil );
}


- (NSMenuItem *)p_popupMenuHeaderItemForAccount:(LPAccount *)account
{
	id item = nil;
	int idx = [m_addressesPopUp indexOfItemWithRepresentedObject:account];
	
	if (idx >= 0) {
		item = [m_addressesPopUp itemAtIndex:idx];
	}
	else {
		item = [[NSMenuItem alloc] initWithTitle:@"" action:NULL keyEquivalent:@""];
		
		[item setTitle:[NSString stringWithFormat:NSLocalizedString(@"Account \"%@\"", @"Chat and SMS window popup menu"), [account description]]];
		[item setIndentationLevel:0];
		[item setEnabled:NO];
		[item setRepresentedObject:account];
		
		[item autorelease];
	}
	
	return item;
}


- (NSMenuItem *)p_popupMenuItemForEntry:(LPContactEntry *)entry
{
	id item = nil;
	int idx = [m_addressesPopUp indexOfItemWithRepresentedObject:entry];
	
	if (idx >= 0) {
		item = [m_addressesPopUp itemAtIndex:idx];
	}
	else {
		item = [[NSMenuItem alloc] initWithTitle:@"" action:@selector(selectChatAddress:) keyEquivalent:@""];
		
		NSAttributedString *attributedTitle = 
			[self p_attributedTitleOfJIDMenuItemForContactEntry:entry withFont:[m_addressesPopUp font]];
		
		[item setAttributedTitle:attributedTitle];
		[item setIndentationLevel:1];
		[item setRepresentedObject:entry];
		[item setTarget:self];
		
		[item autorelease];
	}
	
	return item;
}


- (void)p_moveJIDMenuItem:(NSMenuItem *)menuItem toIndex:(int)targetIndex inMenu:(NSMenu *)menu
{
	int currentIndex = [menu indexOfItem:menuItem];
	if (currentIndex != targetIndex) {
		// Prevent it from being dealloced while we possibly take it out of the menu
		[menuItem retain];
		if (currentIndex >= 0)
			[menu removeItemAtIndex:currentIndex];
		[menu insertItem:menuItem atIndex:targetIndex];
		[menuItem release];
	}
}


- (void)p_syncJIDsPopupMenu
{
	NSMenuItem		*selectedItem = [m_addressesPopUp selectedItem];
	
	NSPredicate		*onlinePred = [NSPredicate predicateWithFormat:@"online == YES"];
	NSPredicate		*offlinePred = [NSPredicate predicateWithFormat:@"online == NO"];
	int				currentIndex = 0;
	
	NSMenu			*menu = [m_addressesPopUp menu];
	NSFont			*menuItemFont = [m_addressesPopUp font];
	
	NSArray			*accounts = [[LPAccountsController sharedAccountsController] accounts];
	unsigned int	nrOfAccounts = [accounts count];
	NSEnumerator	*accountEnumerator = [accounts objectEnumerator];
	LPAccount		*account;
	
	while (account = [accountEnumerator nextObject]) {
		if ([account isEnabled]) {
			
			// Collect all the JIDs in this account into two lists: online JIDs and offline JIDs
			NSPredicate		*accountPred = [NSPredicate predicateWithFormat:@"account == %@", account];
			NSPredicate		*onlineInThisAccountPred = [NSCompoundPredicate andPredicateWithSubpredicates:
				[NSArray arrayWithObjects:accountPred, onlinePred, nil]];
			NSPredicate		*offlineInThisAccountPred = [NSCompoundPredicate andPredicateWithSubpredicates:
				[NSArray arrayWithObjects:accountPred, offlinePred, nil]];
			
			NSArray		*onlineEntries = [[m_contact chatContactEntries] filteredArrayUsingPredicate: onlineInThisAccountPred];
			NSArray		*offlineEntries = [[m_contact chatContactEntries] filteredArrayUsingPredicate: offlineInThisAccountPred];
			
			if (([onlineEntries count] + [offlineEntries count]) > 0) {
				// ---- Separator Item ----
				if (currentIndex > 0) {
					[[m_addressesPopUp menu] insertItem:[NSMenuItem separatorItem] atIndex:currentIndex];
					++currentIndex;
				}
				
				// Setup an account header in the menu, but only if there's more than one configured account
				if (nrOfAccounts > 1) {
					NSMenuItem *menuItem = [self p_popupMenuHeaderItemForAccount:account];
					[self p_moveJIDMenuItem:menuItem toIndex:currentIndex inMenu:menu];
					++currentIndex;
				}				
				
				NSEnumerator	*entryEnum = nil;
				LPContactEntry	*entry = nil;
				
				// Online Contact Entries
				entryEnum = [onlineEntries objectEnumerator];
				while (entry = [entryEnum nextObject]) {
					NSMenuItem *menuItem = [self p_popupMenuItemForEntry:entry];
					
					[self p_moveJIDMenuItem:menuItem toIndex:currentIndex inMenu:menu];
					[menuItem setAttributedTitle:[self p_attributedTitleOfJIDMenuItemForContactEntry:entry withFont:menuItemFont]];
					++currentIndex;
				}
				
				// Offline Contact Entries
				entryEnum = [offlineEntries objectEnumerator];
				while (entry = [entryEnum nextObject]) {
					NSMenuItem *menuItem = [self p_popupMenuItemForEntry:entry];
					
					[self p_moveJIDMenuItem:menuItem toIndex:currentIndex inMenu:menu];
					[menuItem setAttributedTitle:[self p_attributedTitleOfJIDMenuItemForContactEntry:entry withFont:menuItemFont]];
					++currentIndex;
				}
			}
		}
	}
	
	// Remove the remaining items that were left in the menu
	while ([m_addressesPopUp numberOfItems] > currentIndex) {
		[m_addressesPopUp removeItemAtIndex:currentIndex];
	}
	
	// Re-select the saved selection if it's still in the menu
	if (selectedItem != nil && [m_addressesPopUp indexOfItem:selectedItem] >= 0) {
		[m_addressesPopUp selectItem:selectedItem];
	}
	else {
		LPContactEntry *entry = [m_chat activeContactEntry];
		int activeEntryIndex = (entry ? [m_addressesPopUp indexOfItemWithRepresentedObject:[m_chat activeContactEntry]] : -1);
		if (activeEntryIndex >= 0) {
			[m_addressesPopUp selectItemAtIndex:activeEntryIndex];
		}
	}
	
	[m_addressesPopUp synchronizeTitleAndSelectedItem];
}


- (void)p_JIDsMenuWillPop:(NSNotification *)notif
{
	[self p_syncJIDsPopupMenu];
}


#pragma mark ******

- (void)p_setSendFieldHidden:(BOOL)hideFlag animate:(BOOL)animateFlag
{
	BOOL isInputHidden = (m_collapsedHeightWhenLastWentOffline >= 1.0);
	
	if (hideFlag != isInputHidden) {
		// The visibility of the text field doesn't match the state of the connection. We'll have to either show it or hide it.

		unsigned int chatViewAutoresizingMask = [m_chatWebView autoresizingMask];
		unsigned int inputBoxAutoresizingMask = [m_inputControlsBar autoresizingMask];

		// Disable the autoresizing of the views and make them stay where they are when we resize the window vertically
		[m_chatWebView setAutoresizingMask:NSViewMinYMargin];
		[m_inputControlsBar setAutoresizingMask:NSViewMinYMargin];

		float	deltaY = 0.0;
		BOOL	mustBecomeVisible = (!hideFlag && isInputHidden);

		if (mustBecomeVisible) {
			deltaY = m_collapsedHeightWhenLastWentOffline;
			m_collapsedHeightWhenLastWentOffline = 0.0;
		} else {
			m_collapsedHeightWhenLastWentOffline = NSHeight([m_inputControlsBar frame]);
			deltaY = -m_collapsedHeightWhenLastWentOffline;
		}

		if (mustBecomeVisible == NO)
			[[self window] makeFirstResponder:nil];

		[m_inputTextField setEnabled:mustBecomeVisible];
		[m_segmentedButton setEnabled:mustBecomeVisible];

		if (mustBecomeVisible)
			[[self window] makeFirstResponder:m_inputTextField];

		NSWindow *win = [m_inputControlsBar window];
		NSRect windowFrame = [win frame];

		windowFrame.origin.y -= deltaY;
		windowFrame.size.height += deltaY;

		[win setFrame:windowFrame display:YES animate:animateFlag];

		// Restore the autoresizing masks
		[m_chatWebView setAutoresizingMask:chatViewAutoresizingMask];
		[m_inputControlsBar setAutoresizingMask:inputBoxAutoresizingMask];

		// Readjust the size of the text field in case the window was resized while the input bar was collapsed
		if (mustBecomeVisible)
			[m_inputTextField calcContentSize];
		
		[self p_fixResizeIndicator];
	}
}


- (void)p_fixResizeIndicator
{
	// The resize indicator drawn on the corner of the window has some drawing issues when we resize the window
	// and it gets moved to or from over a scroll bar. The only way I got it to get drawn correctly was by disabling
	// the indicator immediatelly and reanabling it only on the next pass through the run loop.
	
	NSWindow *win = [self window];
	
	// Resize Indicator
	[win setShowsResizeIndicator:NO];
	
	
	NSMethodSignature *methodSig = [win methodSignatureForSelector:@selector(setShowsResizeIndicator:)];
	NSInvocation *inv = [NSInvocation invocationWithMethodSignature:methodSig];
	BOOL flag = YES;
	
	[inv setTarget:win];
	[inv setSelector:@selector(setShowsResizeIndicator:)];
	[inv setArgument:&flag atIndex:2];
	[inv retainArguments];
	[inv performSelector:@selector(invoke) withObject:nil afterDelay:0.0];
}


- (NSMutableSet *)p_pendingAudiblesSet
{
	if (m_audibleResourceNamesWaitingForLoadCompletion == nil) {
		m_audibleResourceNamesWaitingForLoadCompletion = [[NSMutableSet alloc] init];
	}
	return m_audibleResourceNamesWaitingForLoadCompletion;
}


- (void)p_appendStandardMessageBlockWithInnerHTML:(NSString *)innerHTML timestamp:(NSDate *)timestamp inbound:(BOOL)isInbound saveInHistory:(BOOL)shouldSave scrollMode:(LPScrollToVisibleMode)scrollMode
{
	NSString *authorName = nil;
	if (isInbound) {
		authorName = [m_contact name];
	} else {
		NSString *globalName = [[LPAccountsController sharedAccountsController] name];
		authorName = ( [globalName length] > 0 ?
					   globalName :
					   [[[[self chat] activeContactEntry] account] JID] );
	}
	
	NSString *htmlString = [m_chatViewsController HTMLStringForStandardBlockWithInnerHTML:innerHTML timestamp:timestamp authorName:authorName];
	
	// if it's an outbound message, also scroll down so that the user can see what he has just written
	[m_chatViewsController appendDIVBlockToWebViewWithInnerHTML:htmlString divClass:@"messageBlock" scrollToVisibleMode:scrollMode];
	
	// Save in the recent history log
	if (shouldSave) {
		LPContactEntry *activeEntry = [m_chat activeContactEntry];
		if (isInbound) {
			[[LPRecentMessagesStore sharedMessagesStore] storeMessage:innerHTML
													  receivedFromJID:[activeEntry address]
													   thruAccountJID:[[activeEntry account] JID]];
		} else {
			[[LPRecentMessagesStore sharedMessagesStore] storeMessage:innerHTML
															sentToJID:[activeEntry address]
													   thruAccountJID:[[activeEntry account] JID]];
		}
	}
}


- (void)p_appendMessageToWebView:(NSString *)message subject:(NSString *)subject timestamp:(NSDate *)timestamp inbound:(BOOL)isInbound
{
	NSString *messageHTML = [m_chatViewsController HTMLifyRawMessageString:message];
	
	if ([subject length] > 0) {
		NSString *subjectHTML = [m_chatViewsController HTMLifyRawMessageString:subject];
		messageHTML = [NSString stringWithFormat:@"<b>%@:</b> %@", subjectHTML, messageHTML];
	}
	
	LPScrollToVisibleMode scrollMode = (isInbound ? LPScrollWithAnimationIfAtBottom : LPScrollWithJumpOrAnimationIfAtBottom);
	
	[self p_appendStandardMessageBlockWithInnerHTML:messageHTML timestamp:timestamp inbound:isInbound saveInHistory:YES scrollMode:scrollMode];
}


- (void)p_appendAudibleWithResourceName:(NSString *)resourceName inbound:(BOOL)inbound
{
	NSString		*pathForHTMLFile = [[NSBundle mainBundle] pathForResource:@"AudibleObject" ofType:@"html" inDirectory:@"ChatView"];
	NSMutableString	*htmlCode = [NSMutableString stringWithContentsOfFile:pathForHTMLFile];
	
	LPAudibleSet	*audibleSet = [LPAudibleSet defaultAudibleSet];
	NSString		*audibleFilePath = [audibleSet filepathForAudibleWithName:resourceName];
	NSString		*audibleCaption = [audibleSet captionForAudibleWithName:resourceName];
	NSString		*audibleText = [audibleSet textForAudibleWithName:resourceName];
	
	if (audibleFilePath) {
		[htmlCode replaceOccurrencesOfString:@"%%AUDIBLE_URL%%"
								  withString:[[NSURL fileURLWithPath:audibleFilePath] absoluteString]
									 options:NSLiteralSearch
									   range:NSMakeRange(0, [htmlCode length])];
		[htmlCode replaceOccurrencesOfString:@"%%AUDIBLE_CAPTION%%"
								  withString:[audibleCaption stringByEscapingHTMLEntities]
									 options:NSLiteralSearch
									   range:NSMakeRange(0, [htmlCode length])];
		[htmlCode replaceOccurrencesOfString:@"%%AUDIBLE_TEXT%%"
								  withString:[audibleText stringByEscapingHTMLEntities]
									 options:NSLiteralSearch
									   range:NSMakeRange(0, [htmlCode length])];
	}
	else {
		// We tried to load the audible and didn't get a file in the end. It's probably an invalid resource name.
		htmlCode = [NSString stringWithFormat:@"Received an invalid audible (ref.: %@)",
			[resourceName stringByEscapingHTMLEntities]];
	}
	
	if (inbound) {
		// Don't do everything at the same time. Allow the scroll animation to run first so that it doesn't appear choppy.
		[[m_chatViewsController grabMethodForAfterScrollingWithTarget:self]
			p_notifyUserAboutReceivedMessage:audibleCaption
				notificationsHandlerSelector:( !m_hasAlreadyProcessedSomeMessages ?
											   @selector(notifyReceptionOfFirstMessage:fromContact:) :
											   @selector(notifyReceptionOfMessage:fromContact:)      )];
	}
	
	LPScrollToVisibleMode scrollMode = (inbound ? LPScrollWithAnimationIfAtBottom : LPScrollWithJumpOrAnimationIfAtBottom);
	
	[self p_appendStandardMessageBlockWithInnerHTML:htmlCode timestamp:[NSDate date] inbound:inbound saveInHistory:YES scrollMode:scrollMode];
}


- (void)p_appendStoredRecentMessagesToWebView
{
	LPRecentMessagesStore *recentMessagesStore = [LPRecentMessagesStore sharedMessagesStore];
	NSArray *messagesList = [recentMessagesStore recentMessagesExchangedWithContact:[self contact]];
	
	NSCalendarDate *prevDate = nil;
	
	NSEnumerator *messageEnum = [messagesList objectEnumerator];
	NSDictionary *messageRec;
	
	while (messageRec = [messageEnum nextObject]) {
		NSDate *timestamp = [messageRec objectForKey:@"Timestamp"];
		NSString *message = [messageRec objectForKey:@"MessageText"];
		NSString *kind = [messageRec objectForKey:@"Kind"];
		
		NSCalendarDate *curDate = [timestamp dateWithCalendarFormat:NSLocalizedString(@"%b %e, %Y",
																					  @"date format for chat recent messages")
														   timeZone:nil];
		
		if (prevDate == nil || [prevDate dayOfCommonEra] != [curDate dayOfCommonEra]) {
			// Post a "system message" to signal the change in the date
			NSString *systemMessage = [NSString stringWithFormat:NSLocalizedString(@"Recent messages exchanged on %@",
																				   @"chat recent messages"),
				[curDate description]];
			
			[m_chatViewsController appendDIVBlockToWebViewWithInnerHTML:[systemMessage stringByEscapingHTMLEntities]
															   divClass:@"systemMessage"
													scrollToVisibleMode:LPScrollWithJump];
		}
		prevDate = curDate;
		
		if ([kind isEqualToString:@"RawHTMLBlock"]) {
			[m_chatViewsController appendDIVBlockToWebViewWithInnerHTML:message
															   divClass:[messageRec objectForKey:@"DIVClass"]
													scrollToVisibleMode:LPScrollWithJump];
		}
		else {
			[self p_appendStandardMessageBlockWithInnerHTML:message
												  timestamp:timestamp
													inbound:[kind isEqualToString:@"Received"]
											  saveInHistory:NO
												 scrollMode:LPScrollWithJump ];
		}
	}
}


- (void)p_resizeInputFieldToContentsSize:(NSSize)newSize
{
	// Determine the new window frame
	float	heightDifference = newSize.height - NSHeight([m_inputTextField bounds]);
	BOOL	inputBarIsCollapsed = (m_collapsedHeightWhenLastWentOffline >= 1.0);
	
	if ((inputBarIsCollapsed == NO) && ((heightDifference > 0.5) || (heightDifference < -0.5))) {
		NSRect	newWindowFrame = [[self window] frame];
		
		newWindowFrame.size.height += heightDifference;
		newWindowFrame.origin.y -= heightDifference;
		
		// Make sure the window is completely enclosed within the screen rect
		NSRect screenRect = [[[self window] screen] visibleFrame];
		
		if (NSContainsRect(screenRect, newWindowFrame) == NO) {
			float dX = 0.0, dY = 0.0;
			
			if (NSMinX(screenRect) > NSMinX(newWindowFrame)) {
				dX = NSMinX(screenRect) - NSMinX(newWindowFrame);
			}
			else if (NSMaxX(screenRect) < NSMaxX(newWindowFrame)) {
				dX = NSMaxX(screenRect) - NSMaxX(newWindowFrame);
			}
			
			if (NSMinY(screenRect) > NSMinY(newWindowFrame)) {
				dY = NSMinY(screenRect) - NSMinY(newWindowFrame);
			}
			else if (NSMaxY(screenRect) < NSMaxY(newWindowFrame)) {
				dY = NSMaxY(screenRect) - NSMaxY(newWindowFrame);
			}
			
			newWindowFrame = NSOffsetRect(newWindowFrame, dX, dY);
		}
		
		// Do the actual resizing
		unsigned int webViewResizeMask = [m_chatWebView autoresizingMask];
		unsigned int inputBoxResizeMask = [m_inputControlsBar autoresizingMask];
		
		[m_chatWebView setAutoresizingMask:NSViewMinYMargin];
		[m_inputControlsBar setAutoresizingMask:NSViewHeightSizable];
		
		[[self window] setFrame:newWindowFrame display:YES animate:YES];
		
		[m_inputControlsBar setAutoresizingMask:inputBoxResizeMask];
		[m_chatWebView setAutoresizingMask:webViewResizeMask];
	}
}


- (void)p_updateChatBackgroundColorFromDefaults
{
	NSData *encodedChatBGColor = [[NSUserDefaults standardUserDefaults] objectForKey:@"ChatBackgroundColor"];
	NSColor *backgroundColor = [NSUnarchiver unarchiveObjectWithData:encodedChatBGColor];
	
	[m_chatWebView setBackgroundColor:backgroundColor];
}


- (void)p_setupChatDocumentTitle
{
	NSString *timeFormat = NSLocalizedString(@"%Y-%m-%d %Hh%Mm%Ss",
											 @"time format for chat transcripts titles and filenames");
	NSMutableString *mutableTimeFormat = [timeFormat mutableCopy];
	
	// Make the timeFormat safe for filenames
	[mutableTimeFormat replaceOccurrencesOfString:@":" withString:@"." options:0
											range:NSMakeRange(0, [mutableTimeFormat length])];
	[mutableTimeFormat replaceOccurrencesOfString:@"/" withString:@"-" options:0
											range:NSMakeRange(0, [mutableTimeFormat length])];
	
	NSString *newTitle = [NSString stringWithFormat:
		NSLocalizedString(@"Chat with \"%@\" on %@", @"filename and title for saved chat transcripts"),
		[[self contact] name],
		[[NSDate date] descriptionWithCalendarFormat:mutableTimeFormat timeZone:nil locale:nil]];
	
	[m_chatViewsController setChatDocumentTitle:newTitle];
	[mutableTimeFormat release];
}


- (void)p_setSaveChatTranscriptEnabled:(BOOL)flag
{
	if (flag && !m_isAutoSavingChatTranscript) {
		[m_autoSaveChatTranscriptTimer invalidate];
		[m_autoSaveChatTranscriptTimer release];
		
		// Randomize the timer a bit so that they're not firing all at the same time.
		// They are going to get delays in the interval [ 25.0 ; 35.0 ]
		float randomCoef = 2.0 * ((float)rand() / (float)RAND_MAX) - 1.0;
		float interval = 30.0 + (5.0 * randomCoef);
		
		m_autoSaveChatTranscriptTimer = [[NSTimer scheduledTimerWithTimeInterval:interval
																		  target:self
																		selector:@selector(p_autoSaveChatTranscript:)
																		userInfo:nil
																		 repeats:YES] retain];
		m_isAutoSavingChatTranscript = YES;
	}
	else if (!flag && m_isAutoSavingChatTranscript) {
		// Save one last time
		[m_autoSaveChatTranscriptTimer fire];
		
		m_isAutoSavingChatTranscript = NO;
		[m_autoSaveChatTranscriptTimer invalidate];
		[m_autoSaveChatTranscriptTimer release];
		m_autoSaveChatTranscriptTimer = nil;
	}
}

- (void)p_autoSaveChatTranscript:(NSTimer *)timer
{
	// Are there any messages worth saving?
	if (m_hasAlreadyProcessedSomeMessages) {
		NSError *error;
		NSString *chatTranscriptPath = [[LPChatTranscriptsFolderPath() stringByAppendingPathComponent:
			[m_chatViewsController chatDocumentTitle]] stringByAppendingPathExtension:@"webarchive"];
		
		[m_chatViewsController saveDocumentToFile:chatTranscriptPath hideExtension:YES error:&error];
	}
}


- (void)p_checkIfPubBannerIsNeeded
{
	if ([[m_chat contact] someEntryHasCapsFeature:@"http://messenger.sapo.pt/features/banners/chat"]) {
		// Insert Pub Elements in the window
		NSWindow *win = [self window];
		NSRect winFrame = [win frame];
		float pubHeight = NSHeight([m_pubElementsView frame]);
		
		winFrame.size.height += pubHeight;
		winFrame.origin.y -= pubHeight;
		
		// Resize the window
		unsigned int savedChatElementsMask = [m_standardChatElementsView autoresizingMask];
		[m_standardChatElementsView setAutoresizingMask:( NSViewWidthSizable | NSViewMinYMargin )];
		[win setFrame:winFrame display:YES animate:YES];
		[m_standardChatElementsView setAutoresizingMask:savedChatElementsMask];
		
		// Resize and Insert the new view
		[m_pubElementsView setFrame:NSMakeRect(0.0, 0.0, NSWidth(winFrame), pubHeight)];
		[[win contentView] addSubview:m_pubElementsView];
		
		// Load the content of the banner webview
		LPContactEntry *entryHavingPub = [[m_chat contact] firstContactEntryWithCapsFeature:@"http://messenger.sapo.pt/features/banners/chat"];
		
		[[[entryHavingPub account] pubManager] fetchHTMLForChatBot:[entryHavingPub address]
														  delegate:self
													didEndSelector:@selector(p_fetchHTMLforChatBotDidFinish:)];
	}
}


- (void)p_fetchHTMLforChatBotDidFinish:(NSString *)htmlCode
{
	if (htmlCode)
		[[m_pubBannerWebView mainFrame] loadHTMLString:htmlCode baseURL:nil];
}


- (void)p_incrementUnreadMessagesCount
{
	[self willChangeValueForKey:@"numberOfUnreadMessages"];
	++m_nrUnreadMessages;
	[self didChangeValueForKey:@"numberOfUnreadMessages"];
	
	[m_unreadCountImageView setImage:[m_unreadMessagesBadge largeBadgeForValue:m_nrUnreadMessages]];
	[self p_updateMiniwindowImage];
}


- (void)p_resetUnreadMessagesCount
{
	[self willChangeValueForKey:@"numberOfUnreadMessages"];
	m_nrUnreadMessages = 0;
	[self didChangeValueForKey:@"numberOfUnreadMessages"];
	
	[m_unreadCountImageView setImage:nil];
	[self p_updateMiniwindowImage];
}


- (void)p_updateMiniwindowImage
{
	if (m_unreadMessagesBadge == nil) {
		m_unreadMessagesBadge = [[CTBadge alloc] init];
	}
	
	NSImage		*badgedImage = ( m_nrUnreadMessages > 0 ?
								 [m_unreadMessagesBadge badgeOverlayImageForValue:m_nrUnreadMessages insetX:0.0 y:0.0] :
								 [[[NSImage alloc] initWithSize:NSMakeSize(128.0, 128.0)] autorelease] );
	NSRect		badgedImageRect = { { 0.0, 0.0 }, [badgedImage size] };
	NSImage		*avatarImage = [[self contact] avatar];
	NSRect		avatarImageRect = { { 0.0, 0.0 }, [avatarImage size] };
	NSImage		*appIcon = [NSImage imageNamed:@"NSApplicationIcon"];
	NSRect		appIconSrcRect = { { 0.0, 0.0 }, [appIcon size] };
	float		appIconSize = 48.0;
	NSRect		appIconDstRect = NSMakeRect(NSWidth(badgedImageRect) - appIconSize - 2.0, 2.0, appIconSize, appIconSize);
	
	// Add the badges
	[badgedImage lockFocus];
	[avatarImage drawInRect:NSInsetRect(badgedImageRect, 4.0, 4.0)
				   fromRect:avatarImageRect
				  operation:NSCompositeDestinationOver
				   fraction:1.0];
	[appIcon drawInRect:appIconDstRect
			   fromRect:appIconSrcRect
			  operation:NSCompositeSourceOver
			   fraction:1.0];
	[badgedImage unlockFocus];
	
	[[self window] setMiniwindowImage:badgedImage];
}


- (void)p_notifyUserAboutReceivedMessage:(NSString *)msgText notificationsHandlerSelector:(SEL)selector
{
	NSWindow *win = [self window];
	
	// Notifications
	if (![NSApp isActive] || ![win isVisible]) {
		[[LPEventNotificationsHandler defaultHandler] performSelector:selector withObject:msgText withObject:[self contact]];
	}
	
	// Unread message accounting
	if (![win isKeyWindow]) {
		[self p_incrementUnreadMessagesCount];
	}
	
	if ([m_delegate respondsToSelector:@selector(chatControllerDidReceiveNewMessage:)]) {
		[m_delegate chatControllerDidReceiveNewMessage:self];
	}
}


#pragma mark -
#pragma mark WebView Frame Load Delegate Methods


- (void)webView:(WebView *)sender windowScriptObjectAvailable:(WebScriptObject *)windowScriptObject
{
	if (m_chatJSInterface == nil) {
		m_chatJSInterface = [[LPChatJavaScriptInterface alloc] init];
		[m_chatJSInterface setAccount:[[[self chat] activeContactEntry] account]];
	}
	
	/* Make it available to the WebView's JavaScript environment */
	[windowScriptObject setValue:m_chatJSInterface forKey:@"chatJSInterface"];
}


- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame
{
	[self p_updateChatBackgroundColorFromDefaults];
	[self p_setupChatDocumentTitle];
	
	[m_chatViewsController dumpQueuedMessagesToWebView];
	[m_chatViewsController showEmoticonsAsImages:[[NSUserDefaults standardUserDefaults] boolForKey:@"DisplayEmoticonImages"]];
}


#pragma mark WebView UI Delegate Methods


- (NSArray *)webView:(WebView *)sender contextMenuItemsForElement:(NSDictionary *)element defaultMenuItems:(NSArray *)defaultMenuItems
{
	if (sender == m_chatWebView) {
		NSMutableArray	*itemsToReturn = [NSMutableArray array];
		NSEnumerator	*enumerator = [defaultMenuItems objectEnumerator];
		id				menuItem;
		
		while ((menuItem = [enumerator nextObject]) != nil) {
			switch ([menuItem tag]) {
				case WebMenuItemTagCopyLinkToClipboard:
				case WebMenuItemTagCopy:
				case WebMenuItemTagSpellingGuess:
				case WebMenuItemTagNoGuessesFound:
				case WebMenuItemTagIgnoreSpelling:
				case WebMenuItemTagLearnSpelling:
				case WebMenuItemTagOther:
					[itemsToReturn addObject:menuItem];
					break;
			}
		}
		
		return itemsToReturn;
	}
	else {
		return [NSArray array];
	}
}


- (unsigned)webView:(WebView *)sender dragDestinationActionMaskForDraggingInfo:(id <NSDraggingInfo>)draggingInfo
{
	// We don't want the WebView to process anything dropped on it
	return WebDragDestinationActionNone;
}


- (unsigned)webView:(WebView *)sender dragSourceActionMaskForPoint:(NSPoint)point
{
	if (sender == m_pubBannerWebView)
		return WebDragSourceActionNone;
	else
		return WebDragSourceActionAny;
}


#pragma mark WebView Delegate Methods (Pub Stuff)


- (WebView *)webView:(WebView *)sender createWebViewWithRequest:(NSURLRequest *)request
{
	if (sender == m_pubBannerWebView) {
		/*
		 * We always get a nil request parameter in this method, it's probably a bug in WebKit or the Flash plug-in.
		 * In order to intercept the URL that WebKit is trying to open (so that we can redirect it to the system default
		 * web browser) we give it a dummy WebView if it wants to open a new window and make ourselves the WebPolicyDelegate
		 * for that dummy view in order to be able to intercept the URL being opened.
		 */
		WebView *myDummyPubViewAux = [[WebView alloc] init];
		[myDummyPubViewAux setPolicyDelegate:self];
		return myDummyPubViewAux;
	}
	else {
		return nil;
	}
}


- (void)webView:(WebView *)sender decidePolicyForNavigationAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request frame:(WebFrame *)frame decisionListener:(id<WebPolicyDecisionListener>)listener
{
	if (sender == m_chatWebView) {
		[[NSWorkspace sharedWorkspace] openURL:[request URL]];
		[listener ignore];
	}
	else if (sender == m_pubBannerWebView) {
		[listener use];
	}
	else {
		[[NSWorkspace sharedWorkspace] openURL:[request URL]];
		[listener ignore];
		[sender autorelease];
	}
}




#pragma mark -
#pragma mark NSWindow Delegate Methods


- (void)windowDidBecomeKey:(NSNotification *)aNotification
{
	NSWindow *win = [self window];
	
	if ([win level] > NSNormalWindowLevel) {
		[win setLevel:NSNormalWindowLevel];
		[win setAlphaValue:1.0];
	}
	
	[self p_resetUnreadMessagesCount];
}


- (void)windowWillClose:(NSNotification *)aNotification
{
	[self p_resetUnreadMessagesCount];
	
	// Undo the retain cycles we have established until now
	[m_audiblesController setChatController:nil];
	[m_chatWebView setChat:nil];
	
	[[m_chatWebView windowScriptObject] setValue:[NSNull null] forKey:@"chatJSInterface"];
	
	// If the WebView hasn't finished loading when the window is closed (extremely rare, but could happen), then we don't
	// want to do any of the setup that is about to happen in our frame load delegate methods, since the window is going away
	// anyway. If we allowed that setup to happen when the window is already closed it could originate some crashes, since
	// most of the stuff was already released by the time the delegate methods get called.
	[m_chatWebView setFrameLoadDelegate:nil];
	[m_chatWebView setUIDelegate:nil];
	[m_pubBannerWebView setFrameLoadDelegate:nil];
	[m_pubBannerWebView setUIDelegate:nil];
	
	// Make sure that the delayed perform of p_checkIfPubBannerIsNeeded doesn't fire
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(p_checkIfPubBannerIsNeeded) object:nil];
	
	// Stop auto-saving our chat transcript
	[self p_setSaveChatTranscriptEnabled:NO];
	
	// Make sure that the content views of our drawers do not leak! (This is a known issue with Cocoa: drawers leak
	// if their parent window is closed while they're open.)
	[[[aNotification object] drawers] makeObjectsPerformSelector:@selector(setContentView:) withObject:nil];
	[[[aNotification object] drawers] makeObjectsPerformSelector:@selector(close)];
	
	// Cancel the pending chat typing notification if there was some text already entered but not yet sent
	if (m_lastInputTextFieldStringLength > 0)
		[m_chat setUserIsTyping:NO];
	[m_chat endChat];
	[m_chat setDelegate:nil];
	
	if ([m_delegate respondsToSelector:@selector(chatControllerWindowWillClose:)]) {
		[m_delegate chatControllerWindowWillClose:self];
	}
}


- (id)windowWillReturnFieldEditor:(NSWindow *)sender toObject:(id)anObject
{
	// This provides support for drag'n'drop to an active text entry field
	if ([anObject isKindOfClass:[LPChatTextField class]])
		return [anObject customFieldEditor];
	else
		return nil;
}


#pragma mark -

#pragma mark NSControl Delegate Methods

- (void)controlTextDidChange:(NSNotification *)aNotification
{
	m_currentInputLineHistoryEntryIndex = 0;
	
	// Chat typing events
	NSUInteger currentStringLen = [[m_inputTextField stringValue] length];
	
	if (m_lastInputTextFieldStringLength == 0 && currentStringLen > 0) {
		// send composing event
		[[self chat] setUserIsTyping:YES];
	}
	else if (m_lastInputTextFieldStringLength > 0 && currentStringLen == 0) {
		// send cancellation of previous event
		[[self chat] setUserIsTyping:NO];
	}
	m_lastInputTextFieldStringLength = currentStringLen;
}


- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)command
{
	//NSLog(@"command: %@", NSStringFromSelector(command));
	
	if (command == @selector(pageDown:)						|| command == @selector(pageUp:)				||
		command == @selector(scrollPageDown:)				|| command == @selector(scrollPageUp:)			||
		command == @selector(moveToBeginningOfDocument:)	|| command == @selector(moveToEndOfDocument:)	||
		/* The following two selectors are undocumented. They're used by Cocoa to represent a Home or End key press. */
		command == @selector(scrollToBeginningOfDocument:)	|| command == @selector(scrollToEndOfDocument:)	 )
	{
		[[[m_chatWebView mainFrame] frameView] doCommandBySelector:command];
		return YES;
	}
	else if (command == @selector(moveUp:) || command == @selector(moveDown:)) {
		
		if (m_currentInputLineHistoryEntryIndex == 0) {
			if ([m_inputLineHistory count] > 0) {
				[m_inputLineHistory replaceObjectAtIndex:0 withObject:[m_inputTextField attributedStringValue]];
			}
			else {
				[m_inputLineHistory addObject:[m_inputTextField attributedStringValue]];
			}
		}
		
		if (command == @selector(moveUp:))
			m_currentInputLineHistoryEntryIndex = (m_currentInputLineHistoryEntryIndex + 1) % [m_inputLineHistory count];
		else
			m_currentInputLineHistoryEntryIndex = (m_currentInputLineHistoryEntryIndex > 0 ?
												   m_currentInputLineHistoryEntryIndex :
												   [m_inputLineHistory count]) - 1;
		
		[m_inputTextField setAttributedStringValue:[m_inputLineHistory objectAtIndex:m_currentInputLineHistoryEntryIndex]];
		[m_inputTextField performSelector:@selector(calcContentSize) withObject:nil afterDelay:0.0];
		
		return YES;
	}
	else {
		return NO;
	}
}


#pragma mark LPGrowingTextField Delegate Methods

- (void)growingTextField:(LPGrowingTextField *)textField contentSizeDidChange:(NSSize)neededSize
{
	[self p_resizeInputFieldToContentsSize:neededSize];
}


#pragma mark LPChatTextField Delegate Methods

- (BOOL)chatTextFieldShouldSupportFileDrops:(LPChatTextField *)tf
{
	return [[[self chat] activeContactEntry] canDoFileTransfer];
}

- (BOOL)chatTextField:(LPChatTextField *)tf sendFileWithPathname:(NSString *)filepath
{
	LPContactEntry *entry = [m_chat activeContactEntry];
	
	if ([entry canDoFileTransfer]) {
		[[LPFileTransfersManager fileTransfersManager] startSendingFile:filepath toContactEntry:entry];
		return YES;
	}
	else {
		return NO;
	}
}


#pragma mark -
#pragma mark NSToolbar Methods


- (void)p_setupToolbar 
{
	// Create a new toolbar instance
	NSToolbar *toolbar = [[NSToolbar alloc] initWithIdentifier:@"LPChatToolbar"];
	
	[toolbar setDisplayMode:NSToolbarDisplayModeIconOnly];
	[toolbar setSizeMode:NSToolbarSizeModeSmall];
	
	// Set up toolbar properties: Allow customization, give a default display mode, and remember state in user defaults 
	[toolbar setAllowsUserCustomization:YES];
	[toolbar setAutosavesConfiguration:YES];

	// We are the delegate.
	[toolbar setDelegate:self];
	
	// Attach the toolbar to the window.
	[[self window] setToolbar:toolbar];
	[toolbar release];
}


- (IBAction)p_openChatTranscriptsFolder:(id)sender
{
	NSString *folderPath = LPChatTranscriptsFolderPath();
	
	if (folderPath == nil) {
		NSBeep();
	}
	else {
		[[NSWorkspace sharedWorkspace] openFile:folderPath];
	}
}


- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)identifier willBeInsertedIntoToolbar:(BOOL)willBeInserted 
{
	// Create our toolbar items.
    NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:identifier];
	
	if ([identifier isEqualToString:ToolbarFileSendIdentifier])
	{
		[item setLabel:NSLocalizedString(@"Send File", @"toolbar button label")];
		[item setPaletteLabel:NSLocalizedString(@"Send File", @"toolbar button label")];
		[item setImage:[NSImage imageNamed:@"FileUpload"]];
		[item setToolTip:NSLocalizedString(@"Send File", @"toolbar button")];
		[item setAction:@selector(sendFile:)];
		[item setTarget:self];
	}
	else if ([identifier isEqualToString:ToolbarSendSMSIdentifier])
	{
		[item setLabel:NSLocalizedString(@"Send SMS", @"toolbar button label")];
		[item setPaletteLabel:NSLocalizedString(@"Send SMS", @"toolbar button label")];
		[item setImage:[NSImage imageNamed:@"sendSMS"]];
		[item setToolTip:NSLocalizedString(@"Send SMS", @"toolbar button")];
		[item setAction:@selector(sendSMS:)];
		[item setTarget:self];
	}
	else if ([identifier isEqualToString:ToolbarInfoIdentifier])
	{
		[item setLabel:NSLocalizedString(@"Get Info", @"toolbar button label")];
		[item setPaletteLabel:NSLocalizedString(@"Get Info", @"toolbar button label")];
		[item setImage:[NSImage imageNamed:@"info"]];
		[item setToolTip:NSLocalizedString(@"Get Info", @"toolbar button")];
		[item setAction:@selector(editContact:)];
		[item setTarget:self];
	}
	else if ([identifier isEqualToString:ToolbarHistoryIdentifier])
	{
		[item setLabel:NSLocalizedString(@"History", @"toolbar button label")];
		[item setPaletteLabel:NSLocalizedString(@"Chat History", @"toolbar button label")];
		[item setImage:[NSImage imageNamed:@"HistoryFolder"]];
		[item setToolTip:NSLocalizedString(@"Open chat history folder", @"toolbar button")];
		[item setAction:@selector(p_openChatTranscriptsFolder:)];
		[item setTarget:self];
	}
	else
	{
		// Invalid identifier!
		NSLog(@"WARNING: Invalid toolbar item identifier: %@", identifier);
		item = nil;
	}

	return [item autorelease];
}


- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar 
{
    return [NSArray arrayWithObjects:
		ToolbarInfoIdentifier,
		ToolbarFileSendIdentifier,
		ToolbarSendSMSIdentifier,
//		NSToolbarShowFontsItemIdentifier, 
//		NSToolbarShowColorsItemIdentifier,
		NSToolbarFlexibleSpaceItemIdentifier,
		ToolbarHistoryIdentifier,
		nil];
}


- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar 
{	
    return [NSArray arrayWithObjects:
		ToolbarInfoIdentifier,
		ToolbarFileSendIdentifier,
		ToolbarSendSMSIdentifier,
		ToolbarHistoryIdentifier,
		NSToolbarCustomizeToolbarItemIdentifier,
		NSToolbarFlexibleSpaceItemIdentifier,
		NSToolbarSeparatorItemIdentifier,
//		NSToolbarShowFontsItemIdentifier,
//		NSToolbarShowColorsItemIdentifier,
		NSToolbarSpaceItemIdentifier,
		NSToolbarPrintItemIdentifier,
		nil];
}


- (BOOL)validateToolbarItem:(NSToolbarItem *)theItem
{
	SEL action = [theItem action];
	
	if (action == @selector(sendSMS:)) {
		return ([m_contact canDoSMS] && [[LPAccountsController sharedAccountsController] isOnline]);
	}
	else {
		BOOL enabled = [self p_validateAction:action];
		
		if (action == @selector(sendFile:)) {
			if (enabled)
				[theItem setToolTip:NSLocalizedString(@"Send File", @"toolbar button")];
			else if ([m_contact canDoFileTransfer])
				[theItem setToolTip:NSLocalizedString(@"The currently selected address doesn't support file transfers. You can send a file by selecting another address of this contact in the pop-up menu below.", @"\"Send File\" button tooltip")];
			else
				[theItem setToolTip:NSLocalizedString(@"This contact doesn't support file transfers.", @"\"Send File\" button tooltip")];
		}
		
		return enabled;
	}
}


@end
