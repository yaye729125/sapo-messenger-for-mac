//
//  LPChat.h
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import <Cocoa/Cocoa.h>


@class LPContact, LPContactEntry, LPAccount;


@interface LPChat : NSObject
{
	id				m_delegate;
	
	int				m_ID;
	LPContact		*m_contact;
	LPContactEntry	*m_activeEntry;
	NSString		*m_fullJID;
	
	LPAccount		*m_account;
	BOOL			m_isActive;
	BOOL			m_contactIsTyping;
}

+ chatWithContact:(LPContact *)contact entry:(LPContactEntry *)entry chatID:(int)chatID JID:(NSString *)fullJID account:(LPAccount *)account;
- initWithContact:(LPContact *)contact entry:(LPContactEntry *)entry chatID:(int)chatID JID:(NSString *)fullJID account:(LPAccount *)account;

- (id)delegate;
- (void)setDelegate:(id)delegate;

- (int)ID;
- (LPContact *)contact;
- (LPContactEntry *)activeContactEntry;
- (void)setActiveContactEntry:(LPContactEntry *)entry;
- (NSString *)fullJID;
- (LPAccount *)account;
- (BOOL)isActive;
- (BOOL)isContactTyping;

- (void)sendMessageWithPlainTextVariant:(NSString *)plainTextMessage XHTMLVariant:(NSString *)XHTMLMessage URLs:(NSArray *)URLs;
- (void)sendAudibleWithResourceName:(NSString *)audibleName;
- (void)sendInvalidAudibleErrorWithMessage:(NSString *)errorMsg originalResourceName:(NSString *)resourceName originalBody:(NSString *)body originalHTMLBody:(NSString *)htmlBody;
- (void)setUserIsTyping:(BOOL)isTyping;
- (void)endChat;

// These methods handle events received by our account
- (void)handleActiveContactEntryChanged:(LPContactEntry *)entry;
- (void)handleReceivedErrorMessage:(NSString *)message;
- (void)handleReceivedMessageFromNick:(NSString *)nick subject:(NSString *)subject plainTextVariant:(NSString *)plainTextMessage XHTMLVariant:(NSString *)XHTMLMessage URLs:(NSArray *)URLs;
- (void)handleReceivedAudibleWithName:(NSString *)audibleResourceName msgBody:(NSString *)body msgHTMLBody:(NSString *)htmlBody;
- (void)handleReceivedSystemMessage:(NSString *)message;
- (void)handleContactTyping:(BOOL)isTyping;
- (void)handleEndOfChat;
- (void)handleResultOfSMSSentTo:(NSString *)destinationPhoneNr withBody:(NSString *)msgBody resultCode:(int)result nrUsedMsgs:(int)nrUsedMsgs nrUsedChars:(int)nrUsedChars newCredit:(int)newCredit newFreeMessages:(int)newFreeMessages newTotalSentThisMonth:(int)newTotalSentThisMonth;
- (void)handleSMSReceivedFrom:(NSString *)sourcePhoneNr withBody:(NSString *)msgBody dateString:(NSString *)dateString newCredit:(int)newCredit newFreeMessages:(int)newFreeMessages newTotalSentThisMonth:(int)newTotalSentThisMonth;
@end


@interface NSObject (LPChatDelegate)
- (void)chat:(LPChat *)chat didReceiveErrorMessage:(NSString *)message;
- (void)chat:(LPChat *)chat didReceiveMessageFromNick:(NSString *)nick subject:(NSString *)subject plainTextVariant:(NSString *)plainTextMessage XHTMLVariant:(NSString *)XHTMLMessage URLs:(NSArray *)URLs;
- (void)chat:(LPChat *)chat didReceiveSystemMessage:(NSString *)message;
- (void)chat:(LPChat *)chat didReceiveResultOfSMSSentTo:(NSString *)destinationPhoneNr withBody:(NSString *)msgBody resultCode:(int)result nrUsedMsgs:(int)nrUsedMsgs nrUsedChars:(int)nrUsedChars newCredit:(int)newCredit newFreeMessages:(int)newFreeMessages newTotalSentThisMonth:(int)newTotalSentThisMonth;
- (void)chat:(LPChat *)chat didReceiveSMSFrom:(NSString *)sourcePhoneNr withBody:(NSString *)msgBody date:(NSDate *)date newCredit:(int)newCredit newFreeMessages:(int)newFreeMessages newTotalSentThisMonth:(int)newTotalSentThisMonth;
- (void)chat:(LPChat *)chat didReceiveAudibleWithResourceName:(NSString *)resourceName msgBody:(NSString *)body msgHTMLBody:(NSString *)htmlBody;
- (void)chatContactDidStartTyping:(LPChat *)chat;
- (void)chatContactDidStopTyping:(LPChat *)chat;
@end

