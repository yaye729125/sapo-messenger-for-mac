//
//  LPAudibleSet.m
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jpavao@co.sapo.pt>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "LPAudibleSet.h"
#import "LPAudibleResourceLoader.h"
#import "LPAudibleXMLConfigParser.h"


// Notifications
NSString *LPAudibleSetAudibleDidFinishLoadingNotification	= @"LPAudibleSetAudibleDidFinishLoadingNotification";
NSString *LPAudibleSetAudibleDidFailLoadingNotification		= @"LPAudibleSetAudibleDidFailLoadingNotification";


static NSString *LPAudibleDefaultConfigDirURLStr		= @"http://messenger.sapo.pt/bocas/";
static NSString *LPAudibleDefaultXMLConfigFileName		= @"AUDIBLE_MAP";
static NSString *LPAudibleDefaultCachedConfigFileName	= @"AudibleMap.plist";
static NSString *LPAudibleDefaultCacheIdentifier		= @"Default Audible Set";


@interface LPAudibleSet ()  // Private Methods
- (void)p_loadFromLocalCache;
- (void)p_saveToLocalCache;
- (id)p_audibleSetPList;
- (void)p_setAudibleSetPList:(id)plist;
- (void)p_setIsUpdatingConfigurationFromServer:(BOOL)flag;
@end


static NSString *
LPAudibleSetLocalCacheFolderPathWithID (NSString *cacheIDString)
{
	/* Create the cache for this Audible Set */
	NSString *cacheDirectoryPath = [LPOurApplicationSupportFolderPath() stringByAppendingPathComponent:cacheIDString];
	[[NSFileManager defaultManager] createDirectoryAtPath:cacheDirectoryPath attributes:nil];
	
	return cacheDirectoryPath;
}


@implementation LPAudibleSet

+ (void)initialize
{
	if (self == [LPAudibleSet class]) {
		[self setKeys:[NSArray arrayWithObject:@"updatingConfigurationFromServer"]
				triggerChangeNotificationsForDependentKey:@"updatingFromServer"];
	}
}

+ (LPAudibleSet *)defaultAudibleSet
{
	static LPAudibleSet *defaultSet = nil;
	
	if (defaultSet == nil) {
		defaultSet = [[LPAudibleSet alloc] initWithConfigDirectoryURL:[NSURL URLWithString:LPAudibleDefaultConfigDirURLStr]
													  cacheIdentifier:LPAudibleDefaultCacheIdentifier];
	}
	return defaultSet;
}

- initWithConfigDirectoryURL:(NSURL *)configDirURL cacheIdentifier:(NSString *)cacheID
{
	if (self = [self init]) {
		
		// Sanitize the directory URL to contain a trailing slash character. This will allow us to later concatenate filenames
		// to this URL in an easier and faster way, by simply using this directory URL as the base URL.
		NSString *dirAbsoluteURLStr = [configDirURL absoluteString];
		
		if ((char)[dirAbsoluteURLStr characterAtIndex:([dirAbsoluteURLStr length] - 1)] != '/') {
			m_configDirectoryURL = [[NSURL alloc] initWithString:[dirAbsoluteURLStr stringByAppendingString:@"/"]];
		} else {
			m_configDirectoryURL = [configDirURL copy];
		}
		
		m_cacheIdentifier = [cacheID copy];
		m_audibleLoaders = [[NSMutableDictionary alloc] init];
	}
	
	return self;
}

- (void)dealloc
{
	[m_configDirectoryURL release];
	[m_cacheIdentifier release];
	
	[m_audibleSetPList release];
	
	[m_configLoader cancel];
	[m_configLoader release];
	
	[[m_audibleLoaders allValues] makeObjectsPerformSelector:@selector(cancel)];
	[m_audibleLoaders release];
	
	[super dealloc];
}

- (NSURL *)configDirectoryURL
{
	return [[m_configDirectoryURL copy] autorelease];
}

- (NSString *)cacheIdentifier
{
	return [[m_cacheIdentifier copy] autorelease];
}

- (BOOL)isUpdatingConfigurationFromServer
{
	return m_isUpdatingConfigurationFromServer;
}

