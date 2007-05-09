//
//  LPChatController.m
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Authors: Joao Pavao <jppavao@criticalsoftware.com>
//           Jason Kim <jason@512k.org>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "LPChatController.h"
#import "LPCommon.h"
#import "LPAccount.h"
#import "LPContact.h"
#import "LPContactEntry.h"
#import "LPChat.h"
#import "NSString+HTMLAdditions.h"
#import "LPEmoticonPicker.h"
#import "LPEmoticonSet.h"
#import "LPChatTextField.h"
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
#import "LPChatWebView.h"
#import "LPFileTransfer.h"

#import "NSString+URLScannerAdditions.h"
#import "NSString+HTMLAdditions.h"

#import <AddressBook/AddressBook.h>


// Toolbar item identifiers
static NSString *ToolbarInfoIdentifier				= @"ToolbarInfoIdentifier";
static NSString *ToolbarFileSendIdentifier			= @"ToolbarFileSendIdentifier";
static NSString *ToolbarSendSMSIdentifier			= @"ToolbarSendSMSIdentifier";
static NSString *ToolbarHistoryIdentifier			= @"ToolbarHistoryIdentifier";


// HTML snippets for each message kind
static NSString	*s_myMessageFormatString;
static NSString	*s_myContiguousMessageFormatString;
static NSString	*s_friendMessageFormatString;
static NSString	*s_friendContiguousMessageFormatString;


typedef enum {
	LPDontScroll,
	LPScrollWithAnimationIfConvenient,
	LPAlwaysScrollWithJumpOrAnimation,
	LPAlwaysScrollWithJump
} LPScrollToVisibleMode;


@interface LPChatController (Private)
- (void)p_setSendFieldHidden:(BOOL)hiddenFlag animate:(BOOL)animateFlag;

/*!
    @abstract   Getter for the queue of messages waiting to be appended to the WebView.
*/
- (NSMutableArray *)p_pendingMessagesQueue;
- (NSMutableSet *)p_pendingAudiblesSet;
- (BOOL)p_existsElementWithID:(NSString *)elementID;
- (void)p_setInnerHTML:(NSString *)innerHTML forElementWithID:(NSString *)elementID;
- (NSString *)p_HTMLForASCIIEmoticonSequence:(NSString *)asciiSequence fromEmoticonSet:(LPEmoticonSet *)emoticonSet useTextualRepresentationByDefault:(BOOL)useTextModeFlag;
- (NSString *)p_HTMLifyRawMessageString:(NSString *)rawString;
- (NSString *)p_HTMLStringForStandardBlockWithInnerHTML:(NSString *)innerHTML timestamp:(NSDate *)timestamp inbound:(BOOL)isInbound;
- (void)p_appendStandardMessageBlockWithInnerHTML:(NSString *)innerHTML timestamp:(NSDate *)timestamp inbound:(BOOL)isInbound saveInHistory:(BOOL)shouldSave scrollMode:(LPScrollToVisibleMode)scrollMode;

/*!
    @method     p_appendMessageToWebView:
    @abstract   Append a message to the WebView.
    @discussion If the WebView is completely loaded, append the message to the view. Otherwise, save the message
				in the pending messages queue (in the form of an NSInvocation) so that they can be dumped to the view
				at a later time, when it has finished loading the "base" HTML document.
*/
- (void)p_appendMessageToWebView:(NSString *)message subject:(NSString *)subject timestamp:(NSDate *)timestamp inbound:(BOOL)isInbound;
- (void)p_appendAudibleWithResourceName:(NSString *)resourceName inbound:(BOOL)inbound;
- (void)p_appendDIVBlockToWebViewWithInnerHTML:(NSString *)htmlContent divClass:(NSString *)class scrollToVisibleMode:(LPScrollToVisibleMode)scrollMode;
- (void)p_appendStoredRecentMessagesToWebView;

- (BOOL)p_isChatViewScrolledToBottom;
- (void)p_scrollWebViewToBottomWithAnimation:(BOOL)animate;
- (void)p_scrollAnimationStep:(NSTimer *)timer;
- (void)p_fireInvocationsWaitingForScrollingToFinish;
- (void)p_resizeInputFieldToContentsSize:(NSSize)newSize;
- (void)p_updateChatBackgroundColorFromDefaults;
- (void)p_setupToolbar;

/*!
    @abstract   Takes all the pending messages in the internal queue and appends them all to the WebView.
*/
- (void)p_dumpQueuedMessagesToWebView;

- (void)p_setupChatDocumentTitle;
- (NSString *)p_chatDocumentTitle;
- (BOOL)p_saveDocumentToFile:(NSString *)pathname hideExtension:(BOOL)hideExt error:(NSError **)errorPtr;

- (void)p_setSaveChatTranscriptEnabled:(BOOL)flag;

- (void)p_checkIfPubBannerIsNeeded;

- (void)p_incrementUnreadMessagesCount;
- (void)p_resetUnreadMessagesCount;
- (void)p_updateMiniwindowImage;
- (void)p_scheduleReceivedMessageNotificationForAfterScrollWithMessage:(NSString *)message notificationsHandlerSelector:(SEL)selector;
- (void)p_notifyUserAboutReceivedMessage:(NSString *)msgText notificationsHandlerSelector:(SEL)selector;
- (void)p_showEmoticonsAsImages:(BOOL)doShow;
@end


#pragma mark -


@implementation LPChatController

- initWithChat:(LPChat *)chat delegate:(id)delegate isIncoming:(BOOL)incomingFlag
{
	if (self = [self initWithWindowNibName:@"Chat"]) {
		m_chat = [chat retain];
		[chat setDelegate:self];
		
		m_contact = [[chat contact] retain];
		
		[self setDelegate:delegate];
		
		m_lastAppendedMessageKind = LPChatMessageKindNone;
		m_collapsedHeightWhenLastWentOffline = 0.0;
		
		if ((s_myMessageFormatString == nil) &&
			(s_myContiguousMessageFormatString == nil) &&
			(s_friendMessageFormatString == nil) &&
			(s_friendContiguousMessageFormatString == nil))
		{
			// load the HTML snippets for each message kind
			NSBundle *bundle = [NSBundle mainBundle];
			
			s_myMessageFormatString = [[NSString alloc] initWithContentsOfFile:
				[bundle pathForResource:@"MyMessage" ofType:@"html" inDirectory:@"ChatView"]];
			s_myContiguousMessageFormatString = [[NSString alloc] initWithContentsOfFile:
				[bundle pathForResource:@"MyContiguousMessage" ofType:@"html" inDirectory:@"ChatView"]];
			s_friendMessageFormatString = [[NSString alloc] initWithContentsOfFile:
				[bundle pathForResource:@"FriendMessage" ofType:@"html" inDirectory:@"ChatView"]];
			s_friendContiguousMessageFormatString = [[NSString alloc] initWithContentsOfFile:
				[bundle pathForResource:@"FriendContiguousMessage" ofType:@"html" inDirectory:@"ChatView"]];
		}
		
		// Setup KVO
		NSUserDefaultsController	*prefsCtrl = [NSUserDefaultsController sharedUserDefaultsController];
		
		[prefsCtrl addObserver:self forKeyPath:@"values.ChatBackgroundColor" options:0 context:NULL];
		[prefsCtrl addObserver:self forKeyPath:@"values.DisplayEmoticonImages" options:0 context:NULL];
		[m_contact addObserver:self forKeyPath:@"contactEntries" options:0 context:NULL];
		[m_contact addObserver:self forKeyPath:@"chatContactEntries" options:0 context:NULL];
		[m_contact addObserver:self forKeyPath:@"avatar" options:0 context:NULL];
		[m_chat addObserver:self forKeyPath:@"activeContactEntry" options:0 context:NULL];
		[m_chat addObserver:self forKeyPath:@"activeContactEntry.online" options:0 context:NULL];
		[[m_chat account] addObserver:self forKeyPath:@"online" options:0 context:NULL];
		
		
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
		
		m_dontMakeKeyOnFirstShowWindow = incomingFlag;
		
		m_invocationsToBeFiredWhenScrollingEnds = [[NSMutableArray alloc] init];
	}
	
	return self;
}


