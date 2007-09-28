//
//  LPFirstRunSetup.m
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "LPFirstRunSetup.h"
#import "LPAccount.h"
#import "LPKeychainManager.h"
#import "LPAccountsController.h"


@implementation LPFirstRunSetup

+ (LPFirstRunSetup *)firstRunSetup
{
	return [[[[self class] alloc] init] autorelease];
}

- init
{
	return [self initWithWindowNibName:@"FirstRunSetup"];
}

- (void)windowDidLoad
{
	[self setShouldCascadeWindows:NO];
	
	[m_backgroundView setImage:[NSImage imageNamed:@"firstLoginBackground"]];
	[m_backgroundView setImageScaling:NSScaleToFit];
	
	LPAccount *defaultAccount = [[self accountsController] defaultAccount];
	[self setJID:[defaultAccount JID]];
	[self setPassword:[defaultAccount password]];
}

- (NSString *)JID
{
	return [[m_JID copy] autorelease];
}

- (void)setJID:(NSString *)aJID
{
	if (aJID != m_JID) {
		[m_JID release];
		m_JID = [aJID copy];
	}
}

- (NSString *)password
{
	return [[m_password copy] autorelease];
}

- (void)setPassword:(NSString *)aPassword
{
	if (aPassword != m_password) {
		[m_password release];
		m_password = [aPassword copy];
	}
}

- (void)runModal
{
	[NSApp runModalForWindow:[self window]];
}

- (LPAccountsController *)accountsController
{
	return [LPAccountsController sharedAccountsController];
}

- (IBAction)okClicked:(id)sender
{
	[[self window] orderOut:nil];
	[NSApp stopModal];
	
	LPAccount *defaultAccount = [[self accountsController] defaultAccount];
	[defaultAccount setJID:[self JID]];
	[defaultAccount setPassword:[self password]];
	[defaultAccount setEnabled:YES];
}

- (IBAction)quitClicked:(id)sender
{
	[NSApp terminate:nil];
}

@end
