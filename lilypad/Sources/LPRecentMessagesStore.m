//
//  LPRecentMessagesStore.m
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informa›es sobre o licenciamento, leia o ficheiro README.
//

#import "LPRecentMessagesStore.h"
#import "LPCommon.h"
#import "LPContact.h"


static LPRecentMessagesStore *s_sharedMessagesStore = nil;


static int MessageRecordComparatorFn (id record1, id record2, void *ctx)
{
	NSDate *timestamp1 = ([record1 count] > 0 ? [record1 objectForKey:@"Timestamp"] : nil);
	NSDate *timestamp2 = ([record2 count] > 0 ? [record2 objectForKey:@"Timestamp"] : nil);
	return [timestamp1 compare:timestamp2];
}


@interface LPRecentMessagesStore (Private)
- (NSString *)p_diskCacheFolderPath;
- (void)p_loadStoredMessagesForJID:(NSString *)jid;
- (void)p_writeToDisk:(NSTimer*)theTimer;
- (NSDictionary *)p_recordForMessage:(NSString *)message type:(NSString *)type DIVClass:(NSString *)class;
- (NSMutableArray *)p_recentMessagesListForJID:(NSString *)jid;
- (void)p_storeMessageRecord:(NSDictionary *)record forJID:(NSString *)jid;
@end


@implementation LPRecentMessagesStore

+ (LPRecentMessagesStore *)sharedMessagesStore
{
	if (s_sharedMessagesStore == nil)
		s_sharedMessagesStore = [[[self class] alloc] init];
	
	return s_sharedMessagesStore;
}

- init
{
	if (self = [super init]) {
		m_nrOfStoredMessagesPerJID = 5;
		m_saveTimer = [NSTimer scheduledTimerWithTimeInterval:30.0
													   target:self
													 selector:@selector(p_writeToDisk:)
													 userInfo:nil
													  repeats:YES];
		
		m_storedMessagesByJID = [[NSMutableDictionary alloc] init];
		
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(applicationWillTerminate:)
													 name:NSApplicationWillTerminateNotification
												   object:nil];
	}
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	// save one last time
	[m_saveTimer fire];
	[m_saveTimer invalidate];
	
	[m_storedMessagesByJID release];
	[m_ourAccountJID release];
	
	[super dealloc];
}

- (NSString *)ourAccountJID
{
	return [[m_ourAccountJID copy] autorelease];
}

- (void)setOurAccountJID:(NSString *)accountJID
{
	if (accountJID != m_ourAccountJID) {
		// Clear the history currently being kept in memory, but save it first
		if ([m_ourAccountJID length] > 0)
			[m_saveTimer fire];
		[m_storedMessagesByJID removeAllObjects];
		
		// Set it
		[m_ourAccountJID release];
		m_ourAccountJID = [accountJID copy];
	}
}

- (unsigned int)numberOfStoredMessagesPerJID
{
	return m_nrOfStoredMessagesPerJID;
}

- (void)setNumberOfStoredMessagesPerJID:(unsigned int)nr
{
	m_nrOfStoredMessagesPerJID = nr;
}


#pragma mark -


- (NSString *)p_diskCacheFolderPath
{
	NSAssert(([m_ourAccountJID length] > 0),
			 @"-[LPRecentMessagesStore setOurAccountJID:] must be invoked before we can read cached stuff from disk!");
	
	NSString *cacheFolderName = @"Recent Chat Messages Cache";
	NSString *cacheFolderPath = [LPOurApplicationSupportFolderPath() stringByAppendingPathComponent:cacheFolderName];
	NSString *ourAccountCacheFolderPath = [cacheFolderPath stringByAppendingPathComponent:[self ourAccountJID]];
	
	// Make sure they exist
	NSFileManager *fm = [NSFileManager defaultManager];
	[fm createDirectoryAtPath:cacheFolderPath attributes:nil];
	[fm createDirectoryAtPath:ourAccountCacheFolderPath attributes:nil];
	
	return ourAccountCacheFolderPath;
}

- (void)p_loadStoredMessagesForJID:(NSString *)jid
{
	NSString *cacheFolderPath = [self p_diskCacheFolderPath];
	NSString *filename = [cacheFolderPath stringByAppendingPathComponent:
		[jid stringByAppendingPathExtension:@"plist"]];
	
	NSData *plistData = [NSData dataWithContentsOfFile:filename];
	id plist = nil;
	
	if (plistData) {
		NSString *errorString;
		
		plist = [NSPropertyListSerialization propertyListFromData:plistData
												 mutabilityOption:NSPropertyListMutableContainers
														   format:NULL
												 errorDescription:&errorString];
	}
	
	[m_storedMessagesByJID setObject:(plist != nil ? plist : [NSMutableArray array])
							  forKey:jid];
}

