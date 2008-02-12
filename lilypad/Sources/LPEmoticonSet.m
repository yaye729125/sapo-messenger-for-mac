//
//  LPEmoticonSet.m
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jpavao@co.sapo.pt>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "LPEmoticonSet.h"


@implementation LPEmoticonSet

+ (LPEmoticonSet *)defaultEmoticonSet
{
	static LPEmoticonSet *defaultEmoticonSet = nil;

	if (defaultEmoticonSet == nil) {
		NSString *emoticonSetDir = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"EmoticonSet"];
		NSString *configFilePath = [emoticonSetDir stringByAppendingPathComponent:@"EMOTICON_MAP.xml"];
		
		defaultEmoticonSet = [[LPEmoticonSet alloc] initWithConfigFilePath:configFilePath imagesDirectory:emoticonSetDir];
	}
	return defaultEmoticonSet;
}

- initWithConfigFilePath:(NSString *)configFilePath imagesDirectory:(NSString *)imagesDirPath
{
	if (self = [super init]) {
		// Gather info from the config file
		NSXMLParser *aXMLParser = [[NSXMLParser alloc] initWithContentsOfURL:[NSURL fileURLWithPath:configFilePath]];
		[aXMLParser setDelegate:self];
		
		@try {
			[aXMLParser parse];			
			m_imagesDirectoryPath = [imagesDirPath copy];
		}
		@catch (NSException *e) {
			NSLog(@"*** Caught exception: %@: %@", [e name], [e reason]);
			[self release];
			self = nil;
		}
		@finally {
			[aXMLParser release];
		}
	}
	return self;
}

- (void)dealloc
{
	[m_emoticonDescriptions release];
	[m_emoticonImageResourceNameForASCIISequence release];
	[m_imagesDirectoryPath release];
	[super dealloc];
}

- (int)count
{
	return [m_emoticonDescriptions count];
}

- (NSArray *)allEmoticonASCIISequences
{
	return [m_emoticonImageResourceNameForASCIISequence allKeys];
}

- (NSEnumerator *)emoticonASCIISequenceEnumerator
{
	return [m_emoticonImageResourceNameForASCIISequence keyEnumerator];
}

- (NSString *)p_absolutePathOfImageResourceNamed:(NSString *)emoticonResourceName
{
	return [m_imagesDirectoryPath stringByAppendingPathComponent:[emoticonResourceName stringByAppendingString:@".png"]];
}

- (NSString *)absolutePathOfImageResourceForEmoticonNr:(int)emoticonNr
{
	return [self p_absolutePathOfImageResourceNamed:[[m_emoticonDescriptions objectAtIndex:emoticonNr] objectForKey:@"resource"]];
}

- (NSString *)absolutePathOfImageResourceForEmoticonWithASCIISequence:(NSString *)asciiSequence
{
	return [self p_absolutePathOfImageResourceNamed:[m_emoticonImageResourceNameForASCIISequence objectForKey:asciiSequence]];
}

- (NSImage *)imageForEmoticonNr:(int)emoticonNr
{
	NSString *resourceName = [[m_emoticonDescriptions objectAtIndex:emoticonNr] objectForKey:@"resource"];
	NSImage  *image = [NSImage imageNamed:resourceName];
	
	if (image == nil) {
		// We'll have to load the image from file
		image = [[NSImage alloc] initWithContentsOfFile:[self p_absolutePathOfImageResourceNamed:resourceName]];
		[image setName:resourceName];
		
		/* The image is staying in the named images cache forever. If we end up implementing multiple alternative and
		 * user-selectable emoticon sets in the future, we'll have to see how the images from the previous set get released
		 * and how and when is the named images cache refreshed. Or we need to decide whether we use named images at all!
		 */
	}
	
	return image;
}

- (NSString *)captionForEmoticonNr:(int)emoticonNr
{
	return [[m_emoticonDescriptions objectAtIndex:emoticonNr] objectForKey:@"caption"];
}

- (NSString *)defaultASCIISequenceForEmoticonNr:(int)emoticonNr
{
	return [[m_emoticonDescriptions objectAtIndex:emoticonNr] objectForKey:@"stroke"];
}


#pragma mark -
#pragma mark NSXMLParser Delegate Methods


- (void)parserDidStartDocument:(NSXMLParser *)parser
{
	[m_emoticonDescriptions release];
	m_emoticonDescriptions = [[NSMutableArray alloc] init];
	[m_emoticonImageResourceNameForASCIISequence release];
	m_emoticonImageResourceNameForASCIISequence = [[NSMutableDictionary alloc] init];
}


- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName attributes:(NSDictionary *)attributeDict
{
	if ([elementName isEqualToString:@"item"]) {
		if (m_insideEmoticonElement) {
			[m_emoticonDescriptions addObject:attributeDict];
		}
		
		[m_emoticonImageResourceNameForASCIISequence setObject:[attributeDict objectForKey:@"resource"]
														forKey:[attributeDict objectForKey:@"stroke"]];
	}
	else if ([elementName isEqualToString:@"emoticon"]) {
		m_insideEmoticonElement = TRUE;
	}
}


- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
{
	if ([elementName isEqualToString:@"emoticon"]) {
		m_insideEmoticonElement = FALSE;
	}
}


- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
	[NSException raise:@"LPEmoticonSetConfigException"
				format:@"Unexpected error while reading the XML configuration file for the emoticon set: %@",
								[parseError localizedDescription]];
}


@end
