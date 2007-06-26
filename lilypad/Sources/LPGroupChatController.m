//
//  LPGroupChatController.m
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "LPGroupChatController.h"
#import "LPGroupChat.h"
#import "LPGroupChatContact.h"
#import "LPGroupChatConfigController.h"
#import "LPAccount.h"
#import "LPContact.h"
#import "LPChatViewsController.h"
#import "LPColorBackgroundView.h"
#import "LPGrowingTextField.h"
#import "LPRosterDragAndDrop.h"
#import "LPCapabilitiesPredicates.h"

#import "NSString+HTMLAdditions.h"
#import "NSxString+EmoticonAdditions.h"


// Toolbar item identifiers
static NSString *ToolbarSetTopicIdentifier		= @"SetTopic";
static NSString *ToolbarSetNicknameIdentifier	= @"SetNickname";
static NSString *ToolbarInviteIdentifier		= @"Invite";
static NSString *ToolbarConfigRoomIdentifier	= @"ConfigRoom";


@interface LPGroupChatController (Private)
- (void)p_setupToolbar;
@end


@implementation LPGroupChatController

- initForJoiningRoomWithJID:(NSString *)roomJID onAccount:(LPAccount *)account nickname:(NSString *)nickname password:(NSString *)password includeChatHistory:(BOOL)includeHistory delegate:(id)delegate
{
	if (self = [self initWithWindowNibName:@"GroupChat"]) {
		m_delegate = delegate;
		
		// Join the room
		m_groupChat = [[account startGroupChatWithJID:roomJID
											 nickname:nickname password:password
									   requestHistory:includeHistory] retain];
		[m_groupChat setDelegate:self];
	}
	return self;
}

- (void)dealloc
{
	[m_groupChat release];
	[m_configController release];
	[super dealloc];
}

- (void)windowDidLoad
{
	[self p_setupToolbar];
	
	[m_chatViewsController setOwnerName:[m_groupChat nickname]];
	
	// Workaround for centering the icons.
	[m_segmentedButton setLabel:nil forSegment:0];
	[[m_segmentedButton cell] setToolTip:NSLocalizedString(@"Choose Emoticon", @"") forSegment:0];
	// IB displays a round segmented button that apparently needs less space than the on that ends up
	// showing in the app (the flat segmented button used in metal windows).
	[m_segmentedButton sizeToFit];
	
	[m_topControlsBar setBackgroundColor:[NSColor colorWithPatternImage:[NSImage imageNamed:@"chatIDBackground"]]];
	[m_topControlsBar setBorderColor:[NSColor colorWithCalibratedWhite:0.60 alpha:1.0]];
	
	[m_inputControlsBar setShadedBackgroundWithOrientation:LPVerticalBackgroundShading
											  minEdgeColor:[NSColor colorWithCalibratedWhite:0.79 alpha:1.0]
											  maxEdgeColor:[NSColor colorWithCalibratedWhite:0.99 alpha:1.0]];
	[m_inputControlsBar setBorderColor:[NSColor colorWithCalibratedWhite:0.80 alpha:1.0]];
	
	
	[m_participantsTableView setIntercellSpacing:NSMakeSize(15.0, 6.0)];
	
	NSSortDescriptor *sortByRole = [[NSSortDescriptor alloc] initWithKey:@"role"
															   ascending:NO
																selector:@selector(roleCompare:)];
	NSSortDescriptor *sortByNick = [[NSSortDescriptor alloc] initWithKey:@"nickname"
															   ascending:YES
																selector:@selector(caseInsensitiveCompare:)];
	[m_participantsController setSortDescriptors:[NSArray arrayWithObjects:sortByRole, sortByNick, nil]];
	[sortByRole release];
	[sortByNick release];
	
	// Make the participants list accept drops of contacts or contact entries
	[m_participantsTableView registerForDraggedTypes:
		[NSArray arrayWithObjects:LPRosterContactPboardType, LPRosterContactEntryPboardType, nil]];
	
	[m_participantsTableView setToolTip:NSLocalizedString(@"Drag a contact into this list to invite it to join this chat-room.", @"Group Chat participants list")];
}

