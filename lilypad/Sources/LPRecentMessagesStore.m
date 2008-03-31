//
//  LPRecentMessagesStore.m
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jpavao@co.sapo.pt>
//
//	For more information on licensing, read the README file.
//	Para mais informa›es sobre o licenciamento, leia o ficheiro README.
//

#import "LPRecentMessagesStore.h"
#import "LPCommon.h"
#import "LPAccountsController.h"
#import "LPAccount.h"
#import "LPContact.h"
#import "LPContactEntry.h"


static LPRecentMessagesStore *s_sharedMessagesStore = nil;


static int MessageRecordComparatorFn (id record1, id record2, void *ctx)
{
	NSDate *timestamp1 = ([record1 count] > 0 ? [record1 objectForKey:@"Timestamp"] : nil);
	NSDate *timestamp2 = ([record2 count] > 0 ? [record2 objectForKey:@"Timestamp"] : nil);
	return [timestamp1 compare:timestamp2];
}


@interface LPRecentMessagesStore ()  // Private Methods
- (NSMutableDictionary *)p_destinationJIDsDictionaryForAccountJID:(NSString *)accountJID;
- (NSMutableArray *)p_messagesListForDestJID:(NSString *)destJID accountJID:(NSString *)accountJID;
- (void)p_setMessagesList:(NSMutableArray *)msgList forDestJID:(NSString *)destJID accountJID:(NSString *)accountJID;
- (NSString *)p_diskCacheFolderPathForAccountJID:(NSString *)accountJID;
- (void)p_loadStoredMessagesForJID:(NSString *)jid accountJID:(NSString *)accountJID;
- (void)p_writeToDisk:(NSTimer*)theTimer;
- (NSDictionary *)p_recordForMessage:(NSString *)message type:(NSString *)type DIVClass:(NSString *)class;
- (NSMutableArray *)p_recentMessagesListForJID:(NSString *)jid accountJID:(NSString *)accountJID;
- (void)p_storeMessageRecord:(NSDictionary *)record forJID:(NSString *)jid accountJID:(NSString *)accountJID;
- (NSArray *)p_sortedAndTrimmedRecentMessagesList:(NSArray *)messagesList;
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
		
		m_storedMessagesByAccountAndDestJIDs = [[NSMutableDictionary alloc] init];
		
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
	
	[m_storedMessagesByAccountAndDestJIDs release];
	
	[super dealloc];
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


- (NSMutableDictionary *)p_destinationJIDsDictionaryForAccountJID:(NSString *)accountJID
{
	NSMutableDictionary *accountJIDsDict = [m_storedMessagesByAccountAndDestJIDs objectForKey:accountJID];
	if (accountJIDsDict == nil) {
		accountJIDsDict = [[NSMutableDictionary alloc] init];
		[m_storedMessagesByAccountAndDestJIDs setObject:accountJIDsDict forKey:accountJID];
		[accountJIDsDict release];
	}
	return accountJIDsDict;
}

- (NSMutableArray *)p_messagesListForDestJID:(NSString *)destJID accountJID:(NSString *)accountJID
{
	NSMutableDictionary *thisAccountJIDsDict = [self p_destinationJIDsDictionaryForAccountJID:accountJID];
	return [thisAccountJIDsDict objectForKey:destJID];
}

- (void)p_setMessagesList:(NSMutableArray *)msgList forDestJID:(NSString *)destJID accountJID:(NSString *)accountJID
{
	NSMutableDictionary *thisAccountJIDsDict = [self p_destinationJIDsDictionaryForAccountJID:accountJID];
	[thisAccountJIDsDict setObject:msgList forKey:destJID];
}

- (NSString *)p_diskCacheFolderPathForAccountJID:(NSString *)accountJID
{
	NSString *cacheFolderName = @"Recent Chat Messages Cache";
	NSString *cacheFolderPath = [LPOurApplicationSupportFolderPath() stringByAppendingPathComponent:cacheFolderName];
	NSString *ourAccountCacheFolderPath = [cacheFolderPath stringByAppendingPathComponent:accountJID];
	
	// Make sure they exist
	NSFileManager *fm = [NSFileManager defaultManager];
	[fm createDirectoryAtPath:cacheFolderPath attributes:nil];
	[fm createDirectoryAtPath:ourAccountCacheFolderPath attributes:nil];
	
	return ourAccountCacheFolderPath;
}

- (void)p_loadStoredMessagesForJID:(NSString *)jid accountJID:(NSString *)accountJID
{
	NSString *cacheFolderPath = [self p_diskCacheFolderPathForAccountJID:accountJID];
	
	if ([cacheFolderPath length] > 0) {
		NSString *filename = [cacheFolderPath stringByAppendingPathComponent:[jid stringByAppendingPathExtension:@"plist"]];
		
		NSData *plistData = [NSData dataWithContentsOfFile:filename];
		id plist = nil;
		
		if (plistData) {
			NSString *errorString;
			
			plist = [NSPropertyListSerialization propertyListFromData:plistData
													 mutabilityOption:NSPropertyListMutableContainers
															   format:NULL
													 errorDescription:&errorString];
		}
		
		[self p_setMessagesList:(plist != nil ? plist : [NSMutableArray array]) forDestJID:jid accountJID:accountJID];
	}
}

