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


@implementation LPGroupChatController

- initForJoiningRoomWithJID:(NSString *)roomJID onAccount:(LPAccount *)account nickname:(NSString *)nickname password:(NSString *)password includeChatHistory:(BOOL)includeHistory delegate:(id)delegate
{
	if (self = [self initWithWindowNibName:@"GroupChat"]) {
		m_delegate = delegate;
		
		// Join the room
		m_groupChat = [[account startGroupChatWithJID:roomJID
											 nickname:nickname password:password
									   requestHistory:includeHistory] retain];
	}
	return self;
}

- (void)dealloc
{
	[m_groupChat release];
	[super dealloc];
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
	
	[m_groupChat leaveGroupChat];
	
	if ([m_delegate respondsToSelector:@selector(groupChatControllerWindowWillClose:)]) {
		[m_delegate groupChatControllerWindowWillClose:self];
	}
}

@end
