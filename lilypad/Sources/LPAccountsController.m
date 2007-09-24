//
//  LPAccountsController.m
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "LPAccountsController.h"
#import "LPAccount.h"
#import "LPKeychainManager.h"


static NSString *LPAllAccountsDefaultsKey = @"Accounts";
static NSString *LPSortedAccountUUIDsDefaultsKey = @"Accounts Sort Order";


@interface LPAccount (Private)
- (void)p_updateLocationFromChangedComputerName;
@end


static NSString *
LPAccountsControllerNewUUIDString()
{
	CFUUIDRef	uuid = CFUUIDCreate(NULL);
	NSString	*uuidStr = (NSString *)CFUUIDCreateString(NULL, uuid);
	
	if (uuid != NULL) CFRelease(uuid);
	
	return [uuidStr autorelease];
}


static void
LPAccountsControllerSCDynamicStoreCallBack (SCDynamicStoreRef store, CFArrayRef changedKeys, void *info)
{
	LPAccountsController *accountsCtrl = (LPAccountsController *)info;
	[[accountsCtrl accounts] makeObjectsPerformSelector:@selector(p_updateLocationFromChangedComputerName)];
}


@interface LPAccountsController (Private)
+ (NSArray *)p_persistentAccountKeys;
- (void)p_setNeedsToSaveAccounts:(BOOL)shouldSave;
@end


@implementation LPAccountsController


+ (LPAccountsController *)sharedAccountsController
{
	static LPAccountsController *sharedController = nil;

	if (sharedController == nil) {
		sharedController = [[LPAccountsController alloc] init];
	}
	return sharedController;
}


- init
{
	if (self = [super init]) {
		m_accountsByUUID = [[NSMutableDictionary alloc] init];
		m_accounts = [[NSMutableArray alloc] init];
		m_isLoadingFromDefaults = NO;
		
		// System Configuration change notifications
		SCDynamicStoreContext ctx = { 0, (void *)self, NULL, NULL, NULL };
		
		m_dynamicStore = SCDynamicStoreCreate(NULL,
											  (CFStringRef)[[NSBundle mainBundle] bundleIdentifier],
											  &LPAccountsControllerSCDynamicStoreCallBack,
											  &ctx);
		
		CFStringRef computerNameKey = SCDynamicStoreKeyCreateComputerName(NULL);
		if (computerNameKey) {
			
			SCDynamicStoreSetNotificationKeys(m_dynamicStore, (CFArrayRef)[NSArray arrayWithObject:(id)computerNameKey], NULL);
			CFRelease(computerNameKey);
			
			m_dynamicStoreNotificationsRunLoopSource = SCDynamicStoreCreateRunLoopSource(NULL, m_dynamicStore, 0);
			if (m_dynamicStoreNotificationsRunLoopSource)
				CFRunLoopAddSource(CFRunLoopGetCurrent(), m_dynamicStoreNotificationsRunLoopSource, kCFRunLoopCommonModes);
		}
		
		[self loadAccountsFromDefaults];
		
		[LFPlatformBridge registerNotificationsObserver:self];
	}
	return self;
}


- (void)dealloc
{
	[LFPlatformBridge unregisterNotificationsObserver:self];
	
	[self saveAccountsToDefaults];
	[[NSUserDefaults standardUserDefaults] synchronize];
	
	[m_accounts release];
	[m_accountsByUUID release];
	
	if (m_dynamicStoreNotificationsRunLoopSource) {
		CFRunLoopSourceInvalidate(m_dynamicStoreNotificationsRunLoopSource);
		CFRelease(m_dynamicStoreNotificationsRunLoopSource);
	}
	if (m_dynamicStore) {
		CFRelease(m_dynamicStore);
	}
	[super dealloc];
}


