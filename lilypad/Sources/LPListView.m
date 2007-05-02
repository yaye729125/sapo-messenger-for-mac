//
//  LPListView.m
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informa›es sobre o licenciamento, leia o ficheiro README.
//

#import "LPListView.h"
#import "LPListViewRow.h"


@interface LPListView (Private)
- (void)p_adjustFrame;
- (void)p_clipViewFrameDidChange:(NSNotification *)note;
- (void)p_windowDidChangeKey:(NSNotification *)note;
- (BOOL)p_shouldShowFirstResponderStatus;
@end


@implementation LPListView

- (id)initWithFrame:(NSRect)frame
{
    if (self = [super initWithFrame:frame]) {
//		m_selectedIndexes = [[NSMutableIndexSet alloc] init];
		m_selectedRowViews = [[NSMutableArray alloc] init];
		m_lastMouseDownIndex = -1;
	}
    return self;
}

- (void)awakeFromNib
{
	// Setup the bounds change notifications
	NSClipView *enclosingClipView = [[self enclosingScrollView] contentView];

	if (enclosingClipView != nil) {
		[enclosingClipView setPostsFrameChangedNotifications:YES];
		
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(p_clipViewFrameDidChange:)
													 name:NSViewFrameDidChangeNotification
												   object:enclosingClipView];
	}
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
//	[m_selectedIndexes release];
	[m_selectedRowViews release];
	[super dealloc];
}

- (id)delegate
{
	return m_delegate;
}

- (void)setDelegate:(id)delegate
{
	m_delegate = delegate;
}

- (void)drawRect:(NSRect)rect
{	
	[self drawBackgroundInRect:rect];
}


- (void)tileRows
{
	float previousMaxY = 0.0;
	NSRect myBounds = [self bounds];
	
	NSEnumerator *viewEnum = [[self rowViews] objectEnumerator];
	NSView *subview;
	while (subview = [viewEnum nextObject]) {
		NSRect subviewFrame = [subview frame];
		
		subviewFrame.origin = NSMakePoint(NSMinX(myBounds), previousMaxY);
		subviewFrame.size.width = NSWidth(myBounds);
		[subview setFrame:subviewFrame];
		
		previousMaxY += NSHeight(subviewFrame);
	}
	
	[self p_adjustFrame];
}


#define LISTVIEW_DEFAULT_ROW_HEIGHT 40.0

- (void)drawBackgroundInRect:(NSRect)rect
{
	NSArray			*alternatingColors = [NSColor controlAlternatingRowBackgroundColors];
	unsigned int	nrOfColors = [alternatingColors count];
	unsigned int	rowIndex = 0;
	float			previousMaxY = 0.0;
	unsigned int	colorIndex = 0;
	
	NSEnumerator	*viewEnum = [[self rowViews] objectEnumerator];
	NSView			*rowView;
	
	// Paint the space filled with subviews
	while (rowView = [viewEnum nextObject]) {
		NSRect rowViewFrame = [rowView frame];
		
		if (NSMinY(rowViewFrame) > NSMaxY(rect)) {
			// We passed the rect to be drawn
			break;
		}
		else if (NSIntersectsRect(rowViewFrame, rect)) {
			[[alternatingColors objectAtIndex:colorIndex] set];
			NSRectFill(rowViewFrame);
		}
		
		++rowIndex;
		colorIndex = rowIndex % nrOfColors;
		previousMaxY += NSHeight(rowViewFrame);
	}
	
	// Paint the remaining space using a default row height.
	NSRect myBounds = [self bounds];
	while (previousMaxY < NSMaxY(rect)) {
		NSRect rowRect = NSMakeRect(NSMinX(myBounds), previousMaxY,
									NSWidth(myBounds), LISTVIEW_DEFAULT_ROW_HEIGHT);
		
		[[alternatingColors objectAtIndex:colorIndex] set];
		NSRectFill(rowRect);
		
		++rowIndex;
		colorIndex = rowIndex % nrOfColors;
		previousMaxY += LISTVIEW_DEFAULT_ROW_HEIGHT;
	}	
}


#pragma mark -


- (unsigned int)numberOfRows
{
	return [[self rowViews] count];
}


- (NSArray *)rowViews
{
	return [self subviews];
}


- (float)contentHeight
{
	id lastSubview = [[self rowViews] lastObject];
	return (lastSubview ? NSMaxY([lastSubview frame]) : 0.0);
}


- (void)addRowView:(LPListViewRow *)view
{
	// Set the subview frame
	NSRect	myBounds = [self bounds];
	
	[view setFrame:NSMakeRect(NSMinX(myBounds), [self contentHeight],
							  NSWidth(myBounds), NSHeight([view frame]))];
	[view setAutoresizingMask:( NSViewWidthSizable | NSViewMaxYMargin )];
	[view setShowsFirstResponder:[self p_shouldShowFirstResponderStatus]];
	
	// Finally, actually add the subview
	[self addSubview:view];
	// Grow our frame if needed
	[self p_adjustFrame];

	[[self enclosingScrollView] setNeedsDisplay:YES];
}


