//
//  LPChat.m
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "LPChat.h"
#import "LPAccount.h"
#import "LPContact.h"
#import "LPContactEntry.h"
#import "LFAppController.h"
#import "LPAudibleSet.h"
#import "NSString+HTMLAdditions.h"

#warning Este deve poder tirar-se quando se resolver a cena dos endChat
#import "LPChatsManager.h"


@implementation LPChat

+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key
{
	if ([key isEqualToString:@"activeContactEntry"]) {
		// Avoid triggering change notifications on calls to -[LPGroupChat setActiveContactEntry:]
		return NO;
	} else {
		return YES;
	}
}

+ chatWithContact:(LPContact *)contact entry:(LPContactEntry *)entry chatID:(int)chatID JID:(NSString *)fullJID
{
	return [[[[self class] alloc] initWithContact:contact entry:entry chatID:chatID JID:fullJID] autorelease];
}

- initWithContact:(LPContact *)contact entry:(LPContactEntry *)entry chatID:(int)chatID JID:(NSString *)fullJID
{
	NSAssert((entry == nil || [entry contact] == contact), @"Contact and entry don't match!");

	if (self = [super init]) {
		m_ID = chatID;
		m_contact = [contact retain];
		m_activeEntry = [entry retain];
		m_fullJID = [fullJID copy];
		m_isActive = YES;
		m_contactIsTyping = NO;
		
		[m_contact addObserver:self forKeyPath:@"chatContactEntries" options:0 context:NULL];
		[m_contact addObserver:self forKeyPath:@"online" options:NSKeyValueObservingOptionOld context:NULL];
		[m_activeEntry addObserver:self forKeyPath:@"online" options:0 context:NULL];
	}
	return self;
}

- (void)dealloc
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(p_reevaluateActiveContactEntry) object:nil];
	
	[m_activeEntry removeObserver:self forKeyPath:@"online"];
	[m_contact removeObserver:self forKeyPath:@"online"];
	[m_contact removeObserver:self forKeyPath:@"chatContactEntries"];
	
	[self setDelegate:nil];
	
	[m_contact release];
	[m_activeEntry release];
	[m_fullJID release];

	[super dealloc];
}

- (void)p_reevaluateActiveContactEntry
{
	LPContactEntry *activeEntry = [self activeContactEntry];
	LPContactEntry *mainEntry = [m_contact mainContactEntry];
	
	// If the selected entry goes offline, try to change to the current main entry of the contact if it is online
	if (![activeEntry isOnline] && mainEntry != activeEntry && [mainEntry isOnline]) {
		[self setActiveContactEntry:mainEntry];
	}
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	LPContactEntry *activeEntry = [self activeContactEntry];
	LPContactEntry *mainEntry = [m_contact mainContactEntry];
	
	if ([keyPath isEqualToString:@"chatContactEntries"]) {
		if (![[m_contact chatContactEntries] containsObject:activeEntry] && mainEntry) {
			// Active contact entry was removed: select a new active entry
			[self setActiveContactEntry:mainEntry];
		}
		else if ([[m_contact chatContactEntries] count] == 0) {
			// All chat entries are gone. If the chat object is kept alive, then it's probably here just to show feedback from non-chat
			// contact entries. Clear the active chat contact entry.
			[self setActiveContactEntry:nil];
		}
	}
	else if ([keyPath isEqualToString:@"online"]) {
		
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(p_reevaluateActiveContactEntry) object:nil];
		
		if (object == m_contact) {
			BOOL wasOnline = [[change objectForKey:NSKeyValueChangeOldKey] boolValue];
			
			if (!wasOnline && [m_contact isOnline]) {
				// If the selected entry goes offline, try to change to the current main entry of the contact if it is online
				if (mainEntry != activeEntry && [mainEntry isOnline]) {
					[self setActiveContactEntry:mainEntry];
				}
			}
		}
		else if (object == activeEntry) {
			if (![activeEntry isOnline]) {
				// Use a small delay to avoid selecting one entry after the other in rapid succession as an entire contact is going offline
				[self performSelector:@selector(p_reevaluateActiveContactEntry) withObject:nil afterDelay:1.0];
			}
		}
	}
	else {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}

