//
//  NSString+ConcatAdditions.h
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jpavao@co.sapo.pt>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import <Cocoa/Cocoa.h>


@interface NSString (HumanReadableObjectConcatenationAdditions)
+ (NSString *)concatenatedStringWithValuesForKey:(NSString *)key ofObjects:(NSArray *)objs useDoubleQuotes:(BOOL)useQuotes;
+ (NSString *)concatenatedStringWithValuesForKey:(NSString *)key ofObjects:(NSArray *)objs useDoubleQuotes:(BOOL)useQuotes maxNrListedItems:(int)maxNrItems;
@end
