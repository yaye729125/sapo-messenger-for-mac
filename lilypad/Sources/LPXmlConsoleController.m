//
//  LPXmlConsoleController.m
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Authors: Joao Pavao <jpavao@co.sapo.pt>
//           Jason Kim <jason@512k.org>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "LPXmlConsoleController.h"
#import "NSAttributedString+FactoryAdditions.h"
#import "LPAccount.h"


@implementation LPXmlConsoleController


- initWithAccount:(LPAccount *)account
{
	if (self = [self initWithWindowNibName:@"XMLConsole"]) {
		m_account = [account retain];

		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(accountDidSendOrReceiveXMLString:)
													 name:LPAccountDidReceiveXMLStringNotification
												   object:account];
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(accountDidSendOrReceiveXMLString:)
													 name:LPAccountDidSendXMLStringNotification
												   object:account];
	}
	return self;
}


- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[m_account release];
	[super dealloc];
}


- (void)windowDidLoad
{
	[[self window] setTitle:[NSString stringWithFormat:@"XML Console for Account \"%@\" (%@)",
							 [m_account description], [m_account JID]]];
	
	// Set up the toolbar
	NSToolbar *tb = [[NSToolbar alloc] initWithIdentifier:@"XMLConsoleToolbar"];
	[tb setDelegate:self];
	[tb setAllowsUserCustomization:YES];
	[tb setAutosavesConfiguration:YES];
	[[self window] setToolbar:tb];
	[tb release];
	
	// Set up some state.
	[self setWindowFrameAutosaveName:@"LPXmlConsoleWindow"];
}


#pragma mark -
#pragma mark Toolbar Delegate Methods


- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar
{
	return [NSArray arrayWithObjects:
			@"XMLConsoleToolbarItemEnabled",
			NSToolbarSeparatorItemIdentifier,
			@"XMLConsoleToolbarItemSendXML",
			NSToolbarFlexibleSpaceItemIdentifier,
			@"XMLConsoleToolbarItemSave",
			NSToolbarSeparatorItemIdentifier,
			@"XMLConsoleToolbarItemClear",
			nil];
}


- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar
{
	return [NSArray arrayWithObjects:
			@"XMLConsoleToolbarItemEnabled",
			@"XMLConsoleToolbarItemSendXML",
			@"XMLConsoleToolbarItemSave",
			@"XMLConsoleToolbarItemClear",
			NSToolbarCustomizeToolbarItemIdentifier,
			NSToolbarFlexibleSpaceItemIdentifier,
			NSToolbarSeparatorItemIdentifier,
			NSToolbarSpaceItemIdentifier,
			nil];
}


- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)identifier willBeInsertedIntoToolbar:(BOOL)willBeInserted 
{
	// Create our toolbar items.
    NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:identifier];
	
	if ([identifier isEqualToString:@"XMLConsoleToolbarItemEnabled"])
	{
		[item setPaletteLabel:NSLocalizedString(@"Enable/Disable Logging", @"toolbar button label")];
		[item setView:m_enableCheckbox];
		[item setMinSize:[m_enableCheckbox frame].size];
		[item setMaxSize:[m_enableCheckbox frame].size];
		[item setToolTip:NSLocalizedString(@"Enable the logging of sent and received XML messages.", @"toolbar button")];
	}
	else if ([identifier isEqualToString:@"XMLConsoleToolbarItemClear"])
	{
		[item setLabel:NSLocalizedString(@"Clear", @"toolbar button label")];
		[item setPaletteLabel:NSLocalizedString(@"Clear Console", @"toolbar button label")];
		[item setImage:[NSImage imageNamed:@"clear_log.tiff"]];
		[item setToolTip:NSLocalizedString(@"Clear the console log.", @"toolbar button")];
		[item setAction:@selector(clear:)];
		[item setTarget:self];
	}
	else if ([identifier isEqualToString:@"XMLConsoleToolbarItemSave"])
	{
		[item setLabel:NSLocalizedString(@"Save to File", @"toolbar button label")];
		[item setPaletteLabel:NSLocalizedString(@"Save to File", @"toolbar button label")];
		[item setImage:[NSImage imageNamed:@"save_log.icns"]];
		[item setToolTip:NSLocalizedString(@"Save the console log to a file.", @"toolbar button")];
		[item setAction:@selector(save:)];
		[item setTarget:self];
	}
	else if ([identifier isEqualToString:@"XMLConsoleToolbarItemSendXML"])
	{
		[item setLabel:NSLocalizedString(@"Send XML", @"toolbar button label")];
		[item setPaletteLabel:NSLocalizedString(@"Send XML", @"toolbar button label")];
		[item setImage:[NSImage imageNamed:@"send_xml.tiff"]];
		[item setToolTip:NSLocalizedString(@"Send an XML stanza.", @"toolbar button")];
		[item setAction:@selector(showInputSheet:)];
		[item setTarget:self];
	}
	
	return [item autorelease];
}


