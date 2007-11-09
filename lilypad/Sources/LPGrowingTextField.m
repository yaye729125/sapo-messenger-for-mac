//
//  LPGrowingTextField.m
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "LPGrowingTextField.h"


@implementation LPGrowingTextField

- (void)awakeFromNib
{
	NSRect	bounds = [self bounds];
	NSRect	cellDrawingRect = [[self cell] drawingRectForBounds:bounds];
	m_verticalPadding = NSHeight(bounds) - NSHeight(cellDrawingRect) + 2.0;
}

- (void)calcContentSize
{
	if (m_calculatingSize == NO) {
		m_calculatingSize = YES;
		
		// Calculate the size where the entire contents can fit
		NSSize		neededTextFieldSize;
		NSRect		bounds = [self bounds];
		NSTextView	*fieldEditor = (NSTextView *)[self currentEditor];
		
		if (fieldEditor) {
			// The text field is being edited. Use the NSTextView's layout manager to get the current text bounds.
			NSRect textBoundsRect = [[fieldEditor layoutManager] usedRectForTextContainer:[fieldEditor textContainer]];
			
			neededTextFieldSize = textBoundsRect.size;
			neededTextFieldSize.width = NSWidth(bounds);
			neededTextFieldSize.height += m_verticalPadding;
		}
		else {
			// The text field is not being edited. Get the needed bounds rect from the cell's content size.
			neededTextFieldSize = [[self cell] cellSizeForBounds:bounds];
		}
		
		if (!NSEqualSizes(bounds.size, neededTextFieldSize)) {
			[[self delegate] growingTextField:self contentSizeDidChange:neededTextFieldSize];
		}
		
		m_calculatingSize = NO;
	}
}

- (void)viewDidEndLiveResize
{
	[super viewDidEndLiveResize];
	[self calcContentSize];
}

- (void)textDidChange:(NSNotification *)aNotification
{
	[self calcContentSize];
	[super textDidChange:aNotification];
}

@end


@implementation NSObject (LPGrowingTextFieldDelegate)
- (void)growingTextField:(LPGrowingTextField *)textField contentSizeDidChange:(NSSize)neededSize { }
@end
