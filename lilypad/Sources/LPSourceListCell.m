//
//  LPSourceListCell.m
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informa›es sobre o licenciamento, leia o ficheiro README.
//

#import "LPSourceListCell.h"


@implementation LPSourceListCell

- (id)copyWithZone:(NSZone *)zone
{
	LPSourceListCell *newObj = [super copyWithZone:zone];
	
	newObj->m_icon = nil;
	[newObj setImage:[self image]];
	
	return newObj;
}

- (void)dealloc
{
	[m_icon release];
	[super dealloc];
}

- (NSImage *)image
{
	return [[m_icon retain] autorelease];
}

- (void)setImage:(NSImage *)img
{
	if (m_icon != img) {
		[m_icon release];
		m_icon = [img copy];
	}
}

- (unsigned int)newItemsCount
{
	return m_newItemsCount;
}

- (void)setNewItemsCount:(unsigned int)count
{
	m_newItemsCount = count;
}


#pragma mark New Items Count

- (NSAttributedString *)newItemsCountAttributedString
{
	NSString *newItemsCountString = [NSString stringWithFormat:@"%d", [self newItemsCount]];
	NSDictionary *attribs = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSFont boldSystemFontOfSize:[NSFont smallSystemFontSize]], NSFontAttributeName,
		nil];
	
	return [[[NSAttributedString alloc] initWithString:newItemsCountString attributes:attribs] autorelease];
}

#pragma mark NSCell overrides


- (NSRect)imageRectForBounds:(NSRect)theRect
{
	NSRect imageRect, remainder;
	NSDivideRect(theRect, &imageRect, &remainder, NSHeight(theRect), NSMinXEdge);
	return imageRect;
}

- (NSRect)titleRectForBounds:(NSRect)theRect
{
	NSRect imageRect = [self imageRectForBounds:theRect];
	NSRect countRect = [self newItemsCountRectForBounds:theRect];
	NSRect titleRect = theRect;
	
	titleRect.origin.x += NSWidth(imageRect);
	titleRect.size.width -= (NSWidth(imageRect) + NSWidth(countRect));
	
	return titleRect;
}

- (NSRect)newItemsCountRectForBounds:(NSRect)theRect
{
	if ([self newItemsCount] > 0) {
		NSSize countStringSize = [[self newItemsCountAttributedString] size];
		
		NSRect newItemsCountRect, remainder;
		NSDivideRect(theRect, &newItemsCountRect, &remainder, countStringSize.width, NSMaxXEdge);
		
		return newItemsCountRect;
	}
	else {
		return NSZeroRect;
	}
}

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	NSRect imageRect = [self imageRectForBounds:cellFrame];
	NSRect titleRect = [self titleRectForBounds:cellFrame];
	NSRect countRect = [self newItemsCountRectForBounds:cellFrame];
	
	NSImage *img = [self image];
	NSSize imgSize = (img ? [img size] : NSZeroSize);
	
	[img setFlipped:[controlView isFlipped]];
	[img drawInRect:imageRect
		   fromRect:NSMakeRect(0.0, 0.0, imgSize.width, imgSize.height)
		  operation:NSCompositeSourceOver
		   fraction:1.0];
	
	// Use super's powers to draw our string value
	[super drawInteriorWithFrame:titleRect inView:controlView];
	
	if ([self newItemsCount] > 0)
		[[self newItemsCountAttributedString] drawAtPoint:countRect.origin];
}

@end