- (void)p_writeToDisk:(NSTimer *)theTimer
{
	NSEnumerator *accountJIDEnum = [m_storedMessagesByAccountAndDestJIDs keyEnumerator];
	NSString *accountJID;
	
	while (accountJID = [accountJIDEnum nextObject]) {
		NSString			*cacheFolderPath = [self p_diskCacheFolderPathForAccountJID:accountJID];
		NSMutableDictionary	*destinationJIDsDict = [m_storedMessagesByAccountAndDestJIDs objectForKey:accountJID];
		
		NSEnumerator	*destJIDEnum = [destinationJIDsDict keyEnumerator];
		NSString		*destJID;
		
		while (destJID = [destJIDEnum nextObject]) {
			NSArray *messagesList = [destinationJIDsDict objectForKey:destJID];
			if ([messagesList count] > 0) {
				NSString *filename = [cacheFolderPath stringByAppendingPathComponent:[destJID stringByAppendingPathExtension:@"plist"]];
				
				[messagesList writeToFile:filename atomically:YES];
			}
		}
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

- (NSMutableArray *)p_recentMessagesListForJID:(NSString *)jid accountJID:(NSString *)accountJID
{
	NSMutableArray *messagesList = [self p_messagesListForDestJID:jid accountJID:accountJID];
	
	if (messagesList == nil) {
		[self p_loadStoredMessagesForJID:jid accountJID:accountJID];
		messagesList = [self p_messagesListForDestJID:jid accountJID:accountJID];
	}
	
	return messagesList;
}

- (void)p_storeMessageRecord:(NSDictionary *)record forJID:(NSString *)jid accountJID:(NSString *)accountJID
{
	NSMutableArray *messagesList = [self p_recentMessagesListForJID:jid accountJID:accountJID];
	
	unsigned int count = [messagesList count];
	if (count >= m_nrOfStoredMessagesPerJID) {
		unsigned int nrOfMessagesToRemove = count - m_nrOfStoredMessagesPerJID + 1;
		[messagesList removeObjectsInRange:NSMakeRange(0, nrOfMessagesToRemove)];
	}
	
	[messagesList addObject:record];
}


#pragma mark -


- (void)storeMessage:(NSString *)msg receivedFromJID:(NSString *)jid thruAccountJID:(NSString *)accountJID
{
	NSDictionary *messageRecord = [self p_recordForMessage:msg type:@"Received" DIVClass:nil];
	[self p_storeMessageRecord:messageRecord forJID:jid accountJID:accountJID];
}

- (void)storeMessage:(NSString *)msg sentToJID:(NSString *)jid thruAccountJID:(NSString *)accountJID
{
	NSDictionary *messageRecord = [self p_recordForMessage:msg type:@"Sent" DIVClass:nil];
	[self p_storeMessageRecord:messageRecord forJID:jid accountJID:accountJID];
}

- (void)storeRawHTMLBlock:(NSString *)htmlBlock withDIVClass:(NSString *)class forJID:(NSString *)jid thruAccountJID:(NSString *)accountJID
{
	NSDictionary *messageRecord = [self p_recordForMessage:htmlBlock type:@"RawHTMLBlock" DIVClass:class];
	[self p_storeMessageRecord:messageRecord forJID:jid accountJID:accountJID];
}


#pragma mark -


- (NSArray *)p_sortedAndTrimmedRecentMessagesList:(NSArray *)messagesList
{
	NSArray *sortedMessagesList = [messagesList sortedArrayUsingFunction:&MessageRecordComparatorFn context:NULL];
	
	// Return only the most recent ones
	unsigned int count = [sortedMessagesList count];
	unsigned int desiredCount = [self numberOfStoredMessagesPerJID];
	unsigned int resultingCount = MIN(count, desiredCount);
	
	return [sortedMessagesList subarrayWithRange:NSMakeRange(count - resultingCount, resultingCount)];
}

- (NSArray *)recentMessagesExchangedWithJID:(NSString *)jid
{
	NSMutableArray *messagesList = [NSMutableArray array];
	
	NSEnumerator *accountsEnumerator = [[[LPAccountsController sharedAccountsController] accounts] objectEnumerator];
	LPAccount *account;
	
	while (account = [accountsEnumerator nextObject]) {
		NSString *accountJID = [account JID];
		if ([accountJID length] > 0) {
			[messagesList addObjectsFromArray:[self p_recentMessagesListForJID:jid accountJID:accountJID]];
		}
	}
	
	return [self p_sortedAndTrimmedRecentMessagesList:messagesList];
}

- (NSArray *)recentMessagesExchangedWithContact:(LPContact *)contact
{
	NSMutableArray *messagesList = [NSMutableArray array];
	
	NSEnumerator *entryEnumerator = [[contact chatContactEntries] objectEnumerator];
	LPContactEntry *entry;
	
	while (entry = [entryEnumerator nextObject]) {
		[messagesList addObjectsFromArray:[self p_recentMessagesListForJID:[entry address] accountJID:[[entry account] JID]]];
	}
	
	return [self p_sortedAndTrimmedRecentMessagesList:messagesList];
}


#pragma mark -


- (void)applicationWillTerminate:(NSNotification *)notif
{
	// Save stuff
	[m_saveTimer fire];
}

@end
