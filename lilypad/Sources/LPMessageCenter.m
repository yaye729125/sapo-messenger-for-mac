//
//  LPMessageCenter.m
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informa›es sobre o licenciamento, leia o ficheiro README.
//

#import "LPMessageCenter.h"
#import "LPAccount.h"
#import "LPRoster.h"
#import "LPPresenceSubscription.h"
#import "LPContact.h"
#import "LPContactEntry.h"
#import "LPEventNotificationsHandler.h"


@implementation LPSapoNotification

+ (void)initialize
{
	[self setKeys:[NSArray arrayWithObjects:@"subject", @"body", @"itemURL", nil]
		  triggerChangeNotificationsForDependentKey:@"attributedStringDescription"];
}

- (NSAttributedString *)attributedStringDescription
{
	NSMutableAttributedString *resultingStr = [[NSMutableAttributedString alloc] init];
	
	NSFont *boldFont = [NSFont boldSystemFontOfSize:10];
	NSFont *plainFont = [NSFont systemFontOfSize:10];
	
	// Subject
	[resultingStr appendAttributedString:
		[[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@\n\n", [self valueForKey:@"subject"]]
										 attributes:[NSDictionary dictionaryWithObject:boldFont forKey:NSFontAttributeName]] autorelease]];
	
	// Body
	[resultingStr appendAttributedString:
		[[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@\n\n", [self valueForKey:@"body"]]
										 attributes:[NSDictionary dictionaryWithObject:plainFont forKey:NSFontAttributeName]] autorelease]];
	
	// URL
	[resultingStr appendAttributedString:
		[[[NSAttributedString alloc] initWithString:[self valueForKey:@"itemURL"]
										 attributes:[NSDictionary dictionaryWithObjectsAndKeys:
											 plainFont, NSFontAttributeName,
											 [self valueForKey:@"itemURL"], NSLinkAttributeName,
											 [NSCursor pointingHandCursor], NSCursorAttributeName,
											 nil]] autorelease]];
	
	return [resultingStr autorelease];
}

@end


@implementation LPMessageCenter

- initWithAccount:(LPAccount *)account
{
	if (self = [super init]) {
		m_account = [account retain];
		
		m_presenceSubscriptionsByJID = [[NSMutableDictionary alloc] init];
		m_presenceSubscriptions = [[NSMutableArray alloc] init];
	}
	return self;
}

- (void)dealloc
{
	[m_account release];
	
	[m_presenceSubscriptionsByJID release];
	[m_presenceSubscriptions release];
	
	[m_managedObjectModel release];
	[m_persistentStoreCoordinator release];
	[m_managedObjectContext release];
	[m_sapoNotifChannels release];
	
	[super dealloc];
}

- (LPAccount *)account
{
	return [[m_account retain] autorelease];
}


#pragma mark -
#pragma mark Presence Subscriptions


- (NSArray *)presenceSubscriptions
{
	return [[m_presenceSubscriptions retain] autorelease];
}

- (void)addReceivedPresenceSubscription:(LPPresenceSubscription *)presSub
{
	[m_presenceSubscriptionsByJID setValue:presSub forKey:[[presSub contactEntry] address]];
	
	NSIndexSet *indexes = [NSIndexSet indexSetWithIndex:[m_presenceSubscriptions count]];
	[self willChange:NSKeyValueChangeInsertion valuesAtIndexes:indexes forKey:@"presenceSubscriptions"];
	[m_presenceSubscriptions addObject:presSub];
	[self didChange:NSKeyValueChangeInsertion valuesAtIndexes:indexes forKey:@"presenceSubscriptions"];
	
	// Notify the user
	[[LPEventNotificationsHandler defaultHandler] notifyReceptionOfPresenceSubscription:presSub];
}


#pragma mark -
#pragma mark CoreData Stuff


