//
//  LPMessageCenter.m
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jpavao@co.sapo.pt>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "LPMessageCenter.h"
#import "LPAccount.h"
#import "LPRoster.h"
#import "LPPresenceSubscription.h"
#import "LPContact.h"
#import "LPContactEntry.h"
#import "LPEventNotificationsHandler.h"


#define CURRENT_VERSION_NR 2


@implementation LPSapoNotificationChannel

- (void)awakeFromFetch
{
	if ([[self valueForKey:@"unreadCount"] intValue] == 0) {
		// Make sure the unread count is correct. We may be migrating from an older data store
		// that didn't have this key yet.
		
		NSPredicate *pred = [NSPredicate predicateWithFormat:@"unread == YES"];
		int realUnreadCount = [[[[self valueForKey:@"notifications"] allObjects] filteredArrayUsingPredicate:pred] count];
		
		if (realUnreadCount > 0)
			[self setValue:[NSNumber numberWithInt:realUnreadCount] forKey:@"unreadCount"];
	}
}

- (void)addToUnreadCount:(int)increment
{
	int currentCount = [[self valueForKey:@"unreadCount"] intValue];
	[self setValue:[NSNumber numberWithInt:(currentCount + increment)] forKey:@"unreadCount"];
}

@end


@implementation LPSapoNotification

+ (void)initialize
{
	if (self == [LPSapoNotification class]) {
		[self setKeys:[NSArray arrayWithObjects:@"subject", @"body", @"itemURL", nil]
				triggerChangeNotificationsForDependentKey:@"attributedStringDescription"];
	}
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

- (void)markAsRead
{
	if ([[self valueForKey:@"unread"] boolValue]) {
		[self setValue:[NSNumber numberWithBool:NO] forKey:@"unread"];
		[[self valueForKey:@"channel"] addToUnreadCount:(-1)];
	}
}

@end


#pragma mark -


@interface LPMessageCenter ()  // Private Methods
- (void)p_updateCountOfPresenceSubscriptionsRequiringAttention;
- (void)p_setCountOfPresenceSubscriptionsRequiringAttention:(int)count;

+ (NSManagedObjectModel *)p_managedObjectModelWithVersionNr:(unsigned int)version;
+ (void)p_migrateOfflineMessagesFromManagedObjectContext:(NSManagedObjectContext *)sourceContext toContext:(NSManagedObjectContext *)targetContext;
+ (void)p_migrateSapoNotificationsFromManagedObjectContext:(NSManagedObjectContext *)sourceContext toContext:(NSManagedObjectContext *)targetContext;
+ (BOOL)p_shouldMigrateFromXMLFilePath:(NSString *)xmlFilePath toSQLiteFilePath:(NSString *)sqliteFilePath;
+ (NSString *)p_migratePersistentStoreWithURL:(NSURL *)storeURL storeType:(NSString *)storeType fromVersion:(int)storeVersionNr;
- (NSPersistentStoreCoordinator *)p_persistentStoreCoordinator;

- (void)p_updateUnreadOfflineMessagesCountFromManagedObjectsContextEmittingKVONotification:(BOOL)emitNotification;
- (void)p_setUnreadOfflineMessagesCount:(int)count emitKVONotification:(BOOL)emitNotification;

- (void)p_managedObjectContextObjectsDidChange:(NSNotification *)notif;
@end


#pragma mark -


@implementation LPMessageCenter

- init
{
	if (self = [super init]) {
		m_presenceSubscriptionsByJID = [[NSMutableDictionary alloc] init];
		m_presenceSubscriptions = [[NSMutableArray alloc] init];
		
		// Mark the offline messages count as uninitialized
		m_unreadOfflineMessagesCount = -1;
	}
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[m_presenceSubscriptions removeObserver:self
					   fromObjectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [m_presenceSubscriptions count])]
								 forKeyPath:@"requiresUserIntervention"];
	
	[m_presenceSubscriptionsByJID release];
	[m_presenceSubscriptions release];
	
	[m_managedObjectModel release];
	[m_persistentStoreCoordinator release];
	[m_managedObjectContext release];
	[m_sapoNotifChannels release];
	
	[super dealloc];
}


- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"requiresUserIntervention"]) {
		[self p_updateCountOfPresenceSubscriptionsRequiringAttention];
	}
	else {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}



#pragma mark -
#pragma mark Presence Subscriptions


- (NSArray *)presenceSubscriptions
{
	return [[m_presenceSubscriptions retain] autorelease];
}

- (void)p_updateCountOfPresenceSubscriptionsRequiringAttention
{
	NSPredicate		*pred = [NSPredicate predicateWithFormat:@"requiresUserIntervention == YES"];
	NSArray			*subscriptionsRequiringAttention = [[self presenceSubscriptions] filteredArrayUsingPredicate:pred];
	
	[self p_setCountOfPresenceSubscriptionsRequiringAttention:[subscriptionsRequiringAttention count]];
}

- (int)countOfPresenceSubscriptionsRequiringAttention
{
	return m_presenceSubscriptionsRequiringAttentionCount;
}

- (void)p_setCountOfPresenceSubscriptionsRequiringAttention:(int)count
{
	if (count != m_presenceSubscriptionsRequiringAttentionCount) {
		[self willChangeValueForKey:@"countOfPresenceSubscriptionsRequiringAttention"];
		m_presenceSubscriptionsRequiringAttentionCount = count;
		[self didChangeValueForKey:@"countOfPresenceSubscriptionsRequiringAttention"];
	}
}

- (void)addReceivedPresenceSubscription:(LPPresenceSubscription *)presSub
{
	[m_presenceSubscriptionsByJID setValue:presSub forKey:[[presSub contactEntry] address]];
	
	NSIndexSet *indexes = [NSIndexSet indexSetWithIndex:[m_presenceSubscriptions count]];
	[self willChange:NSKeyValueChangeInsertion valuesAtIndexes:indexes forKey:@"presenceSubscriptions"];
	[m_presenceSubscriptions addObject:presSub];
	[self didChange:NSKeyValueChangeInsertion valuesAtIndexes:indexes forKey:@"presenceSubscriptions"];
	
	[self p_updateCountOfPresenceSubscriptionsRequiringAttention];
	[presSub addObserver:self forKeyPath:@"requiresUserIntervention" options:0 context:NULL];
	
	// Notify the user
	[[LPEventNotificationsHandler defaultHandler] notifyReceptionOfPresenceSubscription:presSub];
}


#pragma mark -
#pragma mark CoreData Stuff


+ (NSManagedObjectModel *)p_managedObjectModelWithVersionNr:(unsigned int)version
{
	NSString	*filename = [NSString stringWithFormat:@"MessageCenter_v%d", version];
	NSString	*objectModelPath = [[NSBundle mainBundle] pathForResource:filename ofType:@"mom"];
	NSURL		*objectModelURL = [NSURL fileURLWithPath:objectModelPath];
	
	return [[[NSManagedObjectModel alloc] initWithContentsOfURL:objectModelURL] autorelease];
}


+ (void)p_migrateOfflineMessagesFromManagedObjectContext:(NSManagedObjectContext *)sourceContext toContext:(NSManagedObjectContext *)targetContext
{
	NSError *error;
	
	NSFetchRequest *request = [[[NSFetchRequest alloc] init] autorelease];
	[request setEntity:[NSEntityDescription entityForName:@"LPOfflineMessage" inManagedObjectContext:sourceContext]];
	
	NSArray *oldObjs = [sourceContext executeFetchRequest:request error:&error];
	
	NSEnumerator *objEnum = [oldObjs objectEnumerator];
	id oldObj;
	while (oldObj = [objEnum nextObject]) {
		id newObj = [NSEntityDescription insertNewObjectForEntityForName:@"LPOfflineMessage" inManagedObjectContext:targetContext];
		[newObj setValuesForKeysWithDictionary:
			[oldObj dictionaryWithValuesForKeys:
				[NSArray arrayWithObjects:
					@"contactName", @"jid", @"nickname", @"plainTextBody", @"subject", @"timestamp", @"unread", @"xhtmlBody", nil]]];
	}
	
	[targetContext save:&error];
}


