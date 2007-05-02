//
//  LPChatJavaScriptInterface.h
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


@interface LPChatJavaScriptInterface : NSObject
{
	LPAccount	*m_account;
}
- (LPAccount *)account;
- (void)setAccount:(LPAccount *)account;
@end