- (void)startUpdatingConfigurationFromServer
{
	if ([self isUpdatingConfigurationFromServer] == NO) {
		/* Start downloading the XML configuration file asynchronously from the server. In practice this will almost
		always be a very fast operation, but let's do it asynchronously anyway in case the user has a very slow or flawed
		network connection. We wouldn't want the GUI to block just because the download is behaving oddly. */
		
		[m_configLoader cancel];
		[m_configLoader release];
		m_configLoader = [[LPAudibleResourceLoader alloc] initWithResourceName:LPAudibleDefaultXMLConfigFileName
																		ofType:@"xml"
																	   baseURL:[self configDirectoryURL]
																	  delegate:self];	
		[self p_setIsUpdatingConfigurationFromServer:YES];
	}
}

- (BOOL)isUpdatingFromServer
{
	return ([self isUpdatingConfigurationFromServer] || ([m_audibleLoaders count] > 0));
}

- (NSArray *)arrangedCategoryNames
{
	return [[self p_audibleSetPList] objectForKey:@"ArrangedCategoryNames"];
}

- (NSDictionary *)arrangedAudibleNamesByCategory
{
	return [[self p_audibleSetPList] objectForKey:@"CategoryContents"];
}


- (NSArray *)arrangedAudibleNamesForCategory:(NSString *)categoryName
{
	return [[self arrangedAudibleNamesByCategory] objectForKey:categoryName];
}


- (BOOL)isValidAudibleResourceName:(NSString *)audibleName
{
	return ([[[self p_audibleSetPList] objectForKey:@"Audibles"] objectForKey:audibleName] != nil);
}


- (NSString *)captionForAudibleWithName:(NSString *)audibleName
{
	return [[[[self p_audibleSetPList] objectForKey:@"Audibles"] objectForKey:audibleName] objectForKey:@"caption"];
}


- (NSString *)textForAudibleWithName:(NSString *)audibleName
{
	return [[[[self p_audibleSetPList] objectForKey:@"Audibles"] objectForKey:audibleName] objectForKey:@"text"];
}


- (NSString *)filepathForAudibleWithName:(NSString *)audibleName
{
	NSString *localCacheFolder = LPAudibleSetLocalCacheFolderPathWithID([self cacheIdentifier]);
	NSString *audibleFilename = [audibleName stringByAppendingPathExtension:@"swf"];
	NSString *audiblePath = [localCacheFolder stringByAppendingPathComponent:audibleFilename];
	
	return ( [[NSFileManager defaultManager] fileExistsAtPath:audiblePath] ?
			 audiblePath :
			 // We don't have a valid filepath with actual data at this moment
			 nil );
}


- (void)startLoadingAudibleFromServer:(NSString *)audibleName
{
	if ([m_audibleLoaders objectForKey:audibleName] == nil) {
		LPAudibleResourceLoader *audibleLoader;
		audibleLoader = [[LPAudibleResourceLoader alloc] initWithResourceName:audibleName
																	   ofType:@"swf"
																	  baseURL:[self configDirectoryURL]
																	 delegate:self];
		[self willChangeValueForKey:@"updatingFromServer"];
		[m_audibleLoaders setObject:audibleLoader forKey:audibleName];
		[self didChangeValueForKey:@"updatingFromServer"];
		[audibleLoader release];
	}
}


#pragma mark -
#pragma mark Private


- (void)p_loadFromLocalCache
{
	NSString *cacheFolderPath = LPAudibleSetLocalCacheFolderPathWithID([self cacheIdentifier]);
	NSString *cachedConfigFilename = [cacheFolderPath stringByAppendingPathComponent:LPAudibleDefaultCachedConfigFileName];
	NSData *dataFromFile = [NSData dataWithContentsOfFile:cachedConfigFilename];
	NSString *errorString = nil;
	
	[self p_setAudibleSetPList:[NSPropertyListSerialization propertyListFromData:dataFromFile
																mutabilityOption:NSPropertyListImmutable
																		  format:NULL
																errorDescription:&errorString]];
	
	[errorString release];
}

- (void)p_saveToLocalCache
{
	NSString *cacheFolderPath = LPAudibleSetLocalCacheFolderPathWithID([self cacheIdentifier]);
	NSString *cachedConfigFilename = [cacheFolderPath stringByAppendingPathComponent:LPAudibleDefaultCachedConfigFileName];

	[m_audibleSetPList writeToFile:cachedConfigFilename atomically:YES];
}

