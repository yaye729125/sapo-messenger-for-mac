//
//  LPChatViewsController.h
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


@interface LPChatFindPanelController : NSWindowController
{
	BOOL m_shouldClosePanelIfFound;
	IBOutlet NSTextField *m_searchStringField;
}
+ (LPChatFindPanelController *)sharedFindPanel;
- (NSString *)searchString;
- (void)setSearchString:(NSString *)str;
- (IBAction)findNextAndOrderFindPanelOut:(id)sender;
- (void)searchStringWasFound:(BOOL)found;
@end



typedef enum {
	LPDontScroll,
	LPScrollWithAnimationIfConvenient,
	LPAlwaysScrollWithJumpOrAnimation,
	LPAlwaysScrollWithJump
} LPScrollToVisibleMode;


@class LPEmoticonPicker;


@interface LPChatViewsController : NSObject
{
	IBOutlet WebView		*m_chatWebView;
	IBOutlet NSTextField	*m_inputTextField;
	
	id						m_invocationSchedulingProxy;
	
	NSString				*m_ownerAuthorName;
	NSString				*m_lastAppendedMessageAuthorName;
	
	BOOL					m_webViewHasLoaded;
	
	// Scroll animation
	NSTimer					*m_scrollAnimationTimer;
	NSMutableArray			*m_invocationsToBeFiredWhenScrollingEnds;
	
	/*
	 * We must only append messages to the webview when it has finished loading the "base" HTML document
	 * completely. If this controller is asked to append messages while the webview is not loaded, then those
	 * messages are saved in this queue in the form of NSInvocations. When the webview finishes loading, the
	 * queue is emptied by dispatching all the pending invocations, which gets all the corresponding messages
	 * into the view (that is now ready to receive them).
	 */
	NSMutableArray			*m_pendingMessagesQueue;
	
	LPEmoticonPicker		*m_emoticonPicker;
}

- (NSString *)ownerName;
- (void)setOwnerName:(NSString *)ownerName;

- (IBAction)pickEmoticonWithMenuTopRightAt:(NSPoint)topRight parentWindow:(NSWindow *)win;

- (BOOL)existsElementWithID:(NSString *)elementID;
- (void)setInnerHTML:(NSString *)innerHTML forElementWithID:(NSString *)elementID;

- (NSString *)HTMLifyRawMessageString:(NSString *)rawString;
- (NSString *)HTMLStringForStandardBlockWithInnerHTML:(NSString *)innerHTML timestamp:(NSDate *)timestamp authorName:(id)authorName;
- (void)appendDIVBlockToWebViewWithInnerHTML:(NSString *)htmlContent divClass:(NSString *)class scrollToVisibleMode:(LPScrollToVisibleMode)scrollMode;
- (BOOL)isChatViewScrolledToBottom;
- (void)scrollWebViewToBottomWithAnimation:(BOOL)animate;

- (void)dumpQueuedMessagesToWebView;

- (NSString *)chatDocumentTitle;
- (void)setChatDocumentTitle:(NSString *)title;

- (BOOL)saveDocumentToFile:(NSString *)pathname hideExtension:(BOOL)hideExt error:(NSError **)errorPtr;

- (id)grabMethodForAfterScrollingWithTarget:(id)target;
- (void)addInvocationToFireAfterScrolling:(NSInvocation *)inv;

- (void)showEmoticonsAsImages:(BOOL)doShow;

@end
