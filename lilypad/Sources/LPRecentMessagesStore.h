//
//  LPRecentMessagesStore.h
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jpavao@co.sapo.pt>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import <Cocoa/Cocoa.h>


@class LPContact;


@interface LPRecentMessagesStore : NSObject
{
	unsigned int		m_nrOfStoredMessagesPerJID;
	NSTimer				*m_saveTimer;
	
	// Mutable Dict: accountJID(NSString) -> (Mutable Dict: destinationJID (NSString) -> messages list (Mutable Array of Dictionaries))
	NSMutableDictionary	*m_storedMessagesByAccountAndDestJIDs;
}

+ (LPRecentMessagesStore *)sharedMessagesStore;

- (unsigned int)numberOfStoredMessagesPerJID;
- (void)setNumberOfStoredMessagesPerJID:(unsigned int)nr;

- (void)storeMessage:(NSString *)msg receivedFromJID:(NSString *)jid thruAccountJID:(NSString *)accountJID;
- (void)storeMessage:(NSString *)msg sentToJID:(NSString *)jid thruAccountJID:(NSString *)accountJID;
- (void)storeRawHTMLBlock:(NSString *)htmlBlock withDIVClass:(NSString *)class forJID:(NSString *)jid thruAccountJID:(NSString *)accountJID;

/*
 * The methods that follow return a list of NSDictionary instances, each one representing a saved message.
 * Each dictionary contains the following key-value pairs:
 *     - "MessageText" -> NSString
 *     - "Timestamp"   -> NSDate
 *     - "Kind"        -> NSString: "Sent", "Received", "RawHTMLBlock"
 *     - "DIVClass"    -> NSString: if ("Kind" == "RawHTMLBlock"), "DIVClass" contains the class that shall
 *                        be used for the outer DIV block around the raw html being saved.
 */
- (NSArray *)recentMessagesExchangedWithJID:(NSString *)jid;
- (NSArray *)recentMessagesExchangedWithContact:(LPContact *)contact;

@end
