//
//  LPSapoAgentsDebugWinCtrl.h
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


@interface LPSapoAgentsDebugWinCtrl : NSWindowController
{
	IBOutlet NSBrowser		*m_discoInfoBrowserByItem;
	IBOutlet NSBrowser		*m_discoInfoBrowserByFeature;
	IBOutlet NSBrowser		*m_sapoAgentsBrowser;
	
	LPAccount *m_account;
}
- initWithAccount:(LPAccount *)account;
@end
