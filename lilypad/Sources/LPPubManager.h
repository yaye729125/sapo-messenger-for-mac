//
//  LPPubManager.h
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
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
	NSString				*m_chatBotsURLStr;
	
	// Connections and other members needed to fetch the HTML for the pub
	NSURLConnection			*m_statusPhraseConnection;
	NSMutableData			*m_statusPhraseConnectionData;

	NSMutableDictionary		*m_chatBotsConnections; // NSValue(NSConnection) -> NSDictionary:
													//     "ConnectionData" -> NSMutableData
													//     "Delegate"       -> id
													//     "DidEndSel"      -> NSValue(SEL)
}

- (NSURL *)mainPubURL;
- (void)setMainPubURL:(NSURL *)url;
- (NSString *)statusPhraseHTML;
- (void)setStatusPhraseHTML:(NSString *)html;

// Fetch the HTML for a given chatbot. "sel" is expected to have the following signature:
//     - (void)fetchDidFinishWithHTML:(NSString *)htmlStr;
- (void)fetchHTMLForChatBot:(NSString *)chatBot delegate:(id)delegate didEndSelector:(SEL)sel;

- (void)handleUpdatedServerVars:(NSDictionary *)varsAndValues;
@end