- (id)delegate
{
	return m_delegate;
}

- (void)setDelegate:(id)delegate
{
	m_delegate = delegate;
}

- (int)ID
{
	return m_ID;
}

- (LPContact *)contact
{
	return [[m_contact retain] autorelease];
}

- (LPContactEntry *)activeContactEntry
{
	return [[m_activeEntry retain] autorelease];
}

- (void)p_setActiveContactEntry:(LPContactEntry *)entry
{
	if (entry != m_activeEntry) {
		[m_activeEntry removeObserver:self forKeyPath:@"online"];
		[self willChangeValueForKey:@"activeContactEntry"];
		[m_activeEntry release];
		m_activeEntry = [entry retain];
		[self didChangeValueForKey:@"activeContactEntry"];
		[m_activeEntry addObserver:self forKeyPath:@"online" options:0 context:NULL];
	}
}

- (void)setActiveContactEntry:(LPContactEntry *)entry
{
	if (entry != m_activeEntry) {
		NSAssert((entry == nil || [entry contact] == m_contact), @"Contacts for the entries don't match!");
		[LFAppController chatChangeEntry:[self ID] :(entry ? [entry ID] : (-1))];
		[self p_setActiveContactEntry:entry];
	}
}

- (NSString *)fullJID
{
	return [[m_fullJID copy] autorelease];
}

- (BOOL)isActive
{
	return m_isActive;
}

- (BOOL)isContactTyping
{
	return m_contactIsTyping;
}

- (void)sendMessageWithPlainTextVariant:(NSString *)plainTextMessage XHTMLVariant:(NSString *)XHTMLMessage URLs:(NSArray *)URLs
{
	[LFAppController chatMessageSend:[self ID] plain:plainTextMessage xhtml:XHTMLMessage urls:URLs];
}

- (void)sendAudibleWithResourceName:(NSString *)audibleName
{
	// Prepare the text message alternative
	// Take the "AUDIBLE_" prefix out. The URL must have this bit stripped.
	NSString *prefixToStrip = @"AUDIBLE_";
	NSString *unprefixedResourceName = ([audibleName hasPrefix:prefixToStrip] ?
										[audibleName substringFromIndex:[prefixToStrip length]] :
										audibleName);
	
	NSString *plainTextMsg = [NSString stringWithFormat:@"%1$@ Clique aqui para ver: http://messenger.sapo.pt/?b=%2$@",
		[[[LPAudibleSet defaultAudibleSet] textForAudibleWithName:audibleName] stringByEscapingHTMLEntities],
		unprefixedResourceName];
	NSString *HTMLMsg = [NSString stringWithFormat:@"<span style=\"font-family: Tahoma;color: #A0242F\">%@</span>",
		plainTextMsg];
	
	
	// Send it
	[LFAppController chatAudibleSend:[self ID] audibleName:audibleName plainTextAlternative:plainTextMsg HTMLAlternative:HTMLMsg];
}

- (void)sendInvalidAudibleErrorWithMessage:(NSString *)errorMsg originalResourceName:(NSString *)resourceName originalBody:(NSString *)body originalHTMLBody:(NSString *)htmlBody
{
	[LFAppController chatSendInvalidAudibleError:[self ID] errorMessage:errorMsg originalResourceName:resourceName originalBody:body originalHTMLBody:htmlBody];
}

- (void)setUserIsTyping:(BOOL)isTyping
{
	[LFAppController chatUserTyping:[self ID] isTyping:isTyping];
}

- (void)endChat
{
	[[LPChatsManager chatsManager] endChat:self];
}

#pragma mark -
#pragma mark Account Events Handlers

- (void)handleActiveContactEntryChanged:(LPContactEntry *)entry
{
	[self p_setActiveContactEntry:entry];
}

- (void)handleReceivedErrorMessage:(NSString *)message
{
	if ([m_delegate respondsToSelector:@selector(chat:didReceiveErrorMessage:)]) {
		[m_delegate chat:self didReceiveErrorMessage:message];
	}
}

