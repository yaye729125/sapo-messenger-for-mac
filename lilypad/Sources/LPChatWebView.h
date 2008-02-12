//
//  LPChatWebView.h
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jpavao@co.sapo.pt>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>


@class LPChat;


@interface LPChatWebView : WebView
{
	BOOL		m_acceptsDroppingOfFiles;
	NSColor		*m_previousBGColor;
	NSColor		*m_highlightBGColor;
	LPChat		*m_chat;
}
- (LPChat *)chat;
- (void)setChat:(LPChat *)chat;
- (NSColor *)backgroundColor;
- (void)setBackgroundColor:(NSColor *)backgroundColor;
@end
