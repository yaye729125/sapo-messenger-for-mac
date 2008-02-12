//
//  LPEmoticonMatrix.m
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jpavao@co.sapo.pt>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "LPEmoticonMatrix.h"
#import "LPEmoticonCell.h"
#import "LPEmoticonSet.h"

// For the calculations of the number of rows and columns that are needed
#include <math.h>


@implementation LPEmoticonMatrix

- (void)awakeFromNib
{
	id protoCell = [[self cellAtRow:0 column:0] copy];
	
	[self setPrototype:protoCell];
	[protoCell release];
}

- (void)loadEmoticonsFromSet:(LPEmoticonSet *)emoticonSet
{
	int nrOfEmoticons, nrOfRows, nrOfCols;
	
	/* Determine the number of rows and columns that are going to be needed. We try to keep	the shape of the matrix
	as square as possible, with the number of rows being always less than or equal to the number of columns. */
	nrOfEmoticons = [emoticonSet count];
	nrOfRows = (int)floorf(sqrtf(nrOfEmoticons));
	nrOfCols = (int)ceilf((float)nrOfEmoticons / nrOfRows);
	
	[self renewRows:nrOfRows columns:nrOfCols];
	[self sizeToCells];
	
	// Now load them
	int idx = 0;
	int i, j;
	NSCell *cell;
	
	for (i = 0; i < nrOfRows; ++i) {
		for (j = 0; j < nrOfCols; ++j, ++idx) {
			
			cell = [self cellAtRow:i column:j];
			
			if (idx < nrOfEmoticons) {
				[cell setImage:[emoticonSet imageForEmoticonNr:idx]];
				[cell setTag:idx];
			}
			else {
				/* It may happen that we have a number of emoticons that doesn't fill an entire rectangular matrix.
				If we have more matrix cells that emoticons, disable the cells in excess so that they don't highlight
				or accept mouse events. */
				[cell setEnabled:NO];
			}
		}
	}
}

- (NSCell *)highlightedCell
{
	return m_highlightedCell;
}

- (void)setHighlightedCell:(NSCell *)cell
{
	if (cell != m_highlightedCell) {
		[m_highlightedCell setHighlighted:NO];
		[cell setHighlighted:YES];
		m_highlightedCell = cell;
		
		// Notify the delegate
		if ([[self delegate] respondsToSelector:@selector(emoticonMatrix:highlightedCellDidChange:)]) {
			[[self delegate] emoticonMatrix:self highlightedCellDidChange:m_highlightedCell];
		}
	}
}

- (void)mouseMoved:(NSEvent *)theEvent
{
	NSPoint locationInWin = [[self window] mouseLocationOutsideOfEventStream];
	NSPoint location = [self convertPoint:locationInWin fromView:nil];
	
	int row, col;
	[self getRow:&row column:&col forPoint:location];
	NSCell *cellUnderMouse = [self cellAtRow:row column:col];
	
	[self setHighlightedCell:([cellUnderMouse isEnabled] ? cellUnderMouse : nil)];
}

- (void)mouseUp:(NSEvent *)theEvent
{
	if (m_highlightedCell != nil) {
		// Blink the chosen item
		int i;
		for (i = 0; i < 1; ++i) {
			[m_highlightedCell setHighlighted:NO];
			[self display];
			[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
			[m_highlightedCell setHighlighted:YES];
			[self display];
			[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
		}
		[self sendAction];
	}
}

- (void)drawRect:(NSRect)rect
{
	[[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
	[super drawRect:rect];
}

@end
