//
//  LPXMPPURI.h
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import <Cocoa/Cocoa.h>


@interface LPXMPPURI : NSObject <NSCoding, NSCopying>
{
	NSString		*m_originalURIStr;
	NSString		*m_targetJID;
	NSString		*m_queryAction;
	NSDictionary	*m_parameters;
}

+ (id)URIWithString:(NSString *)URIString;
// Designated initializer
- initWithString:(NSString *)URIString;

- (void)encodeWithCoder:(NSCoder *)encoder;
- (id)initWithCoder:(NSCoder *)decoder;

- (id)copyWithZone:(NSZone *)zone;

- (BOOL)isEqual:(id)anObject;
- (unsigned)hash;

- (NSString *)description;

- (NSString *)originalURIString;
- (NSString *)targetJID;
- (NSString *)queryAction;
- (NSDictionary *)parametersDictionary;

@end
