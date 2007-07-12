//
//  LPChatViewsController.cpp
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "LPChatViewsController.h"
#import "LPChatWebView.h"
#import "LPChatTextField.h"
#import "LPEmoticonPicker.h"
#import "LPEmoticonSet.h"
#import "LPChatJavaScriptInterface.h"
#import "NSString+HTMLAdditions.h"
#import "NSString+URLScannerAdditions.h"
#import "NSxString+EmoticonAdditions.h"


/*
 * The method -[LPChatViewsController grabMethodForAfterScrollingWithTarget:] returns an instance of the private class
 * defined below. The messages targeted at this proxy object will be captured into an invocation and forwarded to the
 * associated LPChatViewsController queue. For now it is only used to schedule method invocations that must be fired
 * after the scrolling animation ends.
 *
 * Ex.:
 *
 *   [[chatViewsCtrl grabMethodForAfterScrollingWithTarget:someTarget] someMethodInvocation:x thatWillFireAfterScrolling:y];
 *
 * Nothing happens at this point besides the method invocation being added to an internal queue. When scrolling ends, the
 * chat views controller fires the scheduled method invocation in a way equivalent to the following:
 *
 *   [someTarget someMethodInvocation:x thatWillFireAfterScrolling:y];
 *
 */
@interface _LPChatViewsInvocationSchedulingProxy : NSObject {
	LPChatViewsController	*m_chatViewsController;
	id						m_targetForInvocations;
}
- __initWithChatViewsController:(LPChatViewsController *)chatViewsController;
- (id)__targetForInvocations;
- (void)__setTargetForInvocations:(id)target;
- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector;
- (void)forwardInvocation:(NSInvocation *)anInvocation;
@end

@implementation _LPChatViewsInvocationSchedulingProxy
- __initWithChatViewsController:(LPChatViewsController *)chatViewsController {
	if (self = [super init]) m_chatViewsController = chatViewsController;
	return self;
}
- (id)__targetForInvocations {
	return m_targetForInvocations;
}
- (void)__setTargetForInvocations:(id)target {
	m_targetForInvocations = target;
}
- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
	return [m_targetForInvocations methodSignatureForSelector:aSelector];
}
- (void)forwardInvocation:(NSInvocation *)anInvocation {
	[anInvocation setTarget:m_targetForInvocations];
	[m_chatViewsController addInvocationToFireAfterScrolling:anInvocation];
}
@end



#pragma mark -



// HTML snippets for each message kind
static NSString	*s_myMessageFormatString;
static NSString	*s_myContiguousMessageFormatString;
static NSString	*s_friendMessageFormatString;
static NSString	*s_friendContiguousMessageFormatString;



@implementation LPChatViewsController

- init
{
	if (self = [super init]) {
		m_invocationSchedulingProxy = [[_LPChatViewsInvocationSchedulingProxy alloc] __initWithChatViewsController:self];
		
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
		
		m_invocationsToBeFiredWhenScrollingEnds = [[NSMutableArray alloc] init];
	}
	
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[m_invocationSchedulingProxy release];
	
	[m_ownerAuthorName release];
	[m_lastAppendedMessageAuthorName release];
	
	[m_scrollAnimationTimer invalidate];
	[m_scrollAnimationTimer release];
	[m_invocationsToBeFiredWhenScrollingEnds release];
	
	[m_pendingMessagesQueue release];
	[m_emoticonPicker release];
	[super dealloc];
}


- (NSURL *)p_webViewContentURL
{
	NSString *webViewContentPath = [[NSBundle mainBundle] pathForResource:@"ChatView"
																   ofType:@"html"
															  inDirectory:@"ChatView"];
	return [NSURL fileURLWithPath:[webViewContentPath stringByExpandingTildeInPath]];
}


