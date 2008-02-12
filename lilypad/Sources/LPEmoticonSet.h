//
//  LPEmoticonSet.h
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jpavao@co.sapo.pt>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import <Cocoa/Cocoa.h>


/*!
    @class		 LPEmoticonSet
    @abstract    Loads an emoticon set configuration from disk and provides access to its elements (images and other info).
    @discussion  Loads an emoticon set from disk by reading its configuration info from an XML file with the following format:

					<?xml version="1.0" encoding="UTF-8"?>
					<config> 
						<emoticon>
							<item resource="EMOTICON_STAR" caption="Estrela" stroke="(*)" />
							...
						</emoticon>
						<stroke>
							<item resource="EMOTICON_KING" stroke="{:-)" />
							...
						</stroke>
					</config>
 
				 The value of the "resource" attributes correspond to the name of an image file for the given emoticon. The ".png"
				 suffix will be added to the end of that name before an attemp to load the image file is made.
 
				 Once an instance of this class is created and initialized with an emoticon configuration, other objects will be able
				 to ask it for information and images regarding the emoticon set that it represents.
 
				 Emoticon nrs used throughout methods of this class to refer to emoticons are 0-based.
 */


@interface LPEmoticonSet : NSObject
{
	/*
	 * Emoticon Description Info: Dict { (string) resource, (string) caption, (array of strings) ascii sequences }
	 */
	NSMutableArray		*m_emoticonDescriptions;
	NSMutableDictionary	*m_emoticonImageResourceNameForASCIISequence;
	
	NSString			*m_imagesDirectoryPath;

	// The following variables are only used while parsing the XML config file that contains the configuration for the emoticon set
	BOOL				m_insideEmoticonElement;
}

/*!
    @abstract   Returns the default emoticon set.
    @discussion Returns the default emoticon set that is read from the "EmoticonSet" folder which is in the application resources folder.
*/
+ (LPEmoticonSet *)defaultEmoticonSet;
/*!
    @abstract   Initializes an LPEmoticonSet instance.
    @discussion Initializes an LPEmoticonSet instance. This is the designated initializer for the LPEmoticonSet class.
	@param		configFilePath	Path to the XML configuration file describing the emoticon set.
	@param		imagesDirPath	Path to the directory containing the images for all the emoticons.
*/
- initWithConfigFilePath:(NSString *)configFilePath imagesDirectory:(NSString *)imagesDirPath;

- (int)count;
- (NSArray *)allEmoticonASCIISequences;
- (NSEnumerator *)emoticonASCIISequenceEnumerator;

- (NSString *)absolutePathOfImageResourceForEmoticonNr:(int)emoticonNr;
- (NSString *)absolutePathOfImageResourceForEmoticonWithASCIISequence:(NSString *)asciiSequence;

- (NSImage *)imageForEmoticonNr:(int)emoticonNr;
- (NSString *)captionForEmoticonNr:(int)emoticonNr;
- (NSString *)defaultASCIISequenceForEmoticonNr:(int)emoticonNr;

@end
