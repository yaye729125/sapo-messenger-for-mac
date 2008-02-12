//
//  LPSlidingTilesView.m
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jpavao@co.sapo.pt>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "LPSlidingTilesView.h"


#define LPSLIDING_TILES_VIEW_DEFAULT_BOX_HORIZONTAL_MARGIN	10.0
#define LPSLIDING_TILES_VIEW_DEFAULT_TILES_VERTICAL_MARGIN	10.0
#define LPSLIDING_TILES_VIEW_DEFAULT_MIN_INTER_TILE_SPACE	10.0


static NSString *LPSlidingTilesAnimationMode = @"LPSlidingTilesAnimationMode";


typedef enum {
	LPSlideLeft,
	LPSlideRight
} _LPSlideDirection;


static float
SquareEaseInEaseOut (float x)
{
	// With 0 <= x <= 1.0 this function gives us a nice accelaration at the start and de-acceleration at the end
	// of the animation.
	
	// A square power looks more like the iTunes and Dashboard animations. A cubic power makes the animation start and
	// finish very slowly and it runs really fast at the mid-point. It ends up looking very awkward.
	float power = 2.0;
	
	if (x < 0.5)
		return powf(2.0 * x, power) / 2.0;
	else
		return 1.0 - powf(2.0 * (1.0 - x), power) / 2.0;
}


static float
SnapToPixelBoundaries (NSWindow *win, float xToBeSnapped)
{
	if ([win respondsToSelector:@selector(userSpaceScaleFactor)]) {
		// We're running on something >= 10.4: support resolution-independent UI.
		float scaleFactor = [win userSpaceScaleFactor];
		return floorf(xToBeSnapped * scaleFactor) / scaleFactor;
	}
	else {
		// We're running on <= 10.3: simply round to integral values.
		return floorf(xToBeSnapped);
	}
}




@interface LPSlidingTilesView (Private)
- (void)p_trackMouse:(NSEvent *)theEvent inCell:(NSButtonCell *)cell frame:(NSRect)cellFrame;
- (NSArray *)p_tilesFromDataSourceStartingAtTileNr:(int)firstTile count:(int)count;
- (void)p_layoutTiles:(NSArray *)tiles withFirstGroupRect:(NSRect)firstGroupRect usedTotalWidth:(float *)retUsedWidthPtr usedHorizontalMargin:(float *)retUsedMarginPtr;
- (void)p_animateTiles:(NSArray *)tiles insideRect:(NSRect)targetRect firstTileIndex:(int)firstTileIdx slidingDirection:(_LPSlideDirection)direction usePaddingAtTips:(BOOL)usePaddingAtTips;
- (void)p_animationStep:(NSTimer *)timer;
- (void)p_drawTiles:(NSArray *)tiles toImage:(NSImage *)image;
@end


@implementation LPSlidingTilesView


- (id)initWithFrame:(NSRect)frame
{
    if (self = [super initWithFrame:frame]) {
		
		m_leftArrowCell  = [[NSButtonCell alloc] initImageCell:[NSImage imageNamed:@"SlidingTiles_LeftArrow"]];
		
		[m_leftArrowCell setAlternateImage:[NSImage imageNamed:@"SlidingTiles_LeftArrow_pressed"]];
		[m_leftArrowCell setBezeled:NO];
		[m_leftArrowCell setBordered:NO];
		[m_leftArrowCell setButtonType:NSMomentaryLightButton];
		[m_leftArrowCell setHighlightsBy:NSContentsCellMask];
		
		[m_leftArrowCell setTarget:self];
		[m_leftArrowCell setAction:@selector(slideLeft:)];
		
		
		m_rightArrowCell = [[NSButtonCell alloc] initImageCell:[NSImage imageNamed:@"SlidingTiles_RightArrow"]];
		
		[m_rightArrowCell setAlternateImage:[NSImage imageNamed:@"SlidingTiles_RightArrow_pressed"]];
		[m_rightArrowCell setBezeled:NO];
		[m_rightArrowCell setBordered:NO];
		[m_rightArrowCell setButtonType:NSMomentaryLightButton];
		[m_rightArrowCell setHighlightsBy:NSContentsCellMask];
		
		[m_rightArrowCell setTarget:self];
		[m_rightArrowCell setAction:@selector(slideRight:)];
		
		
		[self setBoxHorizontalMargin: LPSLIDING_TILES_VIEW_DEFAULT_BOX_HORIZONTAL_MARGIN];
		[self setTilesVerticalMargin: LPSLIDING_TILES_VIEW_DEFAULT_TILES_VERTICAL_MARGIN];
		[self setMinimumInterTileSpacing: LPSLIDING_TILES_VIEW_DEFAULT_MIN_INTER_TILE_SPACE];
    }
    return self;
}


