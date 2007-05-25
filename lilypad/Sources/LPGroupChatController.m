//
//  LPGroupChatController.m
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "LPGroupChatController.h"
#import "LPGroupChat.h"
#import "LPAccount.h"
#import "LPChatViewsController.h"

#import "NSString+HTMLAdditions.h"
#import "NSxString+EmoticonAdditions.h"


@implementation LPGroupChatController

- initForJoiningRoomWithJID:(NSString *)roomJID onAccount:(LPAccount *)account nickname:(NSString *)nickname password:(NSString *)password includeChatHistory:(BOOL)includeHistory delegate:(id)delegate
{
	if (self = [self initWithWindowNibName:@"GroupChat"]) {
		m_delegate = delegate;
		
		// Join the room
		m_groupChat = [[account startGroupChatWithJID:roomJID
											 nickname:nickname password:password
									   requestHistory:includeHistory] retain];
		[m_groupChat setDelegate:self];
	}
	return self;
}

- (void)dealloc
{
	[m_groupChat release];
	[super dealloc];
}

- (void)windowDidLoad
{
	[m_chatViewsController setOwnerName:[m_groupChat nickname]];
}

- (LPGroupChat *)groupChat
{
	return [[m_groupChat retain] autorelease];
}

- (NSString *)roomJID
{
	return [m_groupChat roomJID];
}


#pragma mark -


- (IBAction)sendMessage:(id)sender
{
	NSString *message = [[m_inputTextField attributedStringValue] stringByFlatteningAttachedEmoticons];
	
	// Check if the text is all made of whitespace.
	static NSCharacterSet *requiredCharacters = nil;
	if (requiredCharacters == nil) {
		requiredCharacters = [[[NSCharacterSet whitespaceAndNewlineCharacterSet] invertedSet] retain];
	}
	
	if ([message rangeOfCharacterFromSet:requiredCharacters].location != NSNotFound) {
		[m_groupChat sendPlainTextMessage:message];
	}
	
	[[self window] makeFirstResponder:m_inputTextField];
	[m_inputTextField setStringValue:@""];
//	[m_inputTextField calcContentSize];
}


#pragma mark -
#pragma mark NSWindow Delegate Methods


- (void)windowWillClose:(NSNotification *)aNotification
{
//	// Stop the scrolling animation if there is one running
//	if (m_scrollAnimationTimer != nil) {
//		[m_scrollAnimationTimer invalidate];
//		[m_scrollAnimationTimer release];
//		m_scrollAnimationTimer = nil;
//	}
//	
//	// Undo the retain cycles we have established until now
//	[m_audiblesController setChatController:nil];
//	[m_chatWebView setChat:nil];
//	
//	[[m_chatWebView windowScriptObject] setValue:[NSNull null] forKey:@"chatJSInterface"];
//	
//	// If the WebView hasn't finished loading when the window is closed (extremely rare, but could happen), then we don't
//	// want to do any of the setup that is about to happen in our frame load delegate methods, since the window is going away
//	// anyway. If we allowed that setup to happen when the window is already closed it could originate some crashes, since
//	// most of the stuff was already released by the time the delegate methods get called.
//	[m_chatWebView setFrameLoadDelegate:nil];
//	
//	// Make sure that the delayed perform of p_checkIfPubBannerIsNeeded doesn't fire
//	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(p_checkIfPubBannerIsNeeded) object:nil];
//	
//	// Stop auto-saving our chat transcript
//	[self p_setSaveChatTranscriptEnabled:NO];
//	
//	// Make sure that the content views of our drawers do not leak! (This is a known issue with Cocoa: drawers leak
//	// if their parent window is closed while they're open.)
//	[[[aNotification object] drawers] makeObjectsPerformSelector:@selector(setContentView:) withObject:nil];
//	[[[aNotification object] drawers] makeObjectsPerformSelector:@selector(close)];
	
	[m_groupChat endGroupChat];
	
	if ([m_delegate respondsToSelector:@selector(groupChatControllerWindowWillClose:)]) {
		[m_delegate groupChatControllerWindowWillClose:self];
	}
}


#pragma mark -
#pragma mark WebView Frame Load Delegate Methods


//- (void)webView:(WebView *)sender windowScriptObjectAvailable:(WebScriptObject *)windowScriptObject
//{
//	if (m_chatJSInterface == nil) {
//		m_chatJSInterface = [[LPChatJavaScriptInterface alloc] init];
//		[m_chatJSInterface setAccount:[[self chat] account]];
//	}
//	
//	/* Make it available to the WebView's JavaScript environment */
//	[windowScriptObject setValue:m_chatJSInterface forKey:@"chatJSInterface"];
//}


- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame
{
//	[self p_updateChatBackgroundColorFromDefaults];
//	[self p_setupChatDocumentTitle];
	
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
	return WebDragSourceActionAny;
}


#pragma mark LPGroupChat Delegate Methods


- (void)groupChat:(LPGroupChat *)chat didReceivedMessage:(NSString *)msg fromContact:(LPGroupChatContact *)contact
{
	NSString *messageHTML = [m_chatViewsController HTMLifyRawMessageString:msg];
	NSString *authorName = [contact nickname];
	NSString *htmlString = [m_chatViewsController HTMLStringForStandardBlockWithInnerHTML:messageHTML
																				timestamp:[NSDate date]
																			   authorName:authorName];
	
	// if it's an outbound message, also scroll down so that the user can see what he has just written
	[m_chatViewsController appendDIVBlockToWebViewWithInnerHTML:htmlString
													   divClass:@"messageBlock"
											scrollToVisibleMode:LPScrollWithAnimationIfConvenient];
}

- (void)groupChat:(LPGroupChat *)chat didReceivedSystemMessage:(NSString *)msg
{
	[m_chatViewsController appendDIVBlockToWebViewWithInnerHTML:[msg stringByEscapingHTMLEntities]
													   divClass:@"systemMessage"
											scrollToVisibleMode:LPScrollWithAnimationIfConvenient];
}

@end
