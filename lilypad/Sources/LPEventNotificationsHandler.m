//
//  LPEventNotificationsHandler.m
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jpavao@co.sapo.pt>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "LPEventNotificationsHandler.h"
#import "LPAccount.h"
#import "LPContact.h"
#import "LPContactEntry.h"
#import "LPPresenceSubscription.h"


// Notification Names for Growl
static NSString *LPContactAvailabilityChangedNotificationName	= @"Contact Availability Changed";
static NSString *LPFirstChatMessageReceivedNotificationName		= @"First Chat Message Received";
static NSString *LPChatMessageReceivedNotificationName			= @"Chat Message Received";
static NSString *LPSMSMessageReceivedNotificationName			= @"SMS Message Received";
static NSString *LPHeadlineMessageReceivedNotificationName		= @"Notification Headline Received";
static NSString *LPOfflineMessagesReceivedNotificationName		= @"Offline Messages Received";
static NSString *LPPresenceSubscriptionReceivedNotificationName	= @"Presence Subscription Received";
static NSString *LPFileTransferEventNotificationName			= @"File Transfer Event";


// Key names for the Growl click context
static NSString *LPClickContextKindKey			= @"Kind";
static NSString *LPClickContextContactIDKey		= @"ContactID";
static NSString *LPClickContextMessageURIKey	= @"MessageURI";

static NSString *LPClickContextContactKindValue					= @"Contact";
static NSString *LPClickContextHeadlineMessageKindValue			= @"HeadlineMessage";
static NSString *LPClickContextOfflineMessagesKindValue			= @"OfflineMessages";
static NSString *LPClickContextPresenceSubscriptionKindValue	= @"PresenceSubscription";
static NSString *LPClickContextFileTransferKindValue			= @"FileTransfer";

@implementation LPEventNotificationsHandler

+ (void)registerWithGrowl
{
	// This forces the LPEventNotificationsHandler to initialize and register with Growl
	[LPEventNotificationsHandler defaultHandler];
}

+ defaultHandler
{
	static LPEventNotificationsHandler *defaultHandler = nil;

	if (defaultHandler == nil) {
		defaultHandler = [[LPEventNotificationsHandler alloc] init];
		[GrowlApplicationBridge setGrowlDelegate:defaultHandler];
	}
	return defaultHandler;
}


- init
{
	if (self = [super init]) {
		m_contactAvailabilityNotificationsReenableDatesByAccountUUID = [[NSMutableDictionary alloc] init];
	}
	return self;
}


- (void)dealloc
{
	[m_contactAvailabilityNotificationsReenableDatesByAccountUUID release];
	[super dealloc];
}


- (id)delegate
{
	return m_delegate;
}


- (void)setDelegate:(id)delegate
{
	m_delegate = delegate;
}


- (id)p_clickContextForContact:(LPContact *)contact
{
	return [NSDictionary dictionaryWithObjectsAndKeys:
		LPClickContextContactKindValue, LPClickContextKindKey,
		[NSNumber numberWithInt:[contact ID]], LPClickContextContactIDKey,
		nil];
}

- (id)p_clickContextForHeadlineMessage:(id)message
{
	return [NSDictionary dictionaryWithObjectsAndKeys:
		LPClickContextHeadlineMessageKindValue, LPClickContextKindKey,
		[[[message objectID] URIRepresentation] absoluteString], LPClickContextMessageURIKey,
		nil];
}

- (id)p_clickContextForOfflineMessages
{
	return [NSDictionary dictionaryWithObjectsAndKeys:
		LPClickContextOfflineMessagesKindValue, LPClickContextKindKey,
		nil];
}

- (id)p_clickContextForPresenceSubscription:(id)presSub
{
	return [NSDictionary dictionaryWithObjectsAndKeys:
		LPClickContextPresenceSubscriptionKindValue, LPClickContextKindKey,
		nil];
}

- (id)p_clickContextForFileTransfer
{
	return [NSDictionary dictionaryWithObjectsAndKeys:
		LPClickContextFileTransferKindValue, LPClickContextKindKey,
		nil];
}