- (void)loadAccountsFromDefaults
{
	m_isLoadingFromDefaults = YES;
	
	NSDictionary	*accountsFromPrefs = [[NSUserDefaults standardUserDefaults] dictionaryForKey:LPAllAccountsDefaultsKey];
	NSArray			*sortedAccountUUIDs = [[NSUserDefaults standardUserDefaults] arrayForKey:LPSortedAccountUUIDsDefaultsKey];
	
	NSEnumerator	*accountUUIDEnumerator = (sortedAccountUUIDs != nil ?
											  [sortedAccountUUIDs objectEnumerator] :
											  [accountsFromPrefs keyEnumerator]);
	NSString		*accountUUID;
	
	while (accountUUID = [accountUUIDEnumerator nextObject]) {
		LPAccount *account = [m_accountsByUUID objectForKey:accountUUID];
		
		if (account == nil) {
			account = [[LPAccount alloc] initWithUUID:accountUUID];
			[self addAccount:account];
			[account release];
		}
		
		// Load the persistent account keys
		NSDictionary *accountDict = [accountsFromPrefs objectForKey:accountUUID];
		NSEnumerator *keyEnumerator = [accountDict keyEnumerator];
		NSString *key;
		
		while (key = [keyEnumerator nextObject]) {
			@try {
				[account setValue:[accountDict objectForKey:key] forKey:key];
			}
			@catch (NSException *exception) {
				if ([[exception name] isEqualToString:NSUndefinedKeyException]) {
					// Do nothing. It's probably a key that was saved by a previous version of leapfrog but that is unknown to this version.
				}
				else {
					@throw exception;
				}
			}
		}
		
		// Load the passwords
		[account setValue:[LPKeychainManager passwordForAccount:[account JID]]
				   forKey:@"password"];
		NSString *username = [account lastRegisteredMSNEmail];
		[account setValue:[LPKeychainManager passwordForAccount:[NSString stringWithFormat:@"MSN: %@", (username ? username : @"")]]
				   forKey:@"lastRegisteredMSNPassword"];
	}

	m_isLoadingFromDefaults = NO;
}


- (void)saveAccountsToDefaults
{
	NSMutableDictionary	*accountsPropsToSave = [NSMutableDictionary dictionary];
	NSArray				*keysToBeSaved = [LPAccountsController p_persistentAccountKeys];
	
	NSEnumerator	*accountEnumerator = [m_accounts objectEnumerator];
	LPAccount		*account;
	
	while (account = [accountEnumerator nextObject]) {
		
		// Get the values for the persistent keys. We don't use -dictionaryWithValuesForKeys: because the NSNulls returned for nil
		// values aren't valid plist objects and can't be saved to the defaults.
		NSMutableDictionary *currentValuesAndKeys = [NSMutableDictionary dictionary];
		NSEnumerator *keyEnumerator = [keysToBeSaved objectEnumerator];
		NSString *key;
		
		while (key = [keyEnumerator nextObject]) {
			id value = [account valueForKey:key];
			if (value != nil && value != [NSNull null]) {
				[currentValuesAndKeys setValue:value forKey:key];
			}
		}
		
		// Save the persistent account keys
		[accountsPropsToSave setObject:currentValuesAndKeys forKey:[account UUID]];
		
		// Save the passwords
		if ([[account JID] length] > 0 && [[account password] length] > 0) {
			[LPKeychainManager savePassword:[account password] forAccount:[account JID]];
		}
		
		NSString *username = [account lastRegisteredMSNEmail];
		if ([username length] > 0 && [[account lastRegisteredMSNPassword] length] > 0) {
			[LPKeychainManager savePassword:[account lastRegisteredMSNPassword]
								 forAccount:[NSString stringWithFormat:@"MSN: %@", (username ? username : @"")]];
		}
	}
	
	[[NSUserDefaults standardUserDefaults] setObject:accountsPropsToSave forKey:LPAllAccountsDefaultsKey];
	[[NSUserDefaults standardUserDefaults] setObject:[m_accounts valueForKey:@"UUID"] forKey:LPSortedAccountUUIDsDefaultsKey];
}


- (LPAccount *)defaultAccount
{
	if ([m_accounts count] == 0)
		[self addNewAccount];
	
	return [m_accounts objectAtIndex:0];
}


- (NSArray *)accounts
{
	return [[m_accounts retain] autorelease];
}


