//
//  LPSapoAgents+MenuAdditions.m
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "LPSapoAgents+MenuAdditions.h"


@implementation LPSapoAgents (MenuAdditions)

- (NSMenu *)JIDServicesMenuWithTarget:(id)target action:(SEL)action serviceHostnames:(NSArray *)hostnames
{
	// Create the popup menu
	NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Services Menu"];
	NSDictionary *sapoAgentsDict = [self dictionaryRepresentation];
	
	id <NSMenuItem> item;
	NSEnumerator *hostnameEnum = [hostnames objectEnumerator];
	NSString *hostname;
	while (hostname = [hostnameEnum nextObject]) {
		item = [menu addItemWithTitle:[[sapoAgentsDict objectForKey:hostname] objectForKey:@"name"]
							   action:action
						keyEquivalent:@""];
		[item setTarget:target];
		[item setRepresentedObject:hostname];
	}
	
	item = [menu addItemWithTitle:NSLocalizedString(@"Other Jabber Service", @"")
						   action:action
					keyEquivalent:@""];
	[item setTarget:target];
	[item setRepresentedObject:@""];
	
	return [menu autorelease];
}

- (NSMenu *)JIDServicesMenuForAddingJIDsWithTarget:(id)target action:(SEL)action
{
	return [self JIDServicesMenuWithTarget:target
									action:action
						  serviceHostnames:[self rosterContactHostnames]];
}

- (NSMenu *)JIDServicesMenuForChattingServicesWithTarget:(id)target action:(SEL)action
{
	return [self JIDServicesMenuWithTarget:target
									action:action
						  serviceHostnames:[self chattingContactHostnames]];
}

@end
