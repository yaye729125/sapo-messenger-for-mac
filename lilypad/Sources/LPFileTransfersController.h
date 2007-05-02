//
//  LPFileTransfersController.h
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import <Cocoa/Cocoa.h>


@class LPFileTransfer, LPFileTransferRow, LPColorBackgroundView, LPListView;


@interface LPFileTransfersController : NSWindowController
{
	IBOutlet LPColorBackgroundView	*m_bottomBarView;
	IBOutlet LPListView				*m_listView;
	
	NSMutableArray					*m_rowControllers;
}

- (void)addFileTransfer:(LPFileTransfer *)transfer;
@end