- initWithIncomingChat:(LPChat *)newChat delegate:(id)delegate
{
	return [self initWithChat:newChat delegate:delegate isIncoming:YES];
}


- initOutgoingWithContact:(LPContact *)contact delegate:(id)delegate
{
	LPChat *newChat = [[[contact roster] account] startChatWithContact:contact];
	
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
	NSUserDefaultsController	*prefsCtrl = [NSUserDefaultsController sharedUserDefaultsController];
	
	[[m_chat account] removeObserver:self forKeyPath:@"online"];
	[m_chat removeObserver:self forKeyPath:@"activeContactEntry.online"];
	[m_chat removeObserver:self forKeyPath:@"activeContactEntry"];
	[m_contact removeObserver:self forKeyPath:@"avatar"];
	[m_contact removeObserver:self forKeyPath:@"chatContactEntries"];
	[m_contact removeObserver:self forKeyPath:@"contactEntries"];
	[prefsCtrl removeObserver:self forKeyPath:@"values.ChatBackgroundColor"];
	[prefsCtrl removeObserver:self forKeyPath:@"values.DisplayEmoticonImages"];
	[prefsCtrl removeObserver:self forKeyPath:@"values.SaveChatTranscripts"];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[self setDelegate:nil];
	
	[m_autoSaveChatTranscriptTimer invalidate];
	[m_autoSaveChatTranscriptTimer release];
	
	[m_unreadMessagesBadge release];
	
	[m_scrollAnimationTimer invalidate];
	[m_scrollAnimationTimer release];
	[m_invocationsToBeFiredWhenScrollingEnds release];
	
	[m_chat release];
	[m_contact release];
	[m_pendingMessagesQueue release];
	[m_audibleResourceNamesWaitingForLoadCompletion release];
	[m_emoticonPicker release];
	[m_chatJSInterface release];
	[super dealloc];
}


- (NSAttributedString *)p_titleOfJIDMenuItemForContactEntry:(LPContactEntry *)entry
{
	NSAttributedString *retStr = nil;
	
	if ([entry isOnline]) {
		retStr = [[NSAttributedString alloc] initWithString:[entry humanReadableAddress]];
	}
	else {
		NSString *menuTitle = [NSString stringWithFormat:@"%@ %C Offline", [entry humanReadableAddress], 0x2014 /* em-dash */];
		NSDictionary *attribs = [NSDictionary dictionaryWithObject:[NSColor grayColor]
															forKey:NSForegroundColorAttributeName];
		retStr = [[NSAttributedString alloc] initWithString:menuTitle attributes:attribs];
	}
	
	return [retStr autorelease];
}


- (void)p_loadWebViewContent
{
	NSString *webViewContentPath = [[NSBundle mainBundle] pathForResource:@"ChatView"
																   ofType:@"html"
															  inDirectory:@"ChatView"];
	
	NSMutableString *webViewContentString = [NSMutableString stringWithContentsOfFile:webViewContentPath
																			 encoding:NSUTF8StringEncoding
																				error:NULL];
	
	// Insert the user CSS and JS files
	NSArray *libDirs = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
	if ([libDirs count] > 0) {
		NSString *libDirPath = [libDirs objectAtIndex:0];
		NSString *ourAppName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleExecutable"];
		NSString *appSpecificDirPath = [libDirPath stringByAppendingPathComponent:ourAppName];
		
		NSString *userCSSFilePath = [appSpecificDirPath stringByAppendingPathComponent:@"user.css"];
		NSString *userJSFilePath  = [appSpecificDirPath stringByAppendingPathComponent:@"user.js"];
		NSString *userCSSURLStr = [[NSURL fileURLWithPath:userCSSFilePath] absoluteString];
		NSString *userJSURLStr  = [[NSURL fileURLWithPath:userJSFilePath] absoluteString];
		
		[webViewContentString replaceOccurrencesOfString:@"%%USER_STYLESHEET_FILE%%"
											  withString:userCSSURLStr
												 options:NSLiteralSearch
												   range:NSMakeRange(0, [webViewContentString length])];
		[webViewContentString replaceOccurrencesOfString:@"%%USER_JAVASCRIPT_FILE%%"
											  withString:userJSURLStr
												 options:NSLiteralSearch
												   range:NSMakeRange(0, [webViewContentString length])];
	}
	
	/*
	 * Using -[WebFrame loadHTMLString:baseURL:] to load the content of the WebView introduces some new
	 * issues that didn't use to happen when we were using -[WebFrame loadRequest:]. Namely, saved web
	 * archive files (generated by the "Save As..." command, for example) seem to be losing track of
	 * resources being referenced by relative paths in the base HTML file (they show with a 'applewebdata://'
	 * URL scheme in Safari's "Activity" window), even though we're supplying a base URL via the "baseURL:"
	 * parameter. Inserting the base URL in the HTML code itself inside a '<base href="...">' tag apparently
	 * circumvents this issue, even though it should be completely redundant.
	 */
	
	NSURL *baseURL = [NSURL fileURLWithPath:[webViewContentPath stringByExpandingTildeInPath]];
	
	[webViewContentString replaceOccurrencesOfString:@"%%BASE_URL%%"
										  withString:[baseURL absoluteString]
											 options:NSLiteralSearch
											   range:NSMakeRange(0, [webViewContentString length])];
	
	[[m_chatWebView mainFrame] loadHTMLString:webViewContentString baseURL:baseURL];
}

