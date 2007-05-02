//
//  LPSapoAgents.h
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import <Cocoa/Cocoa.h>


@interface LPSapoAgents : NSObject
{
	NSString		*m_serverHost;
	NSDictionary	*m_sapoAgentsDict;
}

- initWithServerHost:(NSString *)host;

- (NSDictionary *)dictionaryRepresentation;
- (NSArray *)rosterContactHostnames;
- (NSString *)hostnameForService:(NSString *)service;

- (void)handleSapoAgentsUpdated:(NSDictionary *)sapoAgents;
@end
