//
//  LPSapoAgents.m
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "LPSapoAgents.h"
#import "LPCommon.h"


static int rosterContactHostnamesSorterFn (id host1, id host2, void *agentsDict)
{
	NSDictionary *host1Info = [(NSDictionary *)agentsDict objectForKey:host1];
	NSDictionary *host2Info = [(NSDictionary *)agentsDict objectForKey:host2];
	int host1Order = [[host1Info objectForKey:@"order"] intValue];
	int host2Order = [[host2Info objectForKey:@"order"] intValue];
	
	if (host1Order < host2Order)
		return NSOrderedAscending;
	else if (host1Order > host2Order)
		return NSOrderedDescending;
	else
		return NSOrderedSame;
}


@implementation LPSapoAgents

+ (void)initialize
{
	[self setKeys:[NSArray arrayWithObject:@"dictionaryRepresentation"]
			triggerChangeNotificationsForDependentKey:@"rosterContactHostnames"];
}

- initWithServerHost:(NSString *)host
{
	if (self = [self init]) {
		m_serverHost = [host copy];
		
		// Load the initial sapo agents dictionary either from the user cache or the app bundle, exactly
		// in this order of preference.
		NSString *supportFolder = LPOurApplicationSupportFolderPath();
		NSString *cacheFile = [supportFolder stringByAppendingPathComponent:@"SapoAgentsCache.plist"];
		
		if (![[NSFileManager defaultManager] fileExistsAtPath:cacheFile]) {
			cacheFile = [[NSBundle mainBundle] pathForResource:@"SapoAgentsCache" ofType:@"plist"];
		}
		
		m_sapoAgentsDict = [[NSDictionary alloc] initWithContentsOfFile:cacheFile];
	}
	return self;
}

- (void)dealloc
{
	[m_serverHost release];
	[m_sapoAgentsDict release];
	[super dealloc];
}

- (NSDictionary *)dictionaryRepresentation
{
	return [[m_sapoAgentsDict retain] autorelease];
}

- (NSArray *)rosterContactHostnames
{
	NSMutableArray *result = [NSMutableArray array];
	
	NSEnumerator *hostEnum = [m_sapoAgentsDict keyEnumerator];
	NSString *key;
	
	while (key = [hostEnum nextObject]) {
		NSDictionary *serviceDict = [m_sapoAgentsDict objectForKey:key];
		BOOL isRosterContact = ([serviceDict objectForKey:@"roster_contact"] != nil);
		
		if (isRosterContact) {
			[result addObject:key];
		}
	}
	
	[result sortUsingFunction:rosterContactHostnamesSorterFn context:m_sapoAgentsDict];
	return result;
}

- (NSArray *)chattingContactHostnames
{
	NSMutableArray *result = [NSMutableArray array];
	
	NSEnumerator *hostEnum = [m_sapoAgentsDict keyEnumerator];
	NSString *key;
	
	while (key = [hostEnum nextObject]) {
		NSDictionary *serviceDict = [m_sapoAgentsDict objectForKey:key];
		BOOL isRosterContact = ([serviceDict objectForKey:@"roster_contact"] != nil);
		BOOL shouldIgnorePresences = ([serviceDict objectForKey:@"ignore_presences"] != nil);
		
		if (isRosterContact && !shouldIgnorePresences) {
			[result addObject:key];
		}
	}
	
	[result sortUsingFunction:rosterContactHostnamesSorterFn context:m_sapoAgentsDict];
	return result;
}

- (NSString *)hostnameForService:(NSString *)service
{
	NSEnumerator *hostEnum = [m_sapoAgentsDict keyEnumerator];
	NSString *key;
	
	while (key = [hostEnum nextObject]) {
		if ([[[m_sapoAgentsDict objectForKey:key] objectForKey:@"service"] isEqualToString:service]) {
			break;
		}
	}
	
	return [[key copy] autorelease];
}

- (void)handleSapoAgentsUpdated:(NSDictionary *)sapoAgents
{
	[self willChangeValueForKey:@"dictionaryRepresentation"];
	[m_sapoAgentsDict release];
	m_sapoAgentsDict = [sapoAgents copy];
	[self didChangeValueForKey:@"dictionaryRepresentation"];
	
	// Save the cache file
	NSString *supportFolder = LPOurApplicationSupportFolderPath();
	NSString *cacheFile = [supportFolder stringByAppendingPathComponent:@"SapoAgentsCache.plist"];
	
	[m_sapoAgentsDict writeToFile:cacheFile atomically:YES];
}

@end
