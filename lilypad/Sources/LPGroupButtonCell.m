//
//  LPGroupButtonCell.m
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "LPGroupButtonCell.h"


@interface LPGroupButtonCell (Private)
- (NSDictionary *)p_titleTextAttributes;
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


- (NSDictionary *)p_titleTextAttributes
{
	static NSDictionary *titleTextAttributes = nil;

	if (titleTextAttributes == nil) {
		NSFont *titleFont = [NSFont boldSystemFontOfSize:[NSFont smallSystemFontSize]];
		NSShadow *shadow = [[NSShadow alloc] init];

		[shadow setShadowColor:[NSColor whiteColor]];
		[shadow setShadowBlurRadius:0.0];
		[shadow setShadowOffset:NSMakeSize(0, -1)];
		
		titleTextAttributes = [[NSDictionary alloc] initWithObjectsAndKeys:
			[NSColor colorWithDeviceWhite:0.4 alpha:1.0], NSForegroundColorAttributeName,
			titleFont, NSFontAttributeName,
			shadow, NSShadowAttributeName,
			nil];
		
		[shadow release];
	}
	
	return titleTextAttributes;
}


- (void)setTitle:(NSString *)aString
{
	// Apply the default attributes
	NSAttributedString *newTitle = [[NSAttributedString alloc] initWithString:aString
																   attributes:[self p_titleTextAttributes]];
	[self setAttributedTitle:newTitle];
	[newTitle release];
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


@end
