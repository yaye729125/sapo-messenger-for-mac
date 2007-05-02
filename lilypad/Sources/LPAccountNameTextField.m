//
//  LPAccountNameTextField.m
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informa›es sobre o licenciamento, leia o ficheiro README.
//

#import "LPAccountNameTextField.h"


@implementation LPAccountNameTextField

- (void)dealloc
{
	[m_name release];
	[m_jid release];
	[super dealloc];
}

- (void)p_updateDisplay
{
	if (m_currentState == LPShowAccountName && m_name != nil && [m_name length] > 0) {
		[self setStringValue:m_name];
	}
	else if (m_jid != nil && [m_jid length] > 0) {
		[self setStringValue:m_jid];
	}
	else {
		[self setStringValue:@"--"];
	}
}

- (NSString *)accountName
{
	return [[m_name copy] autorelease];
}

- (void)setAccountName:(NSString *)name
{
	if (name != m_name) {
		[m_name release];
		m_name = [name copy];
		
		if (m_currentState == LPShowAccountName) {
			[self p_updateDisplay];
		}
	}
}

- (NSString *)accountJID
{
	return [[m_jid copy] autorelease];
}

- (void)setAccountJID:(NSString *)jid
{
	if (jid != m_jid) {
		[m_jid release];
		m_jid = [jid copy];
		
		// The mode doesn't matter. Even if we're not in the "show jid" mode, if the account name
		// is empty we have to display the JID anyway. So, always update the display.
		[self p_updateDisplay];
	}
}

- (void)mouseDown:(NSEvent *)theEvent
{
	[self toggleDisplay:nil];
}

- (IBAction)toggleDisplay:(id)sender
{
	if (m_currentState == LPShowAccountName &&
		m_jid != nil && [m_jid length] > 0 &&
		m_name != nil && [m_name length] > 0)
	{
		// Only change out of the LPShowAccountName state if there is an account name to be shown
		// and the mode switch can be actually visible in the GUI.
		m_currentState = LPShowAccountJID;
	}
	else if (m_currentState == LPShowAccountJID && m_name != nil && [m_name length] > 0)
	{
		m_currentState = LPShowAccountName;
	}
	
	[self p_updateDisplay];
}

@end