- (void)dealloc
{
	[m_leftArrowCell release];
	[m_rightArrowCell release];
	[m_tiledViews release];
	[super dealloc];
}


- (id <LPSlidingTilesViewDataSource>)dataSource
{
	return m_dataSource;
}


- (void)setDataSource:(id <LPSlidingTilesViewDataSource>)dataSource
{
	m_dataSource = dataSource;
	[self reloadTiles];
}


- (id)delegate
{
	return m_delegate;
}


- (void)setDelegate:(id)delegate
{
	m_delegate = delegate;
}


- (NSRect)leftArrowFrameForBounds:(NSRect)boundsRect
{
	NSSize cellSize = [m_leftArrowCell cellSize];
	return NSMakeRect(NSMinX(boundsRect),
					  SnapToPixelBoundaries([self window], NSMidY(boundsRect) - cellSize.height / 2.0),
					  cellSize.width,
					  cellSize.height);
}


- (NSRect)rightArrowFrameForBounds:(NSRect)boundsRect
{
	NSSize cellSize = [m_rightArrowCell cellSize];
	return NSMakeRect(NSMaxX(boundsRect) - cellSize.width,
					  SnapToPixelBoundaries([self window], NSMidY(boundsRect) - cellSize.height / 2.0),
					  cellSize.width,
					  cellSize.height);
}


- (NSRect)contentRectForBounds:(NSRect)boundsRect
{
	NSSize borderSize = [[NSImage imageNamed:@"SlidingTiles_BoxBorder"] size];
	return NSInsetRect(NSInsetRect(boundsRect, [self boxHorizontalMargin], 0.0),
					   borderSize.width / 2.0,
					   borderSize.height / 2.0);
}


