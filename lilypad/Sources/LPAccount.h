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

#import "LPAccountStatus.h"


@class LPRoster, LPChat, LPGroupChat, LPContact, LPContactEntry, LPFileTransfer;
@class LPServerItemsInfo, LPSapoAgents;
@class LPPubManager;


@interface LPAccount : NSObject <LPAccountStatus>
{
	NSString			*m_UUID;
	
	NSString			*m_description;
	BOOL				m_enabled;
	NSString			*m_name;
	NSString			*m_JID;
	NSString			*m_password;
	NSString			*m_location;
	NSString			*m_customServerHost;
	BOOL				m_usesCustomServerHost;
	BOOL				m_usesSSL;
	BOOL				m_locationUsesComputerName;
	
	NSString			*m_lastRegisteredMSNEmail;
	NSString			*m_lastRegisteredMSNPassword;
	
	LPStatus			m_status;
	LPStatus			m_targetStatus;
	NSString			*m_statusMessage;
	
	BOOL				m_isDebugger;
	
	NSImage				*m_avatar;
	
	LPServerItemsInfo	*m_serverItemsInfo;
	LPSapoAgents		*m_sapoAgents;
	NSDictionary		*m_sapoChatOrderDict;
	
	LPPubManager		*m_pubManager;
	
	// NSString (transport host) -> Dictionary w/ "isRegistered", "isLoggedIn", "username"
	NSMutableDictionary	*m_transportAgentsRegistrationStatus;
	
	int					m_smsCredit;
	int					m_smsNrOfFreeMessages;
	int					m_smsTotalSent;
	
	id					m_delegate;
	
	LPRoster			*m_roster;
	
