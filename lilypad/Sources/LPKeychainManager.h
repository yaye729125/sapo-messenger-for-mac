//
//  LPKeychainManager.h
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jpavao@co.sapo.pt>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import <Cocoa/Cocoa.h>


@interface LPKeychainManager : NSObject
+ (NSString *)serviceNameForAccount:(NSString *)account;
+ (BOOL)savePassword:(NSString *)password forAccount:(NSString *)account;
+ (BOOL)savePassword:(NSString *)password forAccount:(NSString *)account serviceName:(NSString *)serviceName;
+ (NSString *)passwordForAccount:(NSString *)account;
+ (NSString *)passwordForAccount:(NSString *)account serviceName:(NSString *)serviceName;
@end
