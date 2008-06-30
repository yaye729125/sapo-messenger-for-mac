//
//  LPReleaseNotesController.m
//  Lilypad
//
//  Created by João Pavão on 08/06/30.
//  Copyright 2008 Sapo. All rights reserved.
//

#import "LPReleaseNotesController.h"


@implementation LPReleaseNotesController

- init
{
	return [self initWithWindowNibName:@"ReleaseNotes"];
}

- (void)windowDidLoad
{
	[[m_webView mainFrame] loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"http://messenger.sapo.pt/artigos/725940/mac"]]];
}

- (void)showWindow:(id)sender
{
	if (![[self window] isVisible]) {
		[[self window] center];
	}
	[super showWindow:sender];
}

@end
