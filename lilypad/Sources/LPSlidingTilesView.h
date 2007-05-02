//
//  LPSlidingTilesView.h
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import <Cocoa/Cocoa.h>


@protocol LPSlidingTilesViewDataSource;


@interface LPSlidingTilesView : NSControl
{
	id <LPSlidingTilesViewDataSource>	m_dataSource;
	id									m_delegate;
	
	NSButtonCell	*m_leftArrowCell;
	NSButtonCell	*m_rightArrowCell;
	NSButtonCell	*m_trackedCell;
	
	float			m_boxHorizontalMargin;
	float			m_tilesVerticalMargin;
	float			m_minimumInterTileSpacing;
	
	NSArray			*m_tiledViews;
	int				m_firstVisibleTileIndex;
	NSView			*m_selectedTileView;
	
	NSDictionary	*m_animationInfo;
}

- (id <LPSlidingTilesViewDataSource>)dataSource;
- (void)setDataSource:(id <LPSlidingTilesViewDataSource>)dataSource;
- (id)delegate;
- (void)setDelegate:(id)delegate;

- (NSRect)leftArrowFrameForBounds:(NSRect)bounds;
- (NSRect)rightArrowFrameForBounds:(NSRect)bounds;
- (NSRect)contentRectForBounds:(NSRect)bounds;

- (void)drawBoxBorderInsideRect:(NSRect)borderBounds;
- (void)drawContentBackgroundInsideRect:(NSRect)rect;
- (void)drawTilesDecorationsForTiles:(NSArray *)tiles;

- (float)boxHorizontalMargin;
- (void)setBoxHorizontalMargin:(float)width;
- (float)tilesVerticalMargin;
- (void)setTilesVerticalMargin:(float)width;
- (float)minimumInterTileSpacing;
- (void)setMinimumInterTileSpacing:(float)space;

- (unsigned int)maxNumberOfTilesFittingInsideRect:(NSRect)rect;
- (void)tile;

- (int)numberOfTiles;
- (int)numberOfVisibleTiles;
- (int)firstVisibleTileIndex;
- (void)setFirstVisibleTileIndex:(int)firstTileIndex;
- (void)reloadTiles;

- (NSView *)selectedTileView;
- (int)selectedTileIndex;
- (void)setSelectedTileView:(NSView *)tileView;

- (float)animationDuration;
- (unsigned int)animationFramesPerSecond;

- (BOOL)canSlideLeft;
- (BOOL)canSlideRight;
- (IBAction)slideLeft:(id)sender;
- (IBAction)slideRight:(id)sender;
- (IBAction)performSlideLeft:(id)sender;
- (IBAction)performSlideRight:(id)sender;

@end


@protocol LPSlidingTilesViewDataSource
- (int)numberOfTilesInSlidingTilesView:(LPSlidingTilesView *)tilesView;
- (NSView *)slidingTilesView:(LPSlidingTilesView *)tilesView viewForTile:(int)tileIndex;
- (NSBitmapImageRep *)slidingTilesView:(LPSlidingTilesView *)tilesView imageRepForAnimationOfTileView:(NSView *)tileView;
@end


@interface NSObject (LPSlidingTilesViewDelegate)
- (void)slidingTilesViewSelectionDidChange:(LPSlidingTilesView *)tilesView;
@end

