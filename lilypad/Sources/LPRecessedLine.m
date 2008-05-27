//
//  LPRecessedLine.m
//  Lilypad
//
//  Created by João Pavão on 08/05/27.
//  Copyright 2008 Sapo. All rights reserved.
//

#import "LPRecessedLine.h"


@implementation LPRecessedLine

- (void)drawRect:(NSRect)rect
{
	NSRect bounds = [self bounds];
	NSRect lightLineRect = NSZeroRect;
	NSRect darkLineRect = NSZeroRect;
	
	if (NSWidth(bounds) > NSHeight(bounds)) {
		lightLineRect = NSMakeRect(NSMinX(bounds), NSMinY(bounds), NSWidth(bounds), 1.0);
		darkLineRect = NSOffsetRect(lightLineRect, 0.0, 1.0);
	}
	else {
		lightLineRect = NSMakeRect(NSMinX(bounds), NSMinY(bounds), 1.0, NSHeight(bounds));
		darkLineRect = NSOffsetRect(lightLineRect, 1.0, 0.0);
	}
	
	[[NSColor colorWithCalibratedWhite:1.0 alpha:0.67] set];
	NSRectFillUsingOperation(lightLineRect, NSCompositeSourceOver);
	[[NSColor colorWithCalibratedWhite:0.0 alpha:0.67] set];
	NSRectFillUsingOperation(darkLineRect, NSCompositeSourceOver);
}

@end
