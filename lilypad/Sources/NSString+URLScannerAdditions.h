//
//  NSString+URLScannerAdditions.h
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import <Foundation/Foundation.h>


@interface NSString (URLScannerAdditions)
- (NSRange)rangeOfNextURLInRange:(NSRange)searchRange normalizedURLString:(NSString **)oNormalizedURLStr;
@end
