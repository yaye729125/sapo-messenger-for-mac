//
//  LPAudibleSet.h
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import <Cocoa/Cocoa.h>


@class LPAudibleResourceLoader;


@interface LPAudibleSet : NSObject
{
	NSURL			*m_configDirectoryURL;
	NSString		*m_cacheIdentifier;
	
	BOOL			m_isUpdatingConfigurationFromServer;
	
	/* This contains all the information that actually represents an "Audible Set". It's a tree of plist objects
	(dictionaries, arrays, etc) structured as returned by LPAudibleXMLConfigParser's parsing methods. */
	id				m_audibleSetPList;
	
	/* The instance variables that follow hold information that aids in the management of the asynchronous loading
	of the various audible resources: XML configuration file and the audibles themselves. */
	LPAudibleResourceLoader		*m_configLoader;	// for the loading of the XML configuration file
	NSMutableDictionary			*m_audibleLoaders;	// audible name --> audible loader
}

+ (LPAudibleSet *)defaultAudibleSet;
- initWithConfigDirectoryURL:(NSURL *)configDirURL cacheIdentifier:(NSString *)cacheID;

- (NSURL *)configDirectoryURL;
- (NSString *)cacheIdentifier;
- (BOOL)isUpdatingConfigurationFromServer;
- (void)startUpdatingConfigurationFromServer;
- (BOOL)isUpdatingFromServer;

- (NSArray *)arrangedCategoryNames;
- (NSDictionary *)arrangedAudibleNamesByCategory;
- (NSArray *)arrangedAudibleNamesForCategory:(NSString *)categoryName;
- (BOOL)isValidAudibleResourceName:(NSString *)audibleName;
- (NSString *)captionForAudibleWithName:(NSString *)audibleName;
- (NSString *)textForAudibleWithName:(NSString *)audibleName;
- (NSString *)filepathForAudibleWithName:(NSString *)audibleName;
- (void)startLoadingAudibleFromServer:(NSString *)audibleName;
@end


// Notifications
extern NSString *LPAudibleSetAudibleDidFinishLoadingNotification;
extern NSString *LPAudibleSetAudibleDidFailLoadingNotification;