- (void)drawBoxBorderInsideRect:(NSRect)borderBounds
{
	NSImage *boxBorderImage = [NSImage imageNamed:@"SlidingTiles_BoxBorder"];
	
	NSRect boxBorderImageRect;
	boxBorderImageRect.origin = NSMakePoint(0.0, 0.0);
	boxBorderImageRect.size = [boxBorderImage size];
	
	float sliceWidth = NSWidth(boxBorderImageRect) / 2.0;
	float sliceHeight = NSHeight(boxBorderImageRect) / 2.0;
	
	NSRect trashRect, remainder;
	NSRect topLeftCorner, topRightCorner, bottomLeftCorner, bottomRightCorner;
	NSRect topBar, bottomBar, leftBar, rightBar;
	
	// Chop off the side margins
	float lateralMargin = [self boxHorizontalMargin];
	NSDivideRect(borderBounds, &trashRect, &remainder, lateralMargin, NSMinXEdge);
	NSDivideRect(remainder, &trashRect, &remainder, lateralMargin, NSMaxXEdge);
	// At this point, "remainder" is the rect that we need to paint
	
	// Get the bars spanning the entire width/height of the "remainder" rect
	NSDivideRect(remainder, &topBar   , &trashRect, sliceHeight, NSMaxYEdge);
	NSDivideRect(remainder, &bottomBar, &trashRect, sliceHeight, NSMinYEdge);
	NSDivideRect(remainder, &leftBar  , &trashRect, sliceWidth , NSMinXEdge);
	NSDivideRect(remainder, &rightBar , &trashRect, sliceWidth , NSMaxXEdge);
	// Get the corners
	topLeftCorner     = NSIntersectionRect(topBar  , leftBar  );
	topRightCorner    = NSIntersectionRect(topBar  , rightBar );
	bottomLeftCorner  = NSIntersectionRect(leftBar , bottomBar);
	bottomRightCorner = NSIntersectionRect(rightBar, bottomBar);
	// Chop the corners off the bars
	
	// Top left corner
	[boxBorderImage compositeToPoint:topLeftCorner.origin
							fromRect:NSMakeRect(0.0, sliceHeight, sliceWidth, sliceHeight)
						   operation:NSCompositeSourceOver];
	// Top right corner
	[boxBorderImage compositeToPoint:topRightCorner.origin
							fromRect:NSMakeRect(sliceWidth, sliceHeight, sliceWidth, sliceHeight)
						   operation:NSCompositeSourceOver];
	// Bottom left corner
	[boxBorderImage compositeToPoint:bottomLeftCorner.origin
							fromRect:NSMakeRect(0.0, 0.0, sliceWidth, sliceHeight)
						   operation:NSCompositeSourceOver];
	// Bottom right corner
	[boxBorderImage compositeToPoint:bottomRightCorner.origin
							fromRect:NSMakeRect(sliceWidth, 0.0, sliceWidth, sliceHeight)
						   operation:NSCompositeSourceOver];
	
	// Draw the rest in-between
	// Top bar
	[boxBorderImage drawInRect:NSInsetRect(topBar, sliceWidth, 0.0)
					  fromRect:NSMakeRect(sliceWidth - 1.0, sliceHeight, 2.0, sliceHeight)
					 operation:NSCompositeSourceOver
					  fraction:1.0];
	// Bottom bar
	[boxBorderImage drawInRect:NSInsetRect(bottomBar, sliceWidth, 0.0)
					  fromRect:NSMakeRect(sliceWidth - 1.0, 0.0, 2.0, sliceHeight)
					 operation:NSCompositeSourceOver
					  fraction:1.0];
	// Left bar
	[boxBorderImage drawInRect:NSInsetRect(leftBar, 0.0, sliceHeight)
					  fromRect:NSMakeRect(0.0, sliceHeight - 1.0, sliceWidth, 2.0)
					 operation:NSCompositeSourceOver
					  fraction:1.0];
	// Right bar
	[boxBorderImage drawInRect:NSInsetRect(rightBar, 0.0, sliceHeight)
					  fromRect:NSMakeRect(sliceWidth, sliceHeight - 1.0, sliceWidth, 2.0)
					 operation:NSCompositeSourceOver
					  fraction:1.0];
}


- (void)drawContentBackgroundInsideRect:(NSRect)rect
{
	NSImage	*bgImage = [NSImage imageNamed:@"SlidingTiles_Background"];
	float	yPhase = [self convertPoint:NSMakePoint(0.0, NSMaxY([self bounds])) toView:nil].y;
	
	[[NSGraphicsContext currentContext] setPatternPhase:NSMakePoint(0.0, yPhase)];
	[[NSColor colorWithPatternImage:bgImage] set];
	NSRectFillUsingOperation(rect, NSCompositeSourceOver);
}


- (void)drawTilesDecorationsForTiles:(NSArray *)tiles
{
	NSShadow *shadow = [[NSShadow alloc] init];
	NSColor *shadowColor = [NSColor blackColor];
	
	[shadow setShadowOffset:NSMakeSize(0.0, -3.0)];
	[shadow setShadowBlurRadius:5.0];
	[shadow setShadowColor:shadowColor];
	
	[NSGraphicsContext saveGraphicsState];
	{
		NSView			*selectedTile = [self selectedTileView];
		NSEnumerator	*tilesEnum = [tiles objectEnumerator];
		NSView			*tile;
		
		while (tile = [tilesEnum nextObject]) {
			[NSGraphicsContext saveGraphicsState];
			{
				// Draw the normal shadow
				[shadow set];
				[shadowColor set];
				NSRectFill(NSInsetRect([tile frame], 0.0, 0.0));
				
				// Draw the selection ring behind everything else
				if (tile == selectedTile) {
					NSShadow *selectionRingShadow = [[NSShadow alloc] init];
					NSColor *selectionColor = [NSColor alternateSelectedControlColor];
					
					[selectionRingShadow setShadowOffset:NSMakeSize(0.0, 0.0)];
					[selectionRingShadow setShadowBlurRadius:2.0];
					[selectionRingShadow setShadowColor:selectionColor];
					
					[selectionRingShadow set];
					[selectionColor set];
					NSRectFill(NSInsetRect([tile frame], -3.0, -3.0));
					
					[selectionRingShadow release];
				}
			}
			[NSGraphicsContext restoreGraphicsState];
			
			// Background white square
			[[NSColor whiteColor] set];
			NSRectFill(NSInsetRect([tile frame], 0.0, 0.0));
		}
	}
	[NSGraphicsContext restoreGraphicsState];
	
	[shadow release];
}


