//
//  LPAudibleXMLConfigParser.m
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "LPAudibleXMLConfigParser.h"




@interface LPAudibleXMLConfigParser_Private : NSObject
{
	NSXMLParser		*m_parser;
	BOOL			m_inAudiblesSection;
	
	// These hold the data that will be the result of running this parser.
	NSMutableDictionary		*m_audiblesByResourceName;
	NSMutableDictionary		*m_categoriesByName;
	NSArray					*m_sortedCategoryNames;
	
	// Accumulated contents of the category being currently read.
	NSMutableArray			*m_currentCategoryContents;
	// List of attributes dictionaries for all the categories. This will be used to know how to sort them at the end.
	NSMutableArray			*m_allCategoriesAttributes;
	
	unsigned int			m_itemNestingLevelInCategoriesSection;
}
+ parserWithXMLConfigData:(NSData *)data;
- initWithXMLConfigData:(NSData *)data;
- (BOOL)parse;
- (id)propertyListResultingFromParsedData;
@end




@implementation LPAudibleXMLConfigParser_Private


+ parserWithXMLConfigData:(NSData *)data
{
	return [[[[self class] alloc] initWithXMLConfigData:data] autorelease];
}


- initWithXMLConfigData:(NSData *)data
{
	if (self = [super init]) {
		m_parser = [[NSXMLParser alloc] initWithData:data];
		[m_parser setDelegate:self];
		
		m_audiblesByResourceName = [[NSMutableDictionary alloc] init];
		m_categoriesByName = [[NSMutableDictionary alloc] init];
		m_allCategoriesAttributes = [[NSMutableArray alloc] init];
	}
	return self;
}


- (void)dealloc
{
	[m_parser release];
	
	[m_audiblesByResourceName release];
	[m_categoriesByName release];
	[m_sortedCategoryNames release];
	
	[m_currentCategoryContents release];
	[m_allCategoriesAttributes release];
	
	[super dealloc];
}


- (BOOL)parse
{
	[m_audiblesByResourceName removeAllObjects];
	[m_categoriesByName removeAllObjects];
	[m_currentCategoryContents removeAllObjects];
	[m_allCategoriesAttributes removeAllObjects];
	
	return [m_parser parse];
}


- (id)propertyListResultingFromParsedData
{
	return [NSDictionary dictionaryWithObjectsAndKeys:
		m_audiblesByResourceName, @"Audibles",
		m_categoriesByName, @"CategoryContents",
		m_sortedCategoryNames, @"ArrangedCategoryNames",
		nil];
}


#pragma mark NSXMLParser Delegate Methods


- (void)parserDidStartDocument:(NSXMLParser *)parser
{
	m_itemNestingLevelInCategoriesSection = 0;
}


- (void)parserDidEndDocument:(NSXMLParser *)parser
{
	NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"order" ascending:YES];
	NSArray *descriptors = [NSArray arrayWithObject:sortDescriptor];
	[sortDescriptor release];
	
	[m_allCategoriesAttributes sortUsingDescriptors:descriptors];
	
	[m_sortedCategoryNames release];
	m_sortedCategoryNames = [[m_allCategoriesAttributes valueForKey:@"name"] retain];
}


- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName attributes:(NSDictionary *)attributeDict
{
	if (m_inAudiblesSection && [elementName isEqualToString:@"item"]) {
		// Save the info about a single audible
		[m_audiblesByResourceName setObject:attributeDict forKey:[attributeDict objectForKey:@"resource"]];
	}
	else if ([elementName isEqualToString:@"audible"]) {
		m_inAudiblesSection = YES;
	}
	else if ((m_inAudiblesSection == NO) && [elementName isEqualToString:@"item"]) {
		++m_itemNestingLevelInCategoriesSection;
		
		if (m_itemNestingLevelInCategoriesSection == 1) {
			// Setup a category to hold the items that follow. We can hang it in the final dictionary right here.
			[m_currentCategoryContents release]; // just to be sure we don't leak anything
			m_currentCategoryContents = [[NSMutableArray alloc] init];
			[m_categoriesByName setObject:m_currentCategoryContents forKey:[attributeDict objectForKey:@"name"]];
			
			[m_allCategoriesAttributes addObject:attributeDict];
		}
		else if (m_itemNestingLevelInCategoriesSection == 2) {
			// Read a description of a category member
			[m_currentCategoryContents addObject:[attributeDict objectForKey:@"resource"]];
		}
	}
}


- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
{
	if ([elementName isEqualToString:@"audible"]) {
		m_inAudiblesSection = NO;
	}
	else if ((m_inAudiblesSection == NO) && [elementName isEqualToString:@"item"]) {
		if (m_itemNestingLevelInCategoriesSection == 1) {
			[m_currentCategoryContents release];
			m_currentCategoryContents = nil;
		}
		
		--m_itemNestingLevelInCategoriesSection;
	}
}


- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
#warning TO DO: Audibles XML parser error handling
	NSLog(@"Error at line %d, column %d, code %d", [parser lineNumber], [parser columnNumber], [parseError code]);
}


@end




@implementation LPAudibleXMLConfigParser

+ (id)configurationPropertyListFromXMLConfigString:(NSString *)string
{
	return [self configurationPropertyListFromXMLConfigData:[string dataUsingEncoding:NSUTF8StringEncoding]];
}

+ (id)configurationPropertyListFromXMLConfigData:(NSData *)data
{
	LPAudibleXMLConfigParser_Private *myParser = [LPAudibleXMLConfigParser_Private parserWithXMLConfigData:data];
	id resultingPList = nil;
	
	@try {
		[myParser parse];
		resultingPList = [myParser propertyListResultingFromParsedData];
	}
	@catch (NSException *e) {
		NSLog(@"*** Caught exception: %@: %@", [e name], [e reason]);
	}
	
	return resultingPList;
}

@end

