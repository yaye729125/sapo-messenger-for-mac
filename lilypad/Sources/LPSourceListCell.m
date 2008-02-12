//
//  LPSourceListCell.m
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jpavao@co.sapo.pt>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
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
		[NSFont systemFontOfSize:[NSFont smallSystemFontSize]], NSFontAttributeName,
		([self isHighlighted] ? [NSColor whiteColor] : [NSColor blackColor]), NSForegroundColorAttributeName,
		nil];
	
	return [[[NSAttributedString alloc] initWithString:newItemsCountString attributes:attribs] autorelease];
}

#pragma mark NSCell overrides


- (NSRect)imageRectForBounds:(NSRect)theRect
{
	NSRect imageRect, remainder;
	NSDivideRect(theRect, &imageRect, &remainder, NSHeight(theRect), NSMinXEdge);
	return NSInsetRect(NSOffsetRect(imageRect, 4.0, 0.0), 1.0, 1.0);
}

- (NSRect)titleRectForBounds:(NSRect)theRect
{
	NSSize titleSize = [[self attributedStringValue] size];
	
	NSRect imageRect = [self imageRectForBounds:theRect];
	NSRect countRect = [self newItemsCountRectForBounds:theRect];
	NSRect titleRect;
	
	titleRect.origin.x = NSMaxX(imageRect) + 4.0;
	titleRect.origin.y = NSMinY(theRect) + (NSHeight(theRect) - titleSize.height) / 2.0;
	titleRect.size.width = (NSIsEmptyRect(countRect) ? NSMaxX(theRect) : NSMinX(countRect)) - NSMaxX(imageRect) - 6.0;
	titleRect.size.height = titleSize.height;
	
	return titleRect;
}

- (NSRect)newItemsCountRectForBounds:(NSRect)theRect
{
	if ([self newItemsCount] > 0) {
		NSSize countStringSize = [[self newItemsCountAttributedString] size];
		
		NSRect newItemsCountRect, remainder;
		NSDivideRect(theRect, &newItemsCountRect, &remainder, countStringSize.width + 2.0, NSMaxXEdge);
		
		newItemsCountRect.origin.y += (NSHeight(newItemsCountRect) - countStringSize.height) / 2.0;
		newItemsCountRect.size.height = countStringSize.height;
		
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
	
	// DEBUG
//	[[NSColor blueColor] set];
//	NSFrameRect(imageRect);
//	[[NSColor greenColor] set];
//	NSFrameRect(titleRect);
//	[[NSColor redColor] set];
//	NSFrameRect(countRect);
	
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
