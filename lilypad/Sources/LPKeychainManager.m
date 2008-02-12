//
//  LPKeychainManager.m
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jpavao@co.sapo.pt>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "LPKeychainManager.h"

#include <CoreFoundation/CoreFoundation.h>
#include <Security/Security.h>
#include <CoreServices/CoreServices.h>


@implementation LPKeychainManager

+ (NSString *)serviceNameForAccount:(NSString *)account
{
	return [NSString stringWithFormat:@"SapoIM: %@", (account ? account : @"")];
}

+ (BOOL)savePassword:(NSString *)password forAccount:(NSString *)account
{
	return [self savePassword:password forAccount:account serviceName:[self serviceNameForAccount:account]];
}

+ (BOOL)savePassword:(NSString *)password forAccount:(NSString *)account serviceName:(NSString *)serviceName
{
	OSStatus			status;
	SecKeychainItemRef	itemRef = NULL;
	
	// check if the item already exists in the keychain
	status = SecKeychainFindGenericPassword (NULL,	// default keychain
											 [serviceName length],
											 [serviceName UTF8String],
											 [account length],
											 [account UTF8String],
											 0,		// password length
											 NULL,	// password data
											 &itemRef);
	
	if (status == errSecItemNotFound) {
		status = SecKeychainAddGenericPassword (NULL,	// default keychain
												[serviceName length],
												[serviceName UTF8String],
												[account length],
												[account UTF8String],
												[password length],
												[password UTF8String],
												NULL);	// the item reference
	} else {
		status = SecKeychainItemModifyAttributesAndData (itemRef,
														 NULL,  // no change to attributes
														 [password length],
														 [password UTF8String]);
		
	}
	
	if (itemRef) CFRelease(itemRef);
	
	return (status == noErr);
}

+ (NSString *)passwordForAccount:(NSString *)account
{
	return [self passwordForAccount:account serviceName:[self serviceNameForAccount:account]];
}

+ (NSString *)passwordForAccount:(NSString *)account serviceName:(NSString *)serviceName
{
	OSStatus	status;
	UInt32		passwordLength;
	void		*passwordData = NULL;
	
	status = SecKeychainFindGenericPassword (NULL,	// default keychain
											 [serviceName length],
											 [serviceName UTF8String],
											 [account length],
											 [account UTF8String],
											 &passwordLength,
											 &passwordData,
											 NULL);	// the item reference
	
	NSString *password = nil;

	if (status == noErr)
		password = [NSString stringWithCString:(const char *)passwordData length:passwordLength];
	
	if (passwordData != NULL)
		status = SecKeychainItemFreeContent(NULL, passwordData);
	
	return (password ? password : @"");
}

@end
