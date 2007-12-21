//
//  LPRosterEventsBadgeView.h
//  Lilypad
//
//  Created by João Pavão on 07/12/20.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@class CTBadge;


@interface LPRosterEventsBadgeView : NSImageView
{
	BOOL		m_isDebugger;
	int			m_unreadOfflineMessagesCount;
	int			m_pendingFileTransfersCount;
	
	CTBadge		*m_badge;
	NSTimer		*m_rollingContentTimer;
	
	NSImage		*m_currentImage; // non-retained, just holds the same value as one of the instance variables that follow
	NSImage		*m_unreadOfflineMessagesCountImage;
	NSImage		*m_pendingFileTransfersCountImage;
}

- (BOOL)isDebugger;
- (void)setIsDebugger:(BOOL)flag;
- (int)unreadOfflineMessagesCount;
- (void)setUnreadOfflineMessagesCount:(int)count;
- (int)pendingFileTransfersCount;
- (void)setPendingFileTransfersCount:(int)count;

@end