#pragma mark Public Methods to Request Posting of Notifications


- (void)disableContactAvailabilityNotificationsForAccount:(LPAccount *)account untilDate:(NSDate *)date
{
	[m_contactAvailabilityNotificationsReenableDatesByAccountUUID setObject:date forKey:[account UUID]];
}


- (void)notifyContactAvailabilityDidChange:(LPContact *)contact
{
	BOOL		shouldNotify = YES;
	NSString	*statusChangeSourceAccountUUID = [[[contact lastContactEntryToChangeStatus] account] UUID];
	NSDate		*notificationsReenableDate = [m_contactAvailabilityNotificationsReenableDatesByAccountUUID objectForKey:statusChangeSourceAccountUUID];
	
	if (notificationsReenableDate != nil) {
		NSDate *now = [NSDate date];
		
		if ([now compare:notificationsReenableDate] == NSOrderedAscending) {
			// We're still in the time interval where notifications should be disabled.
			shouldNotify = NO;
		}
		else {
			// Clear the "timeout" date
			[m_contactAvailabilityNotificationsReenableDatesByAccountUUID removeObjectForKey:statusChangeSourceAccountUUID];
		}
	}
	
	
	if (shouldNotify) {
		// Allow a small delay to avoid having everything happen at the same time. This also allows the avatar to be updated
		// (if it exists) from cache before actually displaying the notification.
		[self performSelector:@selector(p_displayContactAvailabilityDidChangeNotification:)
				   withObject:contact
				   afterDelay:0.5];
	}
}


- (void)p_displayContactAvailabilityDidChangeNotification:(LPContact *)contact
{
	// Avoid notifying about just added (in the last n seconds) and just deleted contacts
	if ([contact roster] != nil && [[contact creationDate] timeIntervalSinceNow] < (-10.0)) {
		NSString *description = ( ([contact status] == LPStatusOffline) ?
								  NSLocalizedString(@"went Offline", @"contact availability change notifications") :
								  NSLocalizedString(@"is now Online", @"contact availability change notifications")  );
		// Make "contact went offline" notifications non-clickable
		id clickContext = ( ([contact status] == LPStatusOffline) ?
							nil :
							[self p_clickContextForContact:contact] );
		
		[GrowlApplicationBridge notifyWithTitle:[contact name]
									description:description
							   notificationName:LPContactAvailabilityChangedNotificationName
									   iconData:[[contact avatar] TIFFRepresentation]
									   priority:0
									   isSticky:NO
								   clickContext:clickContext];
	}
}


- (void)notifyReceptionOfFirstMessage:(NSString *)message fromContact:(LPContact *)contact
{
	NSString *title = [NSString stringWithFormat:
		NSLocalizedString(@"First Message from %@", @"chat messages notifications"),
		[contact name]];
	
	NSNumber *contactIDNr = [NSNumber numberWithInt:[contact ID]];
	NSString *identifier = [[contactIDNr stringValue] stringByAppendingString:message];
	NSData *iconData = [[contact avatar] TIFFRepresentation];
	
	/*
	 * Shoot the two kinds of notifications coalesced under the same identifier. This way, if the user
	 * has "first message notifications" disabled in the prefs but regular "message notifications" enabled,
	 * then the first message will still be able to have a notification displayed.
	 */
	
	[GrowlApplicationBridge notifyWithTitle:title
								description:message
						   notificationName:LPChatMessageReceivedNotificationName
								   iconData:iconData
								   priority:1
								   isSticky:NO
							   clickContext:[self p_clickContextForContact:contact]
								 identifier:identifier];
	
	[NSApp requestUserAttention:NSInformationalRequest];
	
	[GrowlApplicationBridge notifyWithTitle:title
								description:message
						   notificationName:LPFirstChatMessageReceivedNotificationName
								   iconData:iconData
								   priority:1
								   isSticky:NO
							   clickContext:[self p_clickContextForContact:contact]
								 identifier:identifier];
	
	// Play the "Received Message" sound
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"UIPlaySounds"]) {
		[[NSSound soundNamed:@"received"] play];
	}
}