- (void)removeRowView:(LPListViewRow *)view
{
	NSAssert([[self rowViews] containsObject:view], @"Tryed to remove a view that isn't a member of this list");
	
	[view retain]; // the "removeFromSuperview" that follows could release the view
	[view removeFromSuperview];
	
	// Is it the last view? If not, remove the empty space that was left.
	if (NSMaxY([view frame]) < NSMaxY([self bounds]))
		[self tileRows];
	
	[view release];
	[[self enclosingScrollView] setNeedsDisplay:YES];
}


- (unsigned int)indexOfRowView:(LPListViewRow *)view
{
	return [[self rowViews] indexOfObject:view];
}


- (LPListViewRow *)rowViewAtIndex:(unsigned int)rowIndex
{
	return [[self rowViews] objectAtIndex:rowIndex];
}


- (LPListViewRow *)rowViewAtPoint:(NSPoint)point
{
	NSEnumerator	*viewEnum = [[self rowViews] objectEnumerator];
	LPListViewRow	*rowView;
	LPListViewRow	*hitView = nil;

	while (rowView = [viewEnum nextObject]) {
		if ([self mouse:point inRect:[rowView frame]]) {
			hitView = rowView;
			break;
		}
	}
	
	return hitView;
}


- (NSArray *)selectedRowViews
{
	return [[m_selectedRowViews copy] autorelease];
}


- (void)selectRowViews:(NSArray *)rows byExtendingSelection:(BOOL)extend
{
	NSMutableArray *deselectedRows = [m_selectedRowViews mutableCopy];
	NSMutableArray *newlySelectedRows = [rows mutableCopy];
	
	[newlySelectedRows removeObjectsInArray:m_selectedRowViews];
	
	
	if (extend == NO)
		[m_selectedRowViews removeAllObjects];
	
	[m_selectedRowViews addObjectsFromArray:rows];	
	[deselectedRows removeObjectsInArray:m_selectedRowViews];
	
	
	// Update the subviews
	id			delegate = [self delegate];

	NSEnumerator *rowEnumerator = [deselectedRows objectEnumerator];
	LPListViewRow *rowView;
	while (rowView = [rowEnumerator nextObject]) {
        [delegate listView:self didSelect:NO rowView:rowView];
		[rowView setHighlighted:NO];
	}
	
	rowEnumerator = [newlySelectedRows objectEnumerator];
	while (rowView = [rowEnumerator nextObject]) {
        [delegate listView:self didSelect:YES rowView:rowView];
		[rowView setHighlighted:YES];
	}
	
	
	[deselectedRows release];
	[newlySelectedRows release];
	
	[self setNeedsDisplay:YES];
}


- (void)deselectRowView:(LPListViewRow *)row
{
	[m_selectedRowViews removeObject:row];
	[[self delegate] listView:self didSelect:NO rowView:row];
	[row setHighlighted:NO];
	
	[self setNeedsDisplay:YES];
}


#pragma mark -
#pragma mark Actions


- (IBAction)selectAll:(id)sender
{
	[self selectRowViews:[self rowViews] byExtendingSelection:NO];
}


- (IBAction)deselectAll:(id)sender
{
	[self selectRowViews:nil byExtendingSelection:NO];
}


#pragma mark -
#pragma mark NSResponder Overrides


- (BOOL)acceptsFirstResponder
{
	return YES;
}


#pragma mark -
#pragma mark NSView Overrides


- (BOOL)isFlipped
{
	return YES;
}


- (BOOL)isOpaque
{
	return YES;
}


- (void)viewWillMoveToWindow:(NSWindow *)newWindow
{
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	NSWindow *win = [self window];
	
	[nc removeObserver:self name:NSWindowDidBecomeKeyNotification object:win];
	[nc removeObserver:self name:NSWindowDidResignKeyNotification object:win];
	
	[nc addObserver:self selector:@selector(p_windowDidChangeKey:) name:NSWindowDidBecomeKeyNotification object:newWindow];
	[nc addObserver:self selector:@selector(p_windowDidChangeKey:) name:NSWindowDidResignKeyNotification object:newWindow];
}


