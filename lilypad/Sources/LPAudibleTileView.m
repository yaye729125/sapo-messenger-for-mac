//
//  LPAudibleTileView.m
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jpavao@co.sapo.pt>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "LPAudibleTileView.h"


@interface LPAudibleTileView ()  // Private Methods
- (void)p_updateCachedImageRep;
@end


@implementation LPAudibleTileView

- (id)initWithFrame:(NSRect)frame
{
	return [super initWithFrame:frame];
}

- (void)dealloc
{
	[m_cachedImageRep release];
	[super dealloc];
}

- (id)delegate
{
	return m_delegate;
}

- (void)setDelegate:(id)delegate
{
	m_delegate = delegate;
}

- (BOOL)hasAudibleFileContent
{
	return m_hasAudibleContent;
}

- (NSBitmapImageRep *)cachedBitmapImageRep
{
	return [[m_cachedImageRep retain] autorelease];
}

- (void)setAudibleFileContentPath:(NSString *)filepath
{
	NSString *pathForHTMLFile = [[NSBundle mainBundle] pathForResource:@"AudibleTileDocument" ofType:@"html"];
	NSMutableString *htmlText = [NSMutableString stringWithContentsOfFile:pathForHTMLFile];
	
	[htmlText replaceOccurrencesOfString:@"%%AUDIBLE_URL%%"
							  withString:[[NSURL fileURLWithPath:filepath] absoluteString]
								 options:NSLiteralSearch
								   range:NSMakeRange(0, [htmlText length])];
	
	[[self mainFrame] loadHTMLString:htmlText baseURL:nil];
	
	m_hasAudibleContent = YES;

	[self performSelector:@selector(p_updateCachedImageRep) withObject:nil afterDelay:0.5];
}

- (void)setFrame:(NSRect)frame
{
	if ([self window]) {
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(p_updateCachedImageRep) object:nil];
		[self performSelector:@selector(p_updateCachedImageRep) withObject:nil afterDelay:0.5];
	}
	[super setFrame:frame];
}

- (void)p_updateCachedImageRep
{
	if ([self lockFocusIfCanDraw]) {
		NSBitmapImageRep *viewBitmap = [[NSBitmapImageRep alloc] initWithFocusedViewRect:[self bounds]];
		[self unlockFocus];
		
		[m_cachedImageRep release];
		m_cachedImageRep = viewBitmap;
	}
}


/* The flash plug-in (which is managing the tile's contents) absorbs all mouse clicks. The WebView never gets
a chance to know that a mouse down event occurred inside it. However, we need to know when this occurs in order
to be able to notify the delegate, which in turn takes care of updating the current selection. To do this we
take a peek at each call to hitTest in order to know if we're the target of a mouse click or not.

We must take care to process possible repeated invocations only once: the hitTest method may get called more than
once for exactly the same mouseDown event.
*/
- (NSView *)hitTest:(NSPoint)aPoint
{
	NSView	*view = [super hitTest:aPoint];
	NSEvent	*currentEvent = [NSApp currentEvent];
	
	BOOL	isOurSubview = [view isDescendantOf:self];
	BOOL	isButtonDown = ([currentEvent type] == NSLeftMouseDown);
	BOOL	isRepetition = (isButtonDown && ([currentEvent eventNumber] == m_previousMouseEventNr));
	
	if (isButtonDown)
		m_previousMouseEventNr = [currentEvent eventNumber];
	
	
	if (isOurSubview && isButtonDown && (isRepetition == NO)
		&& [[self delegate] respondsToSelector:@selector(audibleTileViewGotMouseDown:)])
	{
		[[self delegate] audibleTileViewGotMouseDown:self];
	}
	
	
	return view;
}

@end
