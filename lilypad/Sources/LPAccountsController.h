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

#import "LPAccountStatus.h"


@class LPAccount;


@interface LPAccountsController : NSObject <LPAccountStatus>
{
	NSMutableDictionary	*m_accountsByUUID;
	NSMutableArray		*m_accounts;
	
	// This is used to suspend the normal handling of key-value change notifications while loading
	BOOL				m_isLoadingFromDefaults;
	
	// For System Configuration change notifications that we provide to our accounts
	SCDynamicStoreRef	m_dynamicStore;
	CFRunLoopSourceRef	m_dynamicStoreNotificationsRunLoopSource;
	
	/*
	 * Cached computed account attributes
	 *
	 * These cached instance variables allow the willChangeValueForKey:/didChangeValueForKey: KVO methods to do their thing.
	 * If we didn't cache these values, and if some object registered as an observer using the options to get both the old and the new
	 * values in the change dictionary, then that object would always get equal values for both the old and the new entries in the
	 * dictionary. This happens because the LPAccountsController would be invoking the willChangeValueForKey: method -- which saves the
	 * old value if the observer has requested for it to be delivered -- when the value had already been changed in the source account.
	 */
	NSString			*m_globalAccountName;
	LPStatus			m_globalAccountStatus;
	NSString			*m_globalAccountStatusMessage;
	LPStatus			m_globalAccountTargetStatus;
	BOOL				m_globalAccountOnlineFlag;
	BOOL				m_globalAccountOfflineFlag;
	BOOL				m_globalAccountDebuggerFlag;
	BOOL				m_globalAccountReconnectingFlag;
	NSImage				*m_globalAccountAvatar;
}

+ (LPAccountsController *)sharedAccountsController;

- (void)loadAccountsFromDefaults;
- (void)saveAccountsToDefaults;

- (LPAccount *)defaultAccount;
- (NSArray *)accounts;

- (LPAccount *)addNewAccount;
- (void)addAccount:(LPAccount *)account;
- (void)removeAccount:(LPAccount *)account;

- (LPAccount *)accountForUUID:(NSString *)theUUID;

- (IBAction)connectAllEnabledAccounts:(id)sender;
- (IBAction)disconnectAllAccounts:(id)sender;

#pragma mark Attributes computed from all the accounts managed by this controller

- (NSString *)name;
- (void)setName:(NSString *)theName;

- (LPStatus)status;
- (NSString *)statusMessage;
- (void)setStatusMessage:(NSString *)theStatusMessage;
- (void)setStatusMessage:(NSString *)theStatusMessage saveToServer:(BOOL)saveFlag;
- (LPStatus)targetStatus;
- (void)setTargetStatus:(LPStatus)theStatus;
- (void)setTargetStatus:(LPStatus)theStatus saveToServer:(BOOL)saveFlag;
- (void)setTargetStatus:(LPStatus)theStatus message:(NSString *)theMessage saveToServer:(BOOL)saveFlag;
- (void)setTargetStatus:(LPStatus)theStatus message:(NSString *)theMessage saveToServer:(BOOL)saveFlag alsoSaveStatusMessage:(BOOL)saveMsg;

- (BOOL)isOnline;
- (BOOL)isOffline;
- (BOOL)isDebugger;
- (BOOL)isTryingToAutoReconnect;

- (NSImage *)avatar;
- (void)setAvatar:(NSImage *)avatar;

@end
