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
	}
	return self;
}


- (void)dealloc
{
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
#warning Disconnect the account first if need be.
	
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


@end
