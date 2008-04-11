//
//  JKGroupTableView.m
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Authors: Joao Pavao <jpavao@co.sapo.pt>
//           Jason Kim <jason@512k.org>
//
//	For more information on licensing, read the README file.
//	Para mais informa›es sobre o licenciamento, leia o ficheiro README.
//
//
// KNOWN BUGS:
//    - 0 elements in data source
//    - 1 element in data source

#import "JKGroupTableView.h"
#import "LPGroupButtonCell.h"


@interface JKGroupTableView ()  // Private Methods
- (unsigned int)p_numberOfGroupsUpToIndex:(unsigned int)rowIndex;
- (unsigned int)p_numberOfHiddenRowsUpToIndex:(unsigned int)rowIndex;
- (int)p_selectNextByExtendingSelection:(BOOL)extend;
- (int)p_selectPreviousByExtendingSelection:(BOOL)extend;
- (void)p_startTrackingGroupCellWithEvent:(NSEvent *)theEvent;
- (void)p_rebuildCaches;
@end


@implementation JKGroupTableView


#pragma mark -
#pragma mark Initialization


- (id)initWithCoder:(NSCoder *)decoder
{
	self = [super initWithCoder:decoder];
	
	m_groupIndexCache = [[NSMutableIndexSet alloc] init];
	m_hiddenRows = [[NSMutableIndexSet alloc] init];
	m_hiddenGroups = [[NSMutableIndexSet alloc] init];
	
	m_rowBeingTracked = -1;
	m_dropGroupRow = -1;
	
	return self;
}


- (void)dealloc
{
    [m_groupIndexCache release];
    [m_hiddenRows release];
    [m_hiddenGroups release];
    [super dealloc];
}


#pragma mark -
#pragma mark Instance Methods


- (BOOL)isRowVisible:(unsigned int)rowIndex
{
	return !([m_hiddenRows containsIndex:rowIndex]);
}


- (BOOL)isGroupIndex:(unsigned int)rowIndex
{
	return [m_groupIndexCache containsIndex:rowIndex];
}


- (unsigned int)groupIndexForRow:(unsigned int)rowIndex
{
	return [m_groupIndexCache indexLessThanOrEqualToIndex:rowIndex];
}


- (NSIndexSet *)rowsForGroupIndex:(unsigned int)rowIndex
{
	NSAssert1([self isGroupIndex:rowIndex], @"rowsForGroupIndex called with a non-group row index (%d)", rowIndex);
	
	unsigned int firstChildIndex = [self groupIndexForRow:rowIndex] + 1;
	unsigned int lastChildIndex = [m_groupIndexCache indexGreaterThanIndex:rowIndex];
	
	if (lastChildIndex == NSNotFound)
		lastChildIndex = m_numberOfRows;
	
	return [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(firstChildIndex, lastChildIndex - firstChildIndex)];
}


- (BOOL)isGroupExpanded:(int)rowIndex
{
	return ([m_hiddenGroups containsIndex:rowIndex] == NO);
}


- (void)collapseGroupAtIndex:(unsigned int)groupIndex
{
	if ([self isGroupIndex:groupIndex]) {
		NSIndexSet	*rowIndexes = [self rowsForGroupIndex:groupIndex];
		
		[m_hiddenGroups addIndex:groupIndex];
		[m_hiddenRows addIndexes:rowIndexes];

		// Force the table to filter out from the current selection the rows that are to be hidden
		[self selectRowIndexes:[self selectedRowIndexes] byExtendingSelection:NO];

		[self tile];
	}
}


- (void)expandGroupAtIndex:(unsigned int)groupIndex
{
	if ([self isGroupIndex:groupIndex]) {
		NSIndexSet *rowIndexes = [self rowsForGroupIndex:groupIndex];
		
		[m_hiddenGroups removeIndex:groupIndex];
		[m_hiddenRows removeIndexes:rowIndexes];
		
		[self tile];
	}
}


- (float)groupRowHeight
{
	return 21.0;
}


- (NSSize)groupIntercellSpacing
{
	return NSMakeSize(4.0, 4.0);
}


- (LPGroupButtonCell *)groupButtonCell
{
	static LPGroupButtonCell *cell = nil;
	if (cell == nil) {
		cell = [[LPGroupButtonCell alloc] init];
	}
	return cell;
}


