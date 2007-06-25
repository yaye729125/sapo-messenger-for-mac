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
	
	// NIB Stuff
	IBOutlet WebView	*m_configurationFormWebView;
}

- initWithGroupChatController:(LPGroupChatController *)gcCtrl;

- (IBAction)ok:(id)sender;
- (IBAction)cancel:(id)sender;

@end