+ (void)p_migrateSapoNotificationsFromManagedObjectContext:(NSManagedObjectContext *)sourceContext toContext:(NSManagedObjectContext *)targetContext
{
	NSError *error;
	
	NSFetchRequest *request = [[[NSFetchRequest alloc] init] autorelease];
	[request setEntity:[NSEntityDescription entityForName:@"LPSapoNotificationChannel" inManagedObjectContext:sourceContext]];
	
	NSArray *oldChannels = [sourceContext executeFetchRequest:request error:&error];
	
	NSEnumerator *channelEnum = [oldChannels objectEnumerator];
	id oldChannel;
	while (oldChannel = [channelEnum nextObject]) {
		id newChannel = [NSEntityDescription insertNewObjectForEntityForName:@"LPSapoNotificationChannel" inManagedObjectContext:targetContext];
		int unreadCount = 0;
		
		// Migrate this channel's notifications
		NSEnumerator *notifEnum = [[oldChannel valueForKey:@"notifications"] objectEnumerator];
		id oldNotif;
		while (oldNotif = [notifEnum nextObject]) {
			id newNotif = [NSEntityDescription insertNewObjectForEntityForName:@"LPSapoNotification" inManagedObjectContext:targetContext];
			[newNotif setValuesForKeysWithDictionary:
				[oldNotif dictionaryWithValuesForKeys:
					[NSArray arrayWithObjects:
						@"body", @"date", @"flashURL", @"iconURL", @"itemURL", @"subject", @"unread", nil]]];
			[newNotif setValue:newChannel forKey:@"channel"];
			
			if ([[newNotif valueForKey:@"unread"] boolValue])
				++unreadCount;
		}
		
		[newChannel setValue:[oldChannel valueForKey:@"name"] forKey:@"name"];
		[newChannel setValue:[NSNumber numberWithInt:unreadCount] forKey:@"unreadCount"];
	}
	
	[targetContext save:&error];
}


+ (BOOL)p_shouldMigrateFromXMLFilePath:(NSString *)xmlFilePath toSQLiteFilePath:(NSString *)sqliteFilePath
{
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
	return migrateXMLFile;
}


+ (NSString *)p_migratePersistentStoreWithURL:(NSURL *)storeURL storeType:(NSString *)storeType fromVersion:(int)storeVersionNr
{
	NSString	*bundleID = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIdentifier"];
	NSString	*tempDir = [NSTemporaryDirectory() stringByAppendingPathComponent:bundleID];
	
	[[NSFileManager defaultManager] createDirectoryAtPath:tempDir attributes:nil];
	
	NSString	*tempFilePath = [tempDir stringByAppendingPathComponent:@"MessageCenterStore_migrated.sqlite"];
	NSURL		*tempURL = [NSURL fileURLWithPath:tempFilePath];
	
	// Remove any existing file with this pathname that may have been left hanging around
	NSFileManager *fm = [NSFileManager defaultManager];
	[fm removeFileAtPath:tempFilePath handler:nil];
	
	NSError *error;
	
	// Setup the persistence stacks
	NSManagedObjectModel			*originalMOM = [self p_managedObjectModelWithVersionNr:storeVersionNr];
	NSPersistentStoreCoordinator	*originalPSC = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:originalMOM];
	NSManagedObjectContext			*originalMOC = [[NSManagedObjectContext alloc] init];
	
	[originalPSC addPersistentStoreWithType:storeType configuration:nil URL:storeURL options:nil error:&error];
	[originalMOC setPersistentStoreCoordinator:originalPSC];
	
	NSManagedObjectModel			*migratedMOM = [self p_managedObjectModelWithVersionNr:CURRENT_VERSION_NR];
	NSPersistentStoreCoordinator	*migratedPSC = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:migratedMOM];
	NSManagedObjectContext			*migratedMOC = [[NSManagedObjectContext alloc] init];
	
	id store = [migratedPSC addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:tempURL options:nil error:&error];
	[migratedMOC setPersistentStoreCoordinator:migratedPSC];
	
	// Copy the objects over to the new stack
	[self p_migrateOfflineMessagesFromManagedObjectContext:originalMOC toContext:migratedMOC];
	[self p_migrateSapoNotificationsFromManagedObjectContext:originalMOC toContext:migratedMOC];
	
	// Set the version number for the new store in its metadata
	NSNumber *newStoreVersion = [NSNumber numberWithInt:CURRENT_VERSION_NR];
	NSDictionary *newMetadata = [NSDictionary dictionaryWithObject:newStoreVersion forKey:@"LPModelVersion"];
	
	[migratedPSC setMetadata:newMetadata forPersistentStore:store];
	[migratedMOC save:&error];
	
	[migratedMOC release];
	[migratedPSC release];
	[originalMOC release];
	[originalPSC release];
	
	return tempFilePath;
}