- (void)drawRect:(NSRect)rect
{
	NSRect myBounds = [self bounds];
	
	[self drawBoxBorderInsideRect:myBounds];
	[self drawContentBackgroundInsideRect:[self contentRectForBounds:myBounds]];
	
	
	if (m_animationInfo == nil) {
		[self drawTilesDecorationsForTiles:m_tiledViews];
	}
	else {
		// The tiles animation is running!
		// If the animation is running the tiles decorations are already included in the cached image so that they can slide too,
		// so we don't need to draw them explicitly in here.
		
		NSDate			*startDate = [m_animationInfo objectForKey:@"startDate"];
		float			animationDuration = [[m_animationInfo objectForKey:@"animationDuration"] floatValue];
		float			elapsedTime = [[NSDate date] timeIntervalSinceDate:startDate];
		float			currentProgress = SquareEaseInEaseOut(elapsedTime / animationDuration);
		
		NSImage			*animatedImage = [m_animationInfo objectForKey:@"animatedImage"];
		NSRect			targetRect = [[m_animationInfo objectForKey:@"targetRect"] rectValue];
		NSRect			srcRect = [[m_animationInfo objectForKey:@"srcRect"] rectValue];
		float			startXPoint = [[m_animationInfo objectForKey:@"startXPoint"] floatValue];
		float			totalXDelta = [[m_animationInfo objectForKey:@"totalXDelta"] floatValue];
		
		srcRect.origin.x = startXPoint + totalXDelta * currentProgress;
		
		[animatedImage compositeToPoint:targetRect.origin
							   fromRect:srcRect
							  operation:NSCompositeSourceOver];
	}
	
	
	[m_leftArrowCell setEnabled:[self canSlideLeft]];
	[m_leftArrowCell  drawWithFrame:[self leftArrowFrameForBounds:myBounds]  inView:self];
	[m_rightArrowCell setEnabled:[self canSlideRight]];
	[m_rightArrowCell drawWithFrame:[self rightArrowFrameForBounds:myBounds] inView:self];
}


- (void)mouseDown:(NSEvent *)theEvent
{
	NSPoint location = [self convertPoint:[theEvent locationInWindow] fromView:nil];
	NSRect myBounds = [self bounds];
	NSRect leftArrowFrame = [self leftArrowFrameForBounds:myBounds];
	NSRect rightArrowFrame = [self rightArrowFrameForBounds:myBounds];
	
	if ([self mouse:location inRect:leftArrowFrame] && [self canSlideLeft]) {
		m_trackedCell = m_leftArrowCell;
		[self p_trackMouse:theEvent inCell:m_leftArrowCell frame:leftArrowFrame];
	}
	else if ([self mouse:location inRect:rightArrowFrame] && [self canSlideRight]) {
		m_trackedCell = m_rightArrowCell;
		[self p_trackMouse:theEvent inCell:m_rightArrowCell frame:rightArrowFrame];
	}
}


- (void)mouseDragged:(NSEvent *)theEvent
{
	NSPoint location = [self convertPoint:[theEvent locationInWindow] fromView:nil];
	NSRect myBounds = [self bounds];
	NSRect leftArrowFrame = [self leftArrowFrameForBounds:myBounds];
	NSRect rightArrowFrame = [self rightArrowFrameForBounds:myBounds];
	
	if ((m_trackedCell == m_leftArrowCell) && [self mouse:location inRect:leftArrowFrame]) {
		[self p_trackMouse:theEvent inCell:m_leftArrowCell frame:leftArrowFrame];
	}
	else if ((m_trackedCell == m_rightArrowCell) && [self mouse:location inRect:rightArrowFrame]) {
		[self p_trackMouse:theEvent inCell:m_rightArrowCell frame:rightArrowFrame];
	}
}


