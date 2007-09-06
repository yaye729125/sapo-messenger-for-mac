//
//  LPAccountsController.h
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import <Cocoa/Cocoa.h>
#import <SystemConfiguration/SystemConfiguration.h>

@class LPAccount;


@interface LPAccountsController : NSObject
{
	NSMutableDictionary	*m_accountsByUUID;
	NSMutableArray		*m_accounts;
	
	// This is used to suspend the normal handling of key-value change notifications while loading
	BOOL				m_isLoadingFromDefaults;
	
	// For System Configuration change notifications that we provide to our accounts
	SCDynamicStoreRef	m_dynamicStore;
	CFRunLoopSourceRef	m_dynamicStoreNotificationsRunLoopSource;
}

+ (LPAccountsController *)sharedAccountsController;

- (void)loadAccountsFromDefaults;
- (void)saveAccountsToDefaults;

- (LPAccount *)defaultAccount;
- (NSArray *)accounts;

- (LPAccount *)addNewAccount;
- (void)addAccount:(LPAccount *)account;
- (void)removeAccount:(LPAccount *)account;

- (IBAction)connectAllAutologinAccounts:(id)sender;
- (IBAction)disconnectAllAccounts:(id)sender;

@end