- (NSPersistentStoreCoordinator *)p_persistentStoreCoordinator
{
    if (m_persistentStoreCoordinator == nil) {
		[LPMessageCenter migrateMessageCenterStoreIfNeeded];
		
		// Add the SQLite store file to the stack
		m_persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:
			[LPMessageCenter p_managedObjectModelWithVersionNr:CURRENT_VERSION_NR]];
		
		NSString	*applicationSupportFolder = LPOurApplicationSupportFolderPath();
		NSString	*sqliteFilePath = [applicationSupportFolder stringByAppendingPathComponent:@"MessageCenterStore.sqlite"];
		NSURL		*sqliteURL = [NSURL fileURLWithPath:sqliteFilePath];
		NSError		*error;
		
		id store = [m_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
															  configuration:nil URL:sqliteURL
																	options:nil error:&error];
		if (store) {
			// Make sure the store has the version number set correctly
			NSNumber *newStoreVersion = [NSNumber numberWithInt:CURRENT_VERSION_NR];
			NSDictionary *newMetadata = [NSDictionary dictionaryWithObject:newStoreVersion forKey:@"LPModelVersion"];
			[m_persistentStoreCoordinator setMetadata:newMetadata forPersistentStore:store];
			
			// Save it right away to preserve the just-inserted version metadata
			NSManagedObjectContext *tempMOC = [[NSManagedObjectContext alloc] init];
			[tempMOC setPersistentStoreCoordinator: m_persistentStoreCoordinator];
			[tempMOC save:&error];
			[tempMOC release];
		} else {
			[[NSApplication sharedApplication] presentError:error];
		}
	}
	
	return m_persistentStoreCoordinator;
}


#pragma mark -


+ (BOOL)needsToMigrateMessageCenterStore
{
	NSString	*applicationSupportFolder = LPOurApplicationSupportFolderPath();
	NSString	*xmlFilePath = [applicationSupportFolder stringByAppendingPathComponent:@"MessageCenterStore.xml"];
	NSString	*sqliteFilePath = [applicationSupportFolder stringByAppendingPathComponent:@"MessageCenterStore.sqlite"];
	NSURL		*sqliteURL = [NSURL fileURLWithPath:sqliteFilePath];
	
	BOOL		needsToMigrate = NO;
	NSError		*error;
	
	if ([self p_shouldMigrateFromXMLFilePath:xmlFilePath toSQLiteFilePath:sqliteFilePath]) {
		needsToMigrate = YES;
	}
	else {
		NSDictionary *metadata = [NSPersistentStoreCoordinator metadataForPersistentStoreWithURL:sqliteURL error:&error];
		
		if (metadata != nil) {
			NSNumber *storeVersion = [metadata objectForKey:@"LPModelVersion"];
			int storeVersionNr = (storeVersion ? [storeVersion intValue] : 1);
			
			needsToMigrate = (storeVersionNr < CURRENT_VERSION_NR);
		}
	}
	
	return needsToMigrate;
}


