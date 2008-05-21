//
//  LPPubManager.m
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jpavao@co.sapo.pt>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "LPPubManager.h"


@implementation LPPubManager

- (void)dealloc
{
	[m_mainPubURL release];
	[m_statusPhraseHTML release];
	[m_chatBotAdsBaseURL release];
	
	[m_statusPhraseConnection cancel];
	[m_statusPhraseConnection release];
    [m_statusPhraseConnectionData release];
	
	[super dealloc];
}


#pragma mark -
#pragma mark Accessors


- (NSURL *)mainPubURL
{
	return [[m_mainPubURL copy] autorelease];
}

- (void)setMainPubURL:(NSURL *)url
{
	if (url != m_mainPubURL) {
		[m_mainPubURL release];
		m_mainPubURL = [url copy];
	}
}


- (NSString *)statusPhraseHTML
{
	return [[m_statusPhraseHTML copy] autorelease];
}

- (void)setStatusPhraseHTML:(NSString *)html
{
	if (html != m_statusPhraseHTML) {
		[m_statusPhraseHTML release];
		m_statusPhraseHTML = [html copy];
	}
}


- (NSURL *)chatBotAdsBaseURL
{
	return [[m_chatBotAdsBaseURL copy] autorelease];
}

- (void)setChatBotAdsBaseURL:(NSURL *)baseChatBotsURL
{
	if (m_chatBotAdsBaseURL != baseChatBotsURL) {
		[m_chatBotAdsBaseURL release];
		m_chatBotAdsBaseURL = [baseChatBotsURL copy];
	}
}


- (NSURL *)chatBotAdURLForBotWithJID:(NSString *)botJID
{
	NSString *theURLString = [[m_chatBotAdsBaseURL absoluteString] stringByAppendingFormat:
							  @"&bot=%@&subchan=msg_passatempos", botJID];
	
	return ([theURLString length] == 0 ? nil : [NSURL URLWithString:theURLString]);
}


#pragma mark -
#pragma mark Private Methods


- (void)p_setMainPubScriptURL:(NSString *)URLString
{
	CFStringRef escapedURLStr = CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault,
																		(CFStringRef)URLString,
																		NULL,
																		CFSTR("?&=+"),
																		kCFStringEncodingUTF8);
	
	[self setMainPubURL:[NSURL URLWithString:[NSString stringWithFormat:
		@"http://messenger.sapo.pt/code/pub.php?url=%@",
		(NSString *)escapedURLStr]]];
	
	if (escapedURLStr != NULL)
		CFRelease(escapedURLStr);
}

- (void)p_setStatusPhraseURL:(NSString *)URLString
{
	[m_statusPhraseConnection cancel];
	[m_statusPhraseConnection release]; m_statusPhraseConnection = nil;
    [m_statusPhraseConnectionData release]; m_statusPhraseConnectionData = nil;
	
	NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:URLString]];
	NSURLConnection *conn = [[NSURLConnection alloc] initWithRequest:request delegate:self];
	
	if (conn) {
		m_statusPhraseConnection = conn;
		m_statusPhraseConnectionData = [[NSMutableData alloc] init];
	}
}

- (void)p_setChatBotsPubURL:(NSString *)URLString
{
	CFStringRef escapedURLStr = CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault,
																		(CFStringRef)URLString,
																		NULL,
																		CFSTR("?&=+"),
																		kCFStringEncodingUTF8);
	
	[self setChatBotAdsBaseURL:[NSURL URLWithString:[NSString stringWithFormat:
													 @"http://messenger.sapo.pt/code/pub.php?url=%@",
													 (NSString *)escapedURLStr]]];
	
	if (escapedURLStr != NULL)
		CFRelease(escapedURLStr);
}


#pragma mark -
#pragma mark NSURLConnection Delegate Methods


- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
	if (connection == m_statusPhraseConnection) {
		if ([response isKindOfClass:[NSHTTPURLResponse class]] && [(NSHTTPURLResponse *)response statusCode] >= 400) {
			[m_statusPhraseConnectionData release];
			m_statusPhraseConnectionData = nil;
		}
		else {
			[m_statusPhraseConnectionData setLength:0];
		}
	}
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    // append the new data to the receivedData
	if (connection == m_statusPhraseConnection)
		[m_statusPhraseConnectionData appendData:data];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
	if (connection == m_statusPhraseConnection) {
		[m_statusPhraseConnection release]; m_statusPhraseConnection = nil;
		[m_statusPhraseConnectionData release]; m_statusPhraseConnectionData = nil;
	}
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
	if (connection == m_statusPhraseConnection) {
		if ([m_statusPhraseConnectionData length] > 0) {
			NSString *connectionDataString = [[NSString alloc] initWithData:m_statusPhraseConnectionData
																   encoding:NSUTF8StringEncoding];
			NSString *htmlCode = [NSString stringWithFormat:
								  @"<html><body link=\"#222\" style=\"margin: 0; padding: 0; font: 11px 'Lucida Grande';\"><div style=\"text-align: center; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; -webkit-text-overflow: ellipsis; \">%@</div></body></html>",
								  connectionDataString];
			[connectionDataString release];
			
			[self setStatusPhraseHTML:htmlCode];
			
			[m_statusPhraseConnection release]; m_statusPhraseConnection = nil;
			[m_statusPhraseConnectionData release]; m_statusPhraseConnectionData = nil;
		}
	}
}


#pragma mark -


- (void)handleUpdatedServerVars:(NSDictionary *)varsAndValues
{
	NSString *mainPub = [varsAndValues objectForKey:@"url.pub.main"];
	NSString *statusPhrase = [varsAndValues objectForKey:@"url.pub.statusphrase"];
	NSString *chatBotsPub = [varsAndValues objectForKey:@"url.pub.chatbots"];
	
	if (mainPub)
		[self p_setMainPubScriptURL:[mainPub stringByAppendingString:@"&appbrand=Sapo"]];
	if (statusPhrase)
		[self p_setStatusPhraseURL:[statusPhrase stringByAppendingString:@"&appbrand=Sapo"]];
	if (chatBotsPub)
		[self p_setChatBotsPubURL:chatBotsPub];
}


@end