- (void)p_loadWebViewContent
{
	NSURL *webViewContentURL = [self p_webViewContentURL];
	NSMutableString *webViewContentString = [NSMutableString stringWithContentsOfURL:webViewContentURL
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
	
	[webViewContentString replaceOccurrencesOfString:@"%%BASE_URL%%"
										  withString:[webViewContentURL absoluteString]
											 options:NSLiteralSearch
											   range:NSMakeRange(0, [webViewContentString length])];
	
	[[m_chatWebView mainFrame] loadHTMLString:webViewContentString baseURL:webViewContentURL];
}

- (void)awakeFromNib
{
	if (m_chatWebView) {
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(windowWillClose:)
													 name:NSWindowWillCloseNotification
												   object:[m_chatWebView window]];
		
		[m_chatWebView setPreferencesIdentifier:[[NSBundle mainBundle] bundleIdentifier]];
		WebPreferences *prefs = [m_chatWebView preferences];
		[prefs setJavaEnabled:NO];
		[prefs setJavaScriptCanOpenWindowsAutomatically:NO];
		[prefs setJavaScriptEnabled:YES];
		[prefs setLoadsImagesAutomatically:YES];
		[prefs setPlugInsEnabled:YES];
		[prefs setShouldPrintBackgrounds:YES];
		
		[self p_loadWebViewContent];
	}
}

// Cleanup
- (void)windowWillClose:(NSNotification *)aNotification
{
	// Stop the scrolling animation if there is one running
	if (m_scrollAnimationTimer != nil) {
		[m_scrollAnimationTimer invalidate];
		[m_scrollAnimationTimer release];
		m_scrollAnimationTimer = nil;
	}
}


- (NSString *)ownerName
{
	return [[m_ownerAuthorName copy] autorelease];
}

- (void)setOwnerName:(NSString *)ownerName
{
	if (ownerName != m_ownerAuthorName) {
		[m_ownerAuthorName release];
		m_ownerAuthorName = [ownerName copy];
	}
}


