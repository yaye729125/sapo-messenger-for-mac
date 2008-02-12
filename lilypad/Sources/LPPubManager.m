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

- init
{
	if (self = [super init]) {
		m_chatBotsConnections = [[NSMutableDictionary alloc] init];
	}
	return self;
}

- (void)dealloc
{
	[m_mainPubURL release];
	[m_statusPhraseHTML release];
	[m_chatBotsURLStr release];
	
	[m_statusPhraseConnection cancel];
	[m_statusPhraseConnection release];
    [m_statusPhraseConnectionData release];
	
	NSArray *connections = [[m_chatBotsConnections allKeys] valueForKey:@"nonretainedObjectValue"];
	[connections makeObjectsPerformSelector:@selector(cancel)];
	[connections makeObjectsPerformSelector:@selector(release)];
	[m_chatBotsConnections release];
	
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


- (void)fetchHTMLForChatBot:(NSString *)chatBot delegate:(id)delegate didEndSelector:(SEL)sel
{
	NSString *chatBotURL = [m_chatBotsURLStr stringByAppendingFormat:@"&bot=%@&subchan=msg_passatempos",
		chatBot];
	
	NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:chatBotURL]];
	NSURLConnection *conn = [[NSURLConnection alloc] initWithRequest:request delegate:self];
	
	if (conn) {
		NSDictionary *connInfo = [NSDictionary dictionaryWithObjectsAndKeys:
			[NSMutableData data], @"ConnectionData",
			delegate, @"Delegate",
			[NSValue valueWithPointer:sel], @"DidEndSel",
			nil];
		[m_chatBotsConnections setObject:connInfo forKey:[NSValue valueWithNonretainedObject:conn]];
	}
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
	if (URLString != m_chatBotsURLStr) {
		[m_chatBotsURLStr release];
		m_chatBotsURLStr = [URLString copy];
	}
}


#pragma mark -
#pragma mark NSURLConnection Delegate Methods


- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
	if (connection == m_statusPhraseConnection)
		[m_statusPhraseConnectionData setLength:0];
	else {
		NSValue *connValue = [NSValue valueWithNonretainedObject:connection];
		NSDictionary *connInfo = [m_chatBotsConnections objectForKey:connValue];
		if (connInfo) {
			[[connInfo objectForKey:@"ConnectionData"] setLength:0];
		}
	}
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    // append the new data to the receivedData
	if (connection == m_statusPhraseConnection)
		[m_statusPhraseConnectionData appendData:data];
	else {
		NSValue *connValue = [NSValue valueWithNonretainedObject:connection];
		NSDictionary *connInfo = [m_chatBotsConnections objectForKey:connValue];
		if (connInfo) {
			[[connInfo objectForKey:@"ConnectionData"] appendData:data];
		}
	}
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
	if (connection == m_statusPhraseConnection) {
		[m_statusPhraseConnection release]; m_statusPhraseConnection = nil;
		[m_statusPhraseConnectionData release]; m_statusPhraseConnectionData = nil;
	}
	else {
		NSValue *connValue = [NSValue valueWithNonretainedObject:connection];
		if ([m_chatBotsConnections objectForKey:connValue] != nil) {
			[m_chatBotsConnections removeObjectForKey:connValue];
			[connection release];
		}
	}
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
	if (connection == m_statusPhraseConnection) {
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
	else {
		NSValue *connValue = [NSValue valueWithNonretainedObject:connection];
		NSDictionary *connInfo = [m_chatBotsConnections objectForKey:connValue];
		
		if (connInfo != nil) {
			NSData *connData = [connInfo objectForKey:@"ConnectionData"];
			id delegate = [connInfo objectForKey:@"Delegate"];
			SEL sel = [[connInfo objectForKey:@"DidEndSel"] pointerValue];
			
			NSString *connectionDataString = [[NSString alloc] initWithData:connData
																   encoding:NSUTF8StringEncoding];
			NSString *htmlCode = [NSString stringWithFormat:
				@"<html><body style=\"margin: 0; padding: 0;\"><script language=\"javascript\">\n\n%@\n\n</script></body></html>",
				connectionDataString];
			[connectionDataString release];
			
			[delegate performSelector:sel withObject:htmlCode];
			
			[m_chatBotsConnections removeObjectForKey:connValue];
			[connection release];
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
