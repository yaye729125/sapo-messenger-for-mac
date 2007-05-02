//
//  LPTermsOfUseController.m
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "LPTermsOfUseController.h"

@implementation LPTermsOfUseController

+ (LPTermsOfUseController *)termsOfUse
{
	return [[[[self class] alloc] init] autorelease];
}

- init
{
	return [self initWithWindowNibName:@"TermsOfUse"];
}

- (void)awakeFromNib
{
	NSString *termsOfUseFilePath = [[NSBundle mainBundle] pathForResource:@"TermsOfUse" ofType:@"rtf"];
	
	[m_textView readRTFDFromFile:termsOfUseFilePath];
	[m_okButton setEnabled:( [m_radioButtons selectedTag] == 0 )];
}

- (int)runModal
{
	return [NSApp runModalForWindow:[self window]];
}

#pragma mark -

- (IBAction)cancelClicked:(id)sender
{
	[[self window] orderOut:nil];
	[NSApp stopModalWithCode:NO];
}

- (IBAction)okClicked:(id)sender
{
	[[self window] orderOut:nil];
	[NSApp stopModalWithCode:YES];
}

- (IBAction)radioButtonClicked:(id)sender
{
	[m_okButton setEnabled:( [m_radioButtons selectedTag] == 0 )];
}

@end