- (NSRect)frameOfGroupCellAtRow:(int)rowIndex
{
	NSSize intercellSpace = [self groupIntercellSpacing];
	float dX = intercellSpace.width / 2.0;
	float dY = intercellSpace.height / 2.0;
	
	return NSInsetRect([self rectOfRow:rowIndex], dX, dY);
}


- (void)drawGroupCellInRow:(unsigned int)rowIndex clipRect:(NSRect)clipRect
{
	LPGroupButtonCell	*cell = [self groupButtonCell];
	NSRect				cellFrame = [self frameOfGroupCellAtRow:rowIndex];
	BOOL				shouldHighlight = NO;
	
	if (rowIndex == m_rowBeingTracked) {
		NSPoint location = [[NSApp currentEvent] locationInWindow];
		NSPoint point = [self convertPoint:location fromView:nil];
		
		shouldHighlight = [self mouse:point inRect:cellFrame];
	}
	
	[cell setTitle:[[self dataSource] groupTableView:self titleForGroupRow:rowIndex]];
	[cell setItemsCount:[[self dataSource] groupTableView:self memberCountForGroupRow:rowIndex]];
	[cell setState:[self isGroupExpanded:rowIndex]];
	[cell setHighlighted:shouldHighlight];
	
	[cell drawWithFrame:cellFrame inView:self];
}


- (NSRect)rectOfAllRowsOfGroupInRow:(int)groupRow
{
	if ([self isGroupIndex:groupRow]) {
		NSRect			groupWithContentsRect = [self rectOfRow:groupRow];
		unsigned int	lastRowIndexInGroup = [[self rowsForGroupIndex:groupRow] lastIndex];
		
		if (lastRowIndexInGroup != NSNotFound) {
			groupWithContentsRect.size.height = NSMaxY([self rectOfRow:lastRowIndexInGroup]) - NSMinY(groupWithContentsRect);
		}
		return groupWithContentsRect;
	}
	else {
		return NSZeroRect;
	}
}

- (NSMenu *)groupContextMenu
{
	return m_groupContextMenu;
}

- (void)setGroupContextMenu:(NSMenu *)menu
{
	if (menu != m_groupContextMenu) {
		[m_groupContextMenu release];
		m_groupContextMenu = [menu retain];
	}
}

- (NSMenu *)contactContextMenu
{
	return m_contactContextMenu;
}

- (void)setContactContextMenu:(NSMenu *)menu
{
	if (menu != m_contactContextMenu) {
		[m_contactContextMenu release];
		m_contactContextMenu = [menu retain];
	}
}

- (int)groupContextMenuLastHitRow
{
	return m_groupContextMenuLastHitRow;
}


- (IBAction)selectFirstNonGroupRow:(id)sender
{
	[self deselectAll:nil];
	[self p_selectNextByExtendingSelection:NO];
}


#pragma mark -
#pragma mark NSTableView Overrides


- (void)drawRect:(NSRect)rect
{
	[super drawRect:rect];
	
	if (m_dropGroupRow >= 0) {
		[[NSColor alternateSelectedControlColor] set];
		NSFrameRectWithWidth([self rectOfAllRowsOfGroupInRow:m_dropGroupRow], 3.0);
	}
}


- (void)drawBackgroundInClipRect:(NSRect)rect
{
	if ([self usesAlternatingRowBackgroundColors] && (m_numberOfRows > 0)) {
		NSArray	*rowColors = [NSColor controlAlternatingRowBackgroundColors];
		int		currentRow = [self rowAtPoint:rect.origin];
		int		rowColorCount = [rowColors count];
		int		colorIndex = (currentRow - [self groupIndexForRow:currentRow] - 1) % rowColorCount;
		float	clipRectEnd = NSMaxY(rect);
		
		// Iterate through the rows, alternating colors each time. Group rows get their
		// backgrounds drawn with the first element (which is probably white), and the first
		// row under each group is always the same color.
		NSRect currentRect = [self rectOfRow:currentRow];
		
		while (currentRect.origin.y < clipRectEnd) {		
			if ([self isGroupIndex:currentRow]) {
				// Draw group row background.
				currentRect.size.height = [self groupRowHeight] + [self groupIntercellSpacing].height;
				[[self backgroundColor] set];
				colorIndex = 0;
			}
			else if ([self isRowVisible:currentRow]) {
				// Draw ordinary (alternating color row) background.
				[[rowColors objectAtIndex:colorIndex] set];
				currentRect.size.height = [self rowHeight] + [self intercellSpacing].height;
				colorIndex = (colorIndex + 1) % rowColorCount;
			}
			else {
				// Row is hidden; don't do anything.
				currentRect.size.height = 0;
			}
			
			NSRectFill(currentRect);
			
			currentRow++;
			currentRect.origin.y += currentRect.size.height;
		}
	}
	else {
		[super drawBackgroundInClipRect:rect];
	}
}


