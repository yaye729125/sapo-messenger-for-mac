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
	
	// Set up some state.
	[self setWindowFrameAutosaveName:@"LPXmlConsoleWindow"];
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
	if (m_enabled)
	{
		NSFont		*font = [NSFont userFixedPitchFontOfSize:10.0];
		NSString	*colorKey;
		NSData		*colorData;
		NSColor		*color;
		
		colorKey = (isInbound) ? @"ChatFriendColor" : @"ChatMyColor";
		colorData =  [[NSUserDefaults standardUserDefaults] dataForKey:colorKey];
		color = [NSUnarchiver unarchiveObjectWithData:colorData];
		
		if (![string isEqualToString:@""])
		{
			// Create the attributed string.
			NSAttributedString *attributedXml = [NSAttributedString attributedStringFromString:string 
																						  font:font 
																						 color:color];
			
			// Append the string, with a linebreak or two.
			[[m_xmlTextView textStorage] appendAttributedString:[NSAttributedString attributedStringFromString:@"\n\n"]];
			[[m_xmlTextView textStorage] appendAttributedString:attributedXml];
		}
		else NSLog(@"WARNING: Console encountered empty string.");
		
		// Scroll to bottom of view.
		[m_xmlTextView scrollRangeToVisible:NSMakeRange([[m_xmlTextView textStorage] length], 0)];
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