- (void)windowDidLoad
{
	[m_chatController setContent:[self chat]];
	[m_contactController setContent:[self contact]];
	
	[self p_setupToolbar];
	
	[m_audiblesController setChatController:self];
	[m_chatWebView setChat:m_chat];
	
	[m_chatWebView setPreferencesIdentifier:[[NSBundle mainBundle] bundleIdentifier]];
	WebPreferences *prefs = [m_chatWebView preferences];
	[prefs setJavaEnabled:NO];
	[prefs setJavaScriptCanOpenWindowsAutomatically:NO];
	[prefs setJavaScriptEnabled:YES];
	[prefs setLoadsImagesAutomatically:YES];
	[prefs setPlugInsEnabled:YES];
	[prefs setShouldPrintBackgrounds:YES];
	
	[self p_loadWebViewContent];
	
	// Workaround for centering the icons.
	[m_segmentedButton setLabel:nil forSegment:0];
	[m_segmentedButton setLabel:nil forSegment:1];
	[[m_segmentedButton cell] setToolTip:NSLocalizedString(@"Choose Emoticon", @"") forSegment:0];
	[[m_segmentedButton cell] setToolTip:NSLocalizedString(@"Toggle Audibles Drawer", @"") forSegment:1];
	// IB displays a round segmented button that apparently needs less space than the on that ends up
	// showing in the app (the flat segmented button used in metal windows).
	[m_segmentedButton sizeToFit];
	
	[m_topControlsBar setBackgroundColor:
		[NSColor colorWithPatternImage:( [[m_chat activeContactEntry] isOnline] ?
										 [NSImage imageNamed:@"chatIDBackground"] :
										 [NSImage imageNamed:@"chatIDBackground_Offline"] )]];
	[m_topControlsBar setBorderColor:[NSColor colorWithCalibratedWhite:0.60 alpha:1.0]];
	
	[m_inputControlsBar setShadedBackgroundWithOrientation:LPVerticalBackgroundShading
											  minEdgeColor:[NSColor colorWithCalibratedWhite:0.79 alpha:1.0]
											  maxEdgeColor:[NSColor colorWithCalibratedWhite:0.99 alpha:1.0]];
	[m_inputControlsBar setBorderColor:[NSColor colorWithCalibratedWhite:0.80 alpha:1.0]];
	
	
	[m_pubElementsView setShadedBackgroundWithOrientation:LPVerticalBackgroundShading
											 minEdgeColor:[NSColor colorWithCalibratedWhite:0.79 alpha:1.0]
											 maxEdgeColor:[NSColor colorWithCalibratedWhite:0.49 alpha:1.0]];
	
	// Show the PUB banner only for contacts with the corresponding capability.
	// Check only some seconds from now so that the core has time to fetch the capabilities of the contact.
	[self performSelector:@selector(p_checkIfPubBannerIsNeeded) withObject:nil afterDelay:3.0];
	
	// Initialize the addresses popup
	[m_addressesPopUp removeAllItems];
	
	NSEnumerator *entryEnum = [[m_contact chatContactEntries] objectEnumerator];
	LPContactEntry *entry;
	while (entry = [entryEnum nextObject]) {
		[m_addressesPopUp addItemWithTitle:@""];
		
		id item = [m_addressesPopUp lastItem];
		[item setAttributedTitle:[self p_titleOfJIDMenuItemForContactEntry:entry]];
		[item setRepresentedObject:entry];
		[item setTarget:self];
		[item setAction:@selector(selectChatAddress:)];
	}
	[m_addressesPopUp selectItemAtIndex:[m_addressesPopUp indexOfItemWithRepresentedObject:[m_chat activeContactEntry]]];
	
	// Post the saved recent messages
	[self p_appendStoredRecentMessagesToWebView];
	/*
	 * Appending the stored recent messages makes use of the m_lastAppendedMessageKind instance variable to help select
	 * the style of the headers for the message blocks. We now reset that instance variable back to its initial state,
	 * which results in getting the next message interpreted as if it was the first one (which it actually is), thus
	 * getting a big header and a special kind of Growl notification.
	 */
	m_lastAppendedMessageKind = LPChatMessageKindNone;

	if ([m_chat activeContactEntry]) {
		// Post a "system message" to start
		NSString *initialSystemMessage = [NSString stringWithFormat:NSLocalizedString(@"Chat started with contact \"%@\"", @"status message written to the text transcript of a chat window"),
			[[m_chat activeContactEntry] humanReadableAddress]];
		[self p_appendDIVBlockToWebViewWithInnerHTML:[initialSystemMessage stringByEscapingHTMLEntities]
											divClass:@"systemMessage"
								 scrollToVisibleMode:LPAlwaysScrollWithJumpOrAnimation];
	}
	else {
		[m_addressesPopUp setEnabled:NO];
	}
	
	
	[self p_setSendFieldHidden:(![[m_chat account] isOnline] || [m_chat activeContactEntry] == nil)
					   animate:NO];
	[self p_updateMiniwindowImage];
}


