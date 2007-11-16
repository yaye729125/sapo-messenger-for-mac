//
//  LPServerItemsInfo.h
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import <Cocoa/Cocoa.h>


@interface LPServerItemsInfo : NSObject
{
	NSString			*m_serverHost;
	
	NSArray				*m_serverItems;
	NSMutableDictionary	*m_serverItemsToIdentities;
	NSMutableDictionary *m_serverItemsToFeatures;
	NSMutableDictionary *m_featuresToServerItems;
	
	BOOL				m_cacheSaveTimerIsRunning;
}

- initWithServerHost:(NSString *)host;

- (NSArray *)serverItems;
- (NSDictionary *)identitiesByItem;
- (NSDictionary *)featuresByItem;
- (NSDictionary *)itemsByFeature;

- (NSArray *)MUCServiceProviderItems;

- (void)handleUpdatedServerHostname:(NSString *)newHostname;
- (void)handleServerItemsUpdated:(NSArray *)items;
- (void)handleInfoUpdatedForServerItem:(NSString *)item withName:(NSString *)name identities:(NSArray *)identities features:(NSArray *)features;
@end
