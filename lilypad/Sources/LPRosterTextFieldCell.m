//
//  LPRosterTextFieldCell.m
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Authors: Joao Pavao <jppavao@criticalsoftware.com>
//           Jason Kim <jason@512k.org>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "LPRosterTextFieldCell.h"


@implementation LPRosterTextFieldCell


- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	NSRect newFrame = cellFrame;
	NSSize size = [[self attributedStringValue] size];
	
	if (size.height < NSHeight(cellFrame)) {
		newFrame.origin.y += (NSHeight(newFrame) - size.height) / 2.0f;
		newFrame.size.height = size.height;
	}
	
	// Make the text white if we're selected.
	NSWindow *win = [controlView window];
	
	if ([self isHighlighted] && [win isKeyWindow] && [win firstResponder] == controlView) {
		NSMutableAttributedString *string = [[self attributedStringValue] mutableCopy];
		
		[string addAttribute:NSForegroundColorAttributeName
					   value:[NSColor whiteColor] 
					   range:NSMakeRange(0, [string length])];
		[self setAttributedStringValue:string];
	}
	
	//	[[NSColor blueColor] set];
	//	NSRectFill(newFrame);
	
	[super drawInteriorWithFrame:newFrame inView:controlView];
}


@end