- (void)keyDown:(NSEvent *)theEvent
{
	unichar firstChar = [[theEvent characters] characterAtIndex:0];
	
	switch (firstChar) {
		case NSDownArrowFunctionKey:
		{
			unsigned int largestSelectedIndex = ( [m_selectedRowViews count] == 0 ?
												  NSNotFound :
												  [self indexOfRowView:[m_selectedRowViews lastObject]] );
			unsigned int indexToSelect = MIN( ([self numberOfRows] - 1),
											   ((largestSelectedIndex == NSNotFound) ? 0 : (largestSelectedIndex + 1)) );
			LPListViewRow *rowToSelect = [self rowViewAtIndex:indexToSelect];
			
			[self selectRowViews:[NSArray arrayWithObject:rowToSelect] byExtendingSelection:NO];
			break;
		}
			
		case NSUpArrowFunctionKey:
		{
			unsigned int smallestSelectedIndex = ( [m_selectedRowViews count] == 0 ?
												   NSNotFound :
												   [self indexOfRowView:[m_selectedRowViews objectAtIndex:0]] );
			unsigned int indexToSelect = ( (smallestSelectedIndex == 0) ? 0 :
										   ( (smallestSelectedIndex == NSNotFound) ?
											 ([self numberOfRows] - 1) :
											 (smallestSelectedIndex - 1) ));
			LPListViewRow *rowToSelect = [self rowViewAtIndex:indexToSelect];
			
			[self selectRowViews:[NSArray arrayWithObject:rowToSelect] byExtendingSelection:NO];
			break;
		}
			
		case NSDeleteFunctionKey:
#warning TO DO: keyDown -> NSDeleteFunctionKey
			NSLog(@"Delete");
			break;
	}
}


- (void)mouseDown:(NSEvent *)theEvent
{
	NSPoint mouseLocation = [self convertPoint:[theEvent locationInWindow] fromView:nil];
	LPListViewRow *hitRowView = [self rowViewAtPoint:mouseLocation];
	
	if (hitRowView == nil) {
		[self deselectAll:nil];
		m_lastMouseDownIndex = -1;
	}
	else {
		unsigned int clickedRowIndex = [self indexOfRowView:hitRowView];
		
		unsigned int modifiers = [theEvent modifierFlags];
		BOOL shiftKeyIsDown = ((modifiers & NSShiftKeyMask) != 0);
		BOOL cmdKeyIsDown = ((modifiers & NSCommandKeyMask) != 0);
		
		if (cmdKeyIsDown && [m_selectedRowViews containsObject:hitRowView]) {
			[self deselectRowView:hitRowView];
			m_lastMouseDownIndex = -1;
		}
		else {
			NSArray *rowsToSelect;
			
			if (shiftKeyIsDown) {
				unsigned int lowerRow, higherRow;
				
				if (m_lastMouseDownIndex == -1) {
					lowerRow = 0;
					higherRow = clickedRowIndex;
				} else {
					lowerRow = MIN(clickedRowIndex, m_lastMouseDownIndex);
					higherRow = MAX(clickedRowIndex, m_lastMouseDownIndex);
				}
				
				rowsToSelect = [[self rowViews] subarrayWithRange:NSMakeRange(lowerRow, higherRow - lowerRow + 1)];
			} else {
				rowsToSelect = [NSArray arrayWithObject:hitRowView];
			}
			
			[self selectRowViews:rowsToSelect byExtendingSelection:(shiftKeyIsDown || cmdKeyIsDown)];
			m_lastMouseDownIndex = clickedRowIndex;
		}
	}
}


- (void)mouseDragged:(NSEvent *)theEvent
{
#warning TO DO: selection by mouse drag or some other action for drag'n'drop
}


#pragma mark -
#pragma mark Private Methods


- (void)p_adjustFrame
{
	NSRect superviewBounds = [[self superview] bounds];
	NSRect myFrame = [self frame];
	
	myFrame.size.width = NSWidth(superviewBounds);
	myFrame.size.height = MAX([self contentHeight], NSHeight(superviewBounds));
	
	// Is the bottom side in the interior of the clip view?
	float bottomDeltaY = NSMaxY(superviewBounds) - NSMaxY(myFrame);
	myFrame.origin.y += MAX(0.0, bottomDeltaY);
	
	[self setFrame:myFrame];
	
	NSScrollView *sv = [self enclosingScrollView];
	[sv reflectScrolledClipView:[sv contentView]];
}

- (void)p_clipViewFrameDidChange:(NSNotification *)note
{
	[self p_adjustFrame];
}

- (void)p_windowDidChangeKey:(NSNotification *)note
{
	NSEnumerator *rowViewEnumerator = [[self rowViews] objectEnumerator];
	id rowView;
	BOOL shouldShowFirstResponder = [self p_shouldShowFirstResponderStatus];
	
	while (rowView = [rowViewEnumerator nextObject]) {
		[rowView setShowsFirstResponder:shouldShowFirstResponder];
	}
	
	[self setNeedsDisplay:YES];	
}

- (BOOL)p_shouldShowFirstResponderStatus
{
	NSWindow *win = [self window];
	return ((win == [NSApp keyWindow] || [win isKeyWindow]) && ([[self window] firstResponder] == self));
}

@end


@implementation NSObject (LPListViewDelegate)
- (void)listView:(LPListView *)l didSelect:(BOOL)flag rowView:(LPListViewRow *)rowView { }
@end