- (id)p_audibleSetPList
{
	if (m_audibleSetPList == nil)
		[self p_loadFromLocalCache];
	
	return m_audibleSetPList;
}

- (void)p_setAudibleSetPList:(id)plist
{
	if (plist != m_audibleSetPList) {
		[self willChangeValueForKey:@"arrangedAudibleNamesByCategory"];
		[self willChangeValueForKey:@"arrangedCategoryNames"];
		
		[m_audibleSetPList release];
		m_audibleSetPList = [plist retain];
		
		[self didChangeValueForKey:@"arrangedCategoryNames"];
		[self didChangeValueForKey:@"arrangedAudibleNamesByCategory"];
	}
}

- (void)p_setIsUpdatingConfigurationFromServer:(BOOL)flag
{
	if (flag != m_isUpdatingConfigurationFromServer) {
		[self willChangeValueForKey:@"updatingConfigurationFromServer"];
		m_isUpdatingConfigurationFromServer = flag;
		[self didChangeValueForKey:@"updatingConfigurationFromServer"];
	}
}


#pragma mark -
#pragma mark LPAudibleResourceLoader Delegate Methods


- (void)audibleResourceLoaderDidFinish:(LPAudibleResourceLoader *)loader
{
	NSData *loadedData = [loader loadedData];
	
	if (loader == m_configLoader) {
		// We are loading the XML configuration file
		
		/* We're assuming iso-latin-1 encoding. The file currently on the server (as of 2006-05-15) doesn't contain
		an XML header declaring the encoding and it's encoded in iso-latin-1. */
		NSString *xmlText = [[NSString alloc] initWithData:loadedData encoding:NSISOLatin1StringEncoding];
		id configurationPList = [LPAudibleXMLConfigParser configurationPropertyListFromXMLConfigString:xmlText];
		[xmlText release];
		
		[self p_setAudibleSetPList:configurationPList];
		[self p_saveToLocalCache];
		[self p_setIsUpdatingConfigurationFromServer:NO];
		
		[m_configLoader release];
		m_configLoader = nil;
	}
	else {
		// We are loading some other resource: an Audible!
		
		NSString *audibleName = [loader resourceName];
		NSString *localCacheFolder = LPAudibleSetLocalCacheFolderPathWithID([self cacheIdentifier]);
		NSString *audibleFilename = [audibleName stringByAppendingPathExtension:@"swf"];
		NSString *audiblePath = [localCacheFolder stringByAppendingPathComponent:audibleFilename];
		
		[[loader loadedData] writeToFile:audiblePath atomically:YES];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:LPAudibleSetAudibleDidFinishLoadingNotification
															object:self
														  userInfo:[NSDictionary dictionaryWithObject:audibleName
																							   forKey:@"LPAudibleName"]];
		
		[self willChangeValueForKey:@"updatingFromServer"];
		[m_audibleLoaders removeObjectForKey:audibleName];
		[self didChangeValueForKey:@"updatingFromServer"];		
	}
}


- (void)audibleResourceLoader:(LPAudibleResourceLoader *)loader didFailWithError:(NSError *)error
{
	NSString *myErrorStr = nil;
	
	if (loader == m_configLoader) {
		// We are loading the XML configuration file
		
		[self p_setIsUpdatingConfigurationFromServer:NO];
		[m_configLoader release];
		m_configLoader = nil;
		
		myErrorStr = @"Failed to update audible configuration file from the server.";
	}
	else {
		// We are loading some other resource: an Audible!
		myErrorStr = [NSString stringWithFormat:@"Failed to download audible file \"%@\" from the server.", [loader resourceName]];
		
		[self willChangeValueForKey:@"updatingFromServer"];
		[m_audibleLoaders removeObjectForKey:[loader resourceName]];
		[self didChangeValueForKey:@"updatingFromServer"];
		
		// Notify about the failure so that objects that could be waiting for this audible can cleanup
		[[NSNotificationCenter defaultCenter] postNotificationName:LPAudibleSetAudibleDidFailLoadingNotification
															object:self
														  userInfo:[NSDictionary dictionaryWithObject:[loader resourceName]
																							   forKey:@"LPAudibleName"]];
	}
	
	NSLog(@"%@ Error Domain: %@; Error Description: %@", myErrorStr, [error domain], [error localizedDescription]);
}


@end
