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


// KVO Contexts
static void *LPAccountsConfigurationChangeContext	= (void *)1001;
static void *LPAccountsDynamicStateChangeContext	= (void *)1002;


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
- (LPAccount *)p_firstAccountPassingOwnPredicate:(SEL)pred;
- (id)p_accountsFirstNonNilObjectValueForKey:(NSString *)key;
- (LPStatus)p_accountsFirstNonOfflineStatusForKey:(NSString *)key;
- (NSString *)p_computedGlobalAccountName;
- (LPStatus)p_computedGlobalAccountStatus;
- (NSString *)p_computedGlobalAccountStatusMessage;
- (LPStatus)p_computedGlobalAccountTargetStatus;
- (BOOL)p_computedGlobalAccountOnlineFlag;
- (BOOL)p_computedGlobalAccountOfflineFlag;
- (BOOL)p_computedGlobalAccountDebuggerFlag;
- (BOOL)p_computedGlobalAccountTryingToAutoReconnectFlag;
- (NSImage *)p_computedGlobalAccountAvatar;

- (void)p_updateCachedGlobalAccountValuesForAllKeys;
- (void)p_updateCachedGlobalAccountValueForKey:(NSString *)key;
@end


@implementation LPAccountsController


+ (void)initialize
{
	// Start by initializing some stuff on the bridge before adding any accounts
	NSTimeZone	*tz = [NSTimeZone defaultTimeZone];
	NSBundle	*appBundle = [NSBundle mainBundle];
	NSString	*clientName = [NSString stringWithFormat:@"%@ Mac", [appBundle objectForInfoDictionaryKey:@"CFBundleExecutable"]];
	NSString	*versionString = [NSString stringWithFormat:@"%@ (%@)",
		[appBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"],
		[appBundle objectForInfoDictionaryKey:@"CFBundleVersion"]];
	NSString	*capsVersionString = [NSString stringWithFormat:@"%@_%@",
		[appBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"],
		[appBundle objectForInfoDictionaryKey:@"CFBundleVersion"]];
	
	[LFAppController setTimeZoneName:[tz abbreviation] timeZoneOffset:([tz secondsFromGMT] / 3600)];
	[LFAppController setClientName:clientName
						   version:versionString
							OSName:@"Mac OS X"
						  capsNode:@"http://messenger.sapo.pt/caps/mac"
					   capsVersion:capsVersionString];
	[LFAppController setSupportDataFolder: LPOurApplicationSupportFolderPath()];
}


+ (LPAccountsController *)sharedAccountsController
{
	static LPAccountsController *sharedController = nil;

	if (sharedController == nil) {
		sharedController = [[LPAccountsController alloc] init];
	}
	return sharedController;
}


+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key
{
	// Cached computed account attributes
	NSArray *manualNotificationKeys = [NSArray arrayWithObjects:@"name", @"status", @"statusMessage", @"targetStatus", @"online", @"offline", @"debugger", @"tryingToAutoReconnect", @"avatar", nil];
	
	return ([manualNotificationKeys containsObject:key] == NO);
}


- init
{
	if (self = [super init]) {
		m_accountsByUUID = [[NSMutableDictionary alloc] init];
		m_accounts = [[NSMutableArray alloc] init];
		
		m_globalAccountStatus = LPStatusOffline;
		m_globalAccountTargetStatus = LPStatusOffline;
		m_globalAccountOfflineFlag = YES;
		
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
	
	// Cache of computed account attributes
	[m_globalAccountName release];
	[m_globalAccountStatusMessage release];
	[m_globalAccountAvatar release];
	
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
		
		// Accounts are assumed enabled by default when the corresponding key isn't found in the defaults
		if ([accountDict valueForKey:@"enabled"] == nil)
			[account setEnabled:YES];
		
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
		[account addObserver:self forKeyPath:someKey
					 options:0 context:LPAccountsConfigurationChangeContext];
	
	// The password is a special case: it is saved to the keychain instead of going to the defaults DB along with the other properties
	[account addObserver:self forKeyPath:@"password"
				 options:0 context:LPAccountsConfigurationChangeContext];
	[account addObserver:self forKeyPath:@"lastRegisteredMSNPassword"
				 options:0 context:LPAccountsConfigurationChangeContext];
	
	[self p_setNeedsToSaveAccounts:YES];
	
	
	// Also observe the keys that may change the values of some of our accessors that consider all the accounts to compute their return value
	// No need to add the "name" key, it is already being observed due to being a "persistent account key"
	[account addObserver:self forKeyPath:@"status"
				 options:0 context:LPAccountsDynamicStateChangeContext];
	[account addObserver:self forKeyPath:@"statusMessage"
				 options:0 context:LPAccountsDynamicStateChangeContext];
	[account addObserver:self forKeyPath:@"targetStatus"
				 options:0 context:LPAccountsDynamicStateChangeContext];
	[account addObserver:self forKeyPath:@"online"
				 options:0 context:LPAccountsDynamicStateChangeContext];
	[account addObserver:self forKeyPath:@"offline"
				 options:0 context:LPAccountsDynamicStateChangeContext];
	[account addObserver:self forKeyPath:@"debugger"
				 options:0 context:LPAccountsDynamicStateChangeContext];
	[account addObserver:self forKeyPath:@"tryingToAutoReconnect"
				 options:0 context:LPAccountsDynamicStateChangeContext];
	[account addObserver:self forKeyPath:@"avatar"
				 options:0 context:LPAccountsDynamicStateChangeContext];
	
	// Make sure the core is aware of it
	[LFAppController addAccountWithUUID:[account UUID]];
	
	[self p_updateCachedGlobalAccountValuesForAllKeys];
}


- (void)removeAccount:(LPAccount *)account
{
	[account setTargetStatus:LPStatusOffline];
	
	[LFAppController removeAccountWithUUID:[account UUID]];
	
	[account removeObserver:self forKeyPath:@"avatar"];
	[account removeObserver:self forKeyPath:@"tryingToAutoReconnect"];
	[account removeObserver:self forKeyPath:@"debugger"];
	[account removeObserver:self forKeyPath:@"offline"];
	[account removeObserver:self forKeyPath:@"online"];
	[account removeObserver:self forKeyPath:@"targetStatus"];
	[account removeObserver:self forKeyPath:@"statusMessage"];
	[account removeObserver:self forKeyPath:@"status"];
	
	
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
	
	[self p_updateCachedGlobalAccountValuesForAllKeys];
}


- (void)moveAccount:(LPAccount *)account toIndex:(int)newIndex
{
	NSAssert([m_accounts containsObject:account], @"The account is not a member of this accounts controller!");
	
	if ([m_accounts indexOfObject:account] != newIndex) {
		[account retain];
		[self willChangeValueForKey:@"accounts"];
		[m_accounts removeObject:account];
		[m_accounts insertObject:account atIndex:newIndex];
		[self didChangeValueForKey:@"accounts"];
		[account release];
		
		[self p_setNeedsToSaveAccounts:YES];
	}
}


- (LPAccount *)accountForUUID:(NSString *)theUUID
{
	return [m_accountsByUUID objectForKey:theUUID];
}


- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	// Do the changes require that we save the current accounts configuration?
	if (context == LPAccountsConfigurationChangeContext) {
		[self p_setNeedsToSaveAccounts:YES];
	}
	
	[self p_updateCachedGlobalAccountValueForKey:keyPath];
	
	if ([keyPath isEqualToString:@"enabled"]) {
		LPAccount *account = object;
		
		if ([account isEnabled] && [account isOffline])
			[account setTargetStatus:[self targetStatus] message:[self statusMessage] saveToServer:YES];
		if (![account isEnabled] && ![account isOffline])
			[account setTargetStatus:LPStatusOffline];
	}
}


#pragma mark -
#pragma mark Private


+ (NSArray *)p_persistentAccountKeys
{
	return [NSArray arrayWithObjects:
		@"description", @"enabled", @"name", @"JID", @"location",
		@"customServerHost", @"usesCustomServerHost",
		@"usesSSL", @"locationUsesComputerName",
		@"lastRegisteredMSNEmail", nil];
}


- (void)p_setNeedsToSaveAccounts:(BOOL)shouldSave
{
	if (shouldSave && m_isLoadingFromDefaults == NO) {
		[self saveAccountsToDefaults];
	}
}


#pragma mark Attributes computed from all the accounts managed by this controller


- (LPAccount *)p_firstAccountPassingOwnPredicate:(SEL)pred
{
	NSInvocation *inv = [NSInvocation invocationWithMethodSignature:[LPAccount instanceMethodSignatureForSelector:pred]];
	[inv setSelector:pred];
	
	NSAssert([[inv methodSignature] methodReturnLength] <= sizeof(BOOL), @"Return value of the provided predicate takes more space than a BOOL!");
	
	NSEnumerator *accountEnum = [m_accounts objectEnumerator];
	LPAccount *account = nil;
	
	BOOL passedPredicate = NO;
	
	while (account = [accountEnum nextObject]) {
		[inv invokeWithTarget:account];
		[inv getReturnValue:&passedPredicate];
		if (passedPredicate) break;
	}
	
	return account;
}

- (id)p_accountsFirstNonNilObjectValueForKey:(NSString *)key
{
	NSEnumerator *accountEnum = [m_accounts objectEnumerator];
	LPAccount *account;
	
	id value = nil;
	
	while (value == nil && (account = [accountEnum nextObject]))
		value = [account valueForKey:key];
	
	return value;
}

- (LPStatus)p_accountsFirstNonOfflineStatusForKey:(NSString *)key
{
	NSEnumerator *accountEnum = [m_accounts objectEnumerator];
	LPAccount *account;
	
	LPStatus status = LPStatusOffline;
	
	while (status == LPStatusOffline && (account = [accountEnum nextObject]))
		status = (LPStatus)[[account valueForKey:key] intValue];
	
	return status;
}

- (NSString *)p_computedGlobalAccountName
{
	return [[self defaultAccount] name];
}

- (LPStatus)p_computedGlobalAccountStatus
{
	return [self p_accountsFirstNonOfflineStatusForKey:@"status"];
}

- (NSString *)p_computedGlobalAccountStatusMessage
{
	// Check whether there is some account trying to get connected. If there is, we want to use this as the prevailing
	// status message to be displayed to the user.
	NSEnumerator *accountEnum = [m_accounts objectEnumerator];
	LPAccount *account;
	
	LPStatus status = LPStatusOffline;
	
	while (status != LPStatusConnecting && (account = [accountEnum nextObject]))
		status = [account status];
	
	
	if (account != nil)
		return [account statusMessage];
	else
		return [self p_accountsFirstNonNilObjectValueForKey:@"statusMessage"];
}

- (LPStatus)p_computedGlobalAccountTargetStatus
{
	return [self p_accountsFirstNonOfflineStatusForKey:@"targetStatus"];
}

- (BOOL)p_computedGlobalAccountOnlineFlag
{
	return ([self p_firstAccountPassingOwnPredicate:@selector(isOnline)] != nil);
}

- (BOOL)p_computedGlobalAccountOfflineFlag
{
	// We can't use the p_firstAccountPassingOwnPredicate: method because we want the inverse: we want to know if all the accounts are offline
	NSEnumerator *accountEnum = [m_accounts objectEnumerator];
	LPAccount *account;
	
	BOOL isOffline = YES;
	
	while (isOffline == YES && (account = [accountEnum nextObject]))
		isOffline = [account isOffline];
	
	return isOffline;
}

- (BOOL)p_computedGlobalAccountDebuggerFlag
{
	return ([self p_firstAccountPassingOwnPredicate:@selector(isDebugger)] != nil);
}

- (BOOL)p_computedGlobalAccountTryingToAutoReconnectFlag
{
	return ([self p_firstAccountPassingOwnPredicate:@selector(isTryingToAutoReconnect)] != nil);
}

- (NSImage *)p_computedGlobalAccountAvatar
{
	return [self p_accountsFirstNonNilObjectValueForKey:@"avatar"];
}

#pragma mark -

- (void)p_updateCachedGlobalAccountValuesForAllKeys
{
	[self p_updateCachedGlobalAccountValueForKey:nil];
}

- (void)p_updateCachedGlobalAccountValueForKey:(NSString *)key
{
	// Update the cached values of any account attribute that has changed
	if (key == nil || [key isEqualToString:@"name"]) {
		[self willChangeValueForKey:@"name"];
		[m_globalAccountName release];
		m_globalAccountName = [[self p_computedGlobalAccountName] copy];
		[self didChangeValueForKey:@"name"];
	}
	if (key == nil || [key isEqualToString:@"status"]) {
		[self willChangeValueForKey:@"status"];
		m_globalAccountStatus = [self p_computedGlobalAccountStatus];
		[self didChangeValueForKey:@"status"];
	}
	if (key == nil || [key isEqualToString:@"statusMessage"]) {
		[self willChangeValueForKey:@"statusMessage"];
		[m_globalAccountStatusMessage release];
		m_globalAccountStatusMessage = [[self p_computedGlobalAccountStatusMessage] copy];
		[self didChangeValueForKey:@"statusMessage"];
	}
	if (key == nil || [key isEqualToString:@"targetStatus"]) {
		[self willChangeValueForKey:@"targetStatus"];
		m_globalAccountTargetStatus = [self p_computedGlobalAccountTargetStatus];
		[self didChangeValueForKey:@"targetStatus"];
	}
	if (key == nil || [key isEqualToString:@"online"]) {
		[self willChangeValueForKey:@"online"];
		m_globalAccountOnlineFlag = [self p_computedGlobalAccountOnlineFlag];
		[self didChangeValueForKey:@"online"];
	}
	if (key == nil || [key isEqualToString:@"offline"]) {
		[self willChangeValueForKey:@"offline"];
		m_globalAccountOfflineFlag = [self p_computedGlobalAccountOfflineFlag];
		[self didChangeValueForKey:@"offline"];
	}
	if (key == nil || [key isEqualToString:@"debugger"]) {
		[self willChangeValueForKey:@"debugger"];
		m_globalAccountDebuggerFlag = [self p_computedGlobalAccountDebuggerFlag];
		[self didChangeValueForKey:@"debugger"];
	}
	if (key == nil || [key isEqualToString:@"tryingToAutoReconnect"]) {
		[self willChangeValueForKey:@"tryingToAutoReconnect"];
		m_globalAccountReconnectingFlag = [self p_computedGlobalAccountTryingToAutoReconnectFlag];
		[self didChangeValueForKey:@"tryingToAutoReconnect"];
	}
	if (key == nil || [key isEqualToString:@"avatar"]) {
		[self willChangeValueForKey:@"avatar"];
		[m_globalAccountAvatar release];
		m_globalAccountAvatar = [[self p_computedGlobalAccountAvatar] retain];
		[self didChangeValueForKey:@"avatar"];
	}
}
	


#pragma mark -
#pragma mark Actions


- (IBAction)connectAllEnabledAccounts:(id)sender
{
	[self setTargetStatus:LPStatusAvailable];
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
#pragma mark Attributes computed from all the accounts managed by this controller


- (NSString *)name
{
	return [[m_globalAccountName copy] autorelease];
}

- (void)setName:(NSString *)theName
{
	[m_accounts setValue:theName forKey:@"name"];
}

- (LPStatus)status
{
	return m_globalAccountStatus;
}

- (NSString *)statusMessage
{
	return [[m_globalAccountStatusMessage copy] autorelease];
}

- (void)setStatusMessage:(NSString *)theStatusMessage
{
	NSEnumerator *accountEnum = [m_accounts objectEnumerator];
	LPAccount *account;
	while (account = [accountEnum nextObject])
		if ([account isEnabled])
			[account setStatusMessage:theStatusMessage];
}

- (void)setStatusMessage:(NSString *)theStatusMessage saveToServer:(BOOL)saveFlag
{
	NSEnumerator *accountEnum = [m_accounts objectEnumerator];
	LPAccount *account;
	while (account = [accountEnum nextObject])
		if ([account isEnabled])
			[account setStatusMessage:theStatusMessage saveToServer:saveFlag];
}

- (LPStatus)targetStatus
{
	return m_globalAccountTargetStatus;
}

- (void)setTargetStatus:(LPStatus)theStatus
{
	NSEnumerator *accountEnum = [m_accounts objectEnumerator];
	LPAccount *account;
	while (account = [accountEnum nextObject])
		if ([account isEnabled])
			[account setTargetStatus:theStatus];
}

- (void)setTargetStatus:(LPStatus)theStatus saveToServer:(BOOL)saveFlag
{
	NSEnumerator *accountEnum = [m_accounts objectEnumerator];
	LPAccount *account;
	while (account = [accountEnum nextObject])
		if ([account isEnabled])
			[account setTargetStatus:theStatus saveToServer:saveFlag];
}

- (void)setTargetStatus:(LPStatus)theStatus message:(NSString *)theMessage saveToServer:(BOOL)saveFlag
{
	NSEnumerator *accountEnum = [m_accounts objectEnumerator];
	LPAccount *account;
	while (account = [accountEnum nextObject])
		if ([account isEnabled])
			[account setTargetStatus:theStatus message:theMessage saveToServer:saveFlag];
}

- (void)setTargetStatus:(LPStatus)theStatus message:(NSString *)theMessage saveToServer:(BOOL)saveFlag alsoSaveStatusMessage:(BOOL)saveMsg
{
	NSEnumerator *accountEnum = [m_accounts objectEnumerator];
	LPAccount *account;
	while (account = [accountEnum nextObject])
		if ([account isEnabled])
			[account setTargetStatus:theStatus message:theMessage saveToServer:saveFlag alsoSaveStatusMessage:saveMsg];
}

- (BOOL)isOnline
{
	return m_globalAccountOnlineFlag;
}

- (BOOL)isOffline
{
	return m_globalAccountOfflineFlag;
}

- (BOOL)isDebugger
{
	return m_globalAccountDebuggerFlag;
}

- (BOOL)isTryingToAutoReconnect
{
	return m_globalAccountReconnectingFlag;
}

- (NSImage *)avatar
{
	return [[m_globalAccountAvatar retain] autorelease];
}

- (void)setAvatar:(NSImage *)avatar
{
	NSEnumerator *accountEnum = [m_accounts objectEnumerator];
	LPAccount *account;
	while (account = [accountEnum nextObject])
		if ([account isEnabled])
			[account setAvatar:avatar];
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


- (void)leapfrogBridge_serverItemsUpdated:(NSString *)accountUUID :(NSArray *)serverItems
{
	[[self accountForUUID:accountUUID] handleServerItemsUpdated:serverItems];
}


- (void)leapfrogBridge_serverItemInfoUpdated:(NSString *)accountUUID :(NSString *)item :(NSString *)name :(NSArray *)features
{
	[[self accountForUUID:accountUUID] handleInfoUpdatedForServerItem:item withName:name features:features];
}


- (void)leapfrogBridge_sapoAgentsUpdated:(NSString *)accountUUID :(NSDictionary *)sapoAgentsDescription
{
	[[self accountForUUID:accountUUID] handleSapoAgentsUpdated:sapoAgentsDescription];
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
