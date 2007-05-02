//
//  LPSourceListCell.h
//  Lilypad
//
//  Created by João Pavão on 07/03/21.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface LPSourceListCell : NSCell
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