- (void)drawRow:(int)rowIndex clipRect:(NSRect)clipRect
{
	if ([self isGroupIndex:rowIndex] && [self dataSource]) {
		[self drawGroupCellInRow:rowIndex clipRect:clipRect];
	}
	else if ([self isRowVisible:rowIndex]) {
		[super drawRow:rowIndex clipRect:clipRect];
	}
}


- (void)keyDown:(NSEvent *)event
{
	unichar key = [[event characters] characterAtIndex:0];
	
	switch (key) {
		case NSDownArrowFunctionKey:
		{
			int selIdx = [self p_selectNextByExtendingSelection:(([event modifierFlags] & NSShiftKeyMask) > 0)];
			[self scrollRowToVisible:selIdx];
			break;
		}
			
		case NSUpArrowFunctionKey:
		{
			int selIdx = [self p_selectPreviousByExtendingSelection:(([event modifierFlags] & NSShiftKeyMask) > 0)];
			[self scrollRowToVisible:selIdx];
			break;
		}
			
		case NSDeleteFunctionKey:
		case NSDeleteCharacter:
			if ([self selectedRow] >= 0) {
				[[self dataSource] groupTableView:self deleteRows:[self selectedRowIndexes]];
				break;
			}
			
		default:
			[super keyDown:event];
	}
}


- (void)mouseDown:(NSEvent *)theEvent
{
	NSPoint location = [theEvent locationInWindow];
	NSPoint point = [self convertPoint:location fromView:nil];
	unsigned int clickedRow = [self rowAtPoint:point];
	
	// We are tolerant and allow the user to also use double-clicks (or n-clicks :)) on the groups
	if ([self isGroupIndex:clickedRow] && ([theEvent clickCount] == 1)) {
		m_rowBeingTracked = clickedRow;
		[self p_startTrackingGroupCellWithEvent:theEvent];
	}
	else {
		[super mouseDown:theEvent];
	}
}


- (void)mouseDragged:(NSEvent *)theEvent
{
	NSPoint location = [theEvent locationInWindow];
	NSPoint point = [self convertPoint:location fromView:nil];
	
	if (m_rowBeingTracked >= 0 && [self mouse:point inRect:[self frameOfGroupCellAtRow:m_rowBeingTracked]]) {
		[self p_startTrackingGroupCellWithEvent:theEvent];
	} else {
		[super mouseDragged:theEvent];
	}
}


- (NSRect)rectOfRow:(int)rowIndex
{
	NSRect rect = NSZeroRect;
	
	if (rowIndex >= 0 && rowIndex < m_numberOfRows) {
		float groupVertIntercellSpace = [self groupIntercellSpacing].height;
		float vertIntercellSpace = [self intercellSpacing].height;
		
		unsigned int groupRowCount = [self p_numberOfGroupsUpToIndex:rowIndex];
		unsigned int rowCount = rowIndex - groupRowCount - [self p_numberOfHiddenRowsUpToIndex:rowIndex];
		
		unsigned int offset = ( (groupRowCount	* ([self groupRowHeight] + groupVertIntercellSpace	)) +
								(rowCount		* ([self rowHeight]		 + vertIntercellSpace		)) );
		
		float rowHeight;
		
		if ([self isRowVisible:rowIndex]) {
			rowHeight = ( ([self isGroupIndex:rowIndex]) ?
						  ([self groupRowHeight] + groupVertIntercellSpace) :
						  ([self rowHeight]		 + vertIntercellSpace	  ) );
		}
		else {
			rowHeight = 0.0;
		}
		
		rect = NSMakeRect(0.0, offset, [self bounds].size.width, rowHeight);
	}
	
	return rect;
}


- (int)rowAtPoint:(NSPoint)point
{
	int row = -1;
	
	if ((point.x >= 0.0) && (point.x <= [self bounds].size.width)) {
		float groupVertIntercellSpace = [self groupIntercellSpacing].height;
		float vertIntercellSpace = [self intercellSpacing].height;
		
		float offset = 0.0;
		int currentRow;
		
		for (currentRow = 0; currentRow < m_numberOfRows; currentRow++) {
			if ([self isRowVisible:currentRow]) {
				offset += ( ([self isGroupIndex:currentRow]) ?
							([self groupRowHeight] + groupVertIntercellSpace) :
							([self rowHeight]	   + vertIntercellSpace		) );
				
				if (point.y < offset) {
					row = currentRow;
					break;
				}
			}
		}
	}
	
	return row;
}


