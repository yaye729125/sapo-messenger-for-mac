//
//  NSString+HTMLAdditions.h
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import <Cocoa/Cocoa.h>


/*
 * The implementation of CFXMLCreateStringByEscapingEntities() and CFXMLCreateStringByUnescapingEntities() is
 * badly broken in Max OS X 10.3 Panther (see <http://www.cocoabuilder.com/archive/message/cocoa/2004/11/2/120728>).
 * Since we also want to target Panther, we are implementing an NSString category of our own that provides some basic
 * functionality similar to what is provided by those functions.
 */

@interface NSString (HTMLAdditions)
- (NSString *)stringByEscapingHTMLEntities;
- (NSString *)stringByUnescapingHTMLEntities;
@end
