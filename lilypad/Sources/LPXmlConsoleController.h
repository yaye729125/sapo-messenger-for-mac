//
//  LPXmlConsoleController.h
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Authors: Joao Pavao <jpavao@co.sapo.pt>
//           Jason Kim <jason@512k.org>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import <Cocoa/Cocoa.h>


@class LPAccount;


@interface LPXmlConsoleController : NSWindowController 
{
	IBOutlet NSWindow		*m_inputSheet;
	IBOutlet NSTextView		*m_xmlTextView;
	IBOutlet NSTextView		*m_inputTextView;
	IBOutlet NSButton		*m_enableCheckbox;
	IBOutlet NSButton		*m_inputSendButton;
	IBOutlet NSTextField	*m_invalidXMLLabel;
	
	BOOL					m_enabled;
	BOOL					m_checkXML;
	LPAccount				*m_account;
	
	// Keeps the most recent XML Stanzas
	NSMutableArray			*m_recentXMLStanzasBuffer;
}

- initWithAccount:(LPAccount *)account;

- (IBAction)clear:(id)sender;
- (IBAction)save:(id)sender;
- (IBAction)showInputSheet:(id)sender;
- (IBAction)inputSheetOK:(id)sender;
- (IBAction)inputSheetCancel:(id)sender;

- (BOOL)isLoggingEnabled;
- (void)setLoggingEnabled:(BOOL)flag;
- (BOOL)isXMLCheckEnabled;
- (void)setXMLCheckEnabled:(BOOL)flag;

- (NSAttributedString *)attributedStringForConsoleFromXMLString:(NSString *)string inbound:(BOOL)isInbound;
- (void)appendXMLString:(NSString *)string inbound:(BOOL)isInbound;

@end