- (void)showWindow:(id)sender
{
	if (![self isWindowLoaded] && m_dontMakeKeyOnFirstShowWindow) {
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


- (LPContact *)contact
{
    return [[m_contact retain] autorelease]; 
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
		[self p_showEmoticonsAsImages:displayImages];
	}
	else if ([keyPath isEqualToString:@"values.SaveChatTranscripts"]) {
		NSUserDefaultsController *prefsCtrl = [NSUserDefaultsController sharedUserDefaultsController];
		[self p_setSaveChatTranscriptEnabled:[[prefsCtrl valueForKeyPath:@"values.SaveChatTranscripts"] boolValue]];
	}
	else if ([keyPath isEqualToString:@"contactEntries"]) {
		// Check whether all JIDs have been removed.
		if ([[m_contact contactEntries] count] == 0) {
			[self performSelector:@selector(close) withObject:nil afterDelay:0.0];
		}
	}
	else if ([keyPath isEqualToString:@"chatContactEntries"]) {
		NSNumber *changeKind = [change objectForKey:NSKeyValueChangeKindKey];
		NSIndexSet *changedIndexes = [change objectForKey:NSKeyValueChangeIndexesKey];
		
		if ([changeKind intValue] == NSKeyValueChangeInsertion) {
			if (![m_addressesPopUp isEnabled] &&
				([m_addressesPopUp numberOfItems] == 1) &&
				[[[m_addressesPopUp itemAtIndex:0] title] isEqualToString:@""])
			{
				// Remove the blank placeholder which is used to clear the text displayed in the menu
				[m_addressesPopUp removeItemAtIndex:0];
			}
			[m_addressesPopUp setEnabled:YES];
			
			unsigned idx = [changedIndexes firstIndex];
			while (idx != NSNotFound) {
				LPContactEntry *addedEntry = [[m_contact chatContactEntries] objectAtIndex:idx];
				[m_addressesPopUp insertItemWithTitle:@"" atIndex:idx];
				
				id item = [m_addressesPopUp itemAtIndex:idx];
				[item setAttributedTitle:[self p_titleOfJIDMenuItemForContactEntry:addedEntry]];
				[item setRepresentedObject:addedEntry];
				[item setTarget:self];
				[item setAction:@selector(selectChatAddress:)];
				
				idx = [changedIndexes indexGreaterThanIndex:idx];
			}
		}
		else if ([changeKind intValue] == NSKeyValueChangeRemoval) {
			unsigned idx = [changedIndexes lastIndex];
			while (idx != NSNotFound) {
				[m_addressesPopUp removeItemAtIndex:idx];
				idx = [changedIndexes indexLessThanIndex:idx];
			}
			
			if ([m_addressesPopUp numberOfItems] == 0) {
				// Add a blank placeholder which is used to clear the text displayed in the menu
				[m_addressesPopUp insertItemWithTitle:@"" atIndex:0];
				[m_addressesPopUp setEnabled:NO];
			}
		}
	}
	else if ([keyPath isEqualToString:@"avatar"]) {
		[self p_updateMiniwindowImage];
	}
	else if ([keyPath isEqualToString:@"activeContactEntry"] || [keyPath isEqualToString:@"activeContactEntry.online"]) {
		
		[self p_setSendFieldHidden:(![[m_chat account] isOnline] || [m_chat activeContactEntry] == nil)
						   animate:YES];
		
		LPContactEntry *entry = [m_chat activeContactEntry];
		int idx = [m_addressesPopUp indexOfItemWithRepresentedObject:entry];
		
		if (idx >= 0)
			[[m_addressesPopUp itemAtIndex:idx] setAttributedTitle:[self p_titleOfJIDMenuItemForContactEntry:entry]];
		
		[m_topControlsBar setBackgroundColor:
			[NSColor colorWithPatternImage:( [entry isOnline] ?
											 [NSImage imageNamed:@"chatIDBackground"] :
											 [NSImage imageNamed:@"chatIDBackground_Offline"] )]];
		
		if ([keyPath isEqualToString:@"activeContactEntry"]) {
			if (idx >= 0) [m_addressesPopUp selectItemAtIndex:idx];
			
			// Post a "system message" to signal the change
			NSString *systemMessage;
			if (entry) {
				systemMessage = [NSString stringWithFormat:NSLocalizedString(@"Chat changed to contact \"%@\"", @"status message written to the text transcript of a chat window"),
					[entry humanReadableAddress]];
			}
			else {
				systemMessage = [NSString stringWithFormat:NSLocalizedString(@"Chat ended.", @"status message written to the text transcript of a chat window")];
			}
			
			[self p_appendDIVBlockToWebViewWithInnerHTML:[systemMessage stringByEscapingHTMLEntities]
												divClass:@"systemMessage"
									 scrollToVisibleMode:LPScrollWithAnimationIfConvenient];
		}
		
		// Make sure the toolbar items are correctly enabled/disabled
		[[self window] update];
	}
	else if ([keyPath isEqualToString:@"online"]) {
		// Account online status
		[self p_setSendFieldHidden:(![[object valueForKeyPath:keyPath] boolValue] || [m_chat activeContactEntry] == nil)
						   animate:YES];
	}
	else {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}


- (void)sendAudibleWithResourceName:(NSString *)audibleName
{
	[self p_appendAudibleWithResourceName:audibleName inbound:NO];
	[m_chat sendAudibleWithResourceName:audibleName];
}


- (IBAction)pickEmoticonWithMenuTopRightAt:(NSPoint)topRight
{
	NSWindow *win = [self window];
	
	if (m_emoticonPicker == nil) {
		m_emoticonPicker = [[LPEmoticonPicker alloc] initWithEmoticonSet:[LPEmoticonSet defaultEmoticonSet]];
	}
	
	int pickedEmoticonNr = [m_emoticonPicker pickEmoticonNrUsingTopRightPoint:topRight parentWindow:win];
	
	if (pickedEmoticonNr != LPEmoticonPickerNoneSelected) {
		// Insert the selected emoticon into the input text field
		
		NSAttributedString	*emoticonString =
			[NSAttributedString attributedStringWithAttachmentForEmoticonNr:pickedEmoticonNr
																emoticonSet:[LPEmoticonSet defaultEmoticonSet]
															 emoticonHeight:0.0 // use the image size
															 baselineOffset:-7.0];
		NSTextView			*fieldEditor = (NSTextView *)[m_inputTextField currentEditor];
		NSTextStorage		*storage = nil;
		NSRange				rangeToReplace;
		
		if (fieldEditor != nil) {
			// We are being edited: replace the current selection
			storage = [fieldEditor textStorage];
			rangeToReplace = [fieldEditor selectedRange];
		}
		else {
			// We are not being edited: append the smiley to the end
			[win makeFirstResponder:m_inputTextField];
			
			fieldEditor = (NSTextView *)[m_inputTextField currentEditor];
			storage = [fieldEditor textStorage];
			rangeToReplace = NSMakeRange([storage length], 0); // the end of the string
		}
		
		NSDictionary *savedAttribs = [fieldEditor typingAttributes];
		
		[m_inputTextField setImportsGraphics:YES];
		[storage beginEditing];
		[storage replaceCharactersInRange:rangeToReplace withAttributedString:emoticonString];
		[storage endEditing];
		[m_inputTextField setImportsGraphics:NO];
		[fieldEditor didChangeText];
		
		// Place the insertion point right after the newly inserted emoticon
		NSRange afterEmoticonRange = NSMakeRange(rangeToReplace.location + [emoticonString length], 0);
		[fieldEditor setSelectedRange:afterEmoticonRange];
		[fieldEditor scrollRangeToVisible:afterEmoticonRange];
		
		[fieldEditor setTypingAttributes:savedAttribs];
	}
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
				
				if (![self p_existsElementWithID:elementID]) {
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
					[self p_setInnerHTML:NSLocalizedString(@"", @"") forElementWithID:elementID];
				}
					
				break;
			}
				
			case LPFileTransferWasNotAccepted:
			{
				NSString *elementID = [NSString stringWithFormat:@"fileTransfer_%d", transferID];
				[self p_setInnerHTML:NSLocalizedString(@"<b>(rejected)</b>", @"") forElementWithID:elementID];
				break;
			}
				
			case LPFileTransferRunning:
			{
				NSString *elementID = [NSString stringWithFormat:@"fileTransfer_%d", transferID];
				[self p_setInnerHTML:NSLocalizedString(@"<b>(transferring...)</b>", @"") forElementWithID:elementID];
				break;
			}
				
			case LPFileTransferAbortedWithError:
			{
				NSString *elementID = [NSString stringWithFormat:@"fileTransfer_%d", transferID];
				NSString *formatStr = NSLocalizedString(@"<b>(error: %@)</b>", @"");
				NSString *html = [NSString stringWithFormat:formatStr, [[ft lastErrorMessage] stringByEscapingHTMLEntities]];
				[self p_setInnerHTML:html forElementWithID:elementID];
				
				divClass = @"systemMessage";
				htmlText = [NSString stringWithFormat:
					NSLocalizedString(@"Transfer of file %@ was <b>aborted</b> with an error: %@.", @""),
					[self p_fileNameHTMLForFileTransfer:ft], [[ft lastErrorMessage] stringByEscapingHTMLEntities]];
				break;
			}
				
			case LPFileTransferCancelled:
			{
				NSString *elementID = [NSString stringWithFormat:@"fileTransfer_%d", transferID];
				[self p_setInnerHTML:NSLocalizedString(@"<b>(cancelled)</b>", @"") forElementWithID:elementID];
				
				divClass = @"systemMessage";
				htmlText = [NSString stringWithFormat:
					NSLocalizedString(@"Transfer of file %@ was <b>cancelled</b>.", @""),
					[self p_fileNameHTMLForFileTransfer:ft]];
				break;
			}
				
			case LPFileTransferCompleted:
			{
				NSString *elementID = [NSString stringWithFormat:@"fileTransfer_%d", transferID];
				[self p_setInnerHTML:NSLocalizedString(@"<b>(completed)</b>", @"") forElementWithID:elementID];
				
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
			[self p_appendDIVBlockToWebViewWithInnerHTML:htmlText
												divClass:divClass
									 scrollToVisibleMode:LPScrollWithAnimationIfConvenient];
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
		[self pickEmoticonWithMenuTopRightAt:NSMakePoint(topRight.x + [sender widthForSegment:clickedSegment],
														 topRight.y)];
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
	NSString *message = [[m_inputTextField attributedStringValue] stringByFlatteningAttachedEmoticons];
	
	// Check if the text is all made of whitespace.
	static NSCharacterSet *requiredCharacters = nil;
	if (requiredCharacters == nil) {
		requiredCharacters = [[[NSCharacterSet whitespaceAndNewlineCharacterSet] invertedSet] retain];
	}
	
	if ([message rangeOfCharacterFromSet:requiredCharacters].location != NSNotFound) {
		[self p_appendMessageToWebView:message subject:nil timestamp:[NSDate date] inbound:NO];
		[m_chat sendMessageWithPlainTextVariant:message XHTMLVariant:nil URLs:nil];
	}
	
	[[self window] makeFirstResponder:m_inputTextField];
	[m_inputTextField setStringValue:@""];
	[m_inputTextField calcContentSize];
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
			[[m_chat account] startSendingFile:[panel filename] toContactEntry:[m_chat activeContactEntry]];
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
						  file:[self p_chatDocumentTitle]
				modalForWindow:[self window]
				 modalDelegate:self
				didEndSelector:@selector(p_savePanelDidEnd:returnCode:contextInfo:)
				   contextInfo:NULL];
}


- (void)p_savePanelDidEnd:(NSSavePanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	if (returnCode == NSOKButton) {
		NSError *error;
		if (![self p_saveDocumentToFile:[sheet filename] hideExtension:[sheet isExtensionHidden] error:&error]) {
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


- (BOOL)p_validateAction:(SEL)action
{
	if (action == @selector(sendSMS:)) {
		return ([m_contact canDoSMS] &&
				[[m_chat account] isOnline]);
	}
	else if (action == @selector(sendFile:)) {
		return ([[m_chat activeContactEntry] canDoFileTransfer] &&
				[[m_chat activeContactEntry] isOnline]);
	}
	else {
		return YES;
	}
}


- (BOOL)validateMenuItem:(id <NSMenuItem>)menuItem
{
	SEL action = [menuItem action];
	
	if (action == @selector(selectChatAddress:)) {
		// JID selection pop-up menu items
		[menuItem setAttributedTitle:[self p_titleOfJIDMenuItemForContactEntry:[menuItem representedObject]]];
		return YES;
	}
	else {
		return [self p_validateAction:action];
	}
}


#pragma mark -
#pragma mark LPChat Delegate Methods


- (void)chat:(LPChat *)chat didReceiveErrorMessage:(NSString *)message
{
	// Post a "system message"
	NSString *systemMessage = [NSString stringWithFormat:@"ERROR: %@", message];
	[self p_appendDIVBlockToWebViewWithInnerHTML:[systemMessage stringByEscapingHTMLEntities]
										divClass:@"systemMessage"
							 scrollToVisibleMode:LPScrollWithAnimationIfConvenient];
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
	[self p_scheduleReceivedMessageNotificationForAfterScrollWithMessage:messageBody
											notificationsHandlerSelector:( (m_lastAppendedMessageKind == LPChatMessageKindNone) ?
																		   @selector(notifyReceptionOfFirstMessage:fromContact:) :
																		   @selector(notifyReceptionOfMessage:fromContact:)      )];
	
	[self p_appendMessageToWebView:messageBody subject:subject timestamp:[NSDate date] inbound:YES];
}


- (void)chat:(LPChat *)chat didReceiveSystemMessage:(NSString *)message
{
	// Post a "system message"
	NSString *systemMessage = [NSString stringWithFormat:@"System Message: %@", message];
	[self p_appendDIVBlockToWebViewWithInnerHTML:[systemMessage stringByEscapingHTMLEntities]
										divClass:@"systemMessage"
							 scrollToVisibleMode:LPScrollWithAnimationIfConvenient];
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
			NSLocalizedString(@"SMS <b>sent</b> to \"%@\" at %@<br/>Used: %d message(s), total of %d characters.", @""),
			[phoneNr stringByEscapingHTMLEntities],
			[[NSDate date] descriptionWithCalendarFormat:@"%H:%M:%S" timeZone:nil locale:nil],
			//[msgBody stringByEscapingHTMLEntities],
			nrUsedMsgs, nrUsedChars
			//newCredit, newFreeMessages, newTotalSentThisMonth
			];
	}
	else {
		// Failure
		htmlText = [NSString stringWithFormat:
			NSLocalizedString(@"<b>Failed</b> to send SMS to \"%@\" at %@.", @""),
			[phoneNr stringByEscapingHTMLEntities],
			[[NSDate date] descriptionWithCalendarFormat:@"%H:%M:%S" timeZone:nil locale:nil]];
	}
	
	[self p_appendDIVBlockToWebViewWithInnerHTML:htmlText
										divClass:@"smsSentReplyBlock"
							 scrollToVisibleMode:LPScrollWithAnimationIfConvenient];
}


- (void)chat:(LPChat *)chat didReceiveSMSFrom:(NSString *)sourcePhoneNr withBody:(NSString *)msgBody date:(NSDate *)date newCredit:(int)newCredit newFreeMessages:(int)newFreeMessages newTotalSentThisMonth:(int)newTotalSentThisMonth
{
	// DEBUG:
	//	NSString *text = [NSString stringWithFormat:@"SMS RECEIVED on %@ from %@: \"%@\". New credit: %d , new free msgs: %d , new total sent: %d", date, sourcePhoneNr, msgBody, newCredit, newFreeMessages, newTotalSentThisMonth];
	
	NSString *phoneNr = ( [sourcePhoneNr isPhoneJID] ?
						  [sourcePhoneNr userPresentablePhoneNrRepresentation] :
						  sourcePhoneNr );
	NSString *htmlText = [NSString stringWithFormat:
		NSLocalizedString(@"SMS <b>received</b> from \"%@\" at %@<br/>\"<b>%@</b>\"", @""),
		// We don't use the date provided by the server because it is nil sometimes
		[phoneNr stringByEscapingHTMLEntities],
		[[NSDate date] descriptionWithCalendarFormat:@"%H:%M:%S" timeZone:nil locale:nil],
		[self p_HTMLifyRawMessageString:msgBody]];
	
	// Don't do everything at the same time. Allow the scroll animation to run first so that it doesn't appear choppy.
	[self p_scheduleReceivedMessageNotificationForAfterScrollWithMessage:msgBody
											notificationsHandlerSelector:@selector(notifyReceptionOfSMSMessage:fromContact:)];
	
	[self p_appendDIVBlockToWebViewWithInnerHTML:htmlText
										divClass:@"smsReceivedReplyBlock"
							 scrollToVisibleMode:LPScrollWithAnimationIfConvenient];
	
	[[LPRecentMessagesStore sharedMessagesStore] storeRawHTMLBlock:htmlText
													  withDIVClass:@"smsReceivedReplyBlock"
															forJID:[[m_chat activeContactEntry] address]];
}


- (void)chat:(LPChat *)chat didReceiveAudibleWithResourceName:(NSString *)resourceName
{
	LPAudibleSet *set = [LPAudibleSet defaultAudibleSet];
	NSString *localPath = [set filepathForAudibleWithName:resourceName];
	
	if (localPath == nil) {
		// We don't have this audible in local storage yet. Start loading it and insert it into the webview later.
		
		[[self p_pendingAudiblesSet] addObject:resourceName];
		[set startLoadingAudibleFromServer:resourceName];
	} else {
		[self p_appendAudibleWithResourceName:resourceName inbound:YES];
	}
}


- (void)chatContactDidStartTyping:(LPChat *)chat
{
#warning TO DO: chatContactDidStartTyping
	NSLog(@"Contact did start typing...");
}


- (void)chatContactDidStopTyping:(LPChat *)chat
{
#warning TO DO: chatContactDidStopTyping
	NSLog(@"Contact did stop typing...");
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
	}
}


- (NSMutableArray *)p_pendingMessagesQueue
{
	if (m_pendingMessagesQueue == nil) {
		m_pendingMessagesQueue = [[NSMutableArray alloc] init];
	}
	return m_pendingMessagesQueue;
}


- (NSMutableSet *)p_pendingAudiblesSet
{
	if (m_audibleResourceNamesWaitingForLoadCompletion == nil) {
		m_audibleResourceNamesWaitingForLoadCompletion = [[NSMutableSet alloc] init];
	}
	return m_audibleResourceNamesWaitingForLoadCompletion;
}


- (BOOL)p_existsElementWithID:(NSString *)elementID
{
	DOMHTMLDocument *domDoc = (DOMHTMLDocument *)[[m_chatWebView mainFrame] DOMDocument];
	DOMHTMLElement  *elem = (DOMHTMLElement *)[domDoc getElementById:elementID];
	
	return (elem != nil);
}

- (void)p_setInnerHTML:(NSString *)innerHTML forElementWithID:(NSString *)elementID
{
	DOMHTMLDocument *domDoc = (DOMHTMLDocument *)[[m_chatWebView mainFrame] DOMDocument];
	DOMHTMLElement  *elem = (DOMHTMLElement *)[domDoc getElementById:elementID];
	
	// If the user has manually scrolled up to read something else we shouldn't scroll automatically.
	BOOL isScrolledToBottom = [self p_isChatViewScrolledToBottom];
	
	[elem setInnerHTML:innerHTML];
	
	if (isScrolledToBottom)
		[self p_scrollWebViewToBottomWithAnimation:NO];
}


- (NSString *)p_HTMLForASCIIEmoticonSequence:(NSString *)asciiSequence
							 fromEmoticonSet:(LPEmoticonSet *)emoticonSet
		   useTextualRepresentationByDefault:(BOOL)useTextModeFlag
{
	NSString *imageAbsolutePath = [emoticonSet absolutePathOfImageResourceForEmoticonWithASCIISequence:asciiSequence];
	NSString *imageURLStr = [[NSURL fileURLWithPath:imageAbsolutePath] absoluteString];
	
	return [NSString stringWithFormat:
		@"<span class=\"emoticonImage\"><img src=\"%@\" style=\"vertical-align: middle;\" /></span>"
		@"<span class=\"emoticonText\">%@</span>",
		imageURLStr, asciiSequence];
}


- (NSString *)p_HTMLifyRawMessageString:(NSString *)rawString
{
	NSRange			nextURLRange, nextEmoticonRange, nextFoundURLOrEmoticonRange;
	LPEmoticonSet	*emoticonSet = [LPEmoticonSet defaultEmoticonSet];
	unsigned int	currentLocation = 0;
	unsigned int	remainingLength = [rawString length];
	NSMutableString	*resultString = [NSMutableString string];
	
	// Only do emoticon substitution when there are no newline characters in the rawString
	BOOL hasNewlines = ([rawString rangeOfString:@"\n"].location != NSNotFound);
	
	// Should we display emoticons using images or text?
	BOOL displayEmoticonsUsingImages = [[NSUserDefaults standardUserDefaults] boolForKey:@"DisplayEmoticonImages"];
	
	do {
		NSString *normalizedURLString;
		NSRange searchRange = NSMakeRange(currentLocation, remainingLength);
		
		// Find the next URL...
		nextURLRange = [rawString rangeOfNextURLInRange:searchRange normalizedURLString:&normalizedURLString];
		
		// ...and the next emoticon!
		// Only do emoticon substitution when there are no newline characters in the rawString
		nextEmoticonRange = ( hasNewlines ?
							  NSMakeRange(NSNotFound, 0) :
							  [rawString rangeOfNextDelimitedEmoticonFromEmoticonSet:emoticonSet range:searchRange] );
		
		// Pick the one that occurs sooner
		nextFoundURLOrEmoticonRange = ( ( nextURLRange.location != NSNotFound &&
										  ( nextEmoticonRange.location == NSNotFound ||
											nextURLRange.location < nextEmoticonRange.location ) ) ?
										nextURLRange :
										nextEmoticonRange );
		
		
		unsigned int stringBeforeURLOrEmoticonLength = ( nextFoundURLOrEmoticonRange.location == NSNotFound ?
														 remainingLength :
														 nextFoundURLOrEmoticonRange.location - currentLocation );
		
		NSString *stringBeforeURLOrEmoticon = [rawString substringWithRange:NSMakeRange(currentLocation,
																						stringBeforeURLOrEmoticonLength)];
		
		// Escape the user text
		[resultString appendString:[stringBeforeURLOrEmoticon stringByEscapingHTMLEntities]];
		
		// Insert the "special entity" (URL or Emoticon)
		if (nextFoundURLOrEmoticonRange.location == nextURLRange.location && nextURLRange.location != NSNotFound) {
			// Wrap the URL in the corresponding HTML tags
			[resultString appendFormat:@"<a href=\"javascript:window.chatJSInterface.openURL('%@');\">%@</a>",
				normalizedURLString, [rawString substringWithRange:nextURLRange]];
		}
		else if (nextFoundURLOrEmoticonRange.location == nextEmoticonRange.location && nextEmoticonRange.location != NSNotFound) {
			NSString *HTMLStr = [self p_HTMLForASCIIEmoticonSequence:[rawString substringWithRange:nextEmoticonRange]
													 fromEmoticonSet:emoticonSet
								   useTextualRepresentationByDefault:(!displayEmoticonsUsingImages)];
			
			[resultString appendString:HTMLStr];
		}
		
		currentLocation += (nextFoundURLOrEmoticonRange.length + stringBeforeURLOrEmoticonLength);
		remainingLength -= (nextFoundURLOrEmoticonRange.length + stringBeforeURLOrEmoticonLength);
	} while (nextFoundURLOrEmoticonRange.location != NSNotFound);
	
	return ( hasNewlines ?
			 // Output pre-formatted text
			 [NSString stringWithFormat:@"<div class=\"textWithLinebreaks\">%@</div>", resultString] :
			 (NSString *)resultString );
}


- (NSString *)p_HTMLStringForStandardBlockWithInnerHTML:(NSString *)innerHTML timestamp:(NSDate *)timestamp inbound:(BOOL)isInbound
{
	// Determine the format that is going to be used to print the message
	NSString *formatString = @"";
	
	if (isInbound) {
		formatString = ( (m_lastAppendedMessageKind == LPChatMessageKindFriend) ?
						 s_friendContiguousMessageFormatString :
						 s_friendMessageFormatString );
		m_lastAppendedMessageKind = LPChatMessageKindFriend;
	} else {
		formatString = ( (m_lastAppendedMessageKind == LPChatMessageKindMine) ?
						 s_myContiguousMessageFormatString :
						 s_myMessageFormatString );
		m_lastAppendedMessageKind = LPChatMessageKindMine;
	}
	
	BOOL containsContactName = ( (formatString == s_myMessageFormatString)     ||
								 (formatString == s_friendMessageFormatString)   );
	
	NSString *name = @"";
	
	if (containsContactName) {
		if (isInbound) {
			name = [m_contact name];
		} else {
			name = [[m_chat account] name];
			if (name == nil || [name length] == 0) {
				name = [[m_chat account] JID];
			}
		}
	}
	
	// Get a string with the current time
	// NSString *timeFormatString = [[NSUserDefaults standardUserDefaults] objectForKey:NSTimeFormatString];
	NSString *timeFormatString = @"%H:%M:%S"; // Force 24h display format
	NSString *timestampStr = [timestamp descriptionWithCalendarFormat:timeFormatString timeZone:nil locale:nil];
	
	NSString *escapedName = [name stringByEscapingHTMLEntities];
	NSString *escapedTimestamp = [timestampStr stringByEscapingHTMLEntities];
	
	return ( containsContactName ?
			 [NSString stringWithFormat:formatString, escapedTimestamp, escapedName, innerHTML] :
			 [NSString stringWithFormat:formatString, escapedTimestamp, innerHTML] );
}


- (void)p_appendStandardMessageBlockWithInnerHTML:(NSString *)innerHTML timestamp:(NSDate *)timestamp inbound:(BOOL)isInbound saveInHistory:(BOOL)shouldSave scrollMode:(LPScrollToVisibleMode)scrollMode
{
	NSString *htmlString = [self p_HTMLStringForStandardBlockWithInnerHTML:innerHTML timestamp:timestamp inbound:isInbound];
	
	// if it's an outbound message, also scroll down so that the user can see what he has just written
	[self p_appendDIVBlockToWebViewWithInnerHTML:htmlString divClass:@"messageBlock" scrollToVisibleMode:scrollMode];
	
	// Save in the recent history log
	if (shouldSave) {
		if (isInbound) {
			[[LPRecentMessagesStore sharedMessagesStore] storeMessage:innerHTML
													  receivedFromJID:[[m_chat activeContactEntry] address]];
		} else {
			[[LPRecentMessagesStore sharedMessagesStore] storeMessage:innerHTML
															sentToJID:[[m_chat activeContactEntry] address]];
		}
	}
}


- (void)p_appendMessageToWebView:(NSString *)message subject:(NSString *)subject timestamp:(NSDate *)timestamp inbound:(BOOL)isInbound
{
	NSString *messageHTML = [self p_HTMLifyRawMessageString:message];
	
	if ([subject length] > 0) {
		NSString *subjectHTML = [self p_HTMLifyRawMessageString:subject];
		messageHTML = [NSString stringWithFormat:@"<b>%@:</b> %@", subjectHTML, messageHTML];
	}
	
	LPScrollToVisibleMode scrollMode = (isInbound ? LPScrollWithAnimationIfConvenient : LPAlwaysScrollWithJumpOrAnimation);
	
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
		[self p_scheduleReceivedMessageNotificationForAfterScrollWithMessage:audibleCaption
												notificationsHandlerSelector:( (m_lastAppendedMessageKind == LPChatMessageKindNone) ?
																			   @selector(notifyReceptionOfFirstMessage:fromContact:) :
																			   @selector(notifyReceptionOfMessage:fromContact:)      )];
	}
	
	LPScrollToVisibleMode scrollMode = (inbound ? LPScrollWithAnimationIfConvenient : LPAlwaysScrollWithJumpOrAnimation);
	
	[self p_appendStandardMessageBlockWithInnerHTML:htmlCode timestamp:[NSDate date] inbound:inbound saveInHistory:YES scrollMode:scrollMode];
}


