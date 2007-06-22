//
//  LPCapabilitiesPredicates.h
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import <Cocoa/Cocoa.h>


@interface NSArray (LPCapabilitiesPredicates)
- (id)firstItemInArrayPassingCapabilitiesPredicate:(SEL)conditionSel;
- (BOOL)someItemInArrayPassesCapabilitiesPredicate:(SEL)conditionSel;
@end


@protocol LPCapabilitiesPredicates
- (BOOL)canDoChat;
- (BOOL)canDoSMS;
- (BOOL)canDoMUC;
- (BOOL)canDoFileTransfer;
@end
