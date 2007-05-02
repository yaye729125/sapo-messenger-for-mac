//
//  NSAttributedString+FactoryAdditions.h
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Authors: Joao Pavao <jppavao@criticalsoftware.com>
//           Jason Kim <jason@512k.org>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import <Cocoa/Cocoa.h>


@interface NSAttributedString (FactoryAdditions)
+ (NSAttributedString *)attributedStringFromString:(NSString *)string font:(NSFont *)font color:(NSColor *)color;
+ (NSAttributedString *)attributedStringFromString:(NSString *)string;
@end
