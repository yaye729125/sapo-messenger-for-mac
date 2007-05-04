//
//  NSxString+EmoticonAdditions.m
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informa›es sobre o licenciamento, leia o ficheiro README.
//

#import "NSxString+EmoticonAdditions.h"
#import "NSString+HTMLAdditions.h"
#import "LPEmoticonSet.h"


static int
NSStringLongToShortLengthSortFn(id str1, id str2, void *context)
{
	unsigned int str1Length = [str1 length];
	unsigned int str2Length = [str2 length];
	
	if (str1Length > str2Length) {
		return NSOrderedAscending;
	}
	else if (str1Length < str2Length) {
		return NSOrderedDescending;
	}
	else {
		return NSOrderedSame;
	}
}



NSString *LPAttributedStringWithEmoticonsTransformerName = @"LPAttributedStringWithEmoticonsTransformer";

@implementation LPAttributedStringWithEmoticonsTransformer
+ (Class)transformedValueClass { return [NSAttributedString class]; }
+ (BOOL)allowsReverseTransformation { return NO; }
- (id)transformedValue:(id)value
{
	return [value attributedStringByTranslatingEmoticonsToImagesUsingEmoticonSet:[LPEmoticonSet defaultEmoticonSet]
																 emoticonsHeight:12.0
																  baselineOffset:-3.0];
}
@end




@implementation NSString (LPEmoticonAdditions)

- (NSRange)rangeOfNextASCIIEmoticonSequenceFromEmoticonSet:(LPEmoticonSet *)emoticonSet range:(NSRange)searchRange
{
	NSArray *allEmoticonASCIISequences = [[emoticonSet allEmoticonASCIISequences] sortedArrayUsingFunction:NSStringLongToShortLengthSortFn
																								   context:NULL];
	NSRange			bestFoundRange = { NSNotFound , 0 }; // the match closest to the beginning of the string
	NSEnumerator	*enumerator = [allEmoticonASCIISequences objectEnumerator];
	NSString		*asciiSequence;
	
	while (asciiSequence = [enumerator nextObject]) {
		NSRange currentFoundRange = [self rangeOfString:asciiSequence options:NSLiteralSearch range:searchRange];
		
		if (currentFoundRange.location != NSNotFound
			&& (bestFoundRange.location == NSNotFound || currentFoundRange.location < bestFoundRange.location))
			bestFoundRange = currentFoundRange;
	}
	
	return bestFoundRange;
}


- (NSRange)rangeOfNextDelimitedEmoticonFromEmoticonSet:(LPEmoticonSet *)emoticonSet range:(NSRange)searchRange
{
	NSRange		nextEmoticonRange = { NSNotFound, 0 };
	NSRange		emoticonSearchRange = searchRange;
	BOOL		hasValidLeftBoundary = YES;
	BOOL		hasValidRightBoundary = YES;
	
	do {
		nextEmoticonRange = [self rangeOfNextASCIIEmoticonSequenceFromEmoticonSet:emoticonSet range:emoticonSearchRange];
		
		unsigned int indexBeforeEmoticon = nextEmoticonRange.location - 1;
		unsigned int indexAfterEmoticon = NSMaxRange(nextEmoticonRange);
		unsigned int indexAfterSearchRange = NSMaxRange(searchRange);
		
		// Don't substitute an emoticon unless it's surrounded by spaces or it's at the tip of the string.
		if (nextEmoticonRange.location != NSNotFound) {
			hasValidLeftBoundary = (nextEmoticonRange.location == searchRange.location ||
									[self characterAtIndex:indexBeforeEmoticon] == (unichar)' ');
			hasValidRightBoundary = (indexAfterEmoticon == indexAfterSearchRange ||
									 [self characterAtIndex:indexAfterEmoticon] == (unichar)' ');
		}
		
		emoticonSearchRange.location = indexAfterEmoticon;
		emoticonSearchRange.length = indexAfterSearchRange - indexAfterEmoticon;
	} while (nextEmoticonRange.location != NSNotFound && (!hasValidLeftBoundary || !hasValidRightBoundary));
	
	return nextEmoticonRange;
}


- (NSAttributedString *)attributedStringByTranslatingEmoticonsToImagesUsingEmoticonSet:(LPEmoticonSet *)emoticonSet
																					emoticonsHeight:(float)height
																					 baselineOffset:(float)baselineOffset
{
	NSMutableAttributedString *newString = [[NSMutableAttributedString alloc] initWithString:self];
	
	NSRange foundEmoticonRange;
	NSRange searchRange = NSMakeRange(0, [self length]);
	
	while ((foundEmoticonRange = [[newString string] rangeOfNextDelimitedEmoticonFromEmoticonSet:emoticonSet range:searchRange]).location != NSNotFound) {
		NSString *asciiSequence = [[newString string] substringWithRange:foundEmoticonRange];
		
		[newString replaceCharactersInRange:foundEmoticonRange
					   withAttributedString:[NSAttributedString attributedStringWithAttachmentForEmoticonWithASCIISequence:asciiSequence
																											   emoticonSet:emoticonSet
																											emoticonHeight:height
																											baselineOffset:baselineOffset]];
		searchRange = NSMakeRange(foundEmoticonRange.location, [newString length] - foundEmoticonRange.location);
	}
	
	return [newString autorelease];
}


@end


/* Name of the attribute that stores the ASCII sequence for a given emoticon image attachment that is inserted into
an NSAttributedString. */
static NSString *LPEmoticonEquivalentASCIISequenceAttributeName = @"LPEmoticonEquivalentASCIISequence";