- (void)notifyReceptionOfMessage:(NSString *)message fromContact:(LPContact *)contact
{
	NSString *title = [NSString stringWithFormat:NSLocalizedString(@"Message from %@", @"chat messages notifications"),
		[contact name]];
	
	[NSApp requestUserAttention:NSInformationalRequest];
	
	[GrowlApplicationBridge notifyWithTitle:title
								description:message
						   notificationName:LPChatMessageReceivedNotificationName
								   iconData:[[contact avatar] TIFFRepresentation]
								   priority:1
								   isSticky:NO
							   clickContext:[self p_clickContextForContact:contact]];
	
	// Play the "Received Message" sound
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"UIPlaySounds"]) {
		[[NSSound soundNamed:@"received"] play];
	}
}


- (void)notifyReceptionOfSMSMessage:(NSString *)message fromContact:(LPContact *)contact
{
	NSString *title = [NSString stringWithFormat:NSLocalizedString(@"SMS Message from %@", @"chat messages notifications"),
		[contact name]];
	
	[NSApp requestUserAttention:NSInformationalRequest];
	
	[GrowlApplicationBridge notifyWithTitle:title
								description:message
						   notificationName:LPSMSMessageReceivedNotificationName
								   iconData:[[contact avatar] TIFFRepresentation]
								   priority:1
								   isSticky:NO
							   clickContext:[self p_clickContextForContact:contact]];
}


- (void)notifyReceptionOfHeadlineMessage:(id)message
{
	NSString *title = [NSString stringWithFormat:NSLocalizedString(@"Notification Headline", @"messages notifications")];
	
	[GrowlApplicationBridge notifyWithTitle:title
								description:[message valueForKey:@"subject"]
						   notificationName:LPHeadlineMessageReceivedNotificationName
								   iconData:nil
								   priority:1
								   isSticky:NO
							   clickContext:[self p_clickContextForHeadlineMessage:message]];
}


- (void)p_notifyReceptionOfOfflineMessages
{
	NSString *title = [NSString stringWithFormat:NSLocalizedString(@"Offline Messages", @"messages notifications")];
	NSString *descr = [NSString stringWithFormat:(m_nrOfOfflineMessagesForDelayedNotification == 1 ?
												  NSLocalizedString(@"You have received %d message while you were offline.", @"messages notifications") :
												  NSLocalizedString(@"You have received %d messages while you were offline.", @"messages notifications") ),
					   m_nrOfOfflineMessagesForDelayedNotification];
	
	[NSApp requestUserAttention:NSInformationalRequest];
	
	[GrowlApplicationBridge notifyWithTitle:title
								description:descr
						   notificationName:LPOfflineMessagesReceivedNotificationName
								   iconData:nil
								   priority:1
								   isSticky:NO
							   clickContext:[self p_clickContextForOfflineMessages]];
	
	m_nrOfOfflineMessagesForDelayedNotification = 0;
}

- (void)notifyReceptionOfOfflineMessage:(id)message
{
	[self notifyReceptionOfOfflineMessagesCount:1];
}


- (void)notifyReceptionOfOfflineMessagesCount:(int)messageCount
{
	if (m_nrOfOfflineMessagesForDelayedNotification == 0 && messageCount > 0) {
		[self performSelector:@selector(p_notifyReceptionOfOfflineMessages) withObject:nil afterDelay:3.0];
	}
	m_nrOfOfflineMessagesForDelayedNotification += messageCount;
}


