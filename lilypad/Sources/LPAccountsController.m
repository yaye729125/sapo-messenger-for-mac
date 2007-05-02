//
//  LPAccountsController.m
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informa›es sobre o licenciamento, leia o ficheiro README.
//

#import "LPAccountsController.h"
#import "LPAccount.h"
#import "LPKeychainManager.h"


static NSString *LPAllAccountsDefaultsKey = @"Accounts";


static NSString *
LPAccountsControllerNewUUIDString()
{
	CFUUIDRef	uuid = CFUUIDCreate(NULL);
	NSString	*uuidStr = (NSString *)CFUUIDCreateString(NULL, uuid);
	
	if (uuid != NULL) CFRelease(uuid);
	
	return [uuidStr autorelease];
}


@interface LPAccountsController (Private)
+ (NSArray *)p_persistentAccountKeys;
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
	[super dealloc];
}


- (void)loadAccountsFromDefaults
{
	m_isLoadingFromDefaults = YES;
	
	NSDictionary	*accountsFromPrefs = [[NSUserDefaults standardUserDefaults] dictionaryForKey:LPAllAccountsDefaultsKey];
	NSEnumerator	*accountUUIDEnumerator = [accountsFromPrefs keyEnumerator];
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
}


- (LPAccount *)defaultAccount
{
	if ([m_accounts count] == 0) {
		LPAccount *newAccount = [[LPAccount alloc] initWithUUID: LPAccountsControllerNewUUIDString() ];
		[self addAccount:newAccount];
		[newAccount release];
	}
	return [m_accounts objectAtIndex:0];
}


- (void)addAccount:(LPAccount *)account
{
	[m_accounts addObject:account];
	[m_accountsByUUID setObject:account forKey:[account UUID]];
	
	// Observe keys that should trigger a save to the defaults
	NSEnumerator *interestingKeyEnumerator = [[LPAccountsController p_persistentAccountKeys] objectEnumerator];
	NSString *someKey;
	
	while (someKey = [interestingKeyEnumerator nextObject]) {
		[account addObserver:self forKeyPath:someKey options:0 context:NULL];
	}
	// The password is a special case: it is saved to the keychain instead of going to the defaults DB along with the other properties
	[account addObserver:self forKeyPath:@"password" options:0 context:NULL];
	[account addObserver:self forKeyPath:@"lastRegisteredMSNPassword" options:0 context:NULL];
}


- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if (m_isLoadingFromDefaults == NO) {
		[self saveAccountsToDefaults];
	}
}


#pragma mark -
#pragma mark Private


+ (NSArray *)p_persistentAccountKeys
{
	return [NSArray arrayWithObjects:
		@"name", @"JID", @"location", @"customServerHost", @"usesCustomServerHost", @"usesSSL", @"shouldAutoLogin",
		@"lastRegisteredMSNEmail", nil];
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
