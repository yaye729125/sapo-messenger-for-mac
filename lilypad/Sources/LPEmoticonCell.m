//
//  LPEmoticonCell.m
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "LPEmoticonCell.h"


#define LPEmoticonCellHighlightBGRectCornerRadius	4.0f


@implementation LPEmoticonCell

- (void)mouseEntered:(NSEvent *)event
{
	[self setHighlighted:YES];
}

- (void)mouseExited:(NSEvent *)event
{
	[self setHighlighted:NO];
}

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	if ([self isHighlighted]) {
		/* Draw a rectangle with rounded corners behind the cell */
		float	radius = MIN(LPEmoticonCellHighlightBGRectCornerRadius, 0.5f * MIN(NSWidth(cellFrame), NSHeight(cellFrame)));
		NSRect	rect = NSInsetRect(cellFrame, radius, radius);
		
		NSBezierPath *highlightBackgroundPath = [NSBezierPath bezierPath];
		[highlightBackgroundPath appendBezierPathWithArcWithCenter:NSMakePoint(NSMinX(rect), NSMinY(rect))
															radius:radius startAngle:180.0 endAngle:270.0];
		[highlightBackgroundPath appendBezierPathWithArcWithCenter:NSMakePoint(NSMaxX(rect), NSMinY(rect))
															radius:radius startAngle:270.0 endAngle:360.0];
		[highlightBackgroundPath appendBezierPathWithArcWithCenter:NSMakePoint(NSMaxX(rect), NSMaxY(rect))
															radius:radius startAngle:  0.0 endAngle: 90.0];
		[highlightBackgroundPath appendBezierPathWithArcWithCenter:NSMakePoint(NSMinX(rect), NSMaxY(rect))
															radius:radius startAngle: 90.0 endAngle:180.0];
		[highlightBackgroundPath closePath];
		
		/* iChat uses a less saturated shade of blue in its smileys popup, but we'll use this one because it's the standard for
		highlighting menu items */
		[[NSColor selectedMenuItemColor] set];
		[highlightBackgroundPath fill];
	}
	
	NSImage *image = [self image];
	if (image) {
		/*
		 * Center the image in the cell.
		 *    We are assuming that the image already has the proper size so that we can simply composite it to a certain
		 *    point in the view without having to resize it everytime it's being drawn.
		 */
		NSSize	imageSize = [image size];
		NSPoint	targetPoint;
		
		targetPoint.x = NSMidX(cellFrame) - (imageSize.width / 2.0);
		targetPoint.y = NSMidY(cellFrame) - (imageSize.height / ([controlView isFlipped] ? -2.0 : 2.0));
		
		[image compositeToPoint:targetPoint operation:NSCompositeSourceOver];
	}
}

@end