- (NSManagedObjectModel *)p_managedObjectModel
{
    if (m_managedObjectModel == nil) {
		NSString	*objectModelPath = [[NSBundle mainBundle] pathForResource:@"MessageCenter" ofType:@"mom"];
		NSURL		*objectModelURL = [NSURL fileURLWithPath:objectModelPath];
		
		m_managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:objectModelURL];
	}
		
	return m_managedObjectModel;
}


- (NSPersistentStoreCoordinator *)p_persistentStoreCoordinator
{
    if (m_persistentStoreCoordinator == nil) {
		m_persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self p_managedObjectModel]];
		
		NSString	*applicationSupportFolder = LPOurApplicationSupportFolderPath();
		NSString	*xmlFilePath = [applicationSupportFolder stringByAppendingPathComponent:@"MessageCenterStore.xml"];
		NSString	*sqliteFilePath = [applicationSupportFolder stringByAppendingPathComponent:@"MessageCenterStore.sqlite"];
		
		NSURL		*xmlURL = [NSURL fileURLWithPath:xmlFilePath];
		NSURL		*sqliteURL = [NSURL fileURLWithPath:sqliteFilePath];
		NSError		*error;
		id			store = nil;
		
		NSFileManager *fm = [NSFileManager defaultManager];
		BOOL migrateXMLFile = NO;
		
		if ([fm fileExistsAtPath:xmlFilePath]) {
			if ([fm fileExistsAtPath:sqliteFilePath]) {
				NSDate *xmlModifDate = [[fm fileAttributesAtPath:xmlFilePath traverseLink:YES] objectForKey:NSFileModificationDate];
				NSDate *sqliteModifDate = [[fm fileAttributesAtPath:sqliteFilePath traverseLink:YES] objectForKey:NSFileModificationDate];
				
				// Migrate only if the XML file is more recent than the SQLite database
				migrateXMLFile = ([xmlModifDate compare:sqliteModifDate] == NSOrderedDescending);
			} else {
				migrateXMLFile = YES;
			}
		}
		
		if (migrateXMLFile) {
			// Migrate the XML file to the SQLite format
			store = [m_persistentStoreCoordinator addPersistentStoreWithType:NSXMLStoreType
															   configuration:nil URL:xmlURL options:nil error:&error];
			if (store) {
				// Remove any previously existing SQLite store. If we don't remove it first, then the objects migrated from
				// the XML file store will be appended to the existing objects instead of replacing them.
				[fm removeFileAtPath:sqliteFilePath handler:nil];
				store = [m_persistentStoreCoordinator migratePersistentStore:store toURL:sqliteURL
																	 options:nil withType:NSSQLiteStoreType error:&error];
			}
		}
		else {
			// Simply add the already existing SQLite store file
			store = [m_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
															   configuration:nil URL:sqliteURL options:nil error:&error];
		}
		
		if (!store) {
			[[NSApplication sharedApplication] presentError:error];
		}
	}
	
	return m_persistentStoreCoordinator;
}


- (NSManagedObjectContext *)managedObjectContext
{
    if (m_managedObjectContext == nil) {
		NSPersistentStoreCoordinator *coordinator = [self p_persistentStoreCoordinator];
		if (coordinator != nil) {
			m_managedObjectContext = [[NSManagedObjectContext alloc] init];
			[m_managedObjectContext setPersistentStoreCoordinator: coordinator];
		}
	}
	
	return m_managedObjectContext;
}


#pragma mark -
#pragma mark Sapo Notifications


- (NSArray *)sapoNotificationsChannels
{
	if (m_sapoNotifChannels == nil) {
		// Fetch the existing channels
		NSManagedObjectContext	*context = [self managedObjectContext];
		NSEntityDescription		*channelEntity = [NSEntityDescription entityForName:@"LPSapoNotificationChannel" inManagedObjectContext:context];
		
		NSFetchRequest	*fetchRequest = [[NSFetchRequest alloc] init];
		NSError			*error;
		
		// No predicate, fetch them all.
		[fetchRequest setEntity:channelEntity];
		
		NSArray *result = [context executeFetchRequest:fetchRequest error:&error];
		[fetchRequest release];
		
		m_sapoNotifChannels = [result mutableCopy];
	}
	return m_sapoNotifChannels;
}


