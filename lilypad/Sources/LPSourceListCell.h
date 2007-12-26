//
//  LPSourceListCell.h
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import <Cocoa/Cocoa.h>


@interface LPSourceListCell : NSActionCell
{
	NSImage			*m_icon;
	unsigned int	m_newItemsCount;
}
- (NSImage *)image;
- (void)setImage:(NSImage *)img;
- (unsigned int)newItemsCount;
- (void)setNewItemsCount:(unsigned int)count;

- (NSAttributedString *)newItemsCountAttributedString;
- (NSRect)imageRectForBounds:(NSRect)theRect;
- (NSRect)titleRectForBounds:(NSRect)theRect;
- (NSRect)newItemsCountRectForBounds:(NSRect)theRect;
- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView;

@end
