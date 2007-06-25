//
//  LPGroupChatConfigController.m
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "LPGroupChatConfigController.h"
#import "LPGroupChatController.h"


// See http://lists.apple.com/archives/Webkitsdk-dev/2005/Apr/msg00065.html
@interface WebView (TransparentBackgroundHack)
- (void)setDrawsBackground:(BOOL)drawsBackround;
- (BOOL)drawsBackground;
@end


@implementation LPGroupChatConfigController

- initWithGroupChatController:(LPGroupChatController *)gcCtrl
{
	if (self = [self initWithWindowNibName:@"GroupChatConfig"]) {
		m_groupChatController = gcCtrl;
	}
	return self;
}


- (void)awakeFromNib
{
	// See http://lists.apple.com/archives/Webkitsdk-dev/2005/Apr/msg00065.html
	[m_configurationFormWebView setDrawsBackground:NO];
}


- (IBAction)ok:(id)sender
{
	NSLog(@"CONF OK");
}


- (IBAction)cancel:(id)sender;
{
	[m_groupChatController actionSheetCancelClicked:sender];
}

@end
