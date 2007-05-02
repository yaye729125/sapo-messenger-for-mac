//
//  JKAnimatedGroupTableView.m
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Authors: Joao Pavao <jppavao@criticalsoftware.com>
//           Jason Kim <jason@512k.org>
//
//	For more information on licensing, read the README file.
//	Para mais informa›es sobre o licenciamento, leia o ficheiro README.
//

#import "JKAnimatedGroupTableView.h"


static NSString *AnimationRunLoopMode		= @"AnimationRunLoopMode";
static NSString *AnimationDurationKey		= @"AnimationDurationKey";
static NSString *AnimationUpperImageKey		= @"AnimationUpperImageKey";
static NSString *AnimationLowerImageKey		= @"AnimationLowerImageKey";
static NSString *AnimationIsClosingKey		= @"AnimationIsClosingKey";
static NSString *AnimationLowerRectKey		= @"AnimationLowerRectKey";
static NSString *AnimationHeightDeltaKey	= @"AnimationHeightDeltaKey";
static NSString *AnimationStartDateKey		= @"AnimationStartDateKey";


static float
EaseOutFunction(float x)
{
	// Simple cubic function that slows the animation down towards the end
	return 1.0 - powf(1.0 - x, 3.0);
}


@interface JKGroupTableView (Private)
- (void)p_animateRowsInRange:(NSRange)range closing:(BOOL)isClosing;
- (void)p_stepAnimation:(NSTimer *)timer;
- (void)p_finishAnimation;
- (NSImage *)p_imageOfRect:(NSRect)rect;
@end


@implementation JKAnimatedGroupTableView


- (void)dealloc
{
	[m_animationData release];
	[super dealloc];
}


#pragma mark -
#pragma mark Instance Methods


- (float)animationDuration
{
	return 0.25;
}


- (unsigned int)animationFramesPerSecond
{
	// Get the refresh rate of the screen that contains our window. That's the ideal frame rate.
	int displayID = [[[[[self window] screen] deviceDescription] objectForKey:@"NSScreenNumber"] intValue];
	
	CFDictionaryRef	modeInfo;
	unsigned int	refreshRate = 60; // Assume LCD
	
	modeInfo = CGDisplayCurrentMode((CGDirectDisplayID)displayID);
	
	if (modeInfo) {
		CFNumberRef value = (CFNumberRef)CFDictionaryGetValue(modeInfo, kCGDisplayRefreshRate);
		
		if (value) {
			CFNumberGetValue(value, kCFNumberIntType, &refreshRate);
			if (refreshRate == 0)
				refreshRate = 60;
		}
	}
	
	return refreshRate;
}


- (void)collapseGroupAtIndex:(unsigned int)groupIndex animate:(BOOL)doAnimation
{
	if (doAnimation && [self isGroupIndex:groupIndex]) {
		// If the scroll bars will become visible as a consequence, we only want them to show up at the end.
		// If we allow them to show during the animation there are some artifacts that are drawn in the place where the
		// scroll bars should be.
		[[self enclosingScrollView] setAutohidesScrollers:NO];
		
		NSIndexSet *rowIndexes = [self rowsForGroupIndex:groupIndex];
		int rowCount = [rowIndexes count];
		
		if (rowCount > 0) {
			[self p_animateRowsInRange:NSMakeRange((groupIndex + 1), rowCount) closing:YES];
		}

		[self collapseGroupAtIndex:groupIndex];
		[[self enclosingScrollView] setAutohidesScrollers:YES];
	}
	else {
		// Just do a plain simple collapse
		[self collapseGroupAtIndex:groupIndex];
	}
}


- (void)expandGroupAtIndex:(unsigned int)groupIndex animate:(BOOL)doAnimation
{
	if (doAnimation && [self isGroupIndex:groupIndex]) {
		// If the scroll bars will become visible as a consequence, we only want them to show up at the end.
		// If we allow them to show during the animation there are some artifacts that are drawn in the place where the
		// scroll bars should be.
		[[self enclosingScrollView] setAutohidesScrollers:NO];
		
		NSIndexSet *rowIndexes = [self rowsForGroupIndex:groupIndex];
		int rowCount = [rowIndexes count];
		
		if (rowCount > 0) {
			[self p_animateRowsInRange:NSMakeRange((groupIndex + 1), rowCount) closing:NO];
		}

		[self expandGroupAtIndex:groupIndex];
		[[self enclosingScrollView] setAutohidesScrollers:YES];
	}
	else {
		// Just do a plain simple expand
		[self expandGroupAtIndex:groupIndex];
	}
}