- (void)p_appendDIVBlockToWebViewWithInnerHTML:(NSString *)htmlContent divClass:(NSString *)class scrollToVisibleMode:(LPScrollToVisibleMode)scrollMode
{
	if (m_webViewHasLoaded == FALSE) {
		// Add this invocation to the queue of messages waiting to be dumped into the webview.
		SEL					selector = @selector(p_appendDIVBlockToWebViewWithInnerHTML:divClass:scrollToVisibleMode:);
		NSMethodSignature	*methodSignature = [self methodSignatureForSelector:selector];
		NSInvocation		*invocation = [NSInvocation invocationWithMethodSignature:methodSignature];
		
		[invocation setTarget:self];
		[invocation setSelector:selector];
		[invocation setArgument:&htmlContent atIndex:2];
		[invocation setArgument:&class atIndex:3];
		[invocation setArgument:(void *)&scrollMode atIndex:4];
		
		[invocation retainArguments];
		[[self p_pendingMessagesQueue] addObject:invocation];
	}
	else {
		// Append to the end of the WebView content's body
		DOMHTMLDocument *domDoc = (DOMHTMLDocument *)[[m_chatWebView mainFrame] DOMDocument];
		DOMHTMLElement  *elem = (DOMHTMLElement *)[domDoc createElement:@"div"];
		
		[elem setClassName:class];
		[elem setInnerHTML:htmlContent];
		
		// If the user has manually scrolled up to read something else we shouldn't scroll automatically.
		BOOL isScrolledToBottom = [self p_isChatViewScrolledToBottom];
		
		[[domDoc body] appendChild:elem];
		
		if ( (scrollMode == LPAlwaysScrollWithJumpOrAnimation) ||
			 (scrollMode == LPAlwaysScrollWithJump) ||
			 ((scrollMode == LPScrollWithAnimationIfConvenient) && isScrolledToBottom) )
		{
			[self p_scrollWebViewToBottomWithAnimation:((scrollMode != LPAlwaysScrollWithJump) && isScrolledToBottom)];
		}
	}
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
			
			[self p_appendDIVBlockToWebViewWithInnerHTML:[systemMessage stringByEscapingHTMLEntities]
												divClass:@"systemMessage"
									 scrollToVisibleMode: LPAlwaysScrollWithJump ];
		}
		prevDate = curDate;
		
		if ([kind isEqualToString:@"RawHTMLBlock"]) {
			[self p_appendDIVBlockToWebViewWithInnerHTML:message
												divClass:[messageRec objectForKey:@"DIVClass"]
									 scrollToVisibleMode:LPAlwaysScrollWithJump];
		}
		else {
			[self p_appendStandardMessageBlockWithInnerHTML:message
												  timestamp:timestamp
													inbound:[kind isEqualToString:@"Received"]
											  saveInHistory:NO
												 scrollMode:LPAlwaysScrollWithJump ];
		}
	}
}


