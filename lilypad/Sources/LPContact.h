//
//  LPContact.h
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jpavao@co.sapo.pt>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import <Cocoa/Cocoa.h>
#import "LPRosterItem.h"
#import "LPCapabilitiesPredicates.h"


@class LPAccount, LPGroup, LPContactEntry;


@interface LPContact : LPRosterItem <NSCopying, LPCapabilitiesPredicates>
{
	NSDate				*m_creationDate;
	
	NSString			*m_name;
	NSString			*m_altName;
	
	NSImage				*m_avatar;
	LPStatus			m_status;
	NSString			*m_statusMessage;
	NSAttributedString	*m_attributedStatusMessage;
	BOOL				m_wasOnlineBeforeDisconnecting;
	
	NSMutableArray		*m_groups;
	
	NSMutableArray		*m_contactEntries;
	NSMutableArray		*m_chatContactEntries;
	NSMutableArray		*m_smsContactEntries;
	
	LPContactEntry		*m_preferredContactEntry;
	LPContactEntry		*m_lastContactEntryToChangeStatus;
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
- (NSAttributedString *)attributedStatusMessage;
- (BOOL)isOnline;
- (BOOL)isInUserRoster;
- (BOOL)wasOnlineBeforeDisconnecting;

- (BOOL)canDoChat;
- (BOOL)canDoSMS;
- (BOOL)canDoMUC;
- (BOOL)canDoFileTransfer;

- (BOOL)isRosterContact;

- (NSArray *)groups;

- (NSArray *)contactEntries;
- (NSArray *)chatContactEntries;
- (NSArray *)smsContactEntries;

- (LPContactEntry *)lastContactEntryToChangeStatus;
- (LPContactEntry *)mainContactEntry;
- (LPContactEntry *)preferredContactEntry;
- (void)setPreferredContactEntry:(LPContactEntry *)entry;

- (LPContactEntry *)firstContactEntryWithCapsFeature:(NSString *)capsFeature;
- (LPContactEntry *)firstContactEntryWithoutCapsFeature:(NSString *)capsFeature;
- (BOOL)someEntryHasCapsFeature:(NSString *)capsFeature;
- (BOOL)someEntryDoesntHaveCapsFeature:(NSString *)capsFeature;

- (void)moveFromGroup:(LPGroup *)originGroup toGroup:(LPGroup *)destinationGroup;

- (LPContactEntry *)addNewContactEntryWithAddress:(NSString *)address account:(LPAccount *)account reason:(NSString *)reason;
- (void)addContactEntry:(LPContactEntry *)entry reason:(NSString *)reason;
- (void)moveContactEntry:(LPContactEntry *)entry toIndex:(NSUInteger)newIndex;
- (void)removeContactEntry:(LPContactEntry *)entry;

- (void)handleContactChangedWithProperties:(NSDictionary *)properties;
- (void)handleAdditionToGroup:(LPGroup *)group;
- (void)handleRemovalFromGroup:(LPGroup *)group;
- (void)handleAdditionOfEntry:(LPContactEntry *)entry;
- (void)handleRemovalOfEntry:(LPContactEntry *)entry;

@end
