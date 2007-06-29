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
#import "LPGroupChat.h"
#import "LPGroupChatContact.h"
#import "NSString+HTMLAdditions.h"


// See http://lists.apple.com/archives/Webkitsdk-dev/2005/Apr/msg00065.html
@interface WebView (TransparentBackgroundHack)
- (void)setDrawsBackground:(BOOL)drawsBackround;
- (BOOL)drawsBackground;
@end


// Just a method from our group chat window controller friend that is handy in here
@interface LPGroupChatController (Private)
- (void)p_appendSystemMessage:(NSString *)msg;
@end


@implementation LPGroupChatConfigController

- initWithGroupChatController:(LPGroupChatController *)gcCtrl
{
	if (self = [self initWithWindowNibName:@"GroupChatConfig"]) {
		m_groupChatController = gcCtrl;
		
		[[m_groupChatController groupChat] addObserver:self
											forKeyPath:@"configurationForm"
											   options:0 context:NULL];
	}
	return self;
}


- (void)dealloc
{
	[[m_groupChatController groupChat] removeObserver:self forKeyPath:@"configurationForm"];
	[m_configurationXMLDocument release];
	[super dealloc];
}


- (void)awakeFromNib
{
	// See http://lists.apple.com/archives/Webkitsdk-dev/2005/Apr/msg00065.html
	[m_configurationFormWebView setDrawsBackground:NO];
	
	// Let's wait for the configuration form to arrive from the server before enabling the OK button
	[m_okButton setEnabled:NO];
}


- (void)reloadConfigurationForm
{
	[[m_groupChatController groupChat] reloadRoomConfigurationForm];
	
	NSString *htmlStr = @"<html><body style=\"font: 13px 'Lucida Grande'\"><center>Reloading the available configuration settings...</center></body></html>";
	
	// Force the loading of the window so that we can set the content of the WebView
	// before the window is displayed on-screen for the first time.
	[self window];
	[[m_configurationFormWebView mainFrame] loadHTMLString:htmlStr baseURL:nil];
	[m_configurationFormWebView display];
	
	[m_progressIndicator startAnimation:nil];
	
	// Let's wait for the configuration form to arrive from the server before enabling the OK button
	[m_okButton setEnabled:NO];
}


- (void)takeReceivedRoomConfigurationForm:(NSString *)configFormXML errorMessage:(NSString *)errorMsg
{
	NSString *htmlStr = nil;
	
	if ([configFormXML length] == 0) {
		htmlStr = [NSString stringWithFormat:@"<html><body style=\"font: 13px 'Lucida Grande'\"><center>Failed to load configuration form from the server!<br/><br/>Error: %@</center></body></html>",
			(errorMsg ? [errorMsg stringByEscapingHTMLEntities] : @"")];
	}
	else {
		NSError *err = nil;
		
		[m_configurationXMLDocument release];
		m_configurationXMLDocument = [[NSXMLDocument alloc] initWithXMLString:configFormXML
																	  options:NSXMLDocumentTidyXML
																		error:&err];
		
		NSString	*xsltPath = [[NSBundle mainBundle] pathForResource:@"ChatRoomConfiguration" ofType:@"xsl"];
		NSURL		*xsltURL = [NSURL fileURLWithPath:xsltPath];
		
		id transformedStuff = [m_configurationXMLDocument objectByApplyingXSLTAtURL:xsltURL arguments:nil error:&err];
		
		htmlStr = [transformedStuff XMLString];
		
		[m_okButton setEnabled:YES];
	}
	
	[[m_configurationFormWebView mainFrame] loadHTMLString:htmlStr baseURL:nil];
	[m_progressIndicator stopAnimation:nil];
}


- (void)takeResultOfRoomConfigurationModification:(BOOL)succeeded errorMessage:(NSString *)errorMsg
{
	if (succeeded) {
		[m_groupChatController p_appendSystemMessage:
			NSLocalizedString(@"Chat room configuration was changed successfully.", @"chat room configuration")];
	}
	else {
		[m_groupChatController p_appendSystemMessage:
			[NSString stringWithFormat:
				NSLocalizedString(@"Chat room configuration failed. Error: %@", @"chat room configuration"),
				(errorMsg ? errorMsg : @"??")]];
	}
}


- (IBAction)ok:(id)sender
{
	NSError *err;
	NSArray *fieldXMLNodes = [m_configurationXMLDocument nodesForXPath:@"x/field[@type != 'hidden']" error:&err];
	
	// Let's iterate over the original nodes in the XML configuration form we received from the jabber server
	NSEnumerator *fieldEnumerator = [fieldXMLNodes objectEnumerator];
	id node;
	
	while (node = [fieldEnumerator nextObject]) {
		NSString *varName = [[node attributeForName:@"var"] stringValue];
		
		DOMDocument *configSheetDOMDoc = [[m_configurationFormWebView mainFrame] DOMDocument];
		id fieldDOMElement = [configSheetDOMDoc getElementById:varName];
		
		// fieldDOMElement is now the HTML DOM element that corresponds to the XML form node of the current iteration
		
		NSString *currentFieldDOMValue = nil;
		
		if ([fieldDOMElement isKindOfClass:[DOMHTMLInputElement class]] && [[(DOMHTMLInputElement *)fieldDOMElement type] isEqualToString:@"checkbox"]) {
			currentFieldDOMValue = ([fieldDOMElement checked] ? @"1" : @"0");
		}
		else {
			currentFieldDOMValue = [fieldDOMElement value];
		}
		
		// Get the <value/> node inside the current XML form node so that we can set its value
		NSArray *valueXMLNodes = [node nodesForXPath:@"value" error:&err];
		
		if ([valueXMLNodes count] > 0) {
			[[valueXMLNodes objectAtIndex:0] setStringValue:currentFieldDOMValue];
		}
	}
	
	// Submit the updated XML form to the server
	NSString *updatedXMLFormStr = [m_configurationXMLDocument XMLStringWithOptions: NSXMLNodePrettyPrint];
	[[m_groupChatController groupChat] submitRoomConfigurationForm: updatedXMLFormStr ];
	
	[NSApp endSheet:[self window]];
	[[self window] orderOut:nil];
}


- (IBAction)cancel:(id)sender;
{
	[m_groupChatController actionSheetCancelClicked:sender];
}


#pragma mark -
#pragma mark WebView Frame Load Delegate


- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame
{
	if (frame == [sender mainFrame]) {
		// Make the WebView size to fit its contents
		NSView *documentView = [[[sender mainFrame] frameView] documentView];
		NSView *containingView = [sender superview];
		NSRect prevFrame = [sender frame];
		NSRect targetFrame = [containingView convertRect:[documentView bounds] fromView:documentView];
		
		NSSize sizeDelta = {
			NSWidth(targetFrame) - NSWidth(prevFrame),
			NSHeight(targetFrame) - NSHeight(prevFrame),
		};
		
		NSWindow *win = [containingView window];
		NSRect winFrame = [win frame];
		
		winFrame.origin.x -= (sizeDelta.width / 2.0);
		winFrame.origin.y -= sizeDelta.height;
		winFrame.size.width += sizeDelta.width;
		winFrame.size.height += sizeDelta.height;
		
		[win setFrame:winFrame display:YES animate:YES];
	}
}


@end
