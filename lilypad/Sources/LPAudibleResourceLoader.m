//
//  LPAudibleResourceLoader.m
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informa›es sobre o licenciamento, leia o ficheiro README.
//

#import "LPAudibleResourceLoader.h"


@implementation LPAudibleResourceLoader

+ loaderWithResourceName:(NSString *)resourceName ofType:(NSString *)type baseURL:(NSURL *)baseURL delegate:(id)delegate
{
	return [[[[self class] alloc] initWithResourceName:resourceName ofType:type baseURL:baseURL delegate:delegate] autorelease];
}

- initWithResourceName:(NSString *)resourceName ofType:(NSString *)type baseURL:(NSURL *)baseURL delegate:(id)delegate
{
	if (self = [super init]) {
		m_resourceName = [resourceName copy];
		m_delegate = delegate;
		
		NSURL			*url = [NSURL URLWithString:[resourceName stringByAppendingPathExtension:type]
									  relativeToURL:baseURL];
		NSURLRequest	*request = [NSURLRequest requestWithURL:url
													cachePolicy:NSURLRequestReloadIgnoringCacheData
												timeoutInterval:60.0];
		m_connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
		m_data = [[NSMutableData alloc] init];
	}
	return self;
}

- (void)dealloc
{
	[m_resourceName release];
	[m_connection cancel];
	[m_connection release];
	[m_data release];
	[super dealloc];
}

- (NSString *)resourceName
{
	return [[m_resourceName copy] autorelease];
}

- (NSData *)loadedData
{
	// Avoid doing a copy
	return [[m_data retain] autorelease];
}

- (void)cancel
{
	[m_connection cancel];
}


#pragma mark -
#pragma mark NSURLConnection Delegate Methods


- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
	if ([m_delegate respondsToSelector:@selector(audibleResourceLoader:didFailWithError:)]) {
		[m_delegate audibleResourceLoader:self didFailWithError:error];
	}
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
	int responseStatusCode = [(NSHTTPURLResponse *)response statusCode];
	
	// 4xx => Client Error ; 5xx => Server Error
	if (responseStatusCode >= 400 && responseStatusCode <= 599) {
		NSLog(@"Connection to download audible file got an error: %d %@",
			  responseStatusCode, [NSHTTPURLResponse localizedStringForStatusCode:responseStatusCode]);
		
		[self connection:connection didFailWithError:[NSError errorWithDomain:@"AudibleHTTPConnectionDomain"
																		 code:responseStatusCode
																	 userInfo:nil]];
		[connection cancel];
	}
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
	[m_data appendData:data];
}

- (NSCachedURLResponse *)connection:(NSURLConnection *)connection willCacheResponse:(NSCachedURLResponse *)cachedResponse
{
	// Don't cache anything. We have our own custom local cache.
	return nil;
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
	if ([m_delegate respondsToSelector:@selector(audibleResourceLoaderDidFinish:)]) {
		[m_delegate audibleResourceLoaderDidFinish:self];
	}
}



@end
