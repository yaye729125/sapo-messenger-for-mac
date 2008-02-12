//
//  LPAvatarEditorController.h
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
@class LPColorBackgroundView, LPAvatarEditorView, LPVideoCamSnapshotView;


@interface LPAvatarEditorController : NSWindowController
{
	BOOL		m_shouldKeepChangesOnClose;
	
	IBOutlet LPAvatarEditorView			*m_avatarEditorView;
	IBOutlet LPColorBackgroundView		*m_shadedZoomBarForEditorView;
	IBOutlet LPVideoCamSnapshotView		*m_videoCamSnapshotView;
	IBOutlet LPColorBackgroundView		*m_shadedZoomBarForCameraView;
	IBOutlet NSTabView					*m_mainViewSwitcher;
	IBOutlet NSButton					*m_cameraEnableButton;
	
	IBOutlet NSObjectController			*m_accountController;
}

- (void)importAvatarFromPasteboard:(NSPasteboard *)pboard;

// Actions
- (IBAction)set:(id)sender;
- (IBAction)cancel:(id)sender;
- (IBAction)toggleCamera:(id)sender;
- (IBAction)takeSnapshot:(id)sender;
- (IBAction)chooseFile:(id)sender;
- (IBAction)useMinZoom:(id)sender;
- (IBAction)useMaxZoom:(id)sender;

@end