- (void)resizeSubviewsWithOldSize:(NSSize)oldBoundsSize
{
	NSRect	contentRect = [self contentRectForBounds:[self bounds]];
	
	if ([self maxNumberOfTilesFittingInsideRect:contentRect] != [self numberOfVisibleTiles]) {
		[self reloadTiles];
	}
	
	[self tile];
}


- (float)boxHorizontalMargin
{
	return m_boxHorizontalMargin;
}


- (void)setBoxHorizontalMargin:(float)width
{
	m_boxHorizontalMargin = width;
	[self reloadTiles];
}


- (float)tilesVerticalMargin
{
	return m_tilesVerticalMargin;
}


- (void)setTilesVerticalMargin:(float)width
{
	m_tilesVerticalMargin = width;
	[self reloadTiles];
}


- (float)minimumInterTileSpacing
{
	return m_minimumInterTileSpacing;
}


- (void)setMinimumInterTileSpacing:(float)space
{
	m_minimumInterTileSpacing = space;
	[self reloadTiles];
}


- (unsigned int)maxNumberOfTilesFittingInsideRect:(NSRect)rect
{
	float			tileWidth = NSHeight(rect) - 2.0 * [self tilesVerticalMargin];
	float			totalTileMargins = [self minimumInterTileSpacing];
	unsigned int	nrOfTilesThatFit = floorf(NSWidth(rect) / (tileWidth + totalTileMargins));
	
	return nrOfTilesThatFit;
}


- (void)tile
{
	if (m_tiledViews != nil) {
		[self p_layoutTiles:m_tiledViews
		 withFirstGroupRect:[self contentRectForBounds:[self bounds]]
			 usedTotalWidth:NULL
	   usedHorizontalMargin:NULL];
		
		[self setNeedsDisplay:YES];
	}
}


- (int)numberOfTiles
{
	return [[self dataSource] numberOfTilesInSlidingTilesView:self];
}


- (int)numberOfVisibleTiles
{
	return [m_tiledViews count];
}


- (int)firstVisibleTileIndex
{
	return m_firstVisibleTileIndex;
}


- (void)setFirstVisibleTileIndex:(int)firstTileIndex
{
	m_firstVisibleTileIndex = firstTileIndex;
	[self reloadTiles];
}


- (void)reloadTiles
{
	if (m_firstVisibleTileIndex >= [self numberOfTiles])
		m_firstVisibleTileIndex = 0;
	
	int maxNrOfTilesThatFit = [self maxNumberOfTilesFittingInsideRect:[self contentRectForBounds:[self bounds]]];

	// Hold a reference to the previous views in a temporary variable so that they don't get released right away.
	// This is in case some of those views aren't meant to go away in this reload and are only retained by us.
	NSArray *oldTiledViews = m_tiledViews;
	NSArray *newTiledViews = [self p_tilesFromDataSourceStartingAtTileNr:[self firstVisibleTileIndex] count:maxNrOfTilesThatFit];
	
	NSMutableSet *commonTiles = [NSMutableSet setWithArray:oldTiledViews];
	[commonTiles intersectSet:[NSSet setWithArray:newTiledViews]];
	
	NSMutableSet *tilesGoingOut = [NSMutableSet setWithArray:oldTiledViews];
	NSMutableSet *tilesCommingIn = [NSMutableSet setWithArray:newTiledViews];
	[tilesGoingOut minusSet:commonTiles];
	[tilesCommingIn minusSet:commonTiles];
	

	[tilesGoingOut makeObjectsPerformSelector:@selector(removeFromSuperview)];
	
	NSEnumerator *newTileEnum = [tilesCommingIn objectEnumerator];
	NSView *newTile;
	
	while (newTile = [newTileEnum nextObject]) {
		[self addSubview:newTile];
	}
	
	
	m_tiledViews = [newTiledViews copy];
	[oldTiledViews release];
	
	// Check up on the selection
	if (([self selectedTileView] != nil) && ([m_tiledViews containsObject:[self selectedTileView]] == NO)) {
		[self setSelectedTileView:nil];
	}
	
	[self tile];
}


