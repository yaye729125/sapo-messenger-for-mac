//
//  JKGroupTableView.h
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Authors: Joao Pavao <jppavao@criticalsoftware.com>
//           Jason Kim <jason@512k.org>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//
//
// Provides a subclass of NSTableView that aims to provide functionality similar to iChat's
// animated, grouped roster view. Although Tiger introduced a variable-height NSTableView, 
// this class is implemented on Panther APIs for compatibility.
//
// This class is intended to work as a drop-in replacement for NSTableView, for the most
// part. Currently, bindings are not supported; the view talks to an enhanced table data
// source for its information.
//
// TODO: The data source interface should be retooled to follow MVC idioms, moving some of the
// responsibility to the data source object; we really shouldn't keep a cached representation of 
// the data source. (See iChat's NSTableView subclasses for inspiration.)
//

#import <Cocoa/Cocoa.h>
#import "LPInterAppDraggingTableView.h"


@class LPGroupButtonCell;


@interface JKGroupTableView : LPInterAppDraggingTableView {
	NSMutableIndexSet	*m_groupIndexCache;
	NSMutableIndexSet	*m_hiddenRows;
	NSMutableIndexSet	*m_hiddenGroups;
	unsigned int		m_numberOfRows;
	int					m_rowBeingTracked;
	int					m_dropGroupRow;
	
	NSMenu				*m_groupContextMenu;
	int					m_groupContextMenuLastHitRow;
	NSMenu				*m_contactContextMenu;
}

- (BOOL)isRowVisible:(unsigned int)rowIndex;

- (BOOL)isGroupIndex:(unsigned int)rowIndex;
- (unsigned int)groupIndexForRow:(unsigned int)rowIndex;
- (NSIndexSet *)rowsForGroupIndex:(unsigned int)rowIndex;
- (BOOL)isGroupExpanded:(int)rowIndex;
- (void)collapseGroupAtIndex:(unsigned int)groupIndex;
- (void)expandGroupAtIndex:(unsigned int)groupIndex;

- (float)groupRowHeight;
- (NSSize)groupIntercellSpacing;
- (LPGroupButtonCell *)groupButtonCell;
- (NSRect)frameOfGroupCellAtRow:(int)rowIndex;
- (void)drawGroupCellInRow:(unsigned int)rowIndex clipRect:(NSRect)clipRect;
- (NSRect)rectOfAllRowsOfGroupInRow:(int)groupRow;

- (void)showDropHighlightAroundGroupOfRow:(int)row;
- (void)clearGroupDropHighlight;

- (NSMenu *)groupContextMenu;
- (void)setGroupContextMenu:(NSMenu *)menu;
- (NSMenu *)contactContextMenu;
- (void)setContactContextMenu:(NSMenu *)menu;
- (int)groupContextMenuLastHitRow;

- (IBAction)selectFirstNonGroupRow:(id)sender;

@end


// Enhanced data source.
@interface NSObject (JKGroupTableViewDataSource)
- (void)tableView:(JKGroupTableView *)tableView deleteRows:(NSIndexSet *)rowSet;
- (BOOL)tableView:(JKGroupTableView *)tableView isGroupRow:(int)rowIndex;
- (NSString *)tableView:(JKGroupTableView *)tableView titleForGroupRow:(int)rowIndex;
- (void)tableView:(JKGroupTableView *)tableView groupRowClicked:(int)rowIndex;
@end
