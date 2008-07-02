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
	if ([NSImage imageNamed:@"release_notes.png"] != nil) {
		self = [self initWithWindowNibName:@"ReleaseNotes"];
	}
	else {
		[self release];
		self = nil;
	}
	return self;
}

- (void)showWindow:(id)sender
{
	if (![[self window] isVisible]) {
		[[self window] center];
	}
	[super showWindow:sender];
}

@end
