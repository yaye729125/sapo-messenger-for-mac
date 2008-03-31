//
//  JKPrefsController.m
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Authors: Jason Kim <jason@512k.org>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "JKPrefsController.h"


@interface JKPrefsController ()  // Private Methods
- (void)p_setupToolbar;
@end


@implementation JKPrefsController


#pragma mark -
#pragma mark Initialization


- (void)awakeFromNib
{
	m_identifiers = [[NSMutableArray alloc] init];
	m_toolbarItems = [[NSMutableDictionary alloc] init];
	m_views = [[NSMutableDictionary alloc] init];
}


- (void)dealloc
{
	[m_identifiers release];
	[m_toolbarItems release];
	[m_views release];
	[m_window release];

	[super dealloc];
}


#pragma mark -
#pragma mark Actions


// This action is automatically invoked by the toolbar items.
- (IBAction)p_activatePrefs:(id)sender
{
	NSString *identifier = [sender itemIdentifier];
	NSView *emptyView = [[NSView alloc] init];
	NSView *newView = nil;

	// Choose the appropriate subView to use.
	newView = [m_views objectForKey:identifier];
	
	if ((newView != nil) && (newView != [m_window contentView]))
	{
		NSRect newFrame = [newView frame];
		NSRect oldFrame = [[m_window contentView] frame];
		NSRect windowFrame = [m_window frame];
		int offset;

		// Reposition the frame so that the top of the window doesn't move.
		offset = NSHeight(oldFrame) - NSHeight(newFrame);
		newFrame.origin.y = windowFrame.origin.y + offset; 
		newFrame.origin.x = windowFrame.origin.x;
		
		// Include the height of the toolbar and title.
		offset = windowFrame.size.height - oldFrame.size.height;
		newFrame.size.height += offset;

		[m_window setContentView:emptyView];
		[m_window setFrame:newFrame display:YES animate:YES];
		[m_window setContentView:newView];
		[m_window setTitle:[sender label]];
		[m_window makeFirstResponder:newView];
	}
	
	[emptyView release];
}


- (IBAction)showPrefs:(id)sender
{
	if (m_window == nil) {
		[self loadNib];
		[self initializePrefPanes];
		[self p_setupToolbar];
	}
	
	if (![m_window isVisible])
		[m_window center];
	[m_window makeKeyAndOrderFront:sender];
}


#pragma mark -
#pragma mark Instance Methods


- (void)addPrefWithView:(NSView *)view label:(NSString *)label image:(NSImage *)image identifier:(NSString *)identifier;
{
	if (![m_identifiers containsObject:identifier]) {
		NSToolbarItem *toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:identifier] autorelease];
		
		// Create the toolbar item.
		[toolbarItem setLabel:label];
		[toolbarItem setImage:image];
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(p_activatePrefs:)];
		
		[m_toolbarItems setObject:toolbarItem forKey:identifier];
		[m_views setObject:view forKey:identifier];
		[m_identifiers addObject:identifier];
		
		NSToolbar *tb = [m_window toolbar];
		[tb insertItemWithItemIdentifier:identifier atIndex:[[tb items] count]];
	}
}


- (void)initializePrefPanes
{
	// Default implementation does nothing. Subclasses override this to add items to
	// the preferences window by calling addPrefView:identifier.
}


- (void)loadNib
{
	// Default implementation does nothing. Subclasses should load the appropriate nib here.
}


- (NSWindow *)window
{
	return [[m_window retain] autorelease];
}


#pragma mark -
#pragma mark NSToolbar Methods


- (void)p_setupToolbar 
{
	// Create a new toolbar instance, and attach it to our document window 
	NSToolbar *toolbar = [[[NSToolbar alloc] initWithIdentifier:@"JKPrefsToolbar"] autorelease];

	// Set up toolbar properties: Allow customization, give a default display mode, and remember state in user defaults 
	[toolbar setAllowsUserCustomization: NO];
	[toolbar setAutosavesConfiguration: NO];
	[toolbar setDisplayMode:NSToolbarDisplayModeIconAndLabel];

	// We are the delegate
	[toolbar setDelegate:self];

	// Select the first item by default.
	if ([m_identifiers count] > 0)
	{
		NSString *identifier = [m_identifiers objectAtIndex:0];
		[self p_activatePrefs:[m_toolbarItems objectForKey:identifier]];
		[toolbar setSelectedItemIdentifier:identifier];
	}

	// Attach the toolbar to the document window 
	[m_window setToolbar:toolbar];

	// Remove the "pill" button from the toolbar.
	if (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_3)
	{
		[m_window setShowsToolbarButton:NO];
	}
	else
	{
		// Instead of removing it from the superview, we'll just make the button unclickable.
		[[m_window standardWindowButton:NSWindowToolbarButton] setFrame:NSZeroRect];
	}
}


- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)identifier willBeInsertedIntoToolbar:(BOOL)willBeInserted 
{
	return [m_toolbarItems objectForKey:identifier];
}


- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar 
{
    return [self toolbarAllowedItemIdentifiers:toolbar];
}


- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar 
{	
    return [[m_identifiers copy] autorelease];
}


- (NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar;
{
    return [self toolbarAllowedItemIdentifiers:toolbar];
}


@end