- (LPAccount *)addNewAccount
{
	LPAccount *newAccount = [[LPAccount alloc] initWithUUID: LPAccountsControllerNewUUIDString() ];
	[self addAccount:newAccount];
	return [newAccount autorelease];
}


- (void)addAccount:(LPAccount *)account
{
	NSIndexSet *changedIndexes = [NSIndexSet indexSetWithIndex:[m_accounts count]];
	
	[self willChange:NSKeyValueChangeInsertion valuesAtIndexes:changedIndexes forKey:@"accounts"];
	[m_accounts addObject:account];
	[self didChange:NSKeyValueChangeInsertion valuesAtIndexes:changedIndexes forKey:@"accounts"];
	
	[m_accountsByUUID setObject:account forKey:[account UUID]];
	
	// Observe keys that should trigger a save to the defaults
	NSEnumerator *interestingKeyEnumerator = [[LPAccountsController p_persistentAccountKeys] objectEnumerator];
	NSString *someKey;
	while (someKey = [interestingKeyEnumerator nextObject])
		[account addObserver:self forKeyPath:someKey options:0 context:NULL];
	
	// The password is a special case: it is saved to the keychain instead of going to the defaults DB along with the other properties
	[account addObserver:self forKeyPath:@"password" options:0 context:NULL];
	[account addObserver:self forKeyPath:@"lastRegisteredMSNPassword" options:0 context:NULL];
	
	[self p_setNeedsToSaveAccounts:YES];
}


- (void)removeAccount:(LPAccount *)account
{
#warning ACCOUNTS POOL: Disconnect the account first if need be.
	
	[account removeObserver:self forKeyPath:@"lastRegisteredMSNPassword"];
	[account removeObserver:self forKeyPath:@"password"];
	
	// Remove as observer of keys that should trigger a save to the defaults
	NSEnumerator *interestingKeyEnumerator = [[LPAccountsController p_persistentAccountKeys] objectEnumerator];
	NSString *someKey;
	while (someKey = [interestingKeyEnumerator nextObject])
		[account removeObserver:self forKeyPath:someKey];
	
	[m_accountsByUUID removeObjectForKey:[account UUID]];
	
	NSIndexSet *changedIndexes = [NSIndexSet indexSetWithIndex:[m_accounts indexOfObject:account]];
	
	[self willChange:NSKeyValueChangeRemoval valuesAtIndexes:changedIndexes forKey:@"accounts"];
	[m_accounts removeObject:account];
	[self didChange:NSKeyValueChangeRemoval valuesAtIndexes:changedIndexes forKey:@"accounts"];
	
	[self p_setNeedsToSaveAccounts:YES];
}


- (LPAccount *)accountForUUID:(NSString *)theUUID
{
	return [m_accountsByUUID objectForKey:theUUID];
}


- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	[self p_setNeedsToSaveAccounts:YES];
}


#pragma mark -
#pragma mark Private


+ (NSArray *)p_persistentAccountKeys
{
	return [NSArray arrayWithObjects:
		@"description", @"name", @"JID", @"location",
		@"customServerHost", @"usesCustomServerHost",
		@"usesSSL", @"locationUsesComputerName", @"shouldAutoLogin",
		@"lastRegisteredMSNEmail", nil];
}


- (void)p_setNeedsToSaveAccounts:(BOOL)shouldSave
{
	if (shouldSave && m_isLoadingFromDefaults == NO) {
		[self saveAccountsToDefaults];
	}
}


#pragma mark -
#pragma mark Actions


- (IBAction)connectAllAutologinAccounts:(id)sender
{
	// Login to all the accounts that are marked with auto-login == TRUE
	NSEnumerator	*accountEnumerator = [m_accounts objectEnumerator];
	LPAccount		*account;
	while (account = [accountEnumerator nextObject]) {
		if ([account shouldAutoLogin]) {
			[account setTargetStatus:LPStatusAvailable];
		}
	}
}


- (IBAction)disconnectAllAccounts:(id)sender
{
	NSEnumerator	*accountEnumerator = [m_accounts objectEnumerator];
	LPAccount		*account;
	while (account = [accountEnumerator nextObject]) {
		[account setTargetStatus:LPStatusOffline];
	}
}


