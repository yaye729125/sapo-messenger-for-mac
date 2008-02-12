//
//  LPMessageCenterWinController.h
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jpavao@co.sapo.pt>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import <Cocoa/Cocoa.h>


@class LPMessageCenter;
@class LPColorBackgroundView;


@interface LPMessageCenterWinController : NSWindowController
{
	LPMessageCenter		*m_messageCenter;
	
	id					m_delegate;
	NSPredicate			*m_baseDisplayedNotificationsPredicate;
	NSURL				*m_sapoNotificationsManagerURL;
	
	// NIB Stuff
	IBOutlet NSOutlineView				*m_sourceListOutlineView;
	IBOutlet NSTabView					*m_mainContentTabView;
	IBOutlet LPColorBackgroundView		*m_offlineMessagesBottomBar;
	IBOutlet LPColorBackgroundView		*m_chatMessagesBottomBar;
	
	IBOutlet NSArrayController			*m_presenceSubscriptionsController;
	IBOutlet NSTableView				*m_presenceSubscriptionsTableView;
	
	IBOutlet NSTableView				*m_sapoNotificationsTableView;
	IBOutlet NSTableView				*m_offlineMessagesTableView;
	
	IBOutlet NSArrayController			*m_sapoNotifChannelsController;
	IBOutlet NSArrayController			*m_sapoNotificationsController;
	IBOutlet NSArrayController			*m_offlineMessagesController;
}

- initWithMessageCenter:(LPMessageCenter *)messageCenter;

- (id)delegate;
- (void)setDelegate:(id)delegate;

- (NSArray *)allBaseDisplayedNotificationsFilters;
- (NSPredicate *)baseDisplayedNotificationsFilterPredicate;
- (void)setBaseDisplayedNotificationsFilterPredicate:(NSPredicate *)basePredicate;

- (NSURL *)sapoNotificationsManagerURL;
- (void)setSapoNotificationsManagerURL:(NSURL *)theURL;

- (IBAction)presenceSubscriptionButton1Clicked:(id)sender;
- (IBAction)presenceSubscriptionButton2Clicked:(id)sender;

- (IBAction)openSapoNotificationURL:(id)sender;
- (IBAction)openSapoNotificationsManagerURL:(id)sender;
- (IBAction)openChatForSelectedOfflineMessage:(id)sender;

- (void)revealSapoNotificationWithURI:(NSString *)messageURI;
- (void)revealOfflineMessages;
- (void)revealPresenceSubscriptions;

@end


@interface NSObject (MessageCenterDelegate)
- (void)messageCenterWinCtrl:(LPMessageCenterWinController *)mesgCenterCtrl openNewChatWithJID:(NSString *)jid;
@end
