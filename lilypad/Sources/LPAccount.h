//
//  LPAccount.h
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Authors: Joao Pavao <jppavao@criticalsoftware.com>
//           Jason Kim <jason@512k.org>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//
//
// Represents a user's account and associated connection settings.
//
// The account system is designed to accommodate multiple accounts, but it is currently only
// implemented to handle a single account. In the future, multiple accounts may exist, and more
// than one may be online and active at once.
//

#import <Cocoa/Cocoa.h>
#import <SystemConfiguration/SCNetworkReachability.h>


@class LPRoster, LPChat, LPGroupChat, LPContact, LPContactEntry, LPFileTransfer;
@class LPServerItemsInfo, LPSapoAgents;
@class LPPubManager;


@interface LPAccount : NSObject
{
	NSString			*m_UUID;
	
	NSString			*m_name;
	NSString			*m_JID;
	NSString			*m_password;
	NSString			*m_location;
	NSString			*m_customServerHost;
	BOOL				m_usesCustomServerHost;
	BOOL				m_usesSSL;
	BOOL				m_shouldAutoLogin;
	
	NSString			*m_lastRegisteredMSNEmail;
	NSString			*m_lastRegisteredMSNPassword;
	
	LPStatus			m_status;
	LPStatus			m_targetStatus;
	NSString			*m_statusMessage;
	
	BOOL				m_isDebugger;
	
	NSImage				*m_avatar;
	
	LPServerItemsInfo	*m_serverItemsInfo;
	LPSapoAgents		*m_sapoAgents;
	
	LPPubManager		*m_pubManager;
	
	// NSString (transport host) -> Dictionary w/ "isRegistered", "isLoggedIn", "username"
	NSMutableDictionary	*m_transportAgentsRegistrationStatus;
	
	int					m_smsCredit;
	int					m_smsNrOfFreeMessages;
	int					m_smsTotalSent;
	
	id					m_delegate;
	
	LPRoster			*m_roster;
	NSMutableDictionary	*m_activeChatsByID;			// NSNumber with the chatID --> LPChat
	NSMutableDictionary	*m_activeChatsByContact;	// LPContact --> LPChat
	NSMutableDictionary	*m_activeGroupChatsByID;	// NSNumber with the chatID --> LPGroupChat
	NSMutableDictionary *m_activeFileTransfersByID; // NSNumber with the file transfer ID --> LPFileTransfer
	
	id			m_automaticReconnectionContext;

	
/*  [jpp] These are apparently unused and impossible to use given the interface available in the bridge
	NSString	*_resource;

	int			_port;
	int			_priority;
	int			_proxyId;
	

	BOOL		_legacySSL;
	BOOL		_legacyProbe;
	BOOL		_allowPlain;
	BOOL		_requireTLS;
	BOOL		_requireMutualAuth;
	SSFMode		_ssfTLS;
	SSFMode		_ssfSASL;
	
	BOOL		_autoReconnect;
	NSString	*_dtProxyJid;
 */
	
}

- initWithUUID:(NSString *)uuid;

// Accessors
- (NSString *)UUID;
- (NSString *)name;
- (void)setName:(NSString *)theName;
- (NSString *)JID;
- (void)setJID:(NSString *)theJID;
- (NSString *)password;
- (void)setPassword:(NSString *)thePassword;
- (NSString *)location;
- (void)setLocation:(NSString *)theLocation;
- (NSString *)serverHost;
- (NSString *)customServerHost;
- (void)setCustomServerHost:(NSString *)theServerHost;
- (BOOL)usesCustomServerHost;
- (void)setUsesCustomServerHost:(BOOL)flag;
- (BOOL)usesSSL;
- (void)setUsesSSL:(BOOL)flag;
- (BOOL)shouldAutoLogin;
- (void)setShouldAutoLogin:(BOOL)flag;

// MSN Transport
- (NSString *)lastRegisteredMSNEmail;
- (void)setLastRegisteredMSNEmail:(NSString *)msnEmail;
- (NSString *)lastRegisteredMSNPassword;
- (void)setLastRegisteredMSNPassword:(NSString *)password;

- (void)registerWithTransportAgent:(NSString *)transportAgent username:(NSString *)username password:(NSString *)password;
- (void)unregisterWithTransportAgent:(NSString *)transportAgent;

- (NSString *)usernameRegisteredWithTransportAgent:(NSString *)transportAgent;
- (BOOL)isRegisteredWithTransportAgent:(NSString *)transportAgent;
- (BOOL)isLoggedInWithTransportAgent:(NSString *)transportAgent;