#pragma mark -
#pragma mark Bridge Notifications


- (void)leapfrogBridge_accountConnectedToServerHost:(NSString *)accountUUID :(NSString *)serverHost
{
	[[self accountForUUID:accountUUID] handleAccountConnectedToServerHost:serverHost];
}


- (void)leapfrogBridge_connectionError:(NSString *)accountUUID :(NSString *)errorName :(int)errorKind :(int)errorCode
{
	[[self accountForUUID:accountUUID] handleConnectionErrorWithName:errorName kind:errorKind code:errorCode];
}


- (void)leapfrogBridge_statusUpdated:(NSString *)accountUUID :(NSString *)status :(NSString *)statusMessage
{
	[[self accountForUUID:accountUUID] handleStatusUpdated:status message:statusMessage];
}


- (void)leapfrogBridge_savedStatusReceived:(NSString *)accountUUID :(NSString *)status :(NSString *)statusMessage
{
	[[self accountForUUID:accountUUID] handleSavedStatusReceived:status message:statusMessage];
}


- (void)leapfrogBridge_selfAvatarChanged:(NSString *)accountUUID :(NSString *)type :(NSData *)avatarData
{
	[[self accountForUUID:accountUUID] handleSelfAvatarChangedWithType:type data:avatarData];
}


- (oneway void)leapfrogBridge_accountXmlIO:(NSString *)accountUUID :(BOOL)isInbound :(NSString *)xml
{
	[[self accountForUUID:accountUUID] handleAccountXmlIO:xml isInbound:isInbound];
}




- (void)leapfrogBridge_offlineMessageReceived:(NSString *)accountUUID :(NSString *)timestamp :(NSString *)jid :(NSString *)nick :(NSString *)subject :(NSString *)plainTextMessage :(NSString *)XHTMLMessage :(NSArray *)URLs
{
	[[self accountForUUID:accountUUID] handleReceivedOfflineMessageAt:(NSString *)timestamp
															  fromJID:(NSString *)jid nickname:(NSString *)nick
															  subject:(NSString *)subject
													 plainTextMessage:(NSString *)plainTextMessage XHTMLMessaage:(NSString *)XHTMLMessage
																 URLs:(NSArray *)URLs];
}


- (void)leapfrogBridge_headlineNotificationMessageReceived:(NSString *)accountUUID :(NSString *)channel :(NSString *)item_url :(NSString *)flash_url :(NSString *)icon_url :(NSString *)nick :(NSString *)subject :(NSString *)plainTextMessage :(NSString *)XHTMLMessage
{
	[[self accountForUUID:accountUUID] handleReceivedHeadlineNotificationMessageFromChannel:channel
																					itemURL:item_url flashURL:flash_url iconURL:icon_url
																				   nickname:nick subject:subject
																		   plainTextMessage:plainTextMessage
																			   XHTMLMessage:XHTMLMessage];
}


- (void)leapfrogBridge_smsCreditUpdated:(NSString *)accountUUID :(int)credit :(int)free_msgs :(int)total_sent_this_month
{
	[[self accountForUUID:accountUUID] handleSMSCreditUpdated:credit freeMessages:free_msgs totalSent:total_sent_this_month];
}


- (void)leapfrogBridge_smsSent:(NSString *)accountUUID
							  :(int)result :(int)nr_used_msgs :(int)nr_used_chars
							  :(NSString *)destination_phone_nr :(NSString *)body
							  :(int)credit :(int)free_msgs :(int)total_sent_this_month
{
	[[self accountForUUID:accountUUID] handleSMSSentWithResult:result nrUsedMessages:nr_used_msgs nrUsedChars:nr_used_chars
											  destinationPhoneNr:destination_phone_nr body:body
														  credit:credit freeMessages:free_msgs totalSent:total_sent_this_month];
}


