//
//  LPGroupChatConfigController.h
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

@class LPGroupChatController;


@interface LPGroupChatConfigController : NSWindowController
{
	LPGroupChatController	*m_groupChatController;
	
	NSXMLDocument			*m_configurationXMLDocument;
	
	// NIB Stuff
	IBOutlet WebView				*m_configurationFormWebView;
	IBOutlet NSProgressIndicator	*m_progressIndicator;
	IBOutlet NSButton				*m_okButton;
}

- initWithGroupChatController:(LPGroupChatController *)gcCtrl;

- (void)reloadConfigurationForm;
- (void)takeReceivedRoomConfigurationForm:(NSString *)configFormXML errorMessage:(NSString *)errorMsg;
- (void)takeResultOfRoomConfigurationModification:(BOOL)succeeded errorMessage:(NSString *)errorMsg;

- (IBAction)ok:(id)sender;
- (IBAction)cancel:(id)sender;

@end
