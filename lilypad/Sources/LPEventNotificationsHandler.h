//
//  LPEventNotificationsHandler.h
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jpavao@co.sapo.pt>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import <Cocoa/Cocoa.h>
#import <Growl/Growl.h>


@class LPAccount, LPContact, LPPresenceSubscription;


@interface LPEventNotificationsHandler : NSObject <GrowlApplicationBridgeDelegate>
{
	id						m_delegate;
	NSMutableDictionary		*m_contactAvailabilityNotificationsReenableDatesByAccountUUID;	// NSString (Account UUID) -> NSDate
	unsigned int			m_nrOfOfflineMessagesForDelayedNotification;
}

+ (void)registerWithGrowl;
+ defaultHandler;

- (id)delegate;
- (void)setDelegate:(id)delegate;

- (void)disableContactAvailabilityNotificationsForAccount:(LPAccount *)account untilDate:(NSDate *)date;
- (void)notifyContactAvailabilityDidChange:(LPContact *)contact;

- (void)notifyReceptionOfFirstMessage:(NSString *)message fromContact:(LPContact *)contact;
- (void)notifyReceptionOfMessage:(NSString *)message fromContact:(LPContact *)contact;
- (void)notifyReceptionOfSMSMessage:(NSString *)message fromContact:(LPContact *)contact;

- (void)notifyReceptionOfHeadlineMessage:(id)message;

- (void)notifyReceptionOfOfflineMessage:(id)message;
- (void)notifyReceptionOfOfflineMessagesCount:(int)messageCount;

- (void)notifyReceptionOfPresenceSubscription:(LPPresenceSubscription *)presSub;

- (void)notifyReceptionOfFileTransferOfferWithFileName:(NSString *)filename fromContact:(LPContact *)contact;
- (void)notifyAcceptanceOfFileTransferWithFileName:(NSString *)filename fromContact:(LPContact *)contact;
- (void)notifyFailureOfFileTransferWithFileName:(NSString *)filename fromContact:(LPContact *)contact withErrorMessage:(NSString *)errorMsg;
- (void)notifyCompletionOfFileTransferWithFileName:(NSString *)filename withContact:(LPContact *)contact;

@end


@interface NSObject (LPEventNotificationsHandlerDelegate)
- (void)notificationsHandler:(LPEventNotificationsHandler *)handler userDidClickNotificationForContactWithID:(unsigned int)contactID;
- (void)notificationsHandler:(LPEventNotificationsHandler *)handler userDidClickNotificationForHeadlineMessageWithURI:(NSString *)messageURI;
- (void)notificationsHandlerUserDidClickNotificationForOfflineMessages:(LPEventNotificationsHandler *)handler;
- (void)notificationsHandlerUserDidClickNotificationForPresenceSubscriptions:(LPEventNotificationsHandler *)handler;
- (void)notificationsHandlerUserDidClickNotificationForFileTransfer:(LPEventNotificationsHandler *)handler;
@end
