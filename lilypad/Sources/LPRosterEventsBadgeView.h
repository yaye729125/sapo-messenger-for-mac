//
//  LPRosterEventsBadgeView.h
//  Lilypad
//
//	Copyright (C) 2007-2008 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jpavao@co.sapo.pt>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import <Cocoa/Cocoa.h>


@class CTBadge;


@interface LPRosterEventsBadgeView : NSImageView
{
	BOOL		m_isDebugger;
	int			m_unreadOfflineMessagesCount;
	int			m_countOfPresenceSubscriptionsRequiringAttention;
	int			m_pendingFileTransfersCount;
	
	CTBadge		*m_badge;
	NSTimer		*m_rollingContentTimer;
	
	NSImage		*m_currentImage; // non-retained, just holds the same value as one of the instance variables that follow
	NSImage		*m_unreadOfflineMessagesCountImage;
	NSImage		*m_countOfPresenceSubscriptionsRequiringAttentionImage;
	NSImage		*m_pendingFileTransfersCountImage;
}

- (BOOL)isDebugger;
- (void)setIsDebugger:(BOOL)flag;
- (int)unreadOfflineMessagesCount;
- (void)setUnreadOfflineMessagesCount:(int)count;
- (int)countOfPresenceSubscriptionsRequiringAttention;
- (void)setCountOfPresenceSubscriptionsRequiringAttention:(int)count;
- (int)pendingFileTransfersCount;
- (void)setPendingFileTransfersCount:(int)count;

@end
