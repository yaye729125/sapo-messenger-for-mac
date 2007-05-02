//
//  LPContact.h
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import <Cocoa/Cocoa.h>
#import "LPRosterItem.h"
#import "LPCapabilitiesPredicates.h"


@class LPGroup, LPContactEntry;


@interface LPContact : LPRosterItem <NSCopying, LPCapabilitiesPredicates>
{
	NSDate			*m_creationDate;
	
	NSString		*m_name;
	NSString		*m_altName;
	
	NSImage			*m_avatar;
	LPStatus		m_status;
	NSString		*m_statusMessage;
	BOOL			m_wasOnlineBeforeDisconnecting;
	
	NSMutableArray	*m_groups;
	
	NSMutableArray	*m_contactEntries;
	NSMutableArray	*m_chatContactEntries;
	NSMutableArray	*m_smsContactEntries;
	
	LPContactEntry	*m_preferredContactEntry;
}

+ contactWithName:(NSString *)name;
// Designated initializer
- initWithName:(NSString *)name;

// This doesn't copy anything, only increases the retain count of the instance
- (id)copyWithZone:(NSZone *)zone;

- (NSDate *)creationDate;

- (NSString *)name;
- (void)setName:(NSString *)newName;
- (NSString *)altName;
- (void)setAltName:(NSString *)newAltName;

- (NSImage *)avatar;
- (NSImage *)framedAvatar;
- (LPStatus)status;
- (NSString *)statusMessage;
- (BOOL)isOnline;
- (BOOL)isInUserRoster;
- (BOOL)wasOnlineBeforeDisconnecting;

- (BOOL)canDoChat;
- (BOOL)canDoSMS;
- (BOOL)canDoFileTransfer;

- (BOOL)isRosterContact;

- (NSArray *)groups;

- (NSArray *)contactEntries;
- (NSArray *)chatContactEntries;
- (NSArray *)smsContactEntries;

- (LPContactEntry *)mainContactEntry;
- (LPContactEntry *)preferredContactEntry;
- (void)setPreferredContactEntry:(LPContactEntry *)entry;

- (BOOL)someEntryHasCapsFeature:(NSString *)capsFeature;
- (BOOL)someEntryDoesntHaveCapsFeature:(NSString *)capsFeature;

- (void)moveFromGroup:(LPGroup *)originGroup toGroup:(LPGroup *)destinationGroup;

- (LPContactEntry *)addNewContactEntryWithAddress:(NSString *)address;
- (void)addContactEntry:(LPContactEntry *)entry;
- (void)removeContactEntry:(LPContactEntry *)entry;

- (void)handleContactChangedWithProperties:(NSDictionary *)properties;
- (void)handleAdditionToGroup:(LPGroup *)group;
- (void)handleRemovalFromGroup:(LPGroup *)group;
- (void)handleAdditionOfEntry:(LPContactEntry *)entry;
- (void)handleRemovalOfEntry:(LPContactEntry *)entry;

@end