- (BOOL)p_isChatViewScrolledToBottom
{
	NSView *view = [[[m_chatWebView mainFrame] frameView] documentView];
	
	// determine the current scrolling point
	NSRect viewFrame = [view frame];
	float viewHeight = NSHeight(viewFrame);
	float maxYInVisibleRectBefore = NSMaxY([view visibleRect]);
	float vertLineScroll = [[view enclosingScrollView] verticalLineScroll];
	
	// Are we currently scrolled to near the bottom of the view?
	return (maxYInVisibleRectBefore > (viewHeight - vertLineScroll));
}


- (void)p_scrollWebViewToBottomWithAnimation:(BOOL)animate
{
	NSView *docView = [[[m_chatWebView mainFrame] frameView] documentView];
	
	if (m_scrollAnimationTimer == nil && animate == NO) {
		// We have to force display so that the webview recomputes its content and updates its frame dimensions.
		[docView display];
		[docView scrollRectToVisible:NSMakeRect(0.0, NSHeight([docView frame]), 1.0, 1.0)];
	}
	else {
		// determine the current scrolling point
		float maxYInVisibleRect = NSMaxY([docView visibleRect]);
		
		// we have to force display so that the webview recomputes its content and updates its frame dimensions
		[docView display];
		
		float documentViewHeightAfter = NSHeight([docView frame]);
		float amountToScroll = documentViewHeightAfter - maxYInVisibleRect;
		
		if (amountToScroll > 0.1 ) {
			float animationDuration = 0.3;
			float animationFPS = 60.0;
			float animationWaitInterval = 1.0 / animationFPS;
			
			// Limit the speed to a constant maximum
			float speedInPixelsPerSecond = MIN((amountToScroll / animationDuration), 1000.0);
			
			// DEBUG
			// NSLog(@"Scroll Speed: %f", speedInPixelsPerSecond);
			
			NSDictionary *animationInfo = [NSDictionary dictionaryWithObjectsAndKeys:
				[NSNumber numberWithFloat:maxYInVisibleRect], @"Initial Y Position",
				[NSNumber numberWithFloat:speedInPixelsPerSecond], @"Pixels per Second",
				[NSDate date], @"Start Date",
				nil];
			
			// If an animation is already running, then adjust the timer anyway so that we can speed up scrolling if there's too much
			// stuff being appended.
			if (m_scrollAnimationTimer != nil) {
				[m_scrollAnimationTimer invalidate];
				[m_scrollAnimationTimer release];
			}

			// Run the animation with a timer in the main event loop so that there are no interruptions to
			// the processing of keyboard input from the user.
			m_scrollAnimationTimer = [[NSTimer scheduledTimerWithTimeInterval:animationWaitInterval
																	   target:self
																	 selector:@selector(p_scrollAnimationStep:)
																	 userInfo:animationInfo
																	  repeats:YES] retain];
		}
		
		if (m_scrollAnimationTimer == nil) {
			// We're not going to run the timer. Dump all the notifications that were waiting for scrolling to finish.
			[self p_fireInvocationsWaitingForScrollingToFinish];
		}
	}
}