- (LPGroupChat *)groupChat
{
	return [[m_groupChat retain] autorelease];
}

- (NSString *)roomJID
{
	return [m_groupChat roomJID];
}


#pragma mark -
#pragma mark Actions


- (IBAction)segmentClicked:(id)sender
{
	int clickedSegment = [sender selectedSegment];
    int clickedSegmentTag = [[sender cell] tagForSegment:clickedSegment];
	
	if (clickedSegmentTag == 0) {    // emoticons
		NSWindow *win = [self window];
		NSRect  buttonFrame = [sender frame];
		NSPoint topRight = [win convertBaseToScreen:[[sender superview] convertPoint:buttonFrame.origin
																			  toView:nil]];
		
		[sender setImage:[NSImage imageNamed:@"emoticonIconPressed"] forSegment:clickedSegment];
		[(NSView *)sender display];
		[m_chatViewsController pickEmoticonWithMenuTopRightAt:NSMakePoint(topRight.x + [sender widthForSegment:clickedSegment], topRight.y)
												 parentWindow:[self window]];
		[sender setImage:[NSImage imageNamed:@"emoticonIconUnpressed"] forSegment:clickedSegment];
		[(NSView *)sender display];
	}
}


- (IBAction)sendMessage:(id)sender
{
	NSString *message = [[m_inputTextField attributedStringValue] stringByFlatteningAttachedEmoticons];
	
	// Check if the text is all made of whitespace.
	static NSCharacterSet *requiredCharacters = nil;
	if (requiredCharacters == nil) {
		requiredCharacters = [[[NSCharacterSet whitespaceAndNewlineCharacterSet] invertedSet] retain];
	}
	
	if ([message rangeOfCharacterFromSet:requiredCharacters].location != NSNotFound) {
		[m_groupChat sendPlainTextMessage:message];
	}
	
	[[self window] makeFirstResponder:m_inputTextField];
	[m_inputTextField setStringValue:@""];
	[m_inputTextField calcContentSize];
}


- (IBAction)changeTopic:(id)sender
{
	NSString *currentTopic = [[self groupChat] topic];
	[m_changeTopicTextField setStringValue:(currentTopic ? currentTopic : @"")];
	
	[NSApp beginSheet:m_changeTopicWindow
	   modalForWindow:[self window]
		modalDelegate:self didEndSelector:NULL contextInfo:NULL];
}


- (IBAction)changeTopicOKClicked:(id)sender
{
	[NSApp endSheet:m_changeTopicWindow];
	[m_changeTopicWindow orderOut:nil];
	
	[[self groupChat] setTopic:[m_changeTopicTextField stringValue]];
}


- (IBAction)changeNickname:(id)sender
{
	NSString *currentNick = [[self groupChat] nickname];
	[m_changeNicknameTextField setStringValue:(currentNick ? currentNick : @"")];
	[m_changeNicknameTextField selectText:nil];
	
	[NSApp beginSheet:m_changeNicknameWindow
	   modalForWindow:[self window]
		modalDelegate:self didEndSelector:NULL contextInfo:NULL];
}


- (IBAction)changeNicknameOKClicked:(id)sender
{
	[NSApp endSheet:m_changeNicknameWindow];
	[m_changeNicknameWindow orderOut:nil];
	
	[[self groupChat] setNickname:[m_changeNicknameTextField stringValue]];
}


- (IBAction)inviteContact:(id)sender
{
	[m_inviteContactTextField setStringValue:@""];
	[m_inviteContactTextField selectText:nil];
	[m_inviteContactReasonTextField setStringValue:@""];
	
	[NSApp beginSheet:m_inviteContactWindow
	   modalForWindow:[self window]
		modalDelegate:self didEndSelector:NULL contextInfo:NULL];
}


