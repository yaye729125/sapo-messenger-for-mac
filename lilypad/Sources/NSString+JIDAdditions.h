//
//  NSString+JIDAdditions.h
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jpavao@co.sapo.pt>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import <Cocoa/Cocoa.h>


@class LPServerItemsInfo;


@interface NSString (JIDAdditions)
- (NSString *)bareJIDComponent;
- (NSString *)JIDResourceNameComponent;
- (NSString *)JIDUsernameComponent;
- (NSString *)JIDHostnameComponent;

- (BOOL)isPhoneJID;
- (NSString *)userPresentablePhoneNrRepresentation;
- (NSString *)internalPhoneNrRepresentation;
- (NSString *)internalPhoneJIDRepresentation;

- (NSString *)userPresentableJIDAsPerAgentsDictionary:(NSDictionary *)sapoAgentsDict serverItemsInfo:(LPServerItemsInfo *)serverItemsInfo;

@end
