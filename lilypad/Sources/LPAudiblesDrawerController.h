//
//  LPAudiblesDrawerController.h
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import <Cocoa/Cocoa.h>


@class LPSlidingTilesView, LPAudibleSet, LPChatController;


@interface LPAudiblesDrawerController : NSObject
{
	IBOutlet NSDrawer				*m_audiblesDrawer;
	IBOutlet LPSlidingTilesView		*m_audiblesView;
	IBOutlet NSButton				*m_sendButton;
	IBOutlet NSPopUpButton			*m_categoryPopUp;
	IBOutlet NSObjectController		*m_audibleSetController;
	
	IBOutlet LPChatController		*m_chatController;
	
	LPAudibleSet					*m_audibleSet;
	NSMutableDictionary				*m_tilesForCurrentCategory;		// Audible Resource Name --> Audible Tile View
}

- (LPChatController *)chatController;
- (void)setChatController:(LPChatController *)chatCtrl;

- (LPAudibleSet *)audibleSet;
- (NSString *)selectedCategory;
- (NSDrawerState)drawerState;

- (IBAction)toggleDrawer:(id)sender;
- (IBAction)categoryChanged:(id)sender;
- (IBAction)sendAudible:(id)sender;

@end