- (void)p_inviteContactWithJID:(NSString *)jid reason:(NSString *)reason
{
	[[self groupChat] inviteJID:jid withReason:reason];
	
	// Append a "system message" to the chat transcript
	NSString *msgFormat = NSLocalizedString(@"An invitation to join this chat has been sent to <%@> with reason \"%@\".",
											@"System message: invitation for group chat was sent");
	NSString *msg = [NSString stringWithFormat:msgFormat, jid, reason];
	
	[m_chatViewsController appendDIVBlockToWebViewWithInnerHTML:[msg stringByEscapingHTMLEntities]
													   divClass:@"systemMessage"
											scrollToVisibleMode:LPScrollWithAnimationIfConvenient];
}


- (IBAction)inviteContactOKClicked:(id)sender
{
	[NSApp endSheet:m_inviteContactWindow];
	[m_inviteContactWindow orderOut:nil];
	
	[self p_inviteContactWithJID:[m_inviteContactTextField stringValue] reason:[m_inviteContactReasonTextField stringValue]];
}


- (LPGroupChatConfigController *)p_groupChatConfigController
{
	if (m_configController == nil) {
		m_configController = [[LPGroupChatConfigController alloc] initWithGroupChatController:self];
	}
	return m_configController;
}


- (IBAction)configureChatRoom:(id)sender
{
	[NSApp beginSheet:[[self p_groupChatConfigController] window]
	   modalForWindow:[self window]
		modalDelegate:self didEndSelector:NULL contextInfo:NULL];
}


- (IBAction)actionSheetCancelClicked:(id)sender
{
	NSWindow *sheet = [[self window] attachedSheet];
	
	[NSApp endSheet:sheet];
	[sheet orderOut:nil];
}


#pragma mark -
#pragma mark LPGroupChat Delegate Methods


- (void)groupChat:(LPGroupChat *)chat didReceivedMessage:(NSString *)msg fromContact:(LPGroupChatContact *)contact
{
	NSString *messageHTML = [m_chatViewsController HTMLifyRawMessageString:msg];
	NSString *authorName = (contact ? [contact nickname] : @"");
	NSString *htmlString = [m_chatViewsController HTMLStringForStandardBlockWithInnerHTML:messageHTML
																				timestamp:[NSDate date]
																			   authorName:authorName];
	
	// if it's an outbound message, also scroll down so that the user can see what he has just written
	[m_chatViewsController appendDIVBlockToWebViewWithInnerHTML:htmlString
													   divClass:@"messageBlock"
											scrollToVisibleMode:LPScrollWithAnimationIfConvenient];
}

- (void)groupChat:(LPGroupChat *)chat didReceivedSystemMessage:(NSString *)msg
{
	[m_chatViewsController appendDIVBlockToWebViewWithInnerHTML:[msg stringByEscapingHTMLEntities]
													   divClass:@"systemMessage"
											scrollToVisibleMode:LPScrollWithAnimationIfConvenient];
}


#pragma mark -
#pragma mark NSResponder Methods


- (void)keyDown:(NSEvent *)theEvent
{
	/* If a keyDown event reaches this low in the responder chain then it means that no text field is
	active to process the event. Activate the input text field and reroute the event that was received
	back to it. */
	if ([m_inputTextField canBecomeKeyView]) {
		NSWindow *window = [self window];
		[window makeFirstResponder:m_inputTextField];
		[[window firstResponder] keyDown:theEvent];
	} else {
		[super keyDown:theEvent];
	}
}


#pragma mark -
#pragma mark Private Methods


- (void)p_resizeInputFieldToContentsSize:(NSSize)newSize
{
	// Determine the new window frame
	float	heightDifference = newSize.height - NSHeight([m_inputTextField bounds]);
	
	if ((heightDifference > 0.5) || (heightDifference < -0.5)) {
		NSRect	newWindowFrame = [[self window] frame];
		
		newWindowFrame.size.height += heightDifference;
		newWindowFrame.origin.y -= heightDifference;
		
		// Do the actual resizing
		unsigned int splitViewResizeMask = [m_chatTranscriptSplitView autoresizingMask];
		unsigned int inputBoxResizeMask = [m_inputControlsBar autoresizingMask];
		
		[m_chatTranscriptSplitView setAutoresizingMask:NSViewMinYMargin];
		[m_inputControlsBar setAutoresizingMask:NSViewHeightSizable];
		
		[[self window] setFrame:newWindowFrame display:YES animate:YES];
		
		[m_inputControlsBar setAutoresizingMask:inputBoxResizeMask];
		[m_chatTranscriptSplitView setAutoresizingMask:splitViewResizeMask];
	}
}


