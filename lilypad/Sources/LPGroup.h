//
//  LPGroup.h
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


typedef enum _LPGroupType {
	LPNoGroupType,
	LPUserGroupType,
	LPAgentsGroupType,
	LPNotInListGroupType
} LPGroupType;


@class LPContact;


@interface LPGroup : LPRosterItem <NSCopying>
{
	LPGroupType		m_type;
	NSString		*m_name;
	
	NSMutableArray	*m_contacts;
}

+ groupWithName:(NSString *)name;
- initWithName:(NSString *)name;

// This doesn't copy anything, only increases the retain count of the instance
- (id)copyWithZone:(NSZone *)zone;

- (LPGroupType)type;
- (NSString *)name;
- (void)setName:(NSString *)newName;

- (NSArray *)contacts;

- (LPContact *)addNewContactWithName:(NSString *)contactName;
- (void)addContact:(LPContact *)contact;
- (void)removeContact:(LPContact *)contact;

- (void)handleGroupChangedWithProperties:(NSDictionary *)properties;
- (void)handleAdditionOfContact:(LPContact *)contact;
- (void)handleRemovalOfContact:(LPContact *)contact;

@end
