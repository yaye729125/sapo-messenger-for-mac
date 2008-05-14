//
//  LPRosterEventsBadgeView.m
//  Lilypad
//
//	Copyright (C) 2007-2008 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jpavao@co.sapo.pt>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "LPRosterEventsBadgeView.h"
#import "CTBadge.h"


@implementation LPRosterEventsBadgeView


- initWithFrame:(NSRect)frameRect
{
	if (self = [super initWithFrame:frameRect]) {
		m_badge = [[CTBadge alloc] init];
		[self setImage:nil];
	}
	return self;
}

- (void)awakeFromNib
{
	if (m_badge == nil) {
		m_badge = [[CTBadge alloc] init];
		[self setImage:nil];
	}
}

- (void)dealloc
{
	[m_rollingContentTimer invalidate];
	[m_rollingContentTimer release];
	
	[m_badge release];
	
	[m_unreadOfflineMessagesCountImage release];
	[m_countOfPresenceSubscriptionsRequiringAttentionImage release];
	[m_pendingFileTransfersCountImage release];
	
	[super dealloc];
}


- (BOOL)p_needsTimerRunning
{
	return ([self unreadOfflineMessagesCount] > 0 ||
			[self countOfPresenceSubscriptionsRequiringAttention] > 0 ||
			[self pendingFileTransfersCount] > 0);
}


- (void)p_updateDisplayedContent
{
	BOOL needsTimerRunning = [self p_needsTimerRunning];
	
	if (needsTimerRunning && (m_rollingContentTimer == nil || ![m_rollingContentTimer isValid])) {
		[m_rollingContentTimer invalidate];
		[m_rollingContentTimer release];
		
		m_rollingContentTimer = [[NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(p_rollContentWithTimer:)
																userInfo:nil repeats:YES] retain];
		
		// Do the initial update
		[m_rollingContentTimer fire];
	}
	else if (!needsTimerRunning && [m_rollingContentTimer isValid]) {
		// Perform a last update to the displayed content
		[m_rollingContentTimer fire];
		
		[m_rollingContentTimer invalidate];
		[m_rollingContentTimer release];
		m_rollingContentTimer = nil;
	}
	
	
	// Update the tooltip
	NSMutableString *tooltipText = [NSMutableString string];
	
	int unreadMsgs = [self unreadOfflineMessagesCount];
	int presSubs = [self countOfPresenceSubscriptionsRequiringAttention];
	int pendingTransfers = [self pendingFileTransfersCount];
	BOOL thereWillBeAMenu = NO;
	
	if (unreadMsgs > 0) {
		thereWillBeAMenu = YES;
		[tooltipText appendFormat:(unreadMsgs == 1 ?
								   NSLocalizedString(@"%C You have %d unread message that was received while you were offline", @"") :
								   NSLocalizedString(@"%C You have %d unread messages that were received while you were offline", @"") ),
			0x2022, unreadMsgs];
	}
	
	if (presSubs > 0) {
		thereWillBeAMenu = YES;
		if ([tooltipText length] > 0)
			[tooltipText appendString:@"\n"];
		[tooltipText appendFormat:(presSubs == 1 ?
								   NSLocalizedString(@"%C You have %d presence subscription needing your attention", @"") :
								   NSLocalizedString(@"%C You have %d presence subscriptions needing your attention", @"") ),
		 0x2022, presSubs];
	}
	
	if (pendingTransfers > 0) {
		thereWillBeAMenu = YES;
		if ([tooltipText length] > 0)
			[tooltipText appendString:@"\n"];
		[tooltipText appendFormat:(pendingTransfers == 1 ?
								   NSLocalizedString(@"%C There is %d pending file transfer that needs your attention", @"") :
								   NSLocalizedString(@"%C There are %d pending file transfers that need your attention", @"") ),
			0x2022, pendingTransfers];
	}
	
	if ([self isDebugger]) {
		if ([tooltipText length] > 0) {
			[tooltipText appendFormat:@"\n%C %@", 0x2022, NSLocalizedString(@"You are a debugger", @"")];
		} else {
			[tooltipText appendString:NSLocalizedString(@"You are a debugger", @"")];
		}
	}
	
	if (thereWillBeAMenu)
		[tooltipText appendString:NSLocalizedString(@"\n\nClick to choose an action from a menu.", @"")];
	
	[self setToolTip:([tooltipText length] > 0 ? tooltipText : nil)];
}


