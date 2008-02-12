//
//  LPAvatarButton.m
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jpavao@co.sapo.pt>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "LPAvatarButton.h"
#import "LPAvatarEditorView.h"


@implementation LPAvatarButton

+ (Class) cellClass
{
    return [LPAvatarButtonCell class];
}

- (id)initWithFrame:(NSRect)frameRect
{
	if (self = [super initWithFrame:frameRect]) {
		[self setBordered:NO];
		[self setImagePosition:NSImageOnly];
		
		[self registerForDraggedTypes:[LPAvatarEditorView acceptedPasteboardTypes]];
	}
	return self;
}

- (BOOL)isFlipped
{
	return NO;
}

- (id)delegate
{
	return m_delegate;
}

- (void)setDelegate:(id)delegate
{
	m_delegate = delegate;
}

#pragma mark -
#pragma mark Tracking Rects

- (void)resetCursorRects
{
	m_trackingRect = [self addTrackingRect:[self bounds] owner:[self cell] userData:NULL assumeInside:NO];
}

- (void)discardCursorRects
{
	[self removeTrackingRect:m_trackingRect];
}

#pragma mark -
#pragma mark Drag & Drop

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
	NSDragOperation result = NSDragOperationNone;
	
	if ([LPAvatarEditorView canImportContentsOfPasteboard:[sender draggingPasteboard]]) {
		result = NSDragOperationCopy;
	}
	
	if (result != NSDragOperationNone) {
		// Let the cell know
		[[self cell] mouseEntered:[NSApp currentEvent]];
	}
	
	return result;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender
{
	[[self cell] mouseExited:[NSApp currentEvent]];
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
	NSPasteboard *pboard = [sender draggingPasteboard];
	
	if ([LPAvatarEditorView canImportContentsOfPasteboard:pboard]) {
		if ([[self delegate] respondsToSelector:@selector(avatarButton:receivedDropWithPasteboard:)]) {
			[[self delegate] avatarButton:self receivedDropWithPasteboard:pboard];
		}
		return YES;
	}
	else {
		return NO;
	}
}

@end


#pragma mark -


@implementation LPAvatarButtonCell

- (NSRect)drawingRectForBounds:(NSRect)theRect
{
	return NSInsetRect(theRect, 1.0, 1.0);
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	[[NSColor colorWithCalibratedWhite:0.0 alpha:0.075] set];
	NSRectFillUsingOperation(cellFrame, NSCompositeSourceOver);
	
	// Draw the recessed border
	NSRectEdge	edges[] = { NSMinYEdge, NSMaxYEdge, NSMinXEdge, NSMaxXEdge };
	NSColor		*darkColor = [NSColor colorWithDeviceWhite:0.75 alpha:1.0];
	NSColor		*lightColor = [NSColor colorWithDeviceWhite:0.95 alpha:1.0];
	NSColor		*edgeColors[] = { lightColor, darkColor, darkColor, darkColor };
	
	NSDrawColorTiledRects(cellFrame, cellFrame, edges, edgeColors, 4);
	
	// Draw the rest
	[self drawInteriorWithFrame:cellFrame inView:controlView];
}

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	NSImage *img = [self image];
	
	NSGraphicsContext *context = [NSGraphicsContext currentContext];
	NSImageInterpolation prevInterpolationSetting = [context imageInterpolation];
	
	[context setImageInterpolation:NSImageInterpolationHigh];
	[img drawInRect:[self imageRectForBounds:cellFrame]
		   fromRect:NSMakeRect(0.0, 0.0, [img size].width, [img size].height)
		  operation:NSCompositeSourceOver
		   fraction:1.0];
	[context setImageInterpolation:prevInterpolationSetting];
	
	if ([self isHighlighted]) {
		[[NSColor colorWithCalibratedWhite:0.0 alpha:0.40] set];
		NSRectFillUsingOperation([self drawingRectForBounds:cellFrame], NSCompositeSourceOver);
	}
	else if (m_mouseInCell) {
		[[NSColor colorWithCalibratedWhite:0.0 alpha:0.25] set];
		NSRectFillUsingOperation([self drawingRectForBounds:cellFrame], NSCompositeSourceOver);
	}
}

- (void)mouseEntered:(NSEvent *)event
{
	m_mouseInCell = YES;
	[[self controlView] setNeedsDisplay:YES];
}

- (void)mouseExited:(NSEvent *)event
{
	m_mouseInCell = NO;
	[[self controlView] setNeedsDisplay:YES];
}

@end