- (void)selectRowIndexes:(NSIndexSet *)indexes byExtendingSelection:(BOOL)extend
{
	NSMutableIndexSet *newIndexes = [indexes mutableCopy];
	
	// Disallow selection of group indexes and hidden items.
	[newIndexes removeIndexes:m_groupIndexCache];
	[newIndexes removeIndexes:m_hiddenRows];
	
	// Pass it on, then clean up.
	[super selectRowIndexes:newIndexes byExtendingSelection:extend];
	[newIndexes release];
}


- (void)reloadData
{
	[self p_rebuildCaches];
	[super reloadData];
}


- (void)showDropHighlightAroundGroupOfRow:(int)row
{
	int groupIndex = [self groupIndexForRow:row];
	
	if (groupIndex != m_dropGroupRow) {
		[self clearGroupDropHighlight];
		m_dropGroupRow = groupIndex;
		[self setNeedsDisplayInRect:[self rectOfAllRowsOfGroupInRow:groupIndex]];
	}
}


- (void)clearGroupDropHighlight
{
	if (m_dropGroupRow >= 0) {
		[self setNeedsDisplayInRect:[self rectOfAllRowsOfGroupInRow:m_dropGroupRow]];
		m_dropGroupRow = -1;
	}
}


/*
 * Unfortunately, if we want to customize the drawing of the drop highlight in a table view we need to
 * override a private method. :-(
 *
 * See the following thread: http://www.cocoabuilder.com/archive/message/cocoa/2006/4/16/161173
 */
- (void)_drawDropHighlightOnRow:(int)row
{
	if ([self isGroupIndex:row]) {
		// Don't draw anything as we're already highlighting entire groups through the regular display mechanism.
		// We can't do it in here because we have a clip rect set around this method that restrains drawing
		// to the row passed in as argument.
	} else {
		[(id)super _drawDropHighlightOnRow:row];
	}
}


- (void)draggingExited:(id <NSDraggingInfo>)sender
{
	[self clearGroupDropHighlight];
	[super draggingExited:sender];
}


- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
	[self clearGroupDropHighlight];
	return [super prepareForDragOperation:sender];
}


- (NSMenu *)menuForEvent:(NSEvent *)theEvent
{
	NSPoint mouseLocInView = [self convertPoint:[theEvent locationInWindow] fromView:nil];
	int hitRow = [self rowAtPoint:mouseLocInView];
	
	if ([self isGroupIndex:hitRow]) {
		m_groupContextMenuLastHitRow = hitRow;
		return [self groupContextMenu];
	}
	else if (hitRow >= 0 && hitRow < [self numberOfRows]) {
		if (![[self selectedRowIndexes] containsIndex:hitRow]) {
			[self selectRowIndexes:[NSIndexSet indexSetWithIndex:hitRow] byExtendingSelection:NO];
		}
		return [self contactContextMenu];
	}
	else {
		return nil;
	}
}


#pragma mark -
#pragma mark Private Methods


- (unsigned int)p_numberOfGroupsUpToIndex:(unsigned int)rowIndex
{
	if (rowIndex == 0) {
		return 0;
	}
	else {
		// FIXME: This should be a category on NSIndexSet.
		NSRange indexRange = NSMakeRange(0, rowIndex);
		unsigned int totalCount = [m_groupIndexCache count];
		unsigned int *indexBuffer = malloc(sizeof(unsigned int) * totalCount);
		
		unsigned int count = [m_groupIndexCache getIndexes:indexBuffer maxCount:totalCount inIndexRange:&indexRange];
		free(indexBuffer);
		
		return count;
	}
}


- (unsigned int)p_numberOfHiddenRowsUpToIndex:(unsigned int)rowIndex
{
	if (rowIndex == 0) {
		return 0;
	}
	else {
		// FIXME: This should probably be a category on NSIndexSet.
		NSRange indexRange = NSMakeRange(0, rowIndex);
		unsigned int totalCount = [m_hiddenRows count];
		unsigned int *indexBuffer = malloc(sizeof(unsigned int) * totalCount);
		
		unsigned int count = [m_hiddenRows getIndexes:indexBuffer maxCount:totalCount inIndexRange:&indexRange];
		free(indexBuffer);
		
		return count;
	}
}


