//
//  LPRecentMessagesStore.h
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import <Cocoa/Cocoa.h>


@class LPContact;


@interface LPRecentMessagesStore : NSObject
{
	NSString			*m_ourAccountJID;
	unsigned int		m_nrOfStoredMessagesPerJID;
	NSTimer				*m_saveTimer;
	NSMutableDictionary	*m_storedMessagesByJID;
}

+ (LPRecentMessagesStore *)sharedMessagesStore;

- (NSString *)ourAccountJID;
- (void)setOurAccountJID:(NSString *)accountJID;

- (unsigned int)numberOfStoredMessagesPerJID;
- (void)setNumberOfStoredMessagesPerJID:(unsigned int)nr;

- (void)storeMessage:(NSString *)msg receivedFromJID:(NSString *)jid;
- (void)storeMessage:(NSString *)msg sentToJID:(NSString *)jid;

/*
 * The methods that follow return a list of NSDictionary instances, each one representing a saved message.
 * Each dictionary contains the following key-value pairs:
 *     - "MessageText" -> NSString
 *     - "Timestamp"   -> NSDate
 *     - "Kind"        -> NSString: "Sent" or "Received"
 */
- (NSArray *)recentMessagesExchangedWithJID:(NSString *)jid;
- (NSArray *)recentMessagesExchangedWithContact:(LPContact *)contact;

@end