- (void)p_scrollAnimationStep:(NSTimer *)timer
{
	NSAssert(timer == m_scrollAnimationTimer, @"Timer being fired and our timer instance variable don't match.");
	
	NSDictionary *animationInfo = [timer userInfo];
	float	initialYPosition = [[animationInfo objectForKey:@"Initial Y Position"] floatValue];
	float	speedInPixelsPerSecond = [[animationInfo objectForKey:@"Pixels per Second"] floatValue];
	NSDate	*startDate = [animationInfo objectForKey:@"Start Date"];
	float	elapsedTimeInterval = (-[startDate timeIntervalSinceNow]);
	
	float	targetPosition = initialYPosition + (elapsedTimeInterval * speedInPixelsPerSecond);
	NSView	*docView = [[[m_chatWebView mainFrame] frameView] documentView];
	
	// DEBUG
	// NSLog(@"initial pos: %f ; speed: %f ; elapsed: %f ; target pos: %f", initialYPosition, speedInPixelsPerSecond, elapsedTimeInterval, targetPosition);
	
	if (targetPosition >= NSHeight([docView frame])) {
		// stop the animation
		[timer invalidate];
		
		[m_scrollAnimationTimer release];
		m_scrollAnimationTimer = nil;
		
		// Clamp the target value to the maximum possible value for a last scroll
		targetPosition = NSHeight([docView frame]);
	}
	
	[docView scrollRectToVisible:NSMakeRect(0.0, targetPosition, 1.0, 1.0)];
	
	// Did we finish the animation? If so, run the queued invocations that were waiting for this to happen.
	if (m_scrollAnimationTimer == nil) {
		[self p_fireInvocationsWaitingForScrollingToFinish];
	}
}


