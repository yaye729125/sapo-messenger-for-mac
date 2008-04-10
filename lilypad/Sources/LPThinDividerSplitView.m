//
//  LPThinDividerSplitView.m
//  Lilypad
//
//	Copyright (C) 2007-2008 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jpavao@co.sapo.pt>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "LPThinDividerSplitView.h"


@implementation LPThinDividerSplitView

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
