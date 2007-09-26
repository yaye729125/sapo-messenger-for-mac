//
//  LPAccountStatus.h
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//


@protocol LPAccountStatus

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
