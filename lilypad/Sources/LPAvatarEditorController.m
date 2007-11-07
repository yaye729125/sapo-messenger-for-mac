//
//  LPAvatarEditorController.m
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "LPAccountsController.h"
#import "LPAvatarEditorController.h"
#import "LPColorBackgroundView.h"
#import "LPAvatarEditorView.h"
#import "LPVideoCamSnapshotView.h"


@implementation LPAvatarEditorController

- init
{
	return [super initWithWindowNibName:@"AvatarEditor"];
}

- (void)importAvatarFromPasteboard:(NSPasteboard *)pboard
{
	// Force the window to load so that the reference to the avatar editor view is valid
	[self window];
	[m_avatarEditorView setOriginalImageFromPasteboard:pboard];
}

#pragma mark -

- (void)p_switchToEditorView
{
	[m_videoCamSnapshotView stopPreviewing];
	[m_mainViewSwitcher selectTabViewItemAtIndex:0];
	[m_cameraEnableButton setState:NSOffState];
	
	[[self window] makeFirstResponder:m_avatarEditorView];
}

- (void)p_switchToCameraView
{
	[m_cameraEnableButton setState:NSOnState];
	[m_mainViewSwitcher selectTabViewItemAtIndex:1];
	
	if ([m_videoCamSnapshotView startPreviewing] == NO) {
		[self p_switchToEditorView];
		NSBeginAlertSheet(NSLocalizedString(@"Unable to access video camera.", @"video camera warning"),
						  nil, nil, nil,
						  [self window],
						  nil, NULL, NULL, NULL,
						  NSLocalizedString(@"The camera is probably already in use by some other application.", @"video camera warning"));
	}
}

- (void)p_loadStateFromUserDefaults
{
	NSDictionary *state = [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"Avatar Editor State"];
	
	if (state != nil) {
		NSData	*imageData = [state objectForKey:@"Image"];
		NSPoint cropRectCenter = NSPointFromString([state objectForKey:@"Crop Rect Center"]);
		float	zoomFactor = [[state objectForKey:@"Zoom Factor"] floatValue];
		
		NSImage *image = [NSUnarchiver unarchiveObjectWithData:imageData];
		
		[m_avatarEditorView setOriginalImage:image];
		[m_avatarEditorView setZoomFactor:zoomFactor];
		[m_avatarEditorView setCropRectCenterInImageScale:cropRectCenter];
	}
	else {
		[m_avatarEditorView setOriginalImage:nil];
	}
}

- (void)p_saveStateToUserDefaults
{
	NSImage *image = [m_avatarEditorView originalImage];
	
	if (image != nil) {
		NSData	*imageData = [NSArchiver archivedDataWithRootObject:image];
		NSPoint	cropRectCenter = [m_avatarEditorView cropRectCenterInImageScale];
		float	zoomFactor = [m_avatarEditorView zoomFactor];
		
		NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
			imageData, @"Image",
			NSStringFromPoint(cropRectCenter), @"Crop Rect Center",
			[NSNumber numberWithFloat:zoomFactor], @"Zoom Factor",
			nil];
		
		[[NSUserDefaults standardUserDefaults] setObject:dict forKey:@"Avatar Editor State"];
	}
}

#pragma mark -

- (void)windowDidLoad
{
	[m_accountController setContent:[LPAccountsController sharedAccountsController]];
	
	[[self window] setExcludedFromWindowsMenu:YES];
	[self setWindowFrameAutosaveName:@"BuddyIconEditor"];
	
	NSColor *editorBarLightColor = [NSColor colorWithCalibratedRed:0.5063 green:0.5455 blue:0.6122 alpha:1.0];
	NSColor *editorBarDarkColor  = [NSColor colorWithCalibratedRed:0.3337 green:0.3651 blue:0.4200 alpha:1.0];
	NSColor *cameraBarLightColor = [NSColor colorWithCalibratedRed:0.8196 green:0.3921 blue:0.4000 alpha:1.0];
	NSColor *cameraBarDarkColor  = [NSColor colorWithCalibratedRed:0.7098 green:0.0509 blue:0.0941 alpha:1.0];
	
	[m_shadedZoomBarForEditorView setBorderColor:[NSColor darkGrayColor]];
	[m_shadedZoomBarForEditorView setShadedBackgroundWithOrientation:LPVerticalBackgroundShading
														minEdgeColor:editorBarDarkColor
														maxEdgeColor:editorBarLightColor];
	
	[m_shadedZoomBarForCameraView setBorderColor:[NSColor darkGrayColor]];
	[m_shadedZoomBarForCameraView setShadedBackgroundWithOrientation:LPVerticalBackgroundShading
														minEdgeColor:cameraBarDarkColor
														maxEdgeColor:cameraBarLightColor];
	
	// Disable camera related stuff if there is none available
	if ([LPVideoCamSnapshotView videoCameraHardwareExists] == NO) {
		[m_cameraEnableButton setEnabled:NO];
		[m_cameraEnableButton setToolTip:NSLocalizedString(@"Unable to find a video camera.", @"video camera warning")];
	}
	
	[self p_loadStateFromUserDefaults];
}

