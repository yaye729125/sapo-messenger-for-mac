//
//  LPAudiblesDrawerController.m
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "LPAudiblesDrawerController.h"
#import "LPAudibleSet.h"
#import "LPAudibleTileView.h"
#import "LPChatController.h"
#import "LPChat.h"
#import "LPContact.h"
#import "LPAccount.h"
#import "LPSlidingTilesView.h"

#import <WebKit/WebKit.h>


@interface LPAudiblesDrawerController (Private)
- (void)p_didFinishGettingAudibleFromServer:(NSNotification *)notif;
- (void)p_updateTiles;
@end


@implementation LPAudiblesDrawerController


- init
{
	if (self = [super init]) {
		m_tilesForCurrentCategory = [[NSMutableDictionary alloc] init];
		
		[[self audibleSet] addObserver:self
							forKeyPath:@"arrangedAudibleNamesByCategory"
							   options:0
							   context:NULL];
		
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(p_didFinishGettingAudibleFromServer:)
													 name:LPAudibleSetAudibleDidFinishLoadingNotification
												   object:[self audibleSet]];
		
	}
	return self;
}


- (void)awakeFromNib
{
	/* Audibles Drawer */
	[m_audiblesView setTilesVerticalMargin:5.0];
	[m_audiblesView setMinimumInterTileSpacing:10.0];
	
	[m_audibleSetController setContent:[LPAudibleSet defaultAudibleSet]];
	
	[m_sendButton setEnabled:([m_audiblesView selectedTileView] != nil &&
							  [[[m_chatController chat] account] isOnline])];
}


- (void)dealloc
{
	[[self audibleSet] removeObserver:self forKeyPath:@"arrangedAudibleNamesByCategory"];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[m_audibleSet release];
	[m_tilesForCurrentCategory release];
	
	[super dealloc];
}


- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ([keyPath isEqualToString:@"arrangedAudibleNamesByCategory"]) {
		[self p_updateTiles];
	}
	else if ([keyPath isEqualToString:@"account.online"]) {
		[m_sendButton setEnabled:([m_audiblesView selectedTileView] != nil &&
								  [[[m_chatController chat] account] isOnline])];
	}
	else {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}


- (LPChatController *)chatController
{
	return [[m_chatController retain] autorelease];
}

- (void)setChatController:(LPChatController *)chatCtrl
{
	if (m_chatController != chatCtrl) {
		[[m_chatController chat] removeObserver:self forKeyPath:@"account.online"];
		[[m_chatController chat] release];
		
		[m_chatController release];
		m_chatController = [chatCtrl retain];
		
		[[m_chatController chat] retain];
		[[m_chatController chat] addObserver:self forKeyPath:@"account.online" options:0 context:NULL];
	}
}

- (LPAudibleSet *)audibleSet
{
	if (m_audibleSet == nil) {
		m_audibleSet = [[LPAudibleSet defaultAudibleSet] retain];
	}
	return m_audibleSet;
}


- (NSString *)selectedCategory
{
	return [[m_categoryPopUp selectedItem] title];
}


- (NSDrawerState)drawerState
{
	return [m_audiblesDrawer state];
}


- (IBAction)toggleDrawer:(id)sender
{
	static BOOL alreadyUpdatedSetInThisSession = NO;
	
	[m_audiblesDrawer toggle:sender];
	
	if (alreadyUpdatedSetInThisSession == NO) {
		// Delay the update just a bit so that it doesn't ruin the drawer sliding animation. :-)
		[m_audibleSet performSelector:@selector(startUpdatingConfigurationFromServer)
						   withObject:nil
						   afterDelay:1.0];
		alreadyUpdatedSetInThisSession = YES;
	}
	
	// Reload the tiles so that they get loaded/unloaded depending on the drawer being open or closed
	// (also try not to ruin the drawer animation)
	[m_audiblesView performSelector:@selector(reloadTiles) withObject:nil afterDelay:0.5];
}