#pragma mark -
#pragma mark Actions


- (IBAction)clear:(id)sender
{
	[m_xmlTextView setString:@""];
}


- (IBAction)save:(id)sender
{
	NSSavePanel *savePanel = [NSSavePanel savePanel];
	[savePanel beginSheetForDirectory:nil
								 file:@"xmpplog.rtfd" 
					   modalForWindow:[self window] 
						modalDelegate:self 
					   didEndSelector:@selector(savePanelDidEnd:returnCode:contextInfo:) 
						  contextInfo:nil];
}


- (IBAction)showInputSheet:(id)sender
{
	NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSFont userFixedPitchFontOfSize:10.0], NSFontAttributeName,
		nil];
	
	// This must be done to avoid reverting to Helvetica 12pt.
	[m_inputTextView setString:@""];
	[m_inputTextView setTypingAttributes:attributes];
	
	// Show the input sheet.
	[NSApp beginSheet:m_inputSheet
	   modalForWindow:[self window]
		modalDelegate:self
	   didEndSelector:@selector(inputSheetDidEnd:returnCode:contextInfo:)
		  contextInfo:nil];
}


- (IBAction)inputSheetOK:(id)sender
{
	[m_account sendXMLString:[m_inputTextView string]];
	[NSApp endSheet:m_inputSheet];
}


- (IBAction)inputSheetCancel:(id)sender
{
	[NSApp endSheet:m_inputSheet];
}


#pragma mark -
#pragma mark Instance Methods

- (BOOL)isLoggingEnabled
{
	return m_enabled;
}

- (void)setLoggingEnabled:(BOOL)flag
{
	m_enabled = flag;
}

- (void)appendXmlString:(NSString *)string inbound:(BOOL)isInbound
{
	if (m_enabled) {
		NSTextStorage	*textStorage = [m_xmlTextView textStorage];
		BOOL			wasScrolledToBottom = (NSMaxY([m_xmlTextView visibleRect]) >=
											   (NSMaxY([m_xmlTextView bounds]) - 30.0));
		
		NSFont		*font = [NSFont userFixedPitchFontOfSize:10.0];
		NSString	*colorKey = (isInbound ? @"ChatFriendColor" : @"ChatMyColor");
		NSData		*colorData = [[NSUserDefaults standardUserDefaults] dataForKey:colorKey];
		NSColor		*color = [NSUnarchiver unarchiveObjectWithData:colorData];
		
		if (![string isEqualToString:@""]) {
			// Create the attributed string.
			NSAttributedString *attributedXml = [NSAttributedString attributedStringFromString:string 
																						  font:font 
																						 color:color];
			// Append the string, with a linebreak or two.
			[textStorage beginEditing];
			[textStorage appendAttributedString:[NSAttributedString attributedStringFromString:@"\n\n"]];
			[textStorage appendAttributedString:attributedXml];
			[textStorage endEditing];
		}
		else {
			NSLog(@"WARNING: Console encountered empty string.");
		}
		
		// Auto-Scroll to the bottom of the content view, but only if we were already at the bottom.
		if (wasScrolledToBottom) {
			[m_xmlTextView scrollRangeToVisible:NSMakeRange([textStorage length], 0)];
		}
	}
}


#pragma mark -
#pragma mark Input Sheet Delegate


- (void)savePanelDidEnd:(NSSavePanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	[m_xmlTextView writeRTFDToFile:[sheet filename] atomically:YES];	
}

- (void)inputSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	[m_inputSheet orderOut:self];
}


#pragma mark -
#pragma mark Account Notification Methods


- (void)accountDidSendOrReceiveXMLString:(NSNotification *)notification
{
	[self appendXmlString:[[notification userInfo] objectForKey:LPXMLString]
				  inbound:[[notification name] isEqualToString:LPAccountDidReceiveXMLStringNotification]];
}


@end