- (void)p_displayIdleImage
{
	[self setImage:([self isDebugger] ? [NSImage imageNamed:@"bug"] : nil)];
	m_currentImage = nil;
}

- (void)p_displayUnreadOfflineMessagesImage
{
	[self setImage:m_unreadOfflineMessagesCountImage];
	m_currentImage = m_unreadOfflineMessagesCountImage;
}

- (void)p_displayPresenceSubscriptionsImage
{
	[self setImage:m_countOfPresenceSubscriptionsRequiringAttentionImage];
	m_currentImage = m_countOfPresenceSubscriptionsRequiringAttentionImage;
}

- (void)p_displayPendingFileTransfersImage
{
	[self setImage:m_pendingFileTransfersCountImage];
	m_currentImage = m_pendingFileTransfersCountImage;
}


- (void)p_rollContentWithTimer:(NSTimer *)timer
{
	BOOL needsToDisplayUnreadCount                = ([self unreadOfflineMessagesCount] > 0);
	BOOL needsToDisplayPendingFilesCount          = ([self pendingFileTransfersCount] > 0);
	BOOL needsToDisplayPresenceSubscriptionsCount = ([self countOfPresenceSubscriptionsRequiringAttention] > 0);
	
#define AVAILABLE_IMAGES_COUNT 3
	
	NSImage *images[AVAILABLE_IMAGES_COUNT] = {
		m_unreadOfflineMessagesCountImage, m_pendingFileTransfersCountImage, m_countOfPresenceSubscriptionsRequiringAttentionImage
	};
	BOOL needsToDisplay[AVAILABLE_IMAGES_COUNT] = {
		needsToDisplayUnreadCount, needsToDisplayPendingFilesCount, needsToDisplayPresenceSubscriptionsCount
	};
	SEL displaySelectors[AVAILABLE_IMAGES_COUNT] = {
		@selector(p_displayUnreadOfflineMessagesImage),
		@selector(p_displayPendingFileTransfersImage),
		@selector(p_displayPresenceSubscriptionsImage)
	};
	
	BOOL didDisplay = NO;
	
	if (m_currentImage == nil) {
		int nextDisplayedIndex;
		for (nextDisplayedIndex = 0; nextDisplayedIndex != AVAILABLE_IMAGES_COUNT; ++nextDisplayedIndex) {
			if (needsToDisplay[nextDisplayedIndex]) {
				[self performSelector:displaySelectors[nextDisplayedIndex]];
				didDisplay = YES;
				break;
			}
		}
	}
	else {
		int prevDisplayedIndex;
		for (prevDisplayedIndex = 0; prevDisplayedIndex < AVAILABLE_IMAGES_COUNT; ++prevDisplayedIndex)
			if (images[prevDisplayedIndex] == m_currentImage)
				break;
		
		NSAssert((prevDisplayedIndex < AVAILABLE_IMAGES_COUNT), @"LPRosterEventsBadgeView is displaying an unknown image!");
		
		int nextDisplayedIndex;
		for (nextDisplayedIndex = (prevDisplayedIndex + 1) % AVAILABLE_IMAGES_COUNT;
			 nextDisplayedIndex != prevDisplayedIndex;
			 nextDisplayedIndex = (nextDisplayedIndex + 1) % AVAILABLE_IMAGES_COUNT)
		{
			if (needsToDisplay[nextDisplayedIndex]) {
				[self performSelector:displaySelectors[nextDisplayedIndex]];
				didDisplay = YES;
				break;
			}
		}
	}
	
	if (!didDisplay) {
		[self p_displayIdleImage];
	}
}


#pragma mark -


- (BOOL)isDebugger
{
	return m_isDebugger;
}

- (void)setIsDebugger:(BOOL)flag
{
	if (flag != m_isDebugger) {
		m_isDebugger = flag;
		
		if (m_currentImage == nil)
			[self p_displayIdleImage];
		
		[self p_updateDisplayedContent];
	}
}


