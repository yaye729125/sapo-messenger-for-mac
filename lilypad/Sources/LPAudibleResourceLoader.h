//
//  LPAudibleResourceLoader.h
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jpavao@co.sapo.pt>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import <Cocoa/Cocoa.h>


@interface LPAudibleResourceLoader : NSObject
{
	NSString			*m_resourceName;
	id					m_delegate;
	NSURLConnection		*m_connection;
	NSMutableData		*m_data;
}
+ loaderWithResourceName:(NSString *)resourceName ofType:(NSString *)type baseURL:(NSURL *)baseURL delegate:(id)delegate;
- initWithResourceName:(NSString *)resourceName ofType:(NSString *)type baseURL:(NSURL *)baseURL delegate:(id)delegate;

- (NSString *)resourceName;
- (NSData *)loadedData;
- (void)cancel;
@end


@interface NSObject (LPAudibleResourceLoaderDelegate)
- (void)audibleResourceLoaderDidFinish:(LPAudibleResourceLoader *)loader;
- (void)audibleResourceLoader:(LPAudibleResourceLoader *)loader didFailWithError:(NSError *)error;
@end