- (void)handleReceivedMessageFromNick:(NSString *)nick subject:(NSString *)subject plainTextVariant:(NSString *)plainTextMessage XHTMLVariant:(NSString *)XHTMLMessage URLs:(NSArray *)URLs
{
	if ([m_delegate respondsToSelector:@selector(chat:didReceiveMessageFromNick:subject:plainTextVariant:XHTMLVariant:URLs:)]) {
		[m_delegate chat:self didReceiveMessageFromNick:nick subject:subject plainTextVariant:plainTextMessage XHTMLVariant:XHTMLMessage URLs:URLs];
	}
}

- (void)handleReceivedAudibleWithName:(NSString *)audibleResourceName msgBody:(NSString *)body msgHTMLBody:(NSString *)htmlBody
{
	if ([m_delegate respondsToSelector:@selector(chat:didReceiveAudibleWithResourceName:msgBody:msgHTMLBody:)]) {
		[m_delegate chat:self didReceiveAudibleWithResourceName:audibleResourceName msgBody:body msgHTMLBody:htmlBody];
	}
}

- (void)handleReceivedSystemMessage:(NSString *)message
{
	if ([m_delegate respondsToSelector:@selector(chat:didReceiveSystemMessage:)]) {
		[m_delegate chat:self didReceiveSystemMessage:message];
	}
}

- (void)handleContactTyping:(BOOL)isTyping
{
	if (isTyping != m_contactIsTyping) {
		[self willChangeValueForKey:@"contactTyping"];
		m_contactIsTyping = isTyping;
		[self didChangeValueForKey:@"contactTyping"];

		if (isTyping) {
			if ([m_delegate respondsToSelector:@selector(chatContactDidStartTyping:)]) {
				[m_delegate chatContactDidStartTyping:self];
			}
		}
		else {
			if ([m_delegate respondsToSelector:@selector(chatContactDidStopTyping:)]) {
				[m_delegate chatContactDidStopTyping:self];
			}
		}
		
	}
}

- (void)handleEndOfChat
{
	[self willChangeValueForKey:@"active"];
	m_isActive = NO;
	[self didChangeValueForKey:@"active"];
}

- (void)handleResultOfSMSSentTo:(NSString *)destinationPhoneNr withBody:(NSString *)msgBody resultCode:(int)result nrUsedMsgs:(int)nrUsedMsgs nrUsedChars:(int)nrUsedChars newCredit:(int)newCredit newFreeMessages:(int)newFreeMessages newTotalSentThisMonth:(int)newTotalSentThisMonth
{
	if ([m_delegate respondsToSelector:@selector(chat:didReceiveResultOfSMSSentTo:withBody:resultCode:nrUsedMsgs:nrUsedChars:newCredit:newFreeMessages:newTotalSentThisMonth:)]) {
		[m_delegate chat:self
				didReceiveResultOfSMSSentTo:destinationPhoneNr
				withBody:msgBody
			  resultCode:result
			  nrUsedMsgs:nrUsedMsgs
			 nrUsedChars:nrUsedChars
			   newCredit:newCredit
		 newFreeMessages:newFreeMessages
   newTotalSentThisMonth:newTotalSentThisMonth];
	}
}

- (void)handleSMSReceivedFrom:(NSString *)sourcePhoneNr withBody:(NSString *)msgBody dateString:(NSString *)dateString newCredit:(int)newCredit newFreeMessages:(int)newFreeMessages newTotalSentThisMonth:(int)newTotalSentThisMonth
{
	if ([m_delegate respondsToSelector:@selector(chat:didReceiveSMSFrom:withBody:date:newCredit:newFreeMessages:newTotalSentThisMonth:)]) {
		[m_delegate chat:self
				didReceiveSMSFrom:sourcePhoneNr
				withBody:msgBody
					date:[NSDate dateWithString:dateString]
			   newCredit:newCredit
		 newFreeMessages:newFreeMessages
   newTotalSentThisMonth:newTotalSentThisMonth];
	}
}

@end
