//
//  LPStatusMenuController.h
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Authors: Joao Pavao <jppavao@criticalsoftware.com>
//           Jason Kim <jason@512k.org>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//
//
// Manages an associated NSMenu that stays synchronized with the user's status.
//
// Each time a status menu is to appear anywhere, use an instance of this class to create
// and insert NSMenuItems into the desired place and the menu items will automagically update
// themselves when the status changes. 
//

#import <Cocoa/Cocoa.h>


@class LPAccount, LPCurrentITunesTrackMonitor;


@interface LPStatusMenuController : NSObject 
{
	LPAccount		*m_account;
	
	NSMutableSet	*m_controlledMenus;
	NSMutableSet	*m_controlledPopUpButtons;
	
	LPStatus		m_currentlySelectedStatusMenuTag;
	BOOL			m_isSettingStatusFromITunes;
	
	LPCurrentITunesTrackMonitor		*m_iTunesTrackMonitor;
	NSString						*m_statusMessageBeforeITunesMonitoring;
}

- initWithAccount:(LPAccount *)account;

- (void)insertControlledStatusItemsIntoMenu:(NSMenu *)menu atIndex:(unsigned int)index;
- (void)stopControllingStatusInMenu:(NSMenu *)menu;
- (void)insertControlledStatusItemsIntoPopUpMenu:(NSPopUpButton *)button atIndex:(unsigned int)index;
- (void)stopControllingStatusInPopUpMenu:(NSPopUpButton *)button;

- (BOOL)usesCurrentITunesTrackAsStatus;
- (void)setUsesCurrentITunesTrackAsStatus:(BOOL)flag;

@end