- (IBAction)showWindow:(id)sender
{
	NSWindow *win = [self window];
	
	if (![win isVisible]) {
		[self p_switchToEditorView];
	}
	[super showWindow:sender];
}

#pragma mark -

- (IBAction)set:(id)sender
{
	// Avoid reverting to the saved state when the window closes
	m_shouldKeepChangesOnClose = YES;
	
	[self p_saveStateToUserDefaults];
	[[LPAccountsController sharedAccountsController] setAvatar:[m_avatarEditorView finalAvatarImage]];
	[[self window] close];
}

- (IBAction)cancel:(id)sender
{
	// Revert to the saved state
	m_shouldKeepChangesOnClose = NO;
	[[self window] close];
}

- (IBAction)toggleCamera:(id)sender
{
	if ([m_cameraEnableButton state] == NSOnState) {
		[self p_switchToCameraView];
	} else {
		[self p_switchToEditorView];
	}
}

- (IBAction)takeSnapshot:(id)sender
{
	// Load the sound before starting to perform the fade effects so that taking the picture is
	// slightly not so slow. :)
	NSSound *shutterSound = [NSSound soundNamed:@"photo_shutter"];
	
	// Fade the screen to 100% white
	CGDisplayFadeReservationToken	fadeToken;
	CGDisplayErr					err;
	float							fullFlashAlpha = 0.90;
	
	err = CGAcquireDisplayFadeReservation(kCGMaxDisplayReservationInterval, &fadeToken);
	if (err == kCGErrorSuccess) {
		CGDisplayFade(fadeToken, 0.15, kCGDisplayBlendNormal, fullFlashAlpha, 1.0, 1.0, 1.0, true);
	}
	
	// Take the picture
	[shutterSound play];
	NSImage *capturedFrame = [m_videoCamSnapshotView captureFrame];
	
	// Fade it back to the real screen image
	if (fadeToken != kCGDisplayFadeReservationInvalidToken) {
		CGDisplayFade(fadeToken, 0.15, fullFlashAlpha, kCGDisplayBlendNormal, 1.0, 1.0, 1.0, true);
		CGReleaseDisplayFadeReservation(fadeToken);
	}
	
	[m_avatarEditorView setOriginalImage:capturedFrame];
	[self p_switchToEditorView];
}

- (IBAction)chooseFile:(id)sender
{
	[self p_switchToEditorView];
	
	NSOpenPanel *op = [NSOpenPanel openPanel];
	[op beginSheetForDirectory:[NSHomeDirectory() stringByAppendingPathComponent:@"Pictures"]
						  file:nil
						 types:[NSImage imageFileTypes]
				modalForWindow:[self window]
				 modalDelegate:self
				didEndSelector:@selector(p_chooseFileDidEnd:returnCode:contextInfo:)
				   contextInfo:NULL];
}

- (void)p_chooseFileDidEnd:(NSOpenPanel *)panel returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	if (returnCode == NSOKButton) {
		NSImage *img = [[NSImage alloc] initWithContentsOfFile:[panel filename]];
		[m_avatarEditorView setOriginalImage:img];
		[img release];
	}
}

- (IBAction)useMinZoom:(id)sender
{
	[m_avatarEditorView setZoomFactor:0.0];
}

- (IBAction)useMaxZoom:(id)sender
{
	[m_avatarEditorView setZoomFactor:2.0];
}

- (void)windowWillClose:(NSNotification *)aNotification
{
	if (!m_shouldKeepChangesOnClose) {
		[self p_loadStateFromUserDefaults];
	} else {
		// Reset it
		m_shouldKeepChangesOnClose = NO;
	}
	
	// This effectively turns off the camera.
	[self p_switchToEditorView];
}

@end