- (IBAction)pickEmoticonWithMenuTopRightAt:(NSPoint)topRight parentWindow:(NSWindow *)win
{
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

- (BOOL)existsElementWithID:(NSString *)elementID
{
	DOMHTMLDocument *domDoc = (DOMHTMLDocument *)[[m_chatWebView mainFrame] DOMDocument];
	DOMHTMLElement  *elem = (DOMHTMLElement *)[domDoc getElementById:elementID];
	
	return (elem != nil);
}

- (void)setInnerHTML:(NSString *)innerHTML forElementWithID:(NSString *)elementID
{
	DOMHTMLDocument *domDoc = (DOMHTMLDocument *)[[m_chatWebView mainFrame] DOMDocument];
	DOMHTMLElement  *elem = (DOMHTMLElement *)[domDoc getElementById:elementID];
	
	// If the user has manually scrolled up to read something else we shouldn't scroll automatically.
	BOOL isScrolledToBottom = [self isChatViewScrolledToBottom];
	
	[elem setInnerHTML:innerHTML];
	
	if (isScrolledToBottom)
		[self scrollWebViewToBottomWithAnimation:NO];
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

- (NSString *)HTMLifyRawMessageString:(NSString *)rawString
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
			[resultString appendFormat:@"<a href=\"%@\">%@</a>",
				normalizedURLString, [[rawString substringWithRange:nextURLRange] stringByEscapingHTMLEntities]];
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


- (NSString *)HTMLStringForStandardBlockWithInnerHTML:(NSString *)innerHTML timestamp:(NSDate *)timestamp authorName:(id)authorName
{
	// Determine the format that is going to be used to print the message
	NSString *formatString = @"";
	
	if ([authorName isEqualToString:m_lastAppendedMessageAuthorName]) {
		// Use the contiguous style
		formatString = ( [authorName isEqualToString:m_ownerAuthorName] ?
						 s_myContiguousMessageFormatString :
						 s_friendContiguousMessageFormatString );
	}
	else {
		// Use the first message format
		formatString = ( [authorName isEqualToString:m_ownerAuthorName] ?
						 s_myMessageFormatString :
						 s_friendMessageFormatString );
	}
	
	BOOL containsContactName = ![authorName isEqualToString:m_lastAppendedMessageAuthorName];
	
	[m_lastAppendedMessageAuthorName release];
	m_lastAppendedMessageAuthorName = [authorName copy];
	
	NSString *name = (containsContactName ? authorName : @"");
	
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


- (NSMutableArray *)p_pendingMessagesQueue
{
	if (m_pendingMessagesQueue == nil) {
		m_pendingMessagesQueue = [[NSMutableArray alloc] init];
	}
	return m_pendingMessagesQueue;
}

- (void)appendDIVBlockToWebViewWithInnerHTML:(NSString *)htmlContent divClass:(NSString *)class scrollToVisibleMode:(LPScrollToVisibleMode)scrollMode
{
	if (m_webViewHasLoaded == FALSE) {
		// Add this invocation to the queue of messages waiting to be dumped into the webview.
		SEL					selector = @selector(appendDIVBlockToWebViewWithInnerHTML:divClass:scrollToVisibleMode:);
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
		BOOL isScrolledToBottom = [self isChatViewScrolledToBottom];
		
		[[domDoc body] appendChild:elem];
		
		if ( (scrollMode == LPAlwaysScrollWithJumpOrAnimation) ||
			 (scrollMode == LPAlwaysScrollWithJump) ||
			 ((scrollMode == LPScrollWithAnimationIfConvenient) && isScrolledToBottom) )
		{
			[self scrollWebViewToBottomWithAnimation:((scrollMode != LPAlwaysScrollWithJump) && isScrolledToBottom)];
		}
	}
}

- (BOOL)isChatViewScrolledToBottom
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


- (void)p_fireInvocationsWaitingForScrollingToFinish
{
	[m_invocationsToBeFiredWhenScrollingEnds makeObjectsPerformSelector:@selector(invoke)];
	[m_invocationsToBeFiredWhenScrollingEnds removeAllObjects];
}


- (void)scrollWebViewToBottomWithAnimation:(BOOL)animate
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


- (void)dumpQueuedMessagesToWebView
{
	m_webViewHasLoaded = TRUE;
	
	// "Fire" all the queued NSInvocations
	[m_pendingMessagesQueue makeObjectsPerformSelector:@selector(invoke)];
	[m_pendingMessagesQueue release];
	m_pendingMessagesQueue = nil;
}

- (NSString *)chatDocumentTitle
{
	return [(DOMHTMLDocument *)[[m_chatWebView mainFrame] DOMDocument] title];
}

- (void)setChatDocumentTitle:(NSString *)newTitle
{
	[(DOMHTMLDocument *)[[m_chatWebView mainFrame] DOMDocument] setTitle:newTitle];
}

- (BOOL)saveDocumentToFile:(NSString *)pathname hideExtension:(BOOL)hideExt error:(NSError **)errorPtr
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

- (id)grabMethodForAfterScrollingWithTarget:(id)target
{
	[m_invocationSchedulingProxy __setTargetForInvocations:target];
	return m_invocationSchedulingProxy;
}

- (void)addInvocationToFireAfterScrolling:(NSInvocation *)inv
{
	[inv retainArguments];
	[m_invocationsToBeFiredWhenScrollingEnds addObject:inv];	
}

- (void)showEmoticonsAsImages:(BOOL)doShow
{
	// If the user has manually scrolled up to read something else we shouldn't scroll automatically.
	BOOL isScrolledToBottom = [self isChatViewScrolledToBottom];
	
	NSString *scriptToRun = ( doShow ?
							  @"showEmoticonsAsImages(true);" :
							  @"showEmoticonsAsImages(false);" );
	
	[[m_chatWebView windowScriptObject] evaluateWebScript:scriptToRun];
	
	if (isScrolledToBottom)
		[self scrollWebViewToBottomWithAnimation:NO];
}


#pragma mark -
#pragma mark WebView Policy Delegate Methods


- (void)webView:(WebView *)sender decidePolicyForNavigationAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request frame:(WebFrame *)frame decisionListener:(id<WebPolicyDecisionListener>)listener
{
	int navigationType = [[actionInformation objectForKey:WebActionNavigationTypeKey] intValue];
	NSURL *requestURL = [request URL];
	
	// Forward it to the workspace, but only if it isn't the initial load of our content view!
	if ((navigationType == WebNavigationTypeLinkClicked || navigationType == WebNavigationTypeOther)
		&& !([requestURL isFileURL] && [[requestURL path] isEqualToString:[[self p_webViewContentURL] path]]))
	{
		[[NSWorkspace sharedWorkspace] openURL:requestURL];
		[listener ignore];
	}
	else
	{
		[listener use];
	}
}


@end
