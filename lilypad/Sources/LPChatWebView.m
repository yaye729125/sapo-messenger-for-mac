//
//  LPChatWebView.m
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "LPChatWebView.h"
#import "LPChat.h"
#import "LPAccount.h"
#import "LPContactEntry.h"


static NSColor *NSColor_from_HTML_color_spec(NSString *htmlSpec)
{
	if ([htmlSpec hasPrefix:@"#"]) {
		htmlSpec = [htmlSpec substringFromIndex:1];
	}
	
	int ri, gi, bi;
	float r, g, b;
	
	if ([htmlSpec length] == 3) {
		sscanf([htmlSpec UTF8String], "%1x%1x%1x", &ri, &gi, &bi);
		r = (float)ri / (float)0x0F;
		g = (float)gi / (float)0x0F;
		b = (float)bi / (float)0x0F;
	}
	else if ([htmlSpec length] == 6) {
		sscanf([htmlSpec UTF8String], "%2x%2x%2x", &ri, &gi, &bi);
		r = (float)ri / (float)0xFF;
		g = (float)gi / (float)0xFF;
		b = (float)bi / (float)0xFF;
	}
	else {
		return nil;
	}
	
	return [NSColor colorWithCalibratedRed:r green:g blue:b alpha:1.0];
}


@implementation LPChatWebView

- (void)dealloc
{
	[self setChat:nil];
	
	[m_previousBGColor release];
	[m_highlightBGColor release];
	
	[super dealloc];
}

- (BOOL)p_acceptsDroppingOfFiles
{
	return m_acceptsDroppingOfFiles;
}

- (void)p_setAcceptsDroppingOfFiles:(BOOL)flag
{
	if (flag != m_acceptsDroppingOfFiles) {
		m_acceptsDroppingOfFiles = flag;
		
		if (flag)
			[self registerForDraggedTypes:[NSArray arrayWithObject:NSFilenamesPboardType]];
		else
			[self unregisterDraggedTypes];
	}
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ([keyPath isEqualToString:@"activeContactEntry"]) {
		[self p_setAcceptsDroppingOfFiles:[[m_chat activeContactEntry] canDoFileTransfer]];
	}
	else {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}

- (LPChat *)chat
{
	return [[m_chat retain] autorelease];
}

- (void)setChat:(LPChat *)chat
{
	if (chat != m_chat) {
		[m_chat removeObserver:self forKeyPath:@"activeContactEntry"];
		[m_chat release];
		m_chat = [chat retain];
		[m_chat addObserver:self forKeyPath:@"activeContactEntry" options:0 context:NULL];
		
		[self p_setAcceptsDroppingOfFiles:[[m_chat activeContactEntry] canDoFileTransfer]];
	}
}

- (NSColor *)backgroundColor
{
	DOMHTMLDocument *domDoc = (DOMHTMLDocument *)[[self mainFrame] DOMDocument];
	DOMHTMLElement  *body = [domDoc body];
	
	return NSColor_from_HTML_color_spec([body getAttribute:@"bgcolor"]);
}

- (void)setBackgroundColor:(NSColor *)backgroundColor
{
	DOMHTMLDocument *domDoc = (DOMHTMLDocument *)[[self mainFrame] DOMDocument];
	DOMHTMLElement  *body = [domDoc body];
	NSColor			*backgroundRGBColor = [backgroundColor colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
	
	[body setAttribute:@"bgcolor"
					  :[NSString stringWithFormat:@"#%02X%02X%02X",
						  (unsigned int)([backgroundRGBColor redComponent  ] * 255.0),
						  (unsigned int)([backgroundRGBColor greenComponent] * 255.0),
						  (unsigned int)([backgroundRGBColor blueComponent ] * 255.0)]];
	
	/*
	 * The next line is a workaround for a bug in WebKit that was still present in the version shipped
	 * with Mac OS X 10.4.6:
	 *   http://lists.apple.com/archives/webkitsdk-dev/2006/Mar/msg00066.html
	 * The WebView doesn't redraw properly using the recently changed styles even if we call setNeedsDisplay:. We need
	 * to force its web document view to re-layout so that it updates immediately.
	 */
	[[[[self mainFrame] frameView] documentView] setNeedsLayout:YES];
	
	[self setNeedsDisplay:YES];
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
	if (m_acceptsDroppingOfFiles) {
		[m_previousBGColor release];
		m_previousBGColor = [[self backgroundColor] retain];
		[m_highlightBGColor release];
		m_highlightBGColor = [[m_previousBGColor blendedColorWithFraction:0.15
																  ofColor:[NSColor alternateSelectedControlColor]] retain];
		
		[self setBackgroundColor:m_highlightBGColor];
		
		return NSDragOperationCopy;
	}
	else
		return NSDragOperationNone;
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender
{
	if (m_acceptsDroppingOfFiles)
		return NSDragOperationCopy;
	else
		return NSDragOperationNone;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender
{
	if (m_acceptsDroppingOfFiles) {
		[self setBackgroundColor:m_previousBGColor];
	}
}

- (void)draggingEnded:(id <NSDraggingInfo>)sender
{
	if (m_acceptsDroppingOfFiles) {
		[m_previousBGColor release]; m_previousBGColor = nil;
		[m_highlightBGColor release]; m_highlightBGColor = nil;
	}
}

- (BOOL)wantsPeriodicDraggingUpdates
{
	return NO;
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
	if (m_acceptsDroppingOfFiles) {
		[self setBackgroundColor:m_previousBGColor];
		[m_previousBGColor release]; m_previousBGColor = nil;
		[m_highlightBGColor release]; m_highlightBGColor = nil;
	}
	
	// We'll take any file
	return YES;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
	NSPasteboard		*pboard = [sender draggingPasteboard];
	NSArray				*draggedTypes = [pboard types];
	LPContactEntry		*targetContactEntry = [m_chat activeContactEntry];
	
	if ([draggedTypes containsObject:NSFilenamesPboardType] && [targetContactEntry canDoFileTransfer]) {
        NSArray		*files = [pboard propertyListForType:NSFilenamesPboardType];
		
		NSEnumerator *filePathEnumerator = [files objectEnumerator];
		NSString *filePath;
		LPAccount *account = [m_chat account];
		
		while (filePath = [filePathEnumerator nextObject]) {
			[account startSendingFile:filePath toContactEntry:targetContactEntry];
		}
		return YES;
	}
	else {
		return NO;
	}
}

@end