#pragma mark -
#pragma mark NSWindow Delegate Methods


- (void)windowWillClose:(NSNotification *)aNotification
{
//	// Stop the scrolling animation if there is one running
//	if (m_scrollAnimationTimer != nil) {
//		[m_scrollAnimationTimer invalidate];
//		[m_scrollAnimationTimer release];
//		m_scrollAnimationTimer = nil;
//	}
//	
//	// Undo the retain cycles we have established until now
//	[m_audiblesController setChatController:nil];
//	[m_chatWebView setChat:nil];
//	
//	[[m_chatWebView windowScriptObject] setValue:[NSNull null] forKey:@"chatJSInterface"];
//	
//	// If the WebView hasn't finished loading when the window is closed (extremely rare, but could happen), then we don't
//	// want to do any of the setup that is about to happen in our frame load delegate methods, since the window is going away
//	// anyway. If we allowed that setup to happen when the window is already closed it could originate some crashes, since
//	// most of the stuff was already released by the time the delegate methods get called.
//	[m_chatWebView setFrameLoadDelegate:nil];
//	
//	// Make sure that the delayed perform of p_checkIfPubBannerIsNeeded doesn't fire
//	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(p_checkIfPubBannerIsNeeded) object:nil];
//	
//	// Stop auto-saving our chat transcript
//	[self p_setSaveChatTranscriptEnabled:NO];
//	
//	// Make sure that the content views of our drawers do not leak! (This is a known issue with Cocoa: drawers leak
//	// if their parent window is closed while they're open.)
//	[[[aNotification object] drawers] makeObjectsPerformSelector:@selector(setContentView:) withObject:nil];
//	[[[aNotification object] drawers] makeObjectsPerformSelector:@selector(close)];
	
	[m_groupChat endGroupChat];
	
	if ([m_delegate respondsToSelector:@selector(groupChatControllerWindowWillClose:)]) {
		[m_delegate groupChatControllerWindowWillClose:self];
	}
}


#pragma mark -
#pragma mark WebView Frame Load Delegate Methods


//- (void)webView:(WebView *)sender windowScriptObjectAvailable:(WebScriptObject *)windowScriptObject
//{
//	if (m_chatJSInterface == nil) {
//		m_chatJSInterface = [[LPChatJavaScriptInterface alloc] init];
//		[m_chatJSInterface setAccount:[[self chat] account]];
//	}
//	
//	/* Make it available to the WebView's JavaScript environment */
//	[windowScriptObject setValue:m_chatJSInterface forKey:@"chatJSInterface"];
//}


- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame
{
//	[self p_updateChatBackgroundColorFromDefaults];
//	[self p_setupChatDocumentTitle];
	
	[m_chatViewsController dumpQueuedMessagesToWebView];
	[m_chatViewsController showEmoticonsAsImages:[[NSUserDefaults standardUserDefaults] boolForKey:@"DisplayEmoticonImages"]];
}


#pragma mark WebView UI Delegate Methods


- (NSArray *)webView:(WebView *)sender contextMenuItemsForElement:(NSDictionary *)element defaultMenuItems:(NSArray *)defaultMenuItems
{
	if (sender == m_chatWebView) {
		NSMutableArray	*itemsToReturn = [NSMutableArray array];
		NSEnumerator	*enumerator = [defaultMenuItems objectEnumerator];
		id				menuItem;
		
		while ((menuItem = [enumerator nextObject]) != nil) {
			switch ([menuItem tag]) {
				case WebMenuItemTagCopy:
				case WebMenuItemTagSpellingGuess:
				case WebMenuItemTagNoGuessesFound:
				case WebMenuItemTagIgnoreSpelling:
				case WebMenuItemTagLearnSpelling:
				case WebMenuItemTagOther:
					[itemsToReturn addObject:menuItem];
					break;
			}
		}
		
		return itemsToReturn;
	}
	else {
		return [NSArray array];
	}
}