- (int)unreadOfflineMessagesCount
{
	return m_unreadOfflineMessagesCount;
}

- (void)setUnreadOfflineMessagesCount:(int)count
{
	if (count != m_unreadOfflineMessagesCount) {
		m_unreadOfflineMessagesCount = count;
		
		BOOL shouldUpdateDisplayedImageImmediately = (m_currentImage != nil && m_currentImage == m_unreadOfflineMessagesCountImage);
		
		// update the badge image
		[m_unreadOfflineMessagesCountImage release];
		if (count > 0) {
			[m_badge setBadgeColor:[NSColor colorWithCalibratedHue:0.0833 saturation:0.65 brightness:0.80 alpha:1.0]];
			m_unreadOfflineMessagesCountImage = [[m_badge largeBadgeForValue:count] retain];
			
			if (shouldUpdateDisplayedImageImmediately)
				[self p_displayUnreadOfflineMessagesImage];
		}
		else {
			m_unreadOfflineMessagesCountImage = nil;
			
			if (shouldUpdateDisplayedImageImmediately)
				[self p_displayIdleImage];
		}
		
		[self p_updateDisplayedContent];
	}
}


- (int)countOfPresenceSubscriptionsRequiringAttention
{
	return m_countOfPresenceSubscriptionsRequiringAttention;
}

- (void)setCountOfPresenceSubscriptionsRequiringAttention:(int)count
{
	if (count != m_countOfPresenceSubscriptionsRequiringAttention) {
		m_countOfPresenceSubscriptionsRequiringAttention = count;
		
		BOOL shouldUpdateDisplayedImageImmediately = (m_currentImage != nil && m_currentImage == m_countOfPresenceSubscriptionsRequiringAttentionImage);
		
		// update the badge image
		[m_countOfPresenceSubscriptionsRequiringAttentionImage release];
		if (count > 0) {
			[m_badge setBadgeColor:[NSColor colorWithCalibratedHue:0.1889 saturation:0.65 brightness:0.80 alpha:1.0]];
			m_countOfPresenceSubscriptionsRequiringAttentionImage = [[m_badge largeBadgeForValue:count] retain];
			
			if (shouldUpdateDisplayedImageImmediately)
				[self p_displayPresenceSubscriptionsImage];
		}
		else {
			m_countOfPresenceSubscriptionsRequiringAttentionImage = nil;
			
			if (shouldUpdateDisplayedImageImmediately)
				[self p_displayIdleImage];
		}
		
		[self p_updateDisplayedContent];
	}
}


- (int)pendingFileTransfersCount
{
	return m_pendingFileTransfersCount;
}

- (void)setPendingFileTransfersCount:(int)count
{
	if (count != m_pendingFileTransfersCount) {
		m_pendingFileTransfersCount = count;
		
		BOOL shouldUpdateDisplayedImageImmediately = (m_currentImage != nil && m_currentImage == m_pendingFileTransfersCountImage);
		
		// update the badge image
		[m_pendingFileTransfersCountImage release];
		if (count > 0) {
			[m_badge setBadgeColor:[NSColor colorWithCalibratedRed:0.2 green:0.2 blue:1.0 alpha:1.0]];
			m_pendingFileTransfersCountImage = [[m_badge largeBadgeForValue:count] retain];
			
			if (shouldUpdateDisplayedImageImmediately)
				[self p_displayPendingFileTransfersImage];
		}
		else {
			m_pendingFileTransfersCountImage = nil;
			
			if (shouldUpdateDisplayedImageImmediately)
				[self p_displayIdleImage];
		}
		
		[self p_updateDisplayedContent];
	}
}


#pragma mark -


- (void)setMenu:(NSMenu *)menu
{
	[super setMenu:([menu numberOfItems] > 0 ? menu : nil)];
}


- (void)mouseDown:(NSEvent *)theEvent
{
	NSMenu *menu = [self menu];
	
	if (menu != nil)
		[NSMenu popUpContextMenu:menu withEvent:theEvent forView:self];
}


@end
