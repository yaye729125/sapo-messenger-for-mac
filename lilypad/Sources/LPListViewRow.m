//
//  LPListViewRow.m
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jpavao@co.sapo.pt>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "LPListViewRow.h"
#import "LPListView.h"


@implementation LPListViewRow


- (LPListView *)listView
{
	return [[m_listView retain] autorelease];
}


- (void)setListView:(LPListView *)listView
{
	m_listView = listView;
}


- (BOOL)isHighlighted
{
	return m_isHighlighted;
}


- (void)setHighlighted:(BOOL)flag
{
	if (m_isHighlighted != flag) {
		m_isHighlighted = flag;
		[self setNeedsDisplay:YES];
	}
}


- (BOOL)showsFirstResponder
{
	return m_showsFirstResponder;
}


- (void)setShowsFirstResponder:(BOOL)flag
{
	if (m_showsFirstResponder != flag) {
		m_showsFirstResponder = flag;
		[self setNeedsDisplay:YES];
	}
}


- (void)drawRect:(NSRect)rect
{
	if ([self isHighlighted]) {
		// Do like NSTableView and take one pixel out so that we can see the separation
		// between consecutive highlighted rows.
		NSRect highlightRect = [self bounds];
		highlightRect.size.height -= 1.0;
		highlightRect.origin.y += 1.0;
		
		if ([self showsFirstResponder]) {
			[[NSColor alternateSelectedControlColor] set];
		} else {
			[[NSColor secondarySelectedControlColor] set];
		}
		NSRectFill(highlightRect);
	}
}


- (float)height
{
	return NSHeight([self frame]);
}


- (void)setHeight:(float)height
{
	NSRect myFrame = [self frame];
	myFrame.size.height = height;
	[self setFrame:myFrame];
	
	[[self listView] tileRows];
	[[self listView] setNeedsDisplay:YES];
	[self setNeedsDisplay:YES];
}


@end
