//
//  LPJIDEntryView.m
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informa›es sobre o licenciamento, leia o ficheiro README.
//

#import "LPJIDEntryView.h"
#import "LPAccount.h"
#import "LPSapoAgents.h"


@interface LPJIDEntryView (Private)
- (void)p_synchronizeJIDTabViewWithSelectedService;
@end


@implementation LPJIDEntryView

- (id)initWithFrame:(NSRect)frameRect;
{
	if (self = [super initWithFrame:frameRect]) {
		if ([NSBundle loadNibNamed:@"JIDEntryView" owner:self]) {
			// Insert the loaded view into our bounds
			[m_assembledControlsView setFrame:[self bounds]];
			[self addSubview:m_assembledControlsView];
			[m_assembledControlsView release];
		}
		else {
			[self release];
			self = nil;
		}
	}
	return self;
}

- (void)dealloc
{
	[m_account release];
	[m_selectedServiceHostname release];
	[super dealloc];
}

- (void)awakeFromNib
{
	[self p_synchronizeJIDTabViewWithSelectedService];
}

- (id)delegate
{
	return m_delegate;
}

- (void)setDelegate:(id)delegate
{
	m_delegate = delegate;
	
	if ([m_delegate respondsToSelector:@selector(JIDEntryView:menuForSelectingJIDServiceWithAction:)]) {
		NSMenu *menuFromDelegate = [m_delegate JIDEntryView:self
					   menuForSelectingJIDServiceWithAction:@selector(serviceSelectionDidChange:)];
		
		[m_servicePopUp setMenu:menuFromDelegate];
		[self setSelectedServiceHostname:[[menuFromDelegate itemAtIndex:0] representedObject]];
	}
	else {
		[m_servicePopUp removeAllItems];
	}
}

- (LPAccount *)account
{
	return [[m_account retain] autorelease];
}

- (void)setAccount:(LPAccount *)account
{
	if (m_account != account) {
		[m_account release];
		m_account = [account retain];
		
		// A change of account implies a change in the sapo agents data. Update the tab view accordingly.
		[self p_synchronizeJIDTabViewWithSelectedService];
	}
}

- (NSString *)selectedServiceHostname
{
	return [[m_selectedServiceHostname copy] autorelease];
}

- (void)setSelectedServiceHostname:(NSString *)hostname
{
	if (hostname != m_selectedServiceHostname) {
		[m_selectedServiceHostname release];
		m_selectedServiceHostname = [hostname copy];
		
		[m_servicePopUp selectItemAtIndex:[m_servicePopUp indexOfItemWithRepresentedObject:m_selectedServiceHostname]];
		[self p_synchronizeJIDTabViewWithSelectedService];
	}
}

- (void)p_synchronizeJIDTabViewWithSelectedService
{
	LPSapoAgents *sapoAgents = [m_account sapoAgents];
	NSDictionary *sapoAgentsDict = [sapoAgents dictionaryRepresentation];
	NSDictionary *sapoAgentsProps = (([m_selectedServiceHostname length] > 0) ?
									 [sapoAgentsDict objectForKey:m_selectedServiceHostname] :
									 nil);
	
	if (sapoAgentsProps == nil) {
		[m_JIDTabView selectTabViewItemWithIdentifier:@"normal"];
		[m_normalJIDTextField setStringValue:@""];
		
		m_jidEntryTextField = m_normalJIDTextField;
	}
	else if ([sapoAgentsProps objectForKey:@"transport"] != nil) {
		
		if ([m_account isRegisteredWithTransportAgent:m_selectedServiceHostname]) {
			[m_JIDTabView selectTabViewItemWithIdentifier:@"transport"];
			[m_transportJIDTextField setStringValue:@""];
			[m_transportNameTextField setStringValue:[NSString stringWithFormat:@"(%@)", [sapoAgentsProps objectForKey:@"name"]]];
			
			m_jidEntryTextField = m_transportJIDTextField;
		}
		else {
			// Not registered
			[m_JIDTabView selectTabViewItemWithIdentifier:@"transport_not_registered"];
			m_jidEntryTextField = nil;
		}
	}
	else if ([[sapoAgentsProps objectForKey:@"service"] isEqualToString:@"phone"]) {
		[m_JIDTabView selectTabViewItemWithIdentifier:@"phone"];
		[m_phoneNrTextField setStringValue:@""];
		
		m_jidEntryTextField = m_phoneNrTextField;
	}
	else {
		[m_JIDTabView selectTabViewItemWithIdentifier:@"sapo"];
		[m_sapoJIDTextField setStringValue:@""];
		[m_sapoHostnameTextField setStringValue:m_selectedServiceHostname];
		
		m_jidEntryTextField = m_sapoJIDTextField;
	}
	
	
	if ([m_delegate respondsToSelector:@selector(JIDEntryViewEntryTextFieldDidChange:)]) {
		[m_delegate JIDEntryViewEntryTextFieldDidChange:self];
	}
	if ([m_delegate respondsToSelector:@selector(JIDEntryViewEnteredJIDDidChange:)]) {
		[m_delegate JIDEntryViewEnteredJIDDidChange:self];
	}
}

- (NSTextField *)JIDEntryTextField
{
	return m_jidEntryTextField;
}

- (NSString *)enteredJID
{
	LPSapoAgents *sapoAgents = [m_account sapoAgents];
	NSDictionary *sapoAgentsDict = [sapoAgents dictionaryRepresentation];
	NSDictionary *sapoAgentsProps = (([m_selectedServiceHostname length] > 0) ?
									 [sapoAgentsDict objectForKey:m_selectedServiceHostname] :
									 nil);
	
	if (sapoAgentsProps == nil) {
		return [m_normalJIDTextField stringValue];
	}
	else if ([sapoAgentsProps objectForKey:@"transport"] != nil) {
		
		if ([m_account isRegisteredWithTransportAgent:m_selectedServiceHostname]) {
			NSString *jid = [m_transportJIDTextField stringValue];
			NSArray *jidComponents = [jid componentsSeparatedByString:@"@"];
			
			return ( ([jidComponents count] >= 2) ?
					 [NSString stringWithFormat:@"%@%%%@@%@",
						 [jidComponents objectAtIndex:0], [jidComponents objectAtIndex:1], m_selectedServiceHostname] :
					 [NSString stringWithFormat:@"%@@%@",
						 jid, m_selectedServiceHostname] );
		}
		else {
			return @"";
		}
	}
	else if ([[sapoAgentsProps objectForKey:@"service"] isEqualToString:@"phone"]) {
		return [[m_phoneNrTextField stringValue] internalPhoneJIDRepresentation];
	}
	else {
		return [NSString stringWithFormat:@"%@@%@",
			[m_sapoJIDTextField stringValue],
			[m_sapoHostnameTextField stringValue]];
	}
	
	return nil;
}


#pragma mark -
#pragma mark NSControl Delegate


- (void)controlTextDidChange:(NSNotification *)aNotification
{
	if ([m_delegate respondsToSelector:@selector(JIDEntryViewEnteredJIDDidChange:)]) {
		[m_delegate JIDEntryViewEnteredJIDDidChange:self];
	}
}


#pragma mark -
#pragma mark Actions


- (IBAction)serviceSelectionDidChange:(id)sender
{
	[self setSelectedServiceHostname:[sender representedObject]];
}


@end

