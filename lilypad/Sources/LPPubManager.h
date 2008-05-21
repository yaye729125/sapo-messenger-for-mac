//
//  LPPubManager.h
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jpavao@co.sapo.pt>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import <Cocoa/Cocoa.h>


@class LPAccount;


@interface LPPubManager : NSObject
{
	// Pub Data
	NSURL					*m_mainPubURL;
	NSString				*m_statusPhraseHTML;
	NSURL					*m_chatBotAdsBaseURL;
	
	// Connections and other members needed to fetch the HTML for the pub
	NSURLConnection			*m_statusPhraseConnection;
	NSMutableData			*m_statusPhraseConnectionData;
}

- (NSURL *)mainPubURL;
- (void)setMainPubURL:(NSURL *)url;
- (NSString *)statusPhraseHTML;
- (void)setStatusPhraseHTML:(NSString *)html;
- (NSURL *)chatBotAdsBaseURL;
- (void)setChatBotAdsBaseURL:(NSURL *)baseChatBotsURL;

- (NSURL *)chatBotAdURLForBotWithJID:(NSString *)botJID;

- (void)handleUpdatedServerVars:(NSDictionary *)varsAndValues;

@end