- (void)p_fireInvocationsWaitingForScrollingToFinish
{
	[m_invocationsToBeFiredWhenScrollingEnds makeObjectsPerformSelector:@selector(invoke)];
	[m_invocationsToBeFiredWhenScrollingEnds removeAllObjects];
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


- (void)p_dumpQueuedMessagesToWebView
{
	// "Fire" all the queued NSInvocations
	[m_pendingMessagesQueue makeObjectsPerformSelector:@selector(invoke)];
	[m_pendingMessagesQueue release];
	m_pendingMessagesQueue = nil;
}


- (void)p_setupChatDocumentTitle;
{
	NSString *timeFormat = NSLocalizedString(@"%Y-%m-%d %Hh%Mm%Ss",
											 @"time format for chat transcripts titles and filenames");
	NSMutableString *mutableTimeFormat = [timeFormat mutableCopy];
	
	// Make the timeFormat safe for filenames
	[mutableTimeFormat replaceOccurrencesOfString:@":" withString:@"." options:0
											range:NSMakeRange(0, [mutableTimeFormat length])];
	[mutableTimeFormat replaceOccurrencesOfString:@"/" withString:@"-" options:0
											range:NSMakeRange(0, [mutableTimeFormat length])];
	
	NSString *newTitle = [NSString stringWithFormat:NSLocalizedString(@"Chat with \"%@\" on %@", @"filename and title for saved chat transcripts"),
		[[self contact] name],
		[[NSDate date] descriptionWithCalendarFormat:mutableTimeFormat timeZone:nil locale:nil]];
	
	[(DOMHTMLDocument *)[[m_chatWebView mainFrame] DOMDocument] setTitle:newTitle];
	[mutableTimeFormat release];
}


- (NSString *)p_chatDocumentTitle
{
	return [(DOMHTMLDocument *)[[m_chatWebView mainFrame] DOMDocument] title];
}


- (BOOL)p_saveDocumentToFile:(NSString *)pathname hideExtension:(BOOL)hideExt error:(NSError **)errorPtr
{
	NSData *webArchiveData = [[[[m_chatWebView mainFrame] DOMDocument] webArchive] data];
	
	BOOL success = [webArchiveData writeToFile:pathname options:NSAtomicWrite error:errorPtr];
	
	if (success) {
		NSDictionary *fileAttribs = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:hideExt]
																forKey:NSFileExtensionHidden];
		[[NSFileManager defaultManager] changeFileAttributes:fileAttribs atPath:pathname];
	}
	
	return success;
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
	if (m_lastAppendedMessageKind != LPChatMessageKindNone) {
		NSError *error;
		NSString *chatTranscriptPath = [[LPChatTranscriptsFolderPath() stringByAppendingPathComponent:
			[self p_chatDocumentTitle]] stringByAppendingPathExtension:@"webarchive"];
		
		[self p_saveDocumentToFile:chatTranscriptPath hideExtension:YES error:&error];
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
		[[[m_chat account] pubManager] fetchHTMLForChatBot:[[m_chat activeContactEntry] address]
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
	[self willChangeValueForKey:@"windowTitleSuffix"];
	++m_nrUnreadMessages;
	[self didChangeValueForKey:@"windowTitleSuffix"];
	
	[m_unreadCountImageView setImage:[m_unreadMessagesBadge largeBadgeForValue:m_nrUnreadMessages]];
	[self p_updateMiniwindowImage];
}


- (void)p_resetUnreadMessagesCount
{
	[self willChangeValueForKey:@"windowTitleSuffix"];
	m_nrUnreadMessages = 0;
	[self didChangeValueForKey:@"windowTitleSuffix"];
	
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


- (void)p_scheduleReceivedMessageNotificationForAfterScrollWithMessage:(NSString *)message notificationsHandlerSelector:(SEL)selector
{
	SEL					notificationSelector = @selector(p_notifyUserAboutReceivedMessage:notificationsHandlerSelector:);
	NSMethodSignature	*methodSig = [self methodSignatureForSelector:notificationSelector];
	NSInvocation		*notificationInvocation = [NSInvocation invocationWithMethodSignature:methodSig];
	
	[notificationInvocation setTarget:self];
	[notificationInvocation setSelector:notificationSelector];
	[notificationInvocation setArgument:&message atIndex:2];
	[notificationInvocation setArgument:&selector atIndex:3];
	[notificationInvocation retainArguments];
	
	[m_invocationsToBeFiredWhenScrollingEnds addObject:notificationInvocation];	
}


- (void)p_notifyUserAboutReceivedMessage:(NSString *)msgText notificationsHandlerSelector:(SEL)selector
{
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	
	if ([userDefaults boolForKey:@"ChatBounceEnable"]) {
		if ([userDefaults integerForKey:@"ChatBounceMode"] == 0)
			[NSApp requestUserAttention:NSInformationalRequest];
		else
			[NSApp requestUserAttention:NSCriticalRequest];
	}
	
	if ([userDefaults boolForKey:@"UIPlaySounds"]) {
		[[NSSound soundNamed:@"received"] play];
	}
	
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


- (void)p_showEmoticonsAsImages:(BOOL)doShow
{
	// If the user has manually scrolled up to read something else we shouldn't scroll automatically.
	BOOL isScrolledToBottom = [self p_isChatViewScrolledToBottom];
	
	NSString *scriptToRun = ( doShow ?
							  @"showEmoticonsAsImages(true);" :
							  @"showEmoticonsAsImages(false);" );
	
	[[m_chatWebView windowScriptObject] evaluateWebScript:scriptToRun];
	
	if (isScrolledToBottom)
		[self p_scrollWebViewToBottomWithAnimation:NO];
}


#pragma mark -
#pragma mark WebView Frame Load Delegate Methods


- (void)webView:(WebView *)sender windowScriptObjectAvailable:(WebScriptObject *)windowScriptObject
{
	if (m_chatJSInterface == nil) {
		m_chatJSInterface = [[LPChatJavaScriptInterface alloc] init];
		[m_chatJSInterface setAccount:[[self chat] account]];
	}
	
	/* Make it available to the WebView's JavaScript environment */
	[windowScriptObject setValue:m_chatJSInterface forKey:@"chatJSInterface"];
}


- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame
{
	m_webViewHasLoaded = TRUE;
	[self p_updateChatBackgroundColorFromDefaults];
	[self p_dumpQueuedMessagesToWebView];
	[self p_setupChatDocumentTitle];
	
	// Setup the emoticon display mode for this web view
	[self p_showEmoticonsAsImages:[[NSUserDefaults standardUserDefaults] boolForKey:@"DisplayEmoticonImages"]];
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
	if (sender == m_chatWebView || sender == m_pubBannerWebView) {
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
	// Stop the scrolling animation if there is one running
	if (m_scrollAnimationTimer != nil) {
		[m_scrollAnimationTimer invalidate];
		[m_scrollAnimationTimer release];
		m_scrollAnimationTimer = nil;
	}
	
	// Undo the retain cycles we have established until now
	[m_audiblesController setChatController:nil];
	[m_chatWebView setChat:nil];
	
	[[m_chatWebView windowScriptObject] setValue:[NSNull null] forKey:@"chatJSInterface"];
	
	// If the WebView hasn't finished loading when the window is closed (extremely rare, but could happen), then we don't
	// want to do any of the setup that is about to happen in our frame load delegate methods, since the window is going away
	// anyway. If we allowed that setup to happen when the window is already closed it could originate some crashes, since
	// most of the stuff was already released by the time the delegate methods get called.
	[m_chatWebView setFrameLoadDelegate:nil];
	
	// Make sure that the delayed perform of p_checkIfPubBannerIsNeeded doesn't fire
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(p_checkIfPubBannerIsNeeded) object:nil];
	
	// Stop auto-saving our chat transcript
	[self p_setSaveChatTranscriptEnabled:NO];
	
	// Make sure that the content views of our drawers do not leak! (This is a known issue with Cocoa: drawers leak
	// if their parent window is closed while they're open.)
	[[[aNotification object] drawers] makeObjectsPerformSelector:@selector(setContentView:) withObject:nil];
	[[[aNotification object] drawers] makeObjectsPerformSelector:@selector(close)];
	
	[m_chat endChat];
	
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

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)command
{
	if (command == @selector(pageDown:)						|| command == @selector(pageUp:)				||
		command == @selector(scrollPageDown:)				|| command == @selector(scrollPageUp:)			||
		command == @selector(moveToBeginningOfDocument:)	|| command == @selector(moveToEndOfDocument:)	||
		/* The following two selectors are undocumented. They're used by Cocoa to represent a Home or End key press. */
		command == @selector(scrollToBeginningOfDocument:)	|| command == @selector(scrollToEndOfDocument:)	 )
	{
		[[[m_chatWebView mainFrame] frameView] doCommandBySelector:command];
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
		[[m_chat account] startSendingFile:filepath toContactEntry:entry];
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


@end
