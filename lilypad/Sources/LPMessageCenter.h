//
//  LPMessageCenter.h
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import <Cocoa/Cocoa.h>


@class LPAccount, LPRoster;
@class LPContactEntry, LPPresenceSubscription;


@interface LPSapoNotificationChannel : NSManagedObject
{}
- (void)addToUnreadCount:(int)increment;
@end


@interface LPSapoNotification : NSManagedObject
{}
- (NSAttributedString *)attributedStringDescription;
- (void)markAsRead;
@end


@interface LPMessageCenter : NSObject
{
	// Presence Subscriptions by JID
	//		NSString (JID) --> LPPresenceSubscription
	NSMutableDictionary		*m_presenceSubscriptionsByJID;
	NSMutableArray			*m_presenceSubscriptions;
	
	// CoreData Stuff
    NSManagedObjectModel			*m_managedObjectModel;
	NSPersistentStoreCoordinator	*m_persistentStoreCoordinator;
    NSManagedObjectContext			*m_managedObjectContext;
	
	// Sapo Notifications
	NSMutableArray					*m_sapoNotifChannels;
	
	// Offline Messages
	int								m_unreadOfflineMessagesCount;
}

- (NSArray *)presenceSubscriptions;
- (void)addReceivedPresenceSubscription:(LPPresenceSubscription *)presSub;

+ (BOOL)needsToMigrateMessageCenterStore;
+ (void)migrateMessageCenterStoreIfNeeded;

- (NSManagedObjectContext *)managedObjectContext;

- (NSArray *)sapoNotificationsChannels;
- (void)addReceivedSapoNotificationFromChannel:(NSString *)channelName subject:(NSString *)subject body:(NSString *)body itemURL:(NSString *)itemURL flashURL:(NSString *)flashURL iconURL:(NSString *)iconURL;

- (int)unreadOfflineMessagesCount;
- (void)addReceivedOfflineMessageFromJID:(NSString *)fromJID account:(LPAccount *)account nick:(NSString *)nick timestamp:(NSString *)timestamp subject:(NSString *)subject plainTextVariant:(NSString *)plainTextVariant XHTMLVariant:(NSString *)xhtmlVariant URLs:(NSArray *)urls;

@end