@interface LPEmoticonAttachmentCell : NSTextAttachmentCell
{
	NSSize m_size;
}
- (void)setCellSize:(NSSize)size;
@end

@implementation LPEmoticonAttachmentCell

- (void)setCellSize:(NSSize)size
{
	m_size = size;
}

- (NSSize)cellSize
{
	return m_size;
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)aView
{
	NSImage *img = [self image];
	NSRect srcRect = { NSZeroPoint , [img size] };
	
	[NSGraphicsContext saveGraphicsState];
	[[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
	[img setFlipped:[aView isFlipped]];
	[img drawInRect:cellFrame fromRect:srcRect operation:NSCompositeSourceOver fraction:1.0];
	[NSGraphicsContext restoreGraphicsState];
}

@end


@implementation NSAttributedString (LPEmoticonAdditions)

+ (NSAttributedString *)attributedStringWithAttachmentForEmoticonWithASCIISequence:(NSString *)asciiSequence
																	   emoticonSet:(LPEmoticonSet *)emoticonSet
																	emoticonHeight:(float)height
																	baselineOffset:(float)baselineOffset
{
	NSString					*imageAbsolutePath = [emoticonSet absolutePathOfImageResourceForEmoticonWithASCIISequence:asciiSequence];
	NSTextAttachment			*attachment = [[NSTextAttachment alloc] initWithFileWrapper:nil];
	NSImage						*img = [[NSImage alloc] initWithContentsOfFile:imageAbsolutePath];
	LPEmoticonAttachmentCell	*cell = [[LPEmoticonAttachmentCell alloc] initImageCell:img];
	
	if (height > 0.0)
		[cell setCellSize:NSMakeSize(height, height)];
	else
		[cell setCellSize:[img size]];
	
	[attachment setAttachmentCell:cell];
	
	NSMutableAttributedString	*attrString = [[NSAttributedString attributedStringWithAttachment:attachment] mutableCopy];
	
	[img release];
	[cell release];
	[attachment release];
	
	NSRange attribRange = NSMakeRange(0, [attrString length]);
	
	[attrString addAttribute:LPEmoticonEquivalentASCIISequenceAttributeName
					   value:asciiSequence
					   range:attribRange];
	[attrString addAttribute:NSBaselineOffsetAttributeName
					   value:[NSNumber numberWithFloat:baselineOffset]
					   range:attribRange];
	
	return [attrString autorelease];
}


+ (NSAttributedString *)attributedStringWithAttachmentForEmoticonNr:(int)emoticonNr
														emoticonSet:(LPEmoticonSet *)emoticonSet
													 emoticonHeight:(float)height
													 baselineOffset:(float)baselineOffset
{
	return [self attributedStringWithAttachmentForEmoticonWithASCIISequence:[emoticonSet defaultASCIISequenceForEmoticonNr:emoticonNr]
																emoticonSet:emoticonSet
															 emoticonHeight:height
															 baselineOffset:baselineOffset];
}


- (NSString *)stringByFlatteningAttachedEmoticons
{
	NSMutableAttributedString *mutableCopy = [self mutableCopy];
	
	// Make it so that the emoticon attachment attributes exist only where there is an emoticon attachment.
	[mutableCopy fixEmoticonAttachmentAttributesInRange:NSMakeRange(0, [mutableCopy length])];
	
	NSMutableString	*newString = [NSMutableString string];
	NSRange			range = NSMakeRange(0, 0);
	unsigned int	currentIndex = 0;
	unsigned int	stringLength = [mutableCopy length];
	
	while (currentIndex < stringLength) {
		NSString *emoticonASCIISequence = [mutableCopy attribute:LPEmoticonEquivalentASCIISequenceAttributeName
														 atIndex:currentIndex
												  effectiveRange:&range];
		
		if (emoticonASCIISequence == nil) {
			[newString appendString:[[mutableCopy attributedSubstringFromRange:range] string]];
		} else {
			// Add a space character before the emoticon if needed
			if (currentIndex > 0 && [[mutableCopy string] characterAtIndex:(range.location - 1)] != (unichar)' ')
				[newString appendString:@" "];
			
			[newString appendString:emoticonASCIISequence];
			
			// Add a space character after the emoticon if needed
			if (currentIndex < (stringLength - 1) && [[mutableCopy string] characterAtIndex:NSMaxRange(range)] != (unichar)' ')
				[newString appendString:@" "];
		}
		
		currentIndex = NSMaxRange(range);
	}
	
	[mutableCopy release];
	
	return newString;
}

@end


@implementation NSMutableAttributedString (LPEmoticonAdditions)

- (void)fixEmoticonAttachmentAttributesInRange:(NSRange)range
{
	NSString		*attachmentCharStr = [NSString stringWithFormat:@"%C", NSAttachmentCharacter];
	NSMutableString	*mutableStr = [self mutableString];
	NSRange			searchRange = range;
	NSRange			foundRange;
	
	do {
		foundRange = [mutableStr rangeOfString:attachmentCharStr options:NSLiteralSearch range:searchRange];
		
		unsigned int lengthOfRangeToClear = ((foundRange.location == NSNotFound) ?
											 searchRange.length :
											 (foundRange.location - searchRange.location));
		
		[self removeAttribute:LPEmoticonEquivalentASCIISequenceAttributeName
						range:NSMakeRange(searchRange.location, lengthOfRangeToClear)];
		
		searchRange.location += (lengthOfRangeToClear + 1); // also skip the attachment char
		searchRange.length -= (lengthOfRangeToClear + 1);
	} while (foundRange.location != NSNotFound);
}

@end