- (int)p_selectNextByExtendingSelection:(BOOL)extend
{
	NSIndexSet *selectedRows = [self selectedRowIndexes];
	int rowToSelect = -1, nextRowToBeTestedForGroup = 0;
	
	if ([selectedRows count] > 0) {
		rowToSelect = [selectedRows lastIndex];
		nextRowToBeTestedForGroup = rowToSelect + 1;
	}
	
	// Find the next non-group row
	while (nextRowToBeTestedForGroup < m_numberOfRows &&
		   ( [self isGroupIndex:nextRowToBeTestedForGroup] || [self isRowVisible:nextRowToBeTestedForGroup] == NO ))
		nextRowToBeTestedForGroup++;
	
	// Did we find one?
	if (nextRowToBeTestedForGroup < m_numberOfRows)
		rowToSelect = nextRowToBeTestedForGroup;
	
	if (rowToSelect >= 0)
		[self selectRowIndexes:[NSIndexSet indexSetWithIndex:rowToSelect] byExtendingSelection:extend];
	
	return rowToSelect;
}


- (int)p_selectPreviousByExtendingSelection:(BOOL)extend
{
	NSIndexSet *selectedRows = [self selectedRowIndexes];
	int rowToSelect = -1, nextRowToBeTestedForGroup = m_numberOfRows - 1;
	
	if ([selectedRows count] > 0) {
		rowToSelect = [selectedRows firstIndex];
		nextRowToBeTestedForGroup = rowToSelect - 1;
	}
	
	// Find the next non-group row
	while (nextRowToBeTestedForGroup >= 0 &&
		   ( [self isGroupIndex:nextRowToBeTestedForGroup] || [self isRowVisible:nextRowToBeTestedForGroup] == NO ))
		nextRowToBeTestedForGroup--;
	
	// Did we find one?
	if (nextRowToBeTestedForGroup >= 0)
		rowToSelect = nextRowToBeTestedForGroup;
	
	if (rowToSelect >= 0)
		[self selectRowIndexes:[NSIndexSet indexSetWithIndex:rowToSelect] byExtendingSelection:extend];
	
	return rowToSelect;
}


- (void)p_startTrackingGroupCellWithEvent:(NSEvent *)theEvent
{
	NSCell	*cell = [self groupButtonCell];
	NSRect	cellFrame = [self frameOfGroupCellAtRow:m_rowBeingTracked];
	
	[cell highlight:YES withFrame:cellFrame inView:self];
	if ([cell trackMouse:theEvent inRect:cellFrame ofView:self untilMouseUp:NO])
		[[self delegate] groupTableView:self groupRowClicked:m_rowBeingTracked];
	[cell highlight:NO withFrame:cellFrame inView:self];

	if ([[NSApp currentEvent] type] == NSLeftMouseUp)
		m_rowBeingTracked = -1;
}


- (void)p_rebuildCaches
{
	// All groups unfold on reload
	[m_groupIndexCache removeAllIndexes];
	[m_hiddenRows removeAllIndexes];
	[m_hiddenGroups removeAllIndexes];
	
	// Make sure we have a data source before proceeding.
	if ([self dataSource]) {				
		// Save the number of rows, as we will be accessing this value many times.
		m_numberOfRows = [[self dataSource] numberOfRowsInTableView:self];
		
		// Find out which row indexes correspond to groups.
		int i;
		for (i = 0; i < m_numberOfRows; i++) {
			if ([[self dataSource] groupTableView:self isGroupRow:i]) {
				[m_groupIndexCache addIndex:i];
			}
		}
	}
}


@end


#pragma mark -
#pragma mark JKGroupTableViewDataSource Stub Methods


@implementation NSObject (JKGroupTableViewDataSource)
- (void)groupTableView:(JKGroupTableView *)tableView deleteRows:(NSIndexSet *)rowSet				{ return;			}
- (BOOL)groupTableView:(JKGroupTableView *)tableView isGroupRow:(int)rowIndex						{ return NO;		}
- (NSString *)groupTableView:(JKGroupTableView *)tableView titleForGroupRow:(int)rowIndex			{ return @"Group";	}
- (unsigned int)groupTableView:(JKGroupTableView *)tableView memberCountForGroupRow:(int)rowIndex	{ return 0;	}
- (void)groupTableView:(JKGroupTableView *)tableView groupRowClicked:(int)rowIndex					{ return;			}
@end
