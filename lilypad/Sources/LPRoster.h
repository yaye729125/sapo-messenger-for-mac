//
//  LPRoster.h
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jpavao@co.sapo.pt>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import <Cocoa/Cocoa.h>


@class LPAccount, LPGroup, LPContact, LPContactEntry;
@class LPPresenceSubscription;


@interface LPRoster : NSObject
{
	id			m_delegate;
	
	NSMutableArray		*m_allGroups;
	NSMutableArray		*m_allContacts;
	
	NSMutableDictionary	*m_groupsByID;
	NSMutableDictionary	*m_contactsByID;
	NSMutableDictionary	*m_contactEntriesByID;
}

+ (LPRoster *)roster;

- (id)delegate;
- (void)setDelegate:(id)delegate;

- (void)registerGroup:(LPGroup *)group forID:(int)groupID;
- (void)unregisterGroup:(LPGroup *)group;
- (void)registerContact:(LPContact *)contact forID:(int)contactID;
- (void)unregisterContact:(LPContact *)contact;
- (void)registerContactEntry:(LPContactEntry *)entry forID:(int)entryID;
- (void)unregisterContactEntry:(LPContactEntry *)entry;

- (LPGroup *)groupForID:(int)groupID;
- (LPContact *)contactForID:(int)contactID;
- (LPContactEntry *)contactEntryForID:(int)entryID;

- (LPGroup *)groupForHiddenContacts;

- (LPGroup *)groupForName:(NSString *)groupName;
- (LPContact *)contactForName:(NSString *)contactName;
/*
 * contactEntryForAddress: is a shortcut for contactEntryForAddress:searchOnlyUserAddedEntries:, where
 * userAddedFlag is NO. It searches all known JIDs, both user added and other JIDs that we're tracking
 * internally.
 */
- (LPContactEntry *)contactEntryInAnyAccountForAddress:(NSString *)entryAddress;
- (LPContactEntry *)contactEntryInAnyAccountForAddress:(NSString *)entryAddress
					 createNewHiddenWithNameIfNotFound:(NSString *)name;
- (LPContactEntry *)contactEntryInAnyAccountForAddress:(NSString *)entryAddress
					 createNewHiddenWithNameIfNotFound:(NSString *)name
									   createInAccount:(LPAccount *)accountForNewEntry;
- (LPContactEntry *)contactEntryInAnyAccountForAddress:(NSString *)entryAddress
							searchOnlyUserAddedEntries:(BOOL)userAddedOnly;
- (LPContactEntry *)contactEntryForAddress:(NSString *)entryAddress account:(LPAccount *)account;
- (LPContactEntry *)contactEntryForAddress:(NSString *)entryAddress account:(LPAccount *)account
		 createNewHiddenWithNameIfNotFound:(NSString *)name;
- (LPContactEntry *)contactEntryForAddress:(NSString *)entryAddress account:(LPAccount *)account
				searchOnlyUserAddedEntries:(BOOL)userAddedOnly;

- (LPGroup *)addNewGroupWithName:(NSString *)groupName;
- (void)addGroup:(LPGroup *)group;
- (void)removeGroup:(LPGroup *)group;

- (void)removeContact:(LPContact *)contact;

- (NSString *)uniqueNameForCopyOfContact:(LPContact *)originalContact;

- (NSArray *)allGroups;
- (NSArray *)sortedUserGroups;
- (NSArray *)allContacts;
- (NSArray *)allContactEntries;

@end


@interface NSObject (LPRosterDelegate)
- (void)roster:(LPRoster *)roster didReceivePresenceSubscriptionRequest:(LPPresenceSubscription *)presSub;
@end