+ (void)migrateMessageCenterStoreIfNeeded
{
	NSString	*applicationSupportFolder = LPOurApplicationSupportFolderPath();
	NSString	*xmlFilePath = [applicationSupportFolder stringByAppendingPathComponent:@"MessageCenterStore.xml"];
	NSString	*sqliteFilePath = [applicationSupportFolder stringByAppendingPathComponent:@"MessageCenterStore.sqlite"];
	NSURL		*sqliteURL = [NSURL fileURLWithPath:sqliteFilePath];
	
	NSString	*originalStoreType = nil;
	NSURL		*originalStoreURL = nil;
	NSError		*error;
	
	if ([self p_shouldMigrateFromXMLFilePath:xmlFilePath toSQLiteFilePath:sqliteFilePath]) {
		originalStoreType = NSXMLStoreType;
		originalStoreURL = [NSURL fileURLWithPath:xmlFilePath];
	}
	else {
		originalStoreType = NSSQLiteStoreType;
		originalStoreURL = sqliteURL;
	}
	
	NSDictionary *metadata = [NSPersistentStoreCoordinator metadataForPersistentStoreWithURL:originalStoreURL error:&error];
	
	if (metadata != nil) {
		NSNumber *storeVersion = [metadata objectForKey:@"LPModelVersion"];
		int storeVersionNr = (storeVersion ? [storeVersion intValue] : 1);
		
		if (storeVersionNr < CURRENT_VERSION_NR || originalStoreType == NSXMLStoreType) {
			NSFileManager *fm = [NSFileManager defaultManager];
			
			@try {
				NSString *migratedFilePath = [self p_migratePersistentStoreWithURL:originalStoreURL
																		 storeType:originalStoreType
																	   fromVersion:storeVersionNr];
				
				// Put the migrated file in the right place
				[fm removeFileAtPath:sqliteFilePath handler:nil];
				[fm movePath:migratedFilePath toPath:sqliteFilePath handler:nil];
			}
			@catch (id exception) {
				/*
				 * There was some problem with the migration. Put the existing store aside and create a new store
				 * so that everything can work as expected.
				 *
				 * The existing store will be renamed to something like "<original name>_bak.<original_extension>".
				 * An integer may be appended to the filename to avoid overwriting existing files.
				 */
				
				NSString *basename = [[sqliteFilePath lastPathComponent] stringByDeletingPathExtension];
				NSString *extension = [sqliteFilePath pathExtension];
				NSString *backupFilename = [NSString stringWithFormat:@"%@_bak", basename];
				NSString *backupFilepath = [[applicationSupportFolder stringByAppendingPathComponent:backupFilename]
												stringByAppendingPathExtension:extension];
				
				int alternativeFilenameIndex = 0;
				
				while ([fm fileExistsAtPath:backupFilepath]) {
					++alternativeFilenameIndex;
					
					NSString *newBackupFilename = [NSString stringWithFormat:@"%@_%d", backupFilename, alternativeFilenameIndex];
					if ([extension length] > 0) {
						backupFilepath = [[applicationSupportFolder stringByAppendingPathComponent:newBackupFilename]
												stringByAppendingPathExtension:extension];
					} else {
						backupFilepath = [applicationSupportFolder stringByAppendingPathComponent:newBackupFilename];
					}
				}
				
				[fm movePath:sqliteFilePath toPath:backupFilepath handler:nil];
			}
		}
	}
}


