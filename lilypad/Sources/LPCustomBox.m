//
//  LPCustomBox.m
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Author: Jason Kim <jason@512k.org>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "LPCustomBox.h"


// Corner image fragments
static NSRect BoxNWRect = { { 0, 10 }, { 6, 6 } };
static NSRect BoxNERect = { { 10, 10 }, { 6, 6 } };
static NSRect BoxSWRect = { { 0, 0 }, { 6, 6 } };
static NSRect BoxSERect = { { 10, 0 }, { 6, 6 } };

// Edge image fragments
static NSRect BoxNRect = { { 6, 10 }, { 4, 6 } };
static NSRect BoxWRect = { { 0, 6 }, { 6, 4 } };
static NSRect BoxERect = { { 10, 6 }, { 6, 4 } };
static NSRect BoxSRect = { { 6, 0 }, { 4, 6 } };


@implementation LPCustomBox


- (void)awakeFromNib
{
	_borderImage = [NSImage imageNamed:@"BoxBorder"];
}


- (void)drawRect:(NSRect)rect
{
	NSPoint nwPoint, nePoint, swPoint, sePoint;
	NSRect nRect, wRect, eRect, sRect;
	NSRect boundsRect;
	float height, width;

	boundsRect = [self bounds];

	// Store dimensions for easy access.
	height = NSHeight(boundsRect);
	width = NSWidth(boundsRect);

	// Compute corner points.
	nwPoint = NSMakePoint(0, height - 6);
	nePoint = NSMakePoint(width - 6, height - 6);
	swPoint = NSMakePoint(0, 0);
	sePoint = NSMakePoint(width - 6, 0);
	
	// Draw corners.
	[_borderImage compositeToPoint:nwPoint fromRect:BoxNWRect operation:NSCompositeSourceOver fraction:1.0];
	[_borderImage compositeToPoint:nePoint fromRect:BoxNERect operation:NSCompositeSourceOver fraction:1.0];
	[_borderImage compositeToPoint:swPoint fromRect:BoxSWRect operation:NSCompositeSourceOver fraction:1.0];
	[_borderImage compositeToPoint:sePoint fromRect:BoxSERect operation:NSCompositeSourceOver fraction:1.0];
	
	// Compute edge rects.
	nRect = NSMakeRect(6, height - 6, width - 12, 6);
	wRect = NSMakeRect(0, 6, 6, height - 12);
	eRect = NSMakeRect(width - 6, 6, 6, height - 12);
	sRect = NSMakeRect(6, 0, width - 12, 6);
	
	// Draw edges.
	[_borderImage drawInRect:nRect fromRect:BoxNRect operation:NSCompositeSourceOver fraction:1.0];
	[_borderImage drawInRect:wRect fromRect:BoxWRect operation:NSCompositeSourceOver fraction:1.0];
	[_borderImage drawInRect:eRect fromRect:BoxERect operation:NSCompositeSourceOver fraction:1.0];
	[_borderImage drawInRect:sRect fromRect:BoxSRect operation:NSCompositeSourceOver fraction:1.0];

/*	
	if (!NSEqualRects(rect, [self bounds]))
	{
		[[NSColor redColor] set];
		NSRectFill(rect);
	}
*/
}


- (BOOL)isOpaque
{
	return NO;
}


@end