- (unsigned)webView:(WebView *)sender dragDestinationActionMaskForDraggingInfo:(id <NSDraggingInfo>)draggingInfo
{
	// We don't want the WebView to process anything dropped on it
	return WebDragDestinationActionNone;
}


- (unsigned)webView:(WebView *)sender dragSourceActionMaskForPoint:(NSPoint)point
{
	return WebDragSourceActionAny;
}


#pragma mark -

#pragma mark NSControl Delegate Methods

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)command
{
	if (command == @selector(pageDown:)						|| command == @selector(pageUp:)				||
		command == @selector(scrollPageDown:)				|| command == @selector(scrollPageUp:)			||
		command == @selector(moveToBeginningOfDocument:)	|| command == @selector(moveToEndOfDocument:)	||
		/* The following two selectors are undocumented. They're used by Cocoa to represent a Home or End key press. */
		command == @selector(scrollToBeginningOfDocument:)	|| command == @selector(scrollToEndOfDocument:)	 )
	{
		[[[m_chatWebView mainFrame] frameView] doCommandBySelector:command];
		return YES;
	}
	else {
		return NO;
	}
}


#pragma mark LPGrowingTextField Delegate Methods

- (void)growingTextField:(LPGrowingTextField *)textField contentSizeDidChange:(NSSize)neededSize
{
	[self p_resizeInputFieldToContentsSize:neededSize];
}


#pragma mark -
#pragma mark NSTableView Delegate Methods


- (NSString *)tableView:(NSTableView *)aTableView toolTipForCell:(NSCell *)aCell rect:(NSRectPointer)rect tableColumn:(NSTableColumn *)aTableColumn row:(int)row mouseLocation:(NSPoint)mouseLocation
{
	LPGroupChatContact *contact = [[m_participantsController arrangedObjects] objectAtIndex:row];
	NSString *realJID = [contact realJID];
	NSString *statusMessage = [contact statusMessage];
	
	return [NSString stringWithFormat:@"%@\n%@, %@\n\n%@%@%@",
		[contact nickname],
		[contact role], [contact affiliation],
		([realJID length] > 0 ? [NSString stringWithFormat:@"%@\n\n", realJID] : @""),
		NSLocalizedStringFromTable(LPStatusStringFromStatus([contact status]), @"Status", @""),
		([statusMessage length] > 0 ? [NSString stringWithFormat:@" : \"%@\"", statusMessage] : @"")];
}


- (void)tableView:(NSTableView *)aTableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
	LPGroupChatContact *contact = [[m_participantsController arrangedObjects] objectAtIndex:rowIndex];
	NSString *role = [contact role];
	
	if ([[aTableView selectedRowIndexes] containsIndex:rowIndex]) {
		[aCell setTextColor:[NSColor whiteColor]];
	}
	else if ([role isEqualToString:@"moderator"]) {
		[aCell setTextColor:[NSColor redColor]];
	}
	else if ([role isEqualToString:@"participant"]) {
		[aCell setTextColor:[NSColor blackColor]];
	}
	else if ([role isEqualToString:@"visitor"]) {
		[aCell setTextColor:[NSColor darkGrayColor]];
	}
}


//- (BOOL)tableView:(NSTableView *)aTableView writeRows:(NSArray *)rows toPasteboard:(NSPasteboard *)pboard
//{
//	// This method is deprecated in 10.4, but the alternative doesn't exist on 10.3, so we have to use this one.
//	
//}