- (void)notifyReceptionOfPresenceSubscription:(LPPresenceSubscription *)presSub
{
	NSString *title = [NSString stringWithFormat:NSLocalizedString(@"Presence Subscription", @"messages notifications")];
	NSString *descr = nil;
	
	NSString *nickname = [presSub nickname];
	NSString *humanReadableJID = [[presSub contactEntry] humanReadableAddress];
	NSString *contactReference = ( ([nickname length] > 0 && ![nickname isEqualToString:humanReadableJID]) ?
								   [NSString stringWithFormat:@"\"%@\" (%@)", nickname, humanReadableJID] :
								   [NSString stringWithFormat:@"\"%@\"", humanReadableJID] );
	
	switch ([presSub state]) {
		case LPAuthorizationGranted:
			descr = [NSString stringWithFormat:
				NSLocalizedString(@"%@ was added to your buddy list. You can now see the online status of this contact.", @"messages notifications"),
				contactReference];
			break;
			
		case LPAuthorizationRequested:
			descr = [NSString stringWithFormat:
				NSLocalizedString(@"%@ wants to add you as a buddy.", @"messages notifications"),
				contactReference];
			break;
			
		case LPAuthorizationLost:
			descr = [NSString stringWithFormat:
				NSLocalizedString(@"Permission to see the online status of contact %@ was lost.", @"messages notifications"),
				contactReference];
			break;
	}
	
	[GrowlApplicationBridge notifyWithTitle:title
								description:descr
						   notificationName:LPPresenceSubscriptionReceivedNotificationName
								   iconData:nil
								   priority:1
								   isSticky:NO
							   clickContext:[self p_clickContextForPresenceSubscription:presSub]];
}


- (void)notifyReceptionOfFileTransferOfferWithFileName:(NSString *)filename fromContact:(LPContact *)contact
{
	NSString *title = [NSString stringWithFormat:NSLocalizedString(@"File Transfer Offer", @"file transfer notifications")];
	NSString *description = [NSString stringWithFormat:
		NSLocalizedString(@"%@ is offering you the file \"%@\"", @"file transfer notifications"),
		[contact name], filename];
	
	[NSApp requestUserAttention:NSCriticalRequest];
	
	[GrowlApplicationBridge notifyWithTitle:title
								description:description
						   notificationName:LPFileTransferEventNotificationName
								   iconData:nil
								   priority:1
								   isSticky:NO
							   clickContext:[self p_clickContextForFileTransfer]];
}

- (void)notifyAcceptanceOfFileTransferWithFileName:(NSString *)filename fromContact:(LPContact *)contact
{
	NSString *title = [NSString stringWithFormat:NSLocalizedString(@"File Transfer Accepted", @"file transfer notifications")];
	NSString *description = [NSString stringWithFormat:
		NSLocalizedString(@"%@ accepted your file named \"%@\"", @"file transfer notifications"),
		[contact name], filename];
	
	[GrowlApplicationBridge notifyWithTitle:title
								description:description
						   notificationName:LPFileTransferEventNotificationName
								   iconData:nil
								   priority:1
								   isSticky:NO
							   clickContext:[self p_clickContextForFileTransfer]];
}

- (void)notifyFailureOfFileTransferWithFileName:(NSString *)filename fromContact:(LPContact *)contact withErrorMessage:(NSString *)errorMsg
{
	NSString *title = [NSString stringWithFormat:NSLocalizedString(@"File Transfer Failed", @"file transfer notifications")];
	NSString *description = ( (errorMsg != nil) ?
							  [NSString stringWithFormat:
								  NSLocalizedString(@"The file transfer of \"%@\" with %@ has failed with the error: %@",
													@"file transfer notifications"),
								  filename, [contact name], errorMsg] :
							  [NSString stringWithFormat:
								  NSLocalizedString(@"The file transfer of \"%@\" with %@ has failed", @"file transfer notifications"),
								  filename, [contact name]] );
	
	[NSApp requestUserAttention:NSInformationalRequest];
	
	[GrowlApplicationBridge notifyWithTitle:title
								description:description
						   notificationName:LPFileTransferEventNotificationName
								   iconData:nil
								   priority:1
								   isSticky:YES
							   clickContext:[self p_clickContextForFileTransfer]];
}

