//
//  LPListViewRow.h
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jpavao@co.sapo.pt>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import <Cocoa/Cocoa.h>


@class LPListView;


@interface LPListViewRow : NSView
{
	LPListView	*m_listView;
	BOOL		m_isHighlighted;
	BOOL		m_showsFirstResponder;
}

- (LPListView *)listView;
- (void)setListView:(LPListView *)listView;
- (BOOL)isHighlighted;
- (void)setHighlighted:(BOOL)flag;
- (BOOL)showsFirstResponder;
- (void)setShowsFirstResponder:(BOOL)flag;
- (float)height;
- (void)setHeight:(float)height;

@end
