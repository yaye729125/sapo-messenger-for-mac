//
//  LPChatRoomsListController.m
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "LPChatRoomsListController.h"
#import "LPAccount.h"
#import "LPServerItemsInfo.h"

#import "LFAppController.h"


@implementation LPChatRoomsListController

- initWithDelegate:(id)delegate
{
	if (self = [self initWithWindowNibName:@"ChatRoomsList"]) {
		m_delegate = delegate;
		m_chatRoomsInfo = [[NSMutableDictionary alloc] init];
	}
	return self;
}

- (void)dealloc
{
	[m_account removeObserver:self forKeyPath:@"serverItemsInfo.MUCServiceProviderItems"];
	
	[m_chatRoomsInfo release];
	
	[m_account release];
	[m_selectedHost release];
	[super dealloc];
}

- (void)awakeFromNib
{
	[m_table setTarget:self];
	[m_table setDoubleAction:@selector(joinRoom:)];
	
	[m_roomsArrayController setSortDescriptors:[NSArray arrayWithObject:[m_initiallySortedColumn sortDescriptorPrototype]]];
}

- (void)p_setDefaultHostFromAccountIfNeeded
{
	NSArray *mucProviders = [[[self account] serverItemsInfo] MUCServiceProviderItems];
	
	if ([[self selectedHost] length] == 0 || ![mucProviders containsObject:[self selectedHost]]) {
		[self setSelectedHost:( [mucProviders count] > 0 ?
								[mucProviders objectAtIndex:0] :
								nil )];
	}
}


- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ([keyPath isEqualToString:@"serverItemsInfo.MUCServiceProviderItems"]) {
		[self p_setDefaultHostFromAccountIfNeeded];
	}
	else {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}


- (LPAccount *)account
{
	return m_account;
}

- (void)setAccount:(LPAccount *)account
{
	if (account != m_account) {
		[m_account removeObserver:self forKeyPath:@"serverItemsInfo.MUCServiceProviderItems"];
		[m_account release];
		m_account = [account retain];
		[account addObserver:self forKeyPath:@"serverItemsInfo.MUCServiceProviderItems" options:0 context:NULL];
		
		[self p_setDefaultHostFromAccountIfNeeded];
	}
}

- (NSString *)selectedHost
{
    return [[m_selectedHost copy] autorelease]; 
}

- (void)setSelectedHost:(NSString *)aHost
{
    if (m_selectedHost != aHost) {
        [m_selectedHost release];
        m_selectedHost = [aHost copy];
    }
}


- (NSArray *)roomsAvailableInSelectedHost
{
	return [[m_chatRoomsInfo objectForKey:[self selectedHost]] allValues];
}


- (NSMutableDictionary *)p_roomsDictForHost:(NSString *)host
{
	NSMutableDictionary *roomsForHost = [m_chatRoomsInfo objectForKey:host];
	
	if (roomsForHost == nil) {
		roomsForHost = [[NSMutableDictionary alloc] init];
		[m_chatRoomsInfo setValue:roomsForHost forKey:host];
		[roomsForHost release];
	}
	
	return roomsForHost;
}


- (void)setChatRoomsList:(NSArray *)chatRooms forHost:(NSString *)host
{
	NSMutableDictionary *roomsForHost = [self p_roomsDictForHost:host];
	
	BOOL modifyingSelectedHost = [host isEqualToString:[self selectedHost]];
	
	if (modifyingSelectedHost)
		[self willChangeValueForKey:@"roomsAvailableInSelectedHost"];
	{
		[roomsForHost removeAllObjects];
		
		NSEnumerator *roomInfoEnum = [chatRooms objectEnumerator];
		id roomInfo;
		while (roomInfo = [roomInfoEnum nextObject]) {
			[roomsForHost setValue:roomInfo forKey:[roomInfo valueForKey:@"jid"]];
		}
	}
	if (modifyingSelectedHost)
		[self didChangeValueForKey:@"roomsAvailableInSelectedHost"];
}


- (void)setInfo:(NSDictionary *)roomInfo forRoomWithJID:(NSString *)roomJID
{
	NSString *host = [roomJID JIDHostnameComponent];
	NSMutableDictionary *roomsForHost = [self p_roomsDictForHost:host];
	
	BOOL modifyingSelectedHost = [host isEqualToString:[self selectedHost]];
	
	if (modifyingSelectedHost)
		[self willChangeValueForKey:@"roomsAvailableInSelectedHost"];
	{
		[roomsForHost setValue:roomInfo forKey:roomJID];
	}
	if (modifyingSelectedHost)
		[self didChangeValueForKey:@"roomsAvailableInSelectedHost"];
}


- (IBAction)fetchChatRooms:(id)sender
{
#warning USING LFAppController DIRECTLY
	[LFAppController fetchChatRoomsListOnHost:[self selectedHost]];
}


- (IBAction)joinRoom:(id)sender
{
	if ([m_delegate respondsToSelector:@selector(chatRoomsListCtrl:joinChatRoomWithJID:)]) {
		NSString *roomJID = [[m_roomsArrayController selection] valueForKey:@"jid"];
		[m_delegate chatRoomsListCtrl:self joinChatRoomWithJID:roomJID];
	}
}


@end