- (NSManagedObjectContext *)managedObjectContext
{
    if (m_managedObjectContext == nil) {
		NSPersistentStoreCoordinator *coordinator = [self p_persistentStoreCoordinator];
		if (coordinator != nil) {
			m_managedObjectContext = [[NSManagedObjectContext alloc] init];
			[m_managedObjectContext setPersistentStoreCoordinator: coordinator];
		}
		
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(p_managedObjectContextObjectsDidChange:)
													 name:NSManagedObjectContextObjectsDidChangeNotification
												   object:m_managedObjectContext];
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
	LPSapoNotification		*newSapoNotif = [NSEntityDescription insertNewObjectForEntityForName:@"LPSapoNotification"
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
	
	LPSapoNotificationChannel *channel;
	
	if ([result count] > 0) {
		channel = [result objectAtIndex:0];
	} else {
		channel = [NSEntityDescription insertNewObjectForEntityForName:@"LPSapoNotificationChannel"
												inManagedObjectContext:context];
		[channel setValue:channelName forKey:@"name"];
		[m_sapoNotifChannels addObject:channel];
	}
	
	[newSapoNotif setValue:channel forKey:@"channel"];
	[channel addToUnreadCount:1];
	
	NSError	*error;
	[context save:&error];
	
	
	// Notify the user
	[[LPEventNotificationsHandler defaultHandler] notifyReceptionOfHeadlineMessage:newSapoNotif];
}


#pragma mark -
#pragma mark Offline Messages


- (void)p_updateUnreadOfflineMessagesCountFromManagedObjectsContextEmittingKVONotification:(BOOL)emitNotification
{
	NSManagedObjectContext	*context = [self managedObjectContext];
	NSEntityDescription		*msgEntity = [NSEntityDescription entityForName:@"LPOfflineMessage" inManagedObjectContext:context];
	
	NSFetchRequest	*fetchRequest = [[NSFetchRequest alloc] init];
	NSError			*error;
	
	// No predicate, fetch them all.
	[fetchRequest setEntity:msgEntity];
	[fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"unread == YES"]];
	
	NSArray *result = [context executeFetchRequest:fetchRequest error:&error];
	[fetchRequest release];
	
	
	[self p_setUnreadOfflineMessagesCount:[result count] emitKVONotification:emitNotification];
}


- (int)unreadOfflineMessagesCount
{
	// Is the unread messages count initialized yet?
	if (m_unreadOfflineMessagesCount < 0)
		[self p_updateUnreadOfflineMessagesCountFromManagedObjectsContextEmittingKVONotification:NO];
	
	return m_unreadOfflineMessagesCount;
}

- (void)p_setUnreadOfflineMessagesCount:(int)count emitKVONotification:(BOOL)emitNotification
{
	if (count != m_unreadOfflineMessagesCount) {
		if (emitNotification)
			[self willChangeValueForKey:@"unreadOfflineMessagesCount"];
		
		m_unreadOfflineMessagesCount = count;
		
		if (emitNotification)
			[self didChangeValueForKey:@"unreadOfflineMessagesCount"];
	}
}


- (void)addReceivedOfflineMessageFromJID:(NSString *)fromJID account:(LPAccount *)account nick:(NSString *)nick timestamp:(NSString *)timestamp subject:(NSString *)subject plainTextVariant:(NSString *)plainTextVariant XHTMLVariant:(NSString *)xhtmlVariant URLs:(NSArray *)urls
{
	NSManagedObjectContext	*context = [self managedObjectContext];
	NSManagedObject			*newOfflineMessage = [NSEntityDescription insertNewObjectForEntityForName:@"LPOfflineMessage"
																			   inManagedObjectContext:context];
	
	NSString *urlsStr = [[urls valueForKey:@"absoluteString"] componentsJoinedByString:@" "];
	NSString *bodyWithURLs = ( [urlsStr length] > 0 ?
							   [plainTextVariant stringByAppendingFormat:@" | URLs: %@", urlsStr] :
							   plainTextVariant );
	
	LPContactEntry *entry = [[account roster] contactEntryForAddress:fromJID account:account];
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


#pragma mark -
#pragma mark NSManagedObjectContext Notifications

- (void)p_managedObjectContextObjectsDidChange:(NSNotification *)notif
{
	[self p_updateUnreadOfflineMessagesCountFromManagedObjectsContextEmittingKVONotification:YES];
}


@end
