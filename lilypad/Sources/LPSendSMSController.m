//
//  LPSendSMSController.m
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informa›es sobre o licenciamento, leia o ficheiro README.
//

#import "LPSendSMSController.h"
#import "LPColorBackgroundView.h"
#import "LPAccount.h"
#import "LPRoster.h"
#import "LPContact.h"
#import "LPContactEntry.h"


@implementation LPSendSMSController

- initWithContact:(LPContact *)contact delegate:(id)delegate
{
	if (self = [self initWithWindowNibName:@"SendSMS"]) {
		m_delegate = delegate;
		m_contact = [contact retain];
		
		[m_contact addObserver:self forKeyPath:@"smsContactEntries" options:0 context:NULL];
		[[[m_contact roster] account] addObserver:self forKeyPath:@"online" options:0 context:NULL];
	}
	return self;
}

- (void)dealloc
{
	[[[m_contact roster] account] removeObserver:self forKeyPath:@"online"];
	[m_contact removeObserver:self forKeyPath:@"smsContactEntries"];
	
	[m_contact release];
	[super dealloc];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ([keyPath isEqualToString:@"smsContactEntries"]) {
		// Check if the contact doesn't have any more SMS capable JIDs
		if ([[m_contact smsContactEntries] count] == 0) {
			[self performSelector:@selector(close) withObject:nil afterDelay:0.0];
		}
	}
	else if ([keyPath isEqualToString:@"online"]) {
		[m_colorBackgroundView setBackgroundColor:
			[NSColor colorWithPatternImage:( [[[m_contact roster] account] isOnline] ?
											 [NSImage imageNamed:@"chatIDBackground"] :
											 [NSImage imageNamed:@"chatIDBackground_Offline"] )]];
	}
	else {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}

- (void)windowDidLoad
{
	[m_contactController setContent:[self contact]];
	
	[m_colorBackgroundView setBackgroundColor:
		[NSColor colorWithPatternImage:( [[[m_contact roster] account] isOnline] ?
										 [NSImage imageNamed:@"chatIDBackground"] :
										 [NSImage imageNamed:@"chatIDBackground_Offline"] )]];
	[m_colorBackgroundView setBorderColor:[NSColor colorWithCalibratedWhite:0.60 alpha:1.0]];
	
	
	[m_characterCountField setStringValue:[NSString stringWithFormat: NSLocalizedString(@"%d characters", @"SMS window character count"), 0]];
}

- (LPContact *)contact
{
	return [[m_contact retain] autorelease];
}


- (IBAction)sendSMS:(id)sender
{
	NSArray *selectedObjs = [m_entriesController selectedObjects];
	
	if ([selectedObjs count] > 0) {
#warning Using LFAppController directly!
		[LFAppController sendSMSToEntry:[[selectedObjs objectAtIndex:0] ID] :[m_messageTextView string]];
		[[self window] close];
	}
}


#pragma mark -
#pragma mark NSText Delegate


- (void)textDidChange:(NSNotification *)aNotification
{
	NSText *text = [aNotification object];
	
	[m_characterCountField setStringValue:[NSString stringWithFormat:
		NSLocalizedString(@"%d characters", @"SMS window character count"),
		[[text string] length]]];
}


#pragma mark -
#pragma mark NSWindow Delegate Methods


- (void)windowWillClose:(NSNotification *)aNotification
{
	if ([m_delegate respondsToSelector:@selector(smsControllerWindowWillClose:)]) {
		[m_delegate smsControllerWindowWillClose:self];
	}
}


@end
