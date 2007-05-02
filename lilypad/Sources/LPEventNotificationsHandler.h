//
//  LPEventNotificationsHandler.h
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import <Cocoa/Cocoa.h>
#import <Growl/Growl.h>


@class LPContact, LPPresenceSubscription;


@interface LPEventNotificationsHandler : NSObject <GrowlApplicationBridgeDelegate>
{
	id		m_delegate;
	NSDate	*m_contactAvailabilityNotificationsReenableDate;
	
	unsigned int	m_nrOfOfflineMessagesForDelayedNotification;
}

+ (void)registerWithGrowl;
+ defaultHandler;

- (id)delegate;
- (void)setDelegate:(id)delegate;

- (void)disableContactAvailabilityNotificationsUntilDate:(NSDate *)date;
- (void)notifyContactAvailabilityDidChange:(LPContact *)contact;
- (void)notifyReceptionOfFirstMessage:(NSString *)message fromContact:(LPContact *)contact;
- (void)notifyReceptionOfMessage:(NSString *)message fromContact:(LPContact *)contact;
- (void)notifyReceptionOfHeadlineMessage:(id)message;
- (void)notifyReceptionOfOfflineMessage:(id)message;
- (void)notifyReceptionOfPresenceSubscription:(LPPresenceSubscription *)presSub;
@end


@interface NSObject (LPEventNotificationsHandlerDelegate)
- (void)notificationsHandler:(LPEventNotificationsHandler *)handler userDidClickNotificationForContactWithID:(unsigned int)contactID;
- (void)notificationsHandler:(LPEventNotificationsHandler *)handler userDidClickNotificationForHeadlineMessageWithURI:(NSString *)messageURI;
- (void)notificationsHandlerUserDidClickNotificationForOfflineMessages:(LPEventNotificationsHandler *)handler;
- (void)notificationsHandlerUserDidClickNotificationForPresenceSubscriptions:(LPEventNotificationsHandler *)handler;
@end
