//
//  LPGroupButtonCell.m
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jpavao@co.sapo.pt>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "LPGroupButtonCell.h"


@interface LPGroupButtonCell ()  // Private Methods
- (NSDictionary *)p_textAttributes;
@end


@implementation LPGroupButtonCell


- (id)initImageCell:(NSImage *)anImage
{
	return [self init];
}

- (id)initTextCell:(NSString *)aString
{
	return [self init];
}

- init
{
	if (self = [super initTextCell:@""]) {		
		// Setup the basic cell properties
		[self setAlignment:NSLeftTextAlignment];
		[self setBezeled:NO];
		[self setBordered:NO];
		[self setButtonType:NSPushOnPushOffButton];
		[self setGradientType:NSGradientConvexWeak];
		
		[self setImagePosition:NSImageLeft];
		[self setImage:[NSImage imageNamed:@"DisclosureClosed"]];
		[self setAlternateImage:[NSImage imageNamed:@"DisclosureOpen"]];
		
		[self setHighlightsBy:NSPushInCellMask];
		[self setShowsStateBy:NSContentsCellMask];
	}
	
	return self;
}


- (NSDictionary *)p_textAttributes
{
	static NSDictionary *textAttributes = nil;

	if (textAttributes == nil) {
		NSFont *titleFont = [NSFont boldSystemFontOfSize:[NSFont smallSystemFontSize]];
		
		NSMutableParagraphStyle *paragraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
		[paragraphStyle setAlignment:NSLeftTextAlignment];
		[paragraphStyle setLineBreakMode:NSLineBreakByTruncatingTail];
		
		NSShadow *shadow = [[NSShadow alloc] init];
		[shadow setShadowColor:[NSColor whiteColor]];
		[shadow setShadowBlurRadius:0.0];
		[shadow setShadowOffset:NSMakeSize(0, -1)];
		
		textAttributes = [[NSDictionary alloc] initWithObjectsAndKeys:
			[NSColor colorWithDeviceWhite:0.4 alpha:1.0], NSForegroundColorAttributeName,
			titleFont, NSFontAttributeName,
			shadow, NSShadowAttributeName,
			paragraphStyle, NSParagraphStyleAttributeName,
			nil];
		
		[shadow release];
		[paragraphStyle release];
	}
	
	return textAttributes;
}


- (void)setTitle:(NSString *)aString
{
	// Apply the default attributes
	NSAttributedString *newTitle = [[NSAttributedString alloc] initWithString:aString
																   attributes:[self p_textAttributes]];
	[self setAttributedTitle:newTitle];
	[newTitle release];
}


- (unsigned int)itemsCount
{
	return m_itemsCount;
}

- (void)setItemsCount:(unsigned int)itemsCount
{
	m_itemsCount = itemsCount;
}


- (NSRect)drawingRectForBounds:(NSRect)theRect
{
	// Add some margins to the sides
	return NSInsetRect(theRect, 6.0, 0.0);
}


- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	NSImage *bgImage = [NSImage imageNamed:@"GroupBar"];
	
	if (bgImage) {
		NSSize imageSize = [bgImage size];

		[bgImage setFlipped:YES];
		[bgImage drawInRect:cellFrame
				   fromRect:NSMakeRect(0.0, 0.0, imageSize.width, imageSize.height)
				  operation:NSCompositeCopy
				   fraction:([self isHighlighted] ? 0.9 : 1.0)];
	}
	else {
		[[NSColor colorWithDeviceWhite:([self isHighlighted] ? 0.7 : 0.8) alpha:1.0] set];
		NSRectFill(cellFrame);
	}
	
	[self drawInteriorWithFrame:cellFrame inView:controlView];
	
	[[NSColor colorWithDeviceWhite:0.75 alpha:1.0] set];
	NSFrameRect(cellFrame);
}

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	NSString *countStr = [NSString stringWithFormat:@"%d", [self itemsCount]];
	NSAttributedString *itemsCountAttribStr = [[NSAttributedString alloc] initWithString:countStr
																			  attributes:[self p_textAttributes]];
	
	CGFloat countWidth = [itemsCountAttribStr size].width;
	NSRect titleRect, countRect;
	NSDivideRect(cellFrame, &countRect, &titleRect, countWidth + 4.0, NSMaxXEdge);
	
	//	[[NSColor yellowColor] set];
	//	NSRectFill(titleRect);
	//	[[NSColor orangeColor] set];
	//	NSRectFill(countRect);
	
	[super drawInteriorWithFrame:titleRect inView:controlView];
	[itemsCountAttribStr drawInRect:NSInsetRect(countRect, 0.0, 4.0)];
	
	[itemsCountAttribStr release];
}


@end