	id					m_automaticReconnectionContext;

	
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
// designated initializer:
- initWithUUID:(NSString *)uuid roster:(LPRoster *)roster;

// Accessors
- (NSString *)UUID;
- (NSString *)description;
- (void)setDescription:(NSString *)theDescription;
- (BOOL)isEnabled;
- (void)setEnabled:(BOOL)enabled;
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
- (BOOL)locationUsesComputerName;
- (void)setLocationUsesComputerName:(BOOL)flag;

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

- (LPStatus)status;
- (NSString *)statusMessage;
- (void)setStatusMessage:(NSString *)theStatusMessage;
- (void)setStatusMessage:(NSString *)theStatusMessage saveToServer:(BOOL)saveFlag;
- (LPStatus)targetStatus;
- (void)setTargetStatus:(LPStatus)theStatus;
- (void)setTargetStatus:(LPStatus)theStatus saveToServer:(BOOL)saveFlag;
- (void)setTargetStatus:(LPStatus)theStatus message:(NSString *)theMessage saveToServer:(BOOL)saveFlag;
- (void)setTargetStatus:(LPStatus)theStatus message:(NSString *)theMessage saveToServer:(BOOL)saveFlag alsoSaveStatusMessage:(BOOL)saveMsg;
- (BOOL)isOnline;
- (BOOL)isOffline;
- (BOOL)isDebugger;
- (BOOL)isTryingToAutoReconnect;

- (NSImage *)avatar;
- (void)setAvatar:(NSImage *)avatar;

- (LPServerItemsInfo *)serverItemsInfo;
- (LPSapoAgents *)sapoAgents;
- (NSDictionary *)sapoChatOrderDictionary;
- (LPPubManager *)pubManager;

- (int)SMSCreditAvailable;
- (int)nrOfFreeSMSMessagesAvailable;
- (int)nrOfSMSMessagesSentThisMonth;

- (id)delegate;
- (void)setDelegate:(id)delegate;

- (LPRoster *)roster;
- (void)sendXMLString:(NSString *)str;

@end


// Notifications
extern NSString *LPAccountWillChangeStatusNotification;
extern NSString *LPAccountDidChangeStatusNotification;
extern NSString *LPAccountDidChangeTransportInfoNotification;
extern NSString *LPAccountDidReceiveXMLStringNotification;
extern NSString *LPAccountDidSendXMLStringNotification;

// Notifications user info dictionary keys
extern NSString *LPXMLString;		// for LPAccountDidReceiveXMLStringNotification and LPAccountDidSendXMLStringNotification


enum { LPAccountSMSCreditUnknown = -1 };


@interface NSObject (LPAccountNotifications)
- (void)accountWillChangeStatus:(NSNotification *)notif;
- (void)accountDidChangeStatus:(NSNotification *)notif;
- (void)accountDidChangeTransportInfo:(NSNotification *)notif;
- (void)accountDidReceiveXMLString:(NSNotification *)notif;
- (void)accountDidSendXMLString:(NSNotification *)notif;
@end


@interface NSObject (LPAccountDelegate)
- (void)account:(LPAccount *)account didReceiveErrorNamed:(NSString *)errorName errorKind:(int)errorKind errorCode:(int)errorCode;
- (void)account:(LPAccount *)account didReceiveSavedStatus:(LPStatus)status message:(NSString *)statusMessage;
- (void)account:(LPAccount *)account didReceiveLiveUpdateURL:(NSString *)URLString;
- (void)account:(LPAccount *)account didReceiveServerVarsDictionary:(NSDictionary *)varsValues;
- (void)account:(LPAccount *)account didReceiveOfflineMessageFromJID:(NSString *)jid nick:(NSString *)nick timestamp:(NSString *)timestamp subject:(NSString *)subject plainTextVariant:(NSString *)plainTextVariant XHTMLVariant:(NSString *)xhtmlVariant URLs:(NSArray *)urls;
- (void)account:(LPAccount *)account didReceiveHeadlineNotificationMessageFromChannel:(NSString *)channelName subject:(NSString *)subject body:(NSString *)body itemURL:(NSString *)itemURL flashURL:(NSString *)flashURL iconURL:(NSString *)iconURL;
- (void)account:(LPAccount *)account didReceiveChatRoomsList:(NSArray *)chatRoomsList forHost:(NSString *)host;
- (void)account:(LPAccount *)account didReceiveInfo:(NSDictionary *)chatRoomInfo forChatRoomWithJID:(NSString *)roomJID;
#warning MUC: the MUC invitation should probably handled by a handle... method in this class
- (void)account:(LPAccount *)account didReceiveInvitationToRoomWithJID:(NSString *)roomJID from:(NSString *)senderJID reason:(NSString *)reason password:(NSString *)password;
@end


#pragma mark -


@interface LPAccount (AccountsControllerInterface)
- (void)handleAccountConnectedToServerHost:(NSString *)serverHost;
- (void)handleConnectionErrorWithName:(NSString *)errorName kind:(int)errorKind code:(int)errorCode;
- (void)handleStatusUpdated:(NSString *)status message:(NSString *)statusMessage;
- (void)handleSavedStatusReceived:(NSString *)status message:(NSString *)statusMessage;
- (void)handleSelfAvatarChangedWithType:(NSString *)type data:(NSData *)avatarData;
- (void)handleAccountXmlIO:(NSString *)xml isInbound:(BOOL)isInbound;
- (void)handleReceivedOfflineMessageAt:(NSString *)timestamp fromJID:(NSString *)jid nickname:(NSString *)nick subject:(NSString *)subject plainTextMessage:(NSString *)plainTextMessage XHTMLMessaage:(NSString *)XHTMLMessage URLs:(NSArray *)URLs;
- (void)handleReceivedHeadlineNotificationMessageFromChannel:(NSString *)channel itemURL:(NSString *)item_url flashURL:(NSString *)flash_url iconURL:(NSString *)icon_url nickname:(NSString *)nick subject:(NSString *)subject plainTextMessage:(NSString *)plainTextMessage XHTMLMessage:(NSString *)XHTMLMessage;
- (void)handleSMSCreditUpdated:(int)credit freeMessages:(int)free_msgs totalSent:(int)total_sent_this_month;
- (void)handleSMSSentWithResult:(int)result nrUsedMessages:(int)nr_used_msgs nrUsedChars:(int)nr_used_chars
			 destinationPhoneNr:(NSString *)destination_phone_nr body:(NSString *)body
						 credit:(int)credit freeMessages:(int)free_msgs totalSent:(int)total_sent_this_month;
- (void)handleSMSReceivedAt:(NSString *)date_received fromPhoneNr:(NSString *)source_phone_nr body:(NSString *)body
					 credit:(int)credit freeMessages:(int)free_msgs totalSent:(int)total_sent_this_month;
- (void)handleReceivedLiveUpdateURLString:(NSString *)urlString;
- (void)handleReceivedSapoChatOrderDictionary:(NSDictionary *)orderDict;
- (void)handleTransportRegistrationStatusUpdatedForAgent:(NSString *)transportAgent
											isRegistered:(BOOL)isRegistered
												username:(NSString *)registeredUsername;
- (void)handleTransportLoggedInStatusUpdatedForAgent:(NSString *)transportAgent isLoggedIn:(BOOL)isLoggedIn;
- (void)handleReceivedServerVarsDictionary:(NSDictionary *)varsDict;
- (void)handleSelfVCardChanged:(NSDictionary *)vCard;
- (void)handleDebuggerStatusChanged:(BOOL)isDebugger;
@end