- (NSRect)rectOfRow:(int)rowIndex
{
	/* We want to return a changed rect for each row that lays below the header of the group that is being animated.
	Although internally the state of the group (expanded or collapsed) hasn't changed yet during the animation, in this
	redefinition of rectOfRow: we will return the current rect of an animated row for the current frame of the animation.
	This allows the table view to have a correct notion of where its frame should end and it allows the scroll bars' thumb
	bar	to be displayed with the correct relative size as the animation progresses. */
	
	NSRect	rect = [super rectOfRow:rowIndex];

	if (m_animationIsRunning && rowIndex > m_animatedGroupIndex) {
		float	heightDelta = [[m_animationData objectForKey:AnimationHeightDeltaKey] floatValue];
		float	currentOffset = heightDelta * m_smoothAnimationProgress;
		
		rect.origin.y += currentOffset;
	}
	
	return rect;
}


#pragma mark -
#pragma mark NSTableView Overrides


- (void)drawRect:(NSRect)rect
{
	if (m_animationIsRunning) {
		NSImage		*upperImage = [m_animationData objectForKey:AnimationUpperImageKey];
		NSImage		*lowerImage = [m_animationData objectForKey:AnimationLowerImageKey];
		NSRect		lowerRect = NSRectFromString([m_animationData objectForKey:AnimationLowerRectKey]);
		
		[upperImage compositeToPoint:lowerRect.origin operation:NSCompositeCopy];
		
		
		BOOL	isClosing = [[m_animationData objectForKey:AnimationIsClosingKey] boolValue];
		float	heightDelta = [[m_animationData objectForKey:AnimationHeightDeltaKey] floatValue];
		float	initialHeight = NSHeight(lowerRect) - (isClosing ? 0.0 : heightDelta);
		float	currentHeight = initialHeight + (heightDelta * m_smoothAnimationProgress);
		
		NSRect	srcRect = NSMakeRect(0, 0, NSWidth(lowerRect), currentHeight);
		NSPoint	destPoint = NSMakePoint(NSMinX(lowerRect), NSMinY(lowerRect) + currentHeight);

		[lowerImage compositeToPoint:destPoint fromRect:srcRect operation:NSCompositeCopy];
	}
	else {
		[super drawRect:rect];
	}
}


#pragma mark -
#pragma mark Private Methods