- (void)leapfrogBridge_smsReceived:(NSString *)accountUUID
								  :(NSString *)date_received
								  :(NSString *)source_phone_nr :(NSString *)body
								  :(int)credit :(int)free_msgs :(int)total_sent_this_month
{
	[[self accountForUUID:accountUUID] handleSMSReceivedAt:date_received fromPhoneNr:source_phone_nr body:body
													  credit:credit freeMessages:free_msgs totalSent:total_sent_this_month];
}


- (void)leapfrogBridge_serverItemsUpdated:(NSArray *)serverItems
{
#warning SERVER ITEMS INFO
//	[m_serverItemsInfo handleServerItemsUpdated:serverItems];
}


- (void)leapfrogBridge_serverItemInfoUpdated:(NSString *)item :(NSString *)name :(NSArray *)features
{
#warning SERVER ITEMS INFO
//	[m_serverItemsInfo handleInfoUpdatedForServerItem:item withName:name features:features];
}


- (void)leapfrogBridge_sapoAgentsUpdated:(NSDictionary *)sapoAgentsDescription
{
#warning SAPO AGENTS
//	[m_sapoAgents handleSapoAgentsUpdated:sapoAgentsDescription];
}


- (void)leapfrogBridge_chatRoomsListReceived:(NSString *)host :(NSArray *)roomsList
{
	// DEBUG
	//NSLog(@"MUC ITEMS UPDATED:\nHost: %@\nRooms: %@\n", host, roomsList);
	
#warning CHAT ROOMS LIST
//	if ([m_delegate respondsToSelector:@selector(account:didReceiveChatRoomsList:forHost:)]) {
//		[m_delegate account:self didReceiveChatRoomsList:roomsList forHost:host];
//	}
}


- (void)leapfrogBridge_chatRoomInfoReceived:(NSString *)roomJID :(NSDictionary *)infoDict
{
	// DEBUG
	//NSLog(@"MUC ITEM INFO UPDATED:\nRoom JID: %@\nInfo: %@\n", roomJID, infoDict);
	
#warning CHAT ROOMS INFO
//	if ([m_delegate respondsToSelector:@selector(account:didReceiveInfo:forChatRoomWithJID:)]) {
//		[m_delegate account:self didReceiveInfo:infoDict forChatRoomWithJID:roomJID];
//	}
}


- (void)leapfrogBridge_liveUpdateURLReceived:(NSString *)accountUUID :(NSString *)liveUpdateURLStr
{
	[[self accountForUUID:accountUUID] handleReceivedLiveUpdateURLString:liveUpdateURLStr];
}


- (void)leapfrogBridge_sapoChatOrderReceived:(NSString *)accountUUID :(NSDictionary *)orderDict
{
	[[self accountForUUID:accountUUID] handleReceivedSapoChatOrderDictionary:orderDict];
}


- (void)leapfrogBridge_transportRegistrationStatusUpdated:(NSString *)accountUUID :(NSString *)transportAgent :(BOOL)isRegistered :(NSString *)registeredUsername
{
	[[self accountForUUID:accountUUID] handleTransportRegistrationStatusUpdatedForAgent:transportAgent
																			 isRegistered:isRegistered
																				 username:registeredUsername];
}

- (void)leapfrogBridge_transportLoggedInStatusUpdated:(NSString *)accountUUID :(NSString *)transportAgent :(BOOL)isLoggedIn
{
	[[self accountForUUID:accountUUID] handleTransportLoggedInStatusUpdatedForAgent:transportAgent isLoggedIn:isLoggedIn];
}


- (void)leapfrogBridge_serverVarsReceived:(NSString *)accountUUID :(NSDictionary *)varsValues
{
	[[self accountForUUID:accountUUID] handleReceivedServerVarsDictionary:varsValues];
}

- (void)leapfrogBridge_selfVCardChanged:(NSString *)accountUUID :(NSDictionary *)vCard
{
	[[self accountForUUID:accountUUID] handleSelfVCardChanged:vCard];
}

- (void)leapfrogBridge_debuggerStatusChanged:(NSString *)accountUUID :(BOOL)isDebugger
{
	[[self accountForUUID:accountUUID] handleDebuggerStatusChanged:isDebugger];
}

@end
