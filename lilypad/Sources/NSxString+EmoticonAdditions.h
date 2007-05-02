//
//  NSxString+EmoticonAdditions.h
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import <Cocoa/Cocoa.h>


extern NSString *LPAttributedStringWithEmoticonsTransformerName;
@interface LPAttributedStringWithEmoticonsTransformer : NSValueTransformer {}
@end


@class LPEmoticonSet;


@interface NSString (LPEmoticonAdditions)

- (NSRange)rangeOfNextASCIIEmoticonSequenceFromEmoticonSet:(LPEmoticonSet *)emoticonSet range:(NSRange)searchRange;
- (NSRange)rangeOfNextEmoticonFromEmoticonSet:(LPEmoticonSet *)emoticonSet range:(NSRange)searchRange;

/*!
    @abstract   Replaces the character sequences within the string that represent an emoticon with the corresponding HTML image tag
				pointing to that emoticon's image file.
    @param		emoticonSet	The emoticon set to be used to translate character sequences to image file paths.
	@param		sequencesAreEscaped Should be TRUE if the character sequences to be replaced already had their characters representing
				special HTML entities encoded (for example, & -> &amp;, etc.), FALSE otherwise (they are still in plain text).
*/
- (NSString *)stringByTranslatingASCIIEmoticonSequencesToHTMLUsingEmoticonSet:(LPEmoticonSet *)emoticonSet
												  originalSequencesAreEscaped:(BOOL)sequencesAreEscaped;

/*!
    @abstract   Replaces the character sequences within the string that represent an emoticon with the corresponding attachments with an
				emoticon image and a private text attribute which will allow them to be translated back to plain text later.
*/
- (NSAttributedString *)attributedStringByTranslatingEmoticonsToImagesUsingEmoticonSet:(LPEmoticonSet *)emoticonSet
																	   emoticonsHeight:(float)height
																		baselineOffset:(float)baselineOffset;

@end


@interface NSAttributedString (LPEmoticonAdditions)

/*!
	@abstract   Returns a new attributed string consisting of a single attachment with an emoticon image and a private text attribute
				which will allow it to be translated back to plain text later.
*/
+ (NSAttributedString *)attributedStringWithAttachmentForEmoticonWithASCIISequence:(NSString *)asciiSequence
																	   emoticonSet:(LPEmoticonSet *)emoticonSet
																	emoticonHeight:(float)height
																	baselineOffset:(float)baselineOffset;

/*!
    @abstract   Returns a new attributed string consisting of a single attachment with an emoticon image and a private text attribute
				which will allow it to be translated back to plain text later.
*/
+ (NSAttributedString *)attributedStringWithAttachmentForEmoticonNr:(int)emoticonNr
														emoticonSet:(LPEmoticonSet *)emoticonSet
													 emoticonHeight:(float)height
													 baselineOffset:(float)baselineOffset;

/*!
    @abstract   Returns a plain text string where emoticon attachments have been translated to their plain ascii text sequences using the
				private text attributes that were attached to the emoticon images by attributedStringWithAttachmentForEmoticonNr:emoticonSet:.
*/
- (NSString *)stringByFlatteningAttachedEmoticons;

@end


@interface NSMutableAttributedString (LPEmoticonAdditions)

/*!
    @abstract   Similar to NSMutableString's fixAttachmentAttributeInRange: but this one deals with emoticon attachments.
*/
- (void)fixEmoticonAttachmentAttributesInRange:(NSRange)range;

@end

