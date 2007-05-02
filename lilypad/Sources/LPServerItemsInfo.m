//
//  LPServerItemsInfo.m
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "LPServerItemsInfo.h"


@implementation LPServerItemsInfo

- initWithServerHost:(NSString *)host
{
	if (self = [self init]) {
		m_serverHost = [host copy];
		
		// Load the initial disco info dictionary either from the user cache or the app bundle, exactly
		// in this order of preference.
		NSString *supportFolder = LPOurApplicationSupportFolderPath();
		NSString *cacheFile = [supportFolder stringByAppendingPathComponent:@"ServerItemsInfoCache.plist"];
		
		if (![[NSFileManager defaultManager] fileExistsAtPath:cacheFile]) {
			cacheFile = [[NSBundle mainBundle] pathForResource:@"ServerItemsInfoCache" ofType:@"plist"];
		}
		
		NSDictionary *cacheDict = [NSDictionary dictionaryWithContentsOfFile:cacheFile];
		
		if ([m_serverHost isEqualToString:[cacheDict objectForKey:@"ServerHost"]]) {
			m_serverItems = [[cacheDict objectForKey:@"Items"] copy];
			m_serverItemsToFeatures = [[cacheDict objectForKey:@"ItemsToFeatures"] mutableCopy];
			m_featuresToServerItems = [[cacheDict objectForKey:@"FeaturesToItems"] mutableCopy];
		}
		else {
			m_serverItemsToFeatures = [[NSMutableDictionary alloc] init];
			m_featuresToServerItems = [[NSMutableDictionary alloc] init];
		}
	}
	return self;
}

- (void)dealloc
{
	[m_serverHost release];
	[m_serverItems release];
	[m_serverItemsToFeatures release];
	[m_featuresToServerItems release];
	[super dealloc];
}

- (NSArray *)serverItems
{
	return [[m_serverItems retain] autorelease];
}

- (NSDictionary *)featuresByItem
{
	return [[m_serverItemsToFeatures retain] autorelease];
}

- (NSDictionary *)itemsByFeature
{
	return [[m_featuresToServerItems retain] autorelease];
}

- (void)p_saveCache:(NSTimer *)timer
{
	NSString *supportFolder = LPOurApplicationSupportFolderPath();
	NSString *cacheFile = [supportFolder stringByAppendingPathComponent:@"ServerItemsInfoCache.plist"];
	
	NSDictionary *cacheDict = [NSDictionary dictionaryWithObjectsAndKeys:
		m_serverHost, @"ServerHost",
		m_serverItems, @"Items",
		m_serverItemsToFeatures, @"ItemsToFeatures",
		m_featuresToServerItems, @"FeaturesToItems",
		nil];
	
	[cacheDict writeToFile:cacheFile atomically:YES];
	
	m_cacheSaveTimerIsRunning = NO;
}

- (void)p_setNeedsCacheSave:(BOOL)flag
{
	if (!m_cacheSaveTimerIsRunning && flag) {
		[NSTimer scheduledTimerWithTimeInterval:20.0
										 target:self
									   selector:@selector(p_saveCache:)
									   userInfo:nil
										repeats:NO];
		m_cacheSaveTimerIsRunning = YES;
	}
}

- (void)handleServerItemsUpdated:(NSArray *)items
{
	[self willChangeValueForKey:@"serverItems"];
	[m_serverItems release];
	m_serverItems = [items copy];
	[self didChangeValueForKey:@"serverItems"];
	
	// Clear the features dictionaries
	[self willChangeValueForKey:@"itemsByFeature"];
	[m_featuresToServerItems release];
	m_featuresToServerItems = [[NSMutableDictionary alloc] init];
	[self didChangeValueForKey:@"itemsByFeature"];
	[self willChangeValueForKey:@"featuresByItem"];
	[m_serverItemsToFeatures release];
	m_serverItemsToFeatures = [[NSMutableDictionary alloc] init];
	[self didChangeValueForKey:@"featuresByItem"];
	
	[self p_setNeedsCacheSave:YES];
}

- (void)handleFeaturesUpdated:(NSArray *)features forServerItem:(NSString *)item
{
	// Add to the index by item
	[self willChangeValueForKey:@"featuresByItem"];
	[m_serverItemsToFeatures setObject:features forKey:item];
	[self didChangeValueForKey:@"featuresByItem"];
	
	// Add to the index by feature
	[self willChangeValueForKey:@"itemsByFeature"];
	NSEnumerator *featureEnum = [features objectEnumerator];
	NSString *feature;
	while (feature = [featureEnum nextObject]) {
		NSMutableArray *itemsList = [m_featuresToServerItems objectForKey:feature];
		
		if (itemsList == nil) {
			itemsList = [[NSMutableArray alloc] init];
			[m_featuresToServerItems setObject:itemsList forKey:feature];
			[itemsList release];
		}
		[itemsList addObject:item];
	}
	[self didChangeValueForKey:@"itemsByFeature"];
	
	[self p_setNeedsCacheSave:YES];
}

@end