- (NSDragOperation)tableView:(NSTableView *)aTableView validateDrop:(id <NSDraggingInfo>)info proposedRow:(int)row proposedDropOperation:(NSTableViewDropOperation)operation
{
	NSDragOperation		resultOp = NSDragOperationNone;
	NSArray				*draggedTypes = [[info draggingPasteboard] types];
	NSArray				*itemsBeingDragged = nil;
	
	if ([draggedTypes containsObject:LPRosterContactEntryPboardType]) {
		itemsBeingDragged = LPRosterContactEntriesBeingDragged(info);
	}
	else if ([draggedTypes containsObject:LPRosterContactPboardType]) {
		itemsBeingDragged = LPRosterContactsBeingDragged(info);
	}
	
	if ([itemsBeingDragged someItemInArrayPassesCapabilitiesPredicate:@selector(canDoMUC)]) {
		resultOp = NSDragOperationGeneric;
		// Highlight the whole table
		[aTableView setDropRow:-1 dropOperation:NSTableViewDropOn];
	}
	
	return resultOp;
}


- (BOOL)tableView:(NSTableView *)aTableView acceptDrop:(id <NSDraggingInfo>)info row:(int)row dropOperation:(NSTableViewDropOperation)operation
{
	NSPasteboard		*pboard = [info draggingPasteboard];
	NSArray				*draggedTypes = [pboard types];
	NSDragOperation		dragOpMask = [info draggingSourceOperationMask];
	
	if (dragOpMask & NSDragOperationGeneric) {
		if ([draggedTypes containsObject:LPRosterContactEntryPboardType]) {
			NSArray			*entriesBeingDragged = LPRosterContactEntriesBeingDragged(info);
			
			NSEnumerator	*entriesEnum = [entriesBeingDragged objectEnumerator];
			LPContactEntry	*entry;
			
			while (entry = [entriesEnum nextObject])
				if ([entry canDoMUC])
					[self p_inviteContactWithJID:[entry address] reason:@""];
		}
		else if ([draggedTypes containsObject:LPRosterContactPboardType]) {
			NSArray			*contactsBeingDragged = LPRosterContactsBeingDragged(info);
			NSEnumerator	*contactsEnum = [contactsBeingDragged objectEnumerator];
			LPContact		*contact;
			
			while (contact = [contactsEnum nextObject]) {
				LPContactEntry *entry = [contact firstContactEntryWithCapsFeature:@"http://jabber.org/protocol/muc"];
				if (entry)
					[self p_inviteContactWithJID:[entry address] reason:@""];
			}
		}
	}
		
	return YES;
}


#pragma mark -
#pragma mark NSSplitView Delegate Methods


- (void)splitView:(NSSplitView *)sender resizeSubviewsWithOldSize:(NSSize)oldSize
{
	NSAssert(([[sender subviews] count] == 2), @"We were expecting exactly 2 views inside the NSSplitView!");
	
	NSView *leftPane = [[sender subviews] objectAtIndex:0];
	NSView *rightPane = [[sender subviews] objectAtIndex:1];
	NSRect newLeftPaneFrame = [leftPane frame];
	NSRect newRightPaneFrame = [rightPane frame];
	NSRect newSplitViewFrame = [sender frame];
	
	float widthDelta = NSWidth(newSplitViewFrame) - oldSize.width;
	
	newLeftPaneFrame.size.height = newRightPaneFrame.size.height = newSplitViewFrame.size.height;
	newRightPaneFrame.origin.x += widthDelta;
	newLeftPaneFrame.size.width += widthDelta;
	
	[leftPane setFrame:newLeftPaneFrame];
	[rightPane setFrame:newRightPaneFrame];
}


#pragma mark -
#pragma mark NSToolbar Methods


- (void)p_setupToolbar 
{
	// Create a new toolbar instance
	NSToolbar *toolbar = [[NSToolbar alloc] initWithIdentifier:@"LPGroupChatToolbar"];
	
	//[toolbar setDisplayMode:NSToolbarDisplayModeIconOnly];
	[toolbar setSizeMode:NSToolbarSizeModeSmall];
	
	// Set up toolbar properties: Allow customization, give a default display mode, and remember state in user defaults 
	[toolbar setAllowsUserCustomization:YES];
	[toolbar setAutosavesConfiguration:YES];
	
	// We are the delegate.
	[toolbar setDelegate:self];
	
	// Attach the toolbar to the window.
	[[self window] setToolbar:toolbar];
	[toolbar release];
}


- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)identifier willBeInsertedIntoToolbar:(BOOL)willBeInserted 
{
	// Create our toolbar items.
    NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:identifier];
	
	if ([identifier isEqualToString:ToolbarSetTopicIdentifier])
	{
		[item setLabel:NSLocalizedString(@"Set Topic", @"toolbar button label")];
		[item setPaletteLabel:NSLocalizedString(@"Set Topic", @"toolbar button label")];
		[item setImage:[NSImage imageNamed:@"NSApplicationIcon"]];
		[item setToolTip:NSLocalizedString(@"Change the topic of this chat-room.", @"toolbar button")];
		[item setAction:@selector(changeTopic:)];
		[item setTarget:self];
	}
	else if ([identifier isEqualToString:ToolbarSetNicknameIdentifier])
	{
		[item setLabel:NSLocalizedString(@"Set Nickname", @"toolbar button label")];
		[item setPaletteLabel:NSLocalizedString(@"Set Nickname", @"toolbar button label")];
		[item setImage:[NSImage imageNamed:@"NSApplicationIcon"]];
		[item setToolTip:NSLocalizedString(@"Change your nickname on this chat-room.", @"toolbar button")];
		[item setAction:@selector(changeNickname:)];
		[item setTarget:self];
	}
	else if ([identifier isEqualToString:ToolbarInviteIdentifier])
	{
		[item setLabel:NSLocalizedString(@"Invite", @"toolbar button label")];
		[item setPaletteLabel:NSLocalizedString(@"Invite Contact", @"toolbar button label")];
		[item setImage:[NSImage imageNamed:@"NSApplicationIcon"]];
		[item setToolTip:NSLocalizedString(@"Invite another contact to this chat-room.", @"toolbar button")];
		[item setAction:@selector(inviteContact:)];
		[item setTarget:self];
	}
	else if ([identifier isEqualToString:ToolbarConfigRoomIdentifier])
	{
		[item setLabel:NSLocalizedString(@"Configure", @"toolbar button label")];
		[item setPaletteLabel:NSLocalizedString(@"Configure Room", @"toolbar button label")];
		[item setImage:[NSImage imageNamed:@"NSApplicationIcon"]];
		[item setToolTip:NSLocalizedString(@"Configure this chat-room.", @"toolbar button")];
		[item setAction:@selector(configureChatRoom:)];
		[item setTarget:self];
	}
	else
	{
		// Invalid identifier!
		NSLog(@"WARNING: Invalid toolbar item identifier: %@", identifier);
		item = nil;
	}
	
	return [item autorelease];
}


- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar 
{
    return [NSArray arrayWithObjects:
		ToolbarSetTopicIdentifier,
		ToolbarSetNicknameIdentifier,
		ToolbarInviteIdentifier,
		ToolbarConfigRoomIdentifier,
		NSToolbarSeparatorItemIdentifier,
		NSToolbarPrintItemIdentifier,
		NSToolbarFlexibleSpaceItemIdentifier,
		NSToolbarSeparatorItemIdentifier,
		NSToolbarCustomizeToolbarItemIdentifier,
		nil];
}


- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar 
{	
    return [NSArray arrayWithObjects:
		ToolbarSetTopicIdentifier,
		ToolbarSetNicknameIdentifier,
		ToolbarInviteIdentifier,
		ToolbarConfigRoomIdentifier,
		NSToolbarCustomizeToolbarItemIdentifier,
		NSToolbarFlexibleSpaceItemIdentifier,
		NSToolbarSeparatorItemIdentifier,
		NSToolbarSpaceItemIdentifier,
		NSToolbarPrintItemIdentifier,
		nil];
}


- (BOOL)validateToolbarItem:(NSToolbarItem *)theItem
{
	return YES;
}


@end