- (IBAction)categoryChanged:(id)sender
{
	NSString *selectedCategory = [self selectedCategory];
	
	if ([selectedCategory length] > 0) {
		[self p_updateTiles];
		[m_audiblesView setFirstVisibleTileIndex:0];
	}
}


- (IBAction)sendAudible:(id)sender
{
	int selectedTileIndex = [m_audiblesView selectedTileIndex];
	
	if (selectedTileIndex >= 0) {
		LPAudibleSet	*set = [self audibleSet];
		NSArray			*audibleNamesForCurrentCategory = [set arrangedAudibleNamesForCategory:[self selectedCategory]];
		NSString		*audibleName = [audibleNamesForCurrentCategory objectAtIndex:selectedTileIndex];

		[m_chatController sendAudibleWithResourceName:audibleName];
	}
}


- (void)p_didFinishGettingAudibleFromServer:(NSNotification *)notif
{
	NSString *audibleName = [[notif userInfo] objectForKey:@"LPAudibleName"];
	LPAudibleTileView *tileView = [m_tilesForCurrentCategory objectForKey:audibleName];
	
	if ([tileView hasAudibleFileContent] == NO) {
		[tileView setAudibleFileContentPath:[[self audibleSet] filepathForAudibleWithName:audibleName]];
	}
}


- (void)p_updateTiles
{
	[m_tilesForCurrentCategory removeAllObjects];
	[m_audiblesView reloadTiles];
}


#pragma mark -
#pragma mark LPSlidingTilesView Data Source Methods


- (int)numberOfTilesInSlidingTilesView:(LPSlidingTilesView *)tilesView
{
	if ([m_audiblesDrawer state] == NSDrawerClosedState) {
		// By having the sliding audibles view empty when the drawer is closed, we effectively stop any preview animation
		// that could be running.
		return 0;
	}
	else {
		NSArray *audibleNamesForCurrentCategory = [[self audibleSet] arrangedAudibleNamesForCategory:[self selectedCategory]];
		return [audibleNamesForCurrentCategory count];
	}
}


- (NSView *)slidingTilesView:(LPSlidingTilesView *)tilesView viewForTile:(int)tileIndex
{
	LPAudibleSet	*set = [self audibleSet];
	NSArray			*audibleNamesForCurrentCategory = [set arrangedAudibleNamesForCategory:[self selectedCategory]];
	NSString		*audibleName = [audibleNamesForCurrentCategory objectAtIndex:tileIndex];
	NSString		*audibleFilePathname = [set filepathForAudibleWithName:audibleName];

	LPAudibleTileView *tileView = [m_tilesForCurrentCategory objectForKey:audibleName];
	
	if (tileView == nil) {
		tileView = [[LPAudibleTileView alloc] init];
		
		[tileView setDelegate:self];
		[tileView setToolTip:[NSString stringWithFormat:@"%@\nText: \"%@\"",
			[set captionForAudibleWithName:audibleName],
			[set textForAudibleWithName:audibleName]]];
		
		[m_tilesForCurrentCategory setObject:tileView forKey:audibleName];
		[tileView release];
	}
	
	if ([tileView hasAudibleFileContent] == NO) {
		if (audibleFilePathname) {
			[tileView setAudibleFileContentPath:audibleFilePathname];
		} else {
			[set startLoadingAudibleFromServer:audibleName];
		}
	}
	
	return tileView;
}


- (NSBitmapImageRep *)slidingTilesView:(LPSlidingTilesView *)tilesView imageRepForAnimationOfTileView:(NSView *)tileView
{
	return [(LPAudibleTileView *)tileView cachedBitmapImageRep];
}


#pragma mark -
#pragma mark LPSlidingTilesView Delegate Methods

- (void)slidingTilesViewSelectionDidChange:(LPSlidingTilesView *)tilesView
{
	[m_sendButton setEnabled:([m_audiblesView selectedTileView] != nil &&
							  [[[m_chatController chat] account] isOnline])];
}


#pragma mark -
#pragma mark LPAudibleTileView Delegate Methods

- (void)audibleTileViewGotMouseDown:(LPAudibleTileView *)view
{
	[m_audiblesView setSelectedTileView:view];
}

@end