- (void)p_animateRowsInRange:(NSRange)range closing:(BOOL)isClosing
{
	m_animationIsRunning = YES;
	m_animatedGroupIndex = range.location - 1;
	m_smoothAnimationProgress = 0.0;
	
	float	changingRowsHeight = ((float)range.length) * ([self rowHeight] + [self intercellSpacing].height);
	NSRect	visibleRect = [self visibleRect];
	NSRect	lowerRect = [self rectOfRow:range.location];
	
	lowerRect.size.height = (NSMaxY(visibleRect) - NSMinY(lowerRect)) + changingRowsHeight;
	
	if (!isClosing)
		// Temporarily make the rows "visible." to take their snapshot
		[self expandGroupAtIndex:[self groupIndexForRow:range.location]];
	
	// Prepare the lower image
	NSImage	*lowerImage = [self p_imageOfRect:lowerRect];
	
	if (!isClosing)
		// Undo the temporary change we made above.
		[self collapseGroupAtIndex:[self groupIndexForRow:range.location]];
	
	
	// Prepare the upper image. This also has to be large enough for a possible upward scroll if lower groups are closed.
	NSRect upperRect = visibleRect;
	upperRect.size.height = NSMinY(lowerRect) - NSMinY(upperRect);
	
	if (isClosing) {
		/* If we are collapsing a group AND the height of the rect below the visible rect is less than the height of the
		rect that will contain the lower image animation AND the height of the rect above the visible rect is > 0
		(basically, if the table view isn't scrolled completelly towards the top or the bottom AND the amount of pixels
		that are going to be pulled up into the visible rect isn't sufficient to completelly collapse the group), then
		the upper image is also going to be animated at some point to cover up the remaining pixels that could not be
		covered by the lower image animation. We have to account for this possibility and take a snapshot of the upper
		image that will be sufficiently tall to contain all the upper pixels that we'll need to bring into the
		visible rect. */
		
		float additionalHeight = MAX(0.0, changingRowsHeight - (NSMaxY([self bounds]) - NSMaxY(visibleRect)));
		upperRect.size.height += additionalHeight;
		upperRect.origin.y -= additionalHeight;
	}
	
	NSImage	*upperImage = [self p_imageOfRect:upperRect];
	
	
	BOOL	shiftKeyIsDown = ([[NSApp currentEvent] modifierFlags] & NSShiftKeyMask) ? YES : NO;
	float	duration = [self animationDuration] * ((shiftKeyIsDown) ? 10.0 : 1.0);
	float	heightDelta = (isClosing ? -1.0 : 1.0) * changingRowsHeight;
	
	// Create the animation data hash. This dictionary lives while the animation
	// is running, then is released immediately after it completes (see p_finishAnimation).
	[m_animationData release];
	m_animationData = [[NSDictionary alloc] initWithObjectsAndKeys:
		[NSNumber numberWithFloat:heightDelta], AnimationHeightDeltaKey,
		[NSNumber numberWithFloat:duration], AnimationDurationKey,
		[NSNumber numberWithBool:isClosing], AnimationIsClosingKey,
		[NSDate date], AnimationStartDateKey,
		NSStringFromRect(lowerRect), AnimationLowerRectKey,
		upperImage, AnimationUpperImageKey,
		lowerImage, AnimationLowerImageKey,
		nil];

	// Prepare drawing loop. This will block user input until the animation completes,
	// which greatly simplifies our task. Since the animation is generally short, this is
	// perfectly acceptable (iChat behaves the same way).
	float		intervalBetweenFrames = 1.0 / [self animationFramesPerSecond];
	NSRunLoop	*runloop = [NSRunLoop currentRunLoop];
	NSTimer		*timer = [NSTimer timerWithTimeInterval:intervalBetweenFrames
												 target:self
											   selector:@selector(p_stepAnimation:)
											   userInfo:nil
												repeats:YES];
	
	[runloop addTimer:timer forMode:AnimationRunLoopMode];
	[runloop runMode:AnimationRunLoopMode beforeDate:[NSDate distantFuture]];
}


- (void)p_stepAnimation:(NSTimer *)timer
{
	NSDate *startDate = [m_animationData objectForKey:AnimationStartDateKey];
	float duration = [[m_animationData objectForKey:AnimationDurationKey] floatValue];
	
	// Calculate the animation progress.
	float animationProgress = MIN(fabsf([startDate timeIntervalSinceNow] / duration), 1.0);
	m_smoothAnimationProgress = EaseOutFunction(animationProgress);
	
	// If we redraw our enclosing NSScrollView, then the scrollbar will also get redrawn properly.
	[self tile];
	[[self enclosingScrollView] display];
	
	// If we reach 1.0 (give or take some floating point error), we're finished.
	if (animationProgress >= 0.99) {
		[self p_finishAnimation];
		[timer invalidate];
	}
}


- (void)p_finishAnimation
{
	m_animationIsRunning = NO;
	
	// Release temporary data structures.
	[m_animationData release];
	m_animationData = nil;
}


- (NSImage *)p_imageOfRect:(NSRect)rect
{
	NSImage *image = [[NSImage alloc] initWithSize:rect.size];	
	[image setFlipped:YES];
	
	@try {
		[image lockFocus];

		NSAffineTransform *transform = [NSAffineTransform transform];
		[transform translateXBy:(-rect.origin.x) yBy:(-rect.origin.y)];
		[transform concat];
		
		[super drawRect:rect];
		
		[image unlockFocus];
	}
	@catch (NSException *exception) {
		// Probably an NSImageCacheException due to the image being unable to lockFocus.
		[image release];
		image = nil;
	}
	
	return [image autorelease];
}


@end