- (NSView *)selectedTileView
{
	return m_selectedTileView;
}


- (int)selectedTileIndex
{
	NSView *selectedTileView = [self selectedTileView];
	
	if (selectedTileView)
		return [self firstVisibleTileIndex] + [m_tiledViews indexOfObject:selectedTileView];
	else
		return -1;
}


- (void)setSelectedTileView:(NSView *)tileView
{
	m_selectedTileView = tileView;
	[self setNeedsDisplay:YES];
	
	if ([[self delegate] respondsToSelector:@selector(slidingTilesViewSelectionDidChange:)]) {
		[[self delegate] slidingTilesViewSelectionDidChange:self];
	}
}


- (float)animationDuration
{
	return 0.4;
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


- (BOOL)canSlideLeft
{
	return ([self firstVisibleTileIndex] > 0);
}


- (BOOL)canSlideRight
{
	NSRect	contentRect = [self contentRectForBounds:[self bounds]];
	int		nrOfTilesThatFit = [self maxNumberOfTilesFittingInsideRect:contentRect];
	int		indexAfterLastTile = [self numberOfTiles];

	return (([self firstVisibleTileIndex] + nrOfTilesThatFit) < indexAfterLastTile);
}


- (IBAction)slideLeft:(id)sender
{
	if ([self canSlideLeft]) {
		[self setSelectedTileView:nil];
		
		NSRect	contentRect = [self contentRectForBounds:[self bounds]];
		int		nrOfTilesThatFit = [self maxNumberOfTilesFittingInsideRect:contentRect];
		int		firstVisibleTileIdx = [self firstVisibleTileIndex];
		int		newFirstTileIndex = MAX(firstVisibleTileIdx - nrOfTilesThatFit, 0);
		int		nrOfTilesToAnimate = MIN(nrOfTilesThatFit * 2, [self numberOfTiles] - newFirstTileIndex);
		
		NSArray *animatedTiles = [self p_tilesFromDataSourceStartingAtTileNr:newFirstTileIndex count:nrOfTilesToAnimate];
		
		/* Let's remove all the tiles subviews temporarilly. The animation works by simply drawing a cached image of the tiles
		that are being slid. When we redraw the view over and over again, we don't want the real tiles to redraw themselves over
		this animation, so we need them to get out of the way. They'll be reset correctly in the invocation of
		setFirstVisibleTileIndex: that follows, anyway. */
		[m_tiledViews makeObjectsPerformSelector:@selector(removeFromSuperview)];
		[m_tiledViews release];
		m_tiledViews = nil;
		
		[self p_animateTiles:animatedTiles
				  insideRect:contentRect
			  firstTileIndex:(firstVisibleTileIdx - newFirstTileIndex)
			slidingDirection:LPSlideLeft
			usePaddingAtTips:(newFirstTileIndex != 0)];
		
		[self setFirstVisibleTileIndex:newFirstTileIndex];
	}
}


- (IBAction)slideRight:(id)sender
{
	if ([self canSlideRight]) {
		[self setSelectedTileView:nil];
		
		int		lastTileIndex = [self numberOfTiles] - 1;	
		NSRect	contentRect = [self contentRectForBounds:[self bounds]];
		int		nrOfTilesThatFit = [self maxNumberOfTilesFittingInsideRect:contentRect];
		int		firstVisibleTileIdx = [self firstVisibleTileIndex];
		int		newFirstTileIndex = MIN(firstVisibleTileIdx + nrOfTilesThatFit, lastTileIndex);
		int		nrOfTilesToAnimate = MIN(nrOfTilesThatFit * 2, lastTileIndex - firstVisibleTileIdx + 1);
		
		NSArray *animatedTiles = [self p_tilesFromDataSourceStartingAtTileNr:firstVisibleTileIdx count:nrOfTilesToAnimate];
		
		/* Let's remove all the tiles subviews temporarilly. The animation works by simply drawing a cached image of the tiles
		that are being slid. When we redraw the view over and over again, we don't want the real tiles to redraw themselves over
		this animation, so we need them to get out of the way. They'll be reset correctly in the invocation of
		setFirstVisibleTileIndex: that follows, anyway. */
		[m_tiledViews makeObjectsPerformSelector:@selector(removeFromSuperview)];
		[m_tiledViews release];
		m_tiledViews = nil;
		
		[self p_animateTiles:animatedTiles
				  insideRect:contentRect
			  firstTileIndex:0
			slidingDirection:LPSlideRight
			usePaddingAtTips:YES];
		
		[self setFirstVisibleTileIndex:newFirstTileIndex];
	}
}


- (IBAction)performSlideLeft:(id)sender
{
	[m_leftArrowCell performClick:self];
}


- (IBAction)performSlideRight:(id)sender
{
	[m_rightArrowCell performClick:self];
}


#pragma mark -
#pragma mark Private


- (void)p_trackMouse:(NSEvent *)theEvent inCell:(NSButtonCell *)cell frame:(NSRect)cellFrame
{
	[cell highlight:YES withFrame:cellFrame inView:self];
	[cell trackMouse:theEvent inRect:cellFrame ofView:self untilMouseUp:NO];
	[cell highlight:NO withFrame:cellFrame inView:self];
	
	if ([[NSApp currentEvent] type] == NSLeftMouseUp)
		m_trackedCell = nil;
}


- (NSArray *)p_tilesFromDataSourceStartingAtTileNr:(int)firstTile count:(int)count
{
	NSMutableArray *tiles = [NSMutableArray array];
	
	id myDataSource = [self dataSource];
	int nrOfTiles = [self numberOfTiles];
	int nrOfTilesToRetrieve = MIN(count, nrOfTiles - firstTile);
	int tileIndexAfterLastTileToRetrieve = firstTile + nrOfTilesToRetrieve;
	int currentTile;
	
	for (currentTile = firstTile; currentTile < tileIndexAfterLastTileToRetrieve; ++currentTile) {
		NSView *tileView = [myDataSource slidingTilesView:self viewForTile:currentTile];
		[tiles addObject:tileView];
	}
	
	return tiles;
}


- (void)p_layoutTiles:(NSArray *)tiles withFirstGroupRect:(NSRect)firstGroupRect usedTotalWidth:(float *)retUsedWidthPtr usedHorizontalMargin:(float *)retUsedMarginPtr
{
	unsigned int	maxNrVisibleTiles = [self maxNumberOfTilesFittingInsideRect:firstGroupRect];
	
	if (maxNrVisibleTiles > 0) {
		float			verticalMargin = [self tilesVerticalMargin];
		float			tileWidthAndHeight = NSHeight(firstGroupRect) - verticalMargin * 2.0;
		float			horizontalMargin = ((NSWidth(firstGroupRect) / (float)maxNrVisibleTiles) - tileWidthAndHeight) / 2.0;
		float			currentXOffset = NSMinX(firstGroupRect);
		
		NSEnumerator	*tilesEnum = [tiles objectEnumerator];
		NSView			*tile;
		int				currentTileIndex = 0;
		
		while (tile = [tilesEnum nextObject]) {
			// Is this the first of a group of tiles that can be visible in the view at once?
			if ((currentTileIndex % maxNrVisibleTiles) == 0) {
				int groupIndex = currentTileIndex / maxNrVisibleTiles;
				currentXOffset = NSMinX(firstGroupRect) + ( groupIndex * NSWidth(firstGroupRect) );
			}
			
			[tile setFrame:NSMakeRect(currentXOffset + horizontalMargin,
									  NSMinY(firstGroupRect) + verticalMargin,
									  tileWidthAndHeight,
									  tileWidthAndHeight)];
			
			++currentTileIndex;
			currentXOffset += tileWidthAndHeight + horizontalMargin * 2.0;
		}
		
		// Return the width of the rect that contains all the laid out tiles, including the margins
		if (retUsedWidthPtr)
			*retUsedWidthPtr = (currentXOffset - NSMinX(firstGroupRect));
		if (retUsedMarginPtr)
			*retUsedMarginPtr = horizontalMargin;
	}
}


- (void)p_animateTiles:(NSArray *)tiles insideRect:(NSRect)targetRect firstTileIndex:(int)firstTileIdx slidingDirection:(_LPSlideDirection)direction usePaddingAtTips:(BOOL)usePaddingAtTips
{
	float totalOccupiedWidth, tileHorizontalMargin;
	
	[self p_layoutTiles:tiles
	 withFirstGroupRect:NSMakeRect(0.0, 0.0, NSWidth(targetRect), NSHeight(targetRect))
		 usedTotalWidth:&totalOccupiedWidth
   usedHorizontalMargin:&tileHorizontalMargin];
	
	float imageWidth = (usePaddingAtTips ? (2.0 * NSWidth(targetRect)) : totalOccupiedWidth);

	// Prepare the animated image
	NSImage *animatedImage = [[NSImage alloc] initWithSize:NSMakeSize(imageWidth, NSHeight(targetRect))];
	
	[self p_drawTiles:tiles toImage:animatedImage];
	
	// Animate the sliding image
	float			animationDuration = [self animationDuration];
	unsigned int	nrOfFramesPerSec = [self animationFramesPerSecond];
	NSTimeInterval	timeIntervalPerFrame = 1.0 / (float)nrOfFramesPerSec;
	
	float			startXPoint = NSMinX([[tiles objectAtIndex:firstTileIdx] frame]) - tileHorizontalMargin;
	float			endXPoint = (direction == LPSlideLeft ? 0.0 : (imageWidth - NSWidth(targetRect)));
	float			totalXDelta = endXPoint - startXPoint;
	NSRect			srcRect;
	
	srcRect.size = targetRect.size;
	srcRect.origin = NSMakePoint(startXPoint, 0.0);
	
	m_animationInfo = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSDate date], @"startDate",
		[NSNumber numberWithFloat:animationDuration], @"animationDuration",
		animatedImage, @"animatedImage",
		[NSValue valueWithRect:targetRect], @"targetRect",
		[NSValue valueWithRect:srcRect], @"srcRect",
		[NSNumber numberWithFloat:startXPoint], @"startXPoint",
		[NSNumber numberWithFloat:totalXDelta], @"totalXDelta",
		nil];
	
	NSTimer *animationTimer = [NSTimer timerWithTimeInterval:timeIntervalPerFrame
													  target:self
													selector:@selector(p_animationStep:)
													userInfo:nil
													 repeats:YES];
		
	NSRunLoop *rl = [NSRunLoop currentRunLoop];
	[rl addTimer:animationTimer forMode:LPSlidingTilesAnimationMode];
	[rl runMode:LPSlidingTilesAnimationMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:animationDuration]];
	[animationTimer invalidate];
	
	m_animationInfo = nil;
	
	[animatedImage release];
}


- (void)p_animationStep:(NSTimer *)timer
{
	[self display];
}


- (void)p_drawTiles:(NSArray *)tiles toImage:(NSImage *)image
{
	/* We draw only the tiles decorations in the cached image. This view is no longer generic as we're catering to the
	intricacies of using WebViews featuring only Flash content as the tiles of the view. The flash plug-in is a beast
	on its own, full of private drawing optimizations and it was extremely difficult to get a satisfying solution for
	this animation. We may make this view more generic and usable in other situations with different tile contents if
	the need arises in the future. */
	[image lockFocus];
	
	[self drawTilesDecorationsForTiles:tiles];
	
	id dataSource = [self dataSource];
	NSEnumerator *tileEnum = [tiles objectEnumerator];
	NSView *tile;
	
	while (tile = [tileEnum nextObject]) {
		NSBitmapImageRep *tileImageRep = [dataSource slidingTilesView:self imageRepForAnimationOfTileView:tile];
		
		if (tileImageRep) {
			[tileImageRep drawInRect:[tile frame]];
		}
	}
	
	[image unlockFocus];
}


@end
