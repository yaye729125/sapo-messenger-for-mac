//
//  LPEmoticonCell.m
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jpavao@co.sapo.pt>
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
		
		/* This is the same color that iChat (Leopard) uses in its smileys popup */
		[[NSColor colorWithDeviceRed:0.3843 green:0.5000 blue:0.7461 alpha:1.0] set];
		[highlightBackgroundPath fill];
	}
	
	NSImage *image = [self image];
	if (image) {
		NSSize imageSize = [image size];
		
		[image setFlipped:[controlView isFlipped]];
		[image drawInRect:NSInsetRect(cellFrame, 1.0, 1.0)
				 fromRect:NSMakeRect(0.0, 0.0, imageSize.width, imageSize.height)
				operation:NSCompositeSourceOver
				 fraction:1.0];
	}
}

@end