- (void)addReceivedSapoNotificationFromChannel:(NSString *)channelName subject:(NSString *)subject body:(NSString *)body itemURL:(NSString *)itemURL flashURL:(NSString *)flashURL iconURL:(NSString *)iconURL
{
	NSManagedObjectContext	*context = [self managedObjectContext];
	NSManagedObject			*newSapoNotif = [NSEntityDescription insertNewObjectForEntityForName:@"LPSapoNotification"
																		  inManagedObjectContext:context];
	
	[newSapoNotif setValue:[NSDate date] forKey:@"date"];
	[newSapoNotif setValue:subject forKey:@"subject"];
	[newSapoNotif setValue:body forKey:@"body"];
	[newSapoNotif setValue:itemURL forKey:@"itemURL"];
	[newSapoNotif setValue:flashURL forKey:@"flashURL"];
	[newSapoNotif setValue:iconURL forKey:@"iconURL"];
	
	// See if there's already a channel object
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"name == %@", channelName];
	NSArray		*result = [[self sapoNotificationsChannels] filteredArrayUsingPredicate:predicate];
	
	NSManagedObject *channel;
	
	if ([result count] > 0) {
		channel = [result objectAtIndex:0];
	} else {
		channel = [NSEntityDescription insertNewObjectForEntityForName:@"LPSapoNotificationChannel"
												inManagedObjectContext:context];
		[channel setValue:channelName forKey:@"name"];
		[m_sapoNotifChannels addObject:channel];
	}
	
	[newSapoNotif setValue:channel forKey:@"channel"];
	
	NSError	*error;
	[context save:&error];
	
	
	// Notify the user
	[[LPEventNotificationsHandler defaultHandler] notifyReceptionOfHeadlineMessage:newSapoNotif];
}


#pragma mark -
#pragma mark Offline Messages


- (void)addReceivedOfflineMessageFromJID:(NSString *)fromJID nick:(NSString *)nick timestamp:(NSString *)timestamp subject:(NSString *)subject plainTextVariant:(NSString *)plainTextVariant XHTMLVariant:(NSString *)xhtmlVariant URLs:(NSArray *)urls
{
	NSManagedObjectContext	*context = [self managedObjectContext];
	NSManagedObject			*newOfflineMessage = [NSEntityDescription insertNewObjectForEntityForName:@"LPOfflineMessage"
																			   inManagedObjectContext:context];
	
	NSString *urlsStr = [[urls valueForKey:@"absoluteString"] componentsJoinedByString:@" "];
	NSString *bodyWithURLs = ( [urlsStr length] > 0 ?
							   [plainTextVariant stringByAppendingFormat:@" | URLs: %@", urlsStr] :
							   plainTextVariant );
	
	LPContactEntry *entry = [[[self account] roster] contactEntryForAddress:fromJID];
	LPContact *contact = [entry contact];
	
	NSCalendarDate *timestampDate = [NSDate dateWithNaturalLanguageString:timestamp];
	
	[newOfflineMessage setValue:[contact name] forKey:@"contactName"];
	[newOfflineMessage setValue:fromJID forKey:@"jid"];
	[newOfflineMessage setValue:nick forKey:@"nickname"];
	[newOfflineMessage setValue:timestampDate forKey:@"timestamp"];
	[newOfflineMessage setValue:subject forKey:@"subject"];
	[newOfflineMessage setValue:bodyWithURLs forKey:@"plainTextBody"];
	[newOfflineMessage setValue:xhtmlVariant forKey:@"xhtmlBody"];
	
	NSError	*error;
	[context save:&error];
	
	
	// Notify the user
	[[LPEventNotificationsHandler defaultHandler] notifyReceptionOfOfflineMessage:newOfflineMessage];
}


@end