- (void)notifyCompletionOfFileTransferWithFileName:(NSString *)filename withContact:(LPContact *)contact
{
	NSString *title = [NSString stringWithFormat:NSLocalizedString(@"File Transfer Completed", @"file transfer notifications")];
	NSString *description = [NSString stringWithFormat:
		NSLocalizedString(@"Transfer of the file \"%@\" with %@ has completed", @"file transfer notifications"),
		filename, [contact name]];
	
	[NSApp requestUserAttention:NSInformationalRequest];
	
	[GrowlApplicationBridge notifyWithTitle:title
								description:description
						   notificationName:LPFileTransferEventNotificationName
								   iconData:nil
								   priority:1
								   isSticky:NO
							   clickContext:[self p_clickContextForFileTransfer]];
}


#pragma mark GrowlApplicationBridge Delegate


- (NSDictionary *)registrationDictionaryForGrowl
{
	return [NSDictionary dictionaryWithObjectsAndKeys:
		
		[NSArray arrayWithObjects:
			LPContactAvailabilityChangedNotificationName,
			LPFirstChatMessageReceivedNotificationName,
			LPChatMessageReceivedNotificationName,
			LPSMSMessageReceivedNotificationName,
			LPHeadlineMessageReceivedNotificationName,
			LPOfflineMessagesReceivedNotificationName,
			LPPresenceSubscriptionReceivedNotificationName,
			LPFileTransferEventNotificationName,
			nil],
		GROWL_NOTIFICATIONS_ALL,
		
		[NSArray arrayWithObjects:
			LPContactAvailabilityChangedNotificationName,
			LPFirstChatMessageReceivedNotificationName,
			LPSMSMessageReceivedNotificationName,
			LPHeadlineMessageReceivedNotificationName,
			LPOfflineMessagesReceivedNotificationName,
			LPPresenceSubscriptionReceivedNotificationName,
			LPFileTransferEventNotificationName,
			nil],
		GROWL_NOTIFICATIONS_DEFAULT,
		
		nil];
}


- (void)growlNotificationWasClicked:(id)clickContext
{
	NSString *kind = [clickContext objectForKey:@"Kind"];
	
	if ([kind isEqualToString: LPClickContextContactKindValue]) {
		if ([m_delegate respondsToSelector:@selector(notificationsHandler:userDidClickNotificationForContactWithID:)]) {
			unsigned int contactID = [[clickContext objectForKey: LPClickContextContactIDKey] intValue];
			[m_delegate notificationsHandler:self userDidClickNotificationForContactWithID:contactID];
		}
	}
	else if ([kind isEqualToString: LPClickContextHeadlineMessageKindValue]) {
		if ([m_delegate respondsToSelector:@selector(notificationsHandler:userDidClickNotificationForHeadlineMessageWithURI:)]) {
			NSString *messageURI = [clickContext objectForKey: LPClickContextMessageURIKey];
			[m_delegate notificationsHandler:self userDidClickNotificationForHeadlineMessageWithURI:messageURI];
		}
	}
	else if ([kind isEqualToString: LPClickContextOfflineMessagesKindValue]) {
		if ([m_delegate respondsToSelector:@selector(notificationsHandlerUserDidClickNotificationForOfflineMessages:)]) {
			[m_delegate notificationsHandlerUserDidClickNotificationForOfflineMessages:self];
		}
	}
	else if ([kind isEqualToString: LPClickContextPresenceSubscriptionKindValue]) {
		if ([m_delegate respondsToSelector:@selector(notificationsHandlerUserDidClickNotificationForPresenceSubscriptions:)]) {
			[m_delegate notificationsHandlerUserDidClickNotificationForPresenceSubscriptions:self];
		}
	}
	else if ([kind isEqualToString: LPClickContextFileTransferKindValue]) {
		if ([m_delegate respondsToSelector:@selector(notificationsHandlerUserDidClickNotificationForFileTransfer:)]) {
			[m_delegate notificationsHandlerUserDidClickNotificationForFileTransfer:self];
		}
	}
}


@end
