//
//  LPCapabilitiesPredicates.h
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jpavao@co.sapo.pt>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import <Cocoa/Cocoa.h>


@interface NSArray (LPCapabilitiesPredicates)
- (id)firstItemInArrayPassingCapabilitiesPredicate:(SEL)conditionSel;
- (id)firstOnlineItemInArrayPassingCapabilitiesPredicate:(SEL)conditionSel;
- (BOOL)someItemInArrayPassesCapabilitiesPredicate:(SEL)conditionSel;
- (BOOL)someOnlineItemInArrayPassesCapabilitiesPredicate:(SEL)conditionSel;
@end


@protocol LPCapabilitiesPredicates
- (BOOL)canDoChat;
- (BOOL)canDoSMS;
- (BOOL)canDoMUC;
- (BOOL)canDoFileTransfer;
@end
