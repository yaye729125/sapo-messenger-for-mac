//
//  NSString+URLScannerAdditions.h
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jpavao@co.sapo.pt>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import <Foundation/Foundation.h>


@interface NSString (URLScannerAdditions)

- (NSRange)rangeOfNextURLInRange:(NSRange)searchRange normalizedURLString:(NSString **)oNormalizedURLStr;

/*
 * Returns a list of URL descriptions, one for each URL found in the original string.
 * Each URL description consists of an NSDictionary with the following values and keys:
 *     - "OriginalURLText"	-> (NSString) URL as originally found in the string
 *     - "URL"				-> (NSURL) normalized URL ready to be opened
 *     - "RangeInString"    -> (NSString representation of an NSRange) range in the string where the URL was found
 */
- (NSArray *)allParsedURLDescriptions;
@end
