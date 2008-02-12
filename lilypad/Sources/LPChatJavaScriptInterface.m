//
//  LPChatJavaScriptInterface.m
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jpavao@co.sapo.pt>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "LPChatJavaScriptInterface.h"
#import "LPAccount.h"
#import "LPFileTransfer.h"
#import "LPFileTransfersManager.h"


@implementation LPChatJavaScriptInterface

- (void)dealloc
{
	[m_account release];
	[super dealloc];
}


- (LPAccount *)account
{
	return [[m_account retain] autorelease];
}

- (void)setAccount:(LPAccount *)account
{
	if (account != m_account) {
		[m_account release];
		m_account = [account retain];
	}
}


#pragma mark -
#pragma mark JavaScript Methods


- (void)p_openURLString:(NSString *)theURLString
{
	/* This is the method that is invoked from the WebView's javascript links to open their corresponding URLs.
	If we used simple <a href="..."></a> URLs instead of a method invoked through javascript, then web pages
	would be loaded inside the chat window's WebView and that's not what we want to happen! */
	
	/* The URL string coming from javascript was already unescaped before being delivered to us. But we need it
	escaped in order to be a valid URL. Don't escape "#", used to represent HTML anchors. */
	CFStringRef escapedURLStr = CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault,
																		(CFStringRef)theURLString,
																		CFSTR("#"),
																		NULL,
																		kCFStringEncodingUTF8);
	
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:(NSString *)escapedURLStr]];
	CFRelease(escapedURLStr);
}


- (void)p_acceptFileTransferWithID:(int)transferID
{
	LPFileTransfer *ft = [[LPFileTransfersManager fileTransfersManager] fileTransferForID:transferID];
	[ft acceptIncomingFileTransfer:YES];
}


- (void)p_rejectFileTransferWithID:(int)transferID
{
	LPFileTransfer *ft = [[LPFileTransfersManager fileTransfersManager] fileTransferForID:transferID];
	[ft acceptIncomingFileTransfer:NO];
}


- (void)p_revealFileForFileTransferWithID:(int)transferID
{
	LPFileTransfer *ft = [[LPFileTransfersManager fileTransfersManager] fileTransferForID:transferID];
	[[NSWorkspace sharedWorkspace] selectFile:[ft localFilePath] inFileViewerRootedAtPath:@""];
}


- (void)p_openFileForFileTransferWithID:(int)transferID
{
	LPFileTransfer *ft = [[LPFileTransfersManager fileTransfersManager] fileTransferForID:transferID];
	[[NSWorkspace sharedWorkspace] openFile:[ft localFilePath]];
}


#pragma mark -
#pragma mark WebScripting Protocol Methods


+ (NSString *)webScriptNameForSelector:(SEL)aSelector
{
	if (aSelector == @selector(p_openURLString:))
		return @"openURL";
	else if (aSelector == @selector(p_acceptFileTransferWithID:))
		return @"acceptTransfer";
	else if (aSelector == @selector(p_rejectFileTransferWithID:))
		return @"rejectTransfer";
	else if (aSelector == @selector(p_revealFileForFileTransferWithID:))
		return @"revealFileOfTransfer";
	else if (aSelector == @selector(p_openFileForFileTransferWithID:))
		return @"openFileOfTransfer";
	else
		return nil;
}


+ (BOOL)isSelectorExcludedFromWebScript:(SEL)aSelector
{
	if (aSelector == @selector(p_openURLString:) ||
		aSelector == @selector(p_acceptFileTransferWithID:) ||
		aSelector == @selector(p_rejectFileTransferWithID:) ||
		aSelector == @selector(p_revealFileForFileTransferWithID:) ||
		aSelector == @selector(p_openFileForFileTransferWithID:))
	{
		return NO;
	}
	else
		return YES;
}


+ (BOOL)isKeyExcludedFromWebScript:(const char *)name
{
	return YES;
}

@end
