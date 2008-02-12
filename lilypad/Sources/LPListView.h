//
//  LPListView.h
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jpavao@co.sapo.pt>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import <Cocoa/Cocoa.h>


@class LPListViewRow;


@interface LPListView : NSView
{
	id					m_delegate;
	
//	NSMutableIndexSet	*m_selectedIndexes;
	NSMutableArray		*m_selectedRowViews;
	unsigned int		m_lastMouseDownIndex;
	unsigned int		m_lastMouseDragIndex;
}

- (id)delegate;
- (void)setDelegate:(id)delegate;

- (void)tileRows;
- (void)drawBackgroundInRect:(NSRect)rect;

- (unsigned int)numberOfRows;
- (NSArray *)rowViews;
- (float)contentHeight;
- (void)addRowView:(LPListViewRow *)view;
- (void)removeRowView:(LPListViewRow *)view;

- (unsigned int)indexOfRowView:(LPListViewRow *)view;
- (LPListViewRow *)rowViewAtIndex:(unsigned int)rowIndex;
- (LPListViewRow *)rowViewAtPoint:(NSPoint)point;

- (NSArray *)selectedRowViews;
- (void)selectRowViews:(NSArray *)rows byExtendingSelection:(BOOL)extend;
- (void)deselectRowView:(LPListViewRow *)row;

- (IBAction)selectAll:(id)sender;
- (IBAction)deselectAll:(id)sender;

@end


@interface NSObject (LPListViewDelegate)
- (void)listView:(LPListView *)lv didSelect:(BOOL)flag rowView:(LPListViewRow *)rowView;
- (void)listView:(LPListView *)lv removeRowView:(LPListViewRow *)rowView;
@end
