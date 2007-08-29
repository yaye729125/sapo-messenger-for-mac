//
//  LPSapoAgents+MenuAdditions.h
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import <Cocoa/Cocoa.h>
#import "LPSapoAgents.h"


@interface LPSapoAgents (MenuAdditions)
- (NSMenu *)JIDServicesMenuWithTarget:(id)target action:(SEL)action serviceHostnames:(NSArray *)hostnames;
- (NSMenu *)JIDServicesMenuForAddingJIDsWithTarget:(id)target action:(SEL)action;
- (NSMenu *)JIDServicesMenuForChattingServicesWithTarget:(id)target action:(SEL)action;
@end