- (void)p_writeToDisk:(NSTimer *)theTimer
{
	NSString *cacheFolderPath = [self p_diskCacheFolderPath];
	
	NSEnumerator *keysEnum = [m_storedMessagesByJID keyEnumerator];
	NSString *key;
	
	while (key = [keysEnum nextObject]) {
		NSString *filename = [cacheFolderPath stringByAppendingPathComponent:
			[key stringByAppendingPathExtension:@"plist"]];
		
		[[m_storedMessagesByJID objectForKey:key] writeToFile:filename atomically:YES];
	}
}

- (NSDictionary *)p_recordForMessage:(NSString *)message type:(NSString *)type DIVClass:(NSString *)class
{
	return [NSDictionary dictionaryWithObjectsAndKeys:
		[NSDate date], @"Timestamp",
		message, @"MessageText",
		type, @"Kind",
		class, @"DIVClass", // Only relevant if @"Kind" == @"RawHTMLBlock". If class == nil, then the declaration of the contents
							// of the dictionary end here and it won't include neither the @"DIVClass" nor anything that is added
							// after this line.
		nil];
}

- (NSMutableArray *)p_recentMessagesListForJID:(NSString *)jid
{
	NSMutableArray *messagesList = [m_storedMessagesByJID objectForKey:jid];
	
	if (messagesList == nil) {
		[self p_loadStoredMessagesForJID:jid];
		messagesList = [m_storedMessagesByJID objectForKey:jid];
	}
	
	return messagesList;
}

- (void)p_storeMessageRecord:(NSDictionary *)record forJID:(NSString *)jid
{
	NSMutableArray *messagesList = [self p_recentMessagesListForJID:jid];
	
	unsigned int count = [messagesList count];
	if (count >= m_nrOfStoredMessagesPerJID) {
		unsigned int nrOfMessagesToRemove = count - m_nrOfStoredMessagesPerJID + 1;
		[messagesList removeObjectsInRange:NSMakeRange(0, nrOfMessagesToRemove)];
	}
	
	[messagesList addObject:record];
}


#pragma mark -


- (void)storeMessage:(NSString *)msg receivedFromJID:(NSString *)jid
{
	NSDictionary *messageRecord = [self p_recordForMessage:msg type:@"Received" DIVClass:nil];
	[self p_storeMessageRecord:messageRecord forJID:jid];
}

- (void)storeMessage:(NSString *)msg sentToJID:(NSString *)jid
{
	NSDictionary *messageRecord = [self p_recordForMessage:msg type:@"Sent" DIVClass:nil];
	[self p_storeMessageRecord:messageRecord forJID:jid];
}

- (void)storeRawHTMLBlock:(NSString *)htmlBlock withDIVClass:(NSString *)class forJID:(NSString *)jid
{
	NSDictionary *messageRecord = [self p_recordForMessage:htmlBlock type:@"RawHTMLBlock" DIVClass:class];
	[self p_storeMessageRecord:messageRecord forJID:jid];
}


- (NSArray *)recentMessagesExchangedWithJID:(NSString *)jid
{
	return [self p_recentMessagesListForJID:jid];
}

- (NSArray *)recentMessagesExchangedWithContact:(LPContact *)contact
{
	NSMutableArray *messagesList = [NSMutableArray array];
	
	NSEnumerator *entryEnumerator = [[contact chatContactEntries] objectEnumerator];
	LPContactEntry *entry;
	
	while (entry = [entryEnumerator nextObject]) {
		[messagesList addObjectsFromArray:[self p_recentMessagesListForJID:[entry address]]];
	}
	
	[messagesList sortUsingFunction:&MessageRecordComparatorFn context:NULL];
	
	// Return only the most recent ones
	unsigned int count = [messagesList count];
	unsigned int desiredCount = [self numberOfStoredMessagesPerJID];
	unsigned int resultingCount = MIN(count, desiredCount);
	
	return [messagesList subarrayWithRange:NSMakeRange(count - resultingCount, resultingCount)];
}


#pragma mark -


- (void)applicationWillTerminate:(NSNotification *)notif
{
	// Save stuff
	[m_saveTimer fire];
}

@end
