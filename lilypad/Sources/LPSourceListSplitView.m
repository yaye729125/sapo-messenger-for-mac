//
//  LPSourceListSplitView.m
//  Lilypad
//
//  Created by João Pavão on 07/12/21.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "LPSourceListSplitView.h"


@implementation LPSourceListSplitView

- (CGFloat)dividerThickness
{
	return 1.0;
}

- (void)drawDividerInRect:(NSRect)aRect
{
	[[NSColor lightGrayColor] set];
	NSRectFill(aRect);
}

@end
