//
//  LPInternalDataUpgradeManager.h
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import <Cocoa/Cocoa.h>


@interface LPInternalDataUpgradeManager : NSObject
{
	volatile BOOL					m_done;
	
	// NIB stuff
	IBOutlet NSWindow				*m_window;
	IBOutlet NSProgressIndicator	*m_progressIndicator;
}

+ (LPInternalDataUpgradeManager *)upgradeManager;
- (void)upgradeInternalDataIfNeeded;

@end
