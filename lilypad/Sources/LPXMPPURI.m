//
//  LPXMPPURI.m
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jpavao@co.sapo.pt>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "LPXMPPURI.h"
#import "LPXMPPURI-Scanner.h"


@implementation LPXMPPURI

+ (id)URIWithString:(NSString *)URIString
{
	return [[[[self class] alloc] initWithString:URIString] autorelease];
}

// Designated initializer
- initWithString:(NSString *)URIString
{
	NSParameterAssert(URIString);
	
	if (self = [super init]) {
		if (LPXMPPURI_ParseURI(URIString, &m_targetJID, &m_queryAction, &m_parameters)) {
			
			m_originalURIStr = [URIString copy];
			
			[m_targetJID retain];
			[m_queryAction retain];
			[m_parameters retain];
		}
		else {
			[self release];
			self = nil;
		}
	}
		
	return self;
}

- init
{
	return [self initWithString:@""];
}

- (void)dealloc
{
	[m_originalURIStr release];
	[m_targetJID release];
	[m_queryAction release];
	[m_parameters release];
	[super dealloc];
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
	if ([encoder allowsKeyedCoding]) {
		[encoder encodeObject:m_originalURIStr forKey:@"XMPPURI-OriginalURI"];
		[encoder encodeObject:m_targetJID forKey:@"XMPPURI-TargetJID"];
		[encoder encodeObject:m_queryAction forKey:@"XMPPURI-QueryAction"];
		[encoder encodeObject:m_parameters forKey:@"XMPPURI-Parameters"];
	}
	else {
		[encoder encodeObject:m_originalURIStr];
		[encoder encodeObject:m_targetJID];
		[encoder encodeObject:m_queryAction];
		[encoder encodeObject:m_parameters];
	}
}

- (id)initWithCoder:(NSCoder *)decoder
{
	if ([decoder allowsKeyedCoding]) {
		m_originalURIStr = [[decoder decodeObjectForKey:@"XMPPURI-OriginalURI"] retain];
		m_targetJID = [[decoder decodeObjectForKey:@"XMPPURI-TargetJID"] retain];
		m_queryAction = [[decoder decodeObjectForKey:@"XMPPURI-QueryAction"] retain];
		m_parameters = [[decoder decodeObjectForKey:@"XMPPURI-Parameters"] retain];
	}
	else {
		m_originalURIStr = [[decoder decodeObject] retain];
		m_targetJID = [[decoder decodeObject] retain];
		m_queryAction = [[decoder decodeObject] retain];
		m_parameters = [[decoder decodeObject] retain];
	}
	return self;
}

- (id)copyWithZone:(NSZone *)zone
{
	// We're immutable, there's no need to waste more memory with another instance.
	return [self retain];
}

- (BOOL)isEqual:(id)anObject
{
	return ( self == anObject ||
			 ( [anObject isKindOfClass:[LPXMPPURI class]] &&
			   [[anObject originalURIString] isEqualToString:[self originalURIString]] ));
}

- (unsigned)hash
{
	return [m_originalURIStr hash];
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%p: URI = \"%@\">", self, [self originalURIString]];
}

- (NSString *)originalURIString
{
	return [[m_originalURIStr copy] autorelease];
}

- (NSString *)targetJID
{
	return [[m_targetJID copy] autorelease];
}

- (NSString *)queryAction
{
	return [[m_queryAction copy] autorelease];
}

- (NSDictionary *)parametersDictionary
{
	return [[m_parameters copy] autorelease];
}

@end