- (LPStatus)targetStatus;
- (LPStatus)status;
- (NSString *)statusMessage;
- (void)setTargetStatus:(LPStatus)theStatus;
- (void)setStatusMessage:(NSString *)theStatusMessage;
- (void)setStatusMessage:(NSString *)theStatusMessage saveToServer:(BOOL)saveFlag;
- (void)setTargetStatus:(LPStatus)theStatus message:(NSString *)theMessage;
- (void)setTargetStatus:(LPStatus)theStatus message:(NSString *)theMessage saveToServer:(BOOL)saveFlag;
- (BOOL)isOnline;
- (BOOL)isOffline;
- (BOOL)isDebugger;
- (BOOL)isTryingToAutoReconnect;

- (NSImage *)avatar;
- (void)setAvatar:(NSImage *)avatar;

- (LPServerItemsInfo *)serverItemsInfo;
- (LPSapoAgents *)sapoAgents;
- (LPPubManager *)pubManager;

- (int)SMSCreditAvailable;
- (int)nrOfFreeSMSMessagesAvailable;
- (int)nrOfSMSMessagesSentThisMonth;

- (id)delegate;
- (void)setDelegate:(id)delegate;

- (LPRoster *)roster;
- (void)sendXMLString:(NSString *)str;

- (LPChat *)startChatWithContact:(LPContact *)contact;
- (LPChat *)chatForID:(int)chatID;
- (LPChat *)chatForContact:(LPContact *)contact;
- (void)endChat:(LPChat *)chat;

- (LPGroupChat *)startGroupChatWithJID:(NSString *)chatRoomJID nickname:(NSString *)nickname password:(NSString *)password requestHistory:(BOOL)reqHist;
- (LPGroupChat *)groupChatForID:(int)chatID;
- (void)endGroupChat:(LPGroupChat *)chat;

- (LPFileTransfer *)startSendingFile:(NSString *)pathname toContactEntry:(LPContactEntry *)contactEntry;
- (LPFileTransfer *)fileTransferForID:(int)transferID;

@end


// Notifications
extern NSString *LPAccountWillChangeStatusNotification;
extern NSString *LPAccountDidChangeTransportInfoNotification;
extern NSString *LPAccountDidReceiveXMLStringNotification;
extern NSString *LPAccountDidSendXMLStringNotification;

// Notifications user info dictionary keys
extern NSString *LPXMLString;		// for LPAccountDidReceiveXMLStringNotification and LPAccountDidSendXMLStringNotification


enum { LPAccountSMSCreditUnknown = -1 };


@interface NSObject (LPAccountNotifications)
- (void)accountWillChangeStatus:(NSNotification *)notif;
- (void)accountDidChangeTransportInfo:(NSNotification *)notif;
- (void)accountDidReceiveXMLString:(NSNotification *)notif;
- (void)accountDidSendXMLString:(NSNotification *)notif;
@end


@interface NSObject (LPAccountDelegate)
- (void)account:(LPAccount *)account didReceiveErrorNamed:(NSString *)errorName errorKind:(int)errorKind errorCode:(int)errorCode;
- (void)account:(LPAccount *)account didReceiveIncomingChat:(LPChat *)newChat;
- (void)account:(LPAccount *)account didReceiveIncomingFileTransfer:(LPFileTransfer *)newFileTransfer;
- (void)account:(LPAccount *)account willStartOutgoingFileTransfer:(LPFileTransfer *)newFileTransfer;
- (void)account:(LPAccount *)account didReceiveLiveUpdateURL:(NSString *)URLString;
- (void)account:(LPAccount *)account didReceiveServerVarsDictionary:(NSDictionary *)varsValues;
- (void)account:(LPAccount *)account didReceiveOfflineMessageFromJID:(NSString *)jid nick:(NSString *)nick timestamp:(NSString *)timestamp subject:(NSString *)subject plainTextVariant:(NSString *)plainTextVariant XHTMLVariant:(NSString *)xhtmlVariant URLs:(NSArray *)urls;
- (void)account:(LPAccount *)account didReceiveHeadlineNotificationMessageFromChannel:(NSString *)channelName subject:(NSString *)subject body:(NSString *)body itemURL:(NSString *)itemURL flashURL:(NSString *)flashURL iconURL:(NSString *)iconURL;

- (void)account:(LPAccount *)account didReceiveChatRoomsList:(NSArray *)chatRoomsList;

@end
