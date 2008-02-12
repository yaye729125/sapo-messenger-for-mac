//
//  LPFileTransfersController.h
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jpavao@co.sapo.pt>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import <Cocoa/Cocoa.h>


@class LPFileTransfer, LPFileTransferRow, LPColorBackgroundView, LPListView;


@interface LPFileTransfersController : NSWindowController
{
	IBOutlet NSView			*m_bottomBarView;
	IBOutlet LPListView		*m_listView;
	
	NSMutableArray			*m_rowControllers;
}

- (void)addFileTransfer:(LPFileTransfer *)transfer;
- (unsigned int)numberOfTransfers;

- (IBAction)clearFileTransfers:(id)sender;

@end
