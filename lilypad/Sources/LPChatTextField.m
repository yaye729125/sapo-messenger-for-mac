//
//  LPChatTextField.m
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jpavao@co.sapo.pt>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "LPChatTextField.h"


static BOOL PerformDragOperation(id <NSDraggingInfo> sender, LPChatTextField *tf)
{
	NSPasteboard	*pboard = [sender draggingPasteboard];
	NSArray			*draggedTypes = [pboard types];
	id				delegate = [tf delegate];
	BOOL			wasProcessed = NO;
	
	if ([draggedTypes containsObject:NSFilenamesPboardType]) {
		BOOL supportsFileDrops = NO;
		
		if ([delegate respondsToSelector:@selector(chatTextFieldShouldSupportFileDrops:)])
			supportsFileDrops = [delegate chatTextFieldShouldSupportFileDrops:tf];
		
		if (supportsFileDrops &&
			[delegate respondsToSelector:@selector(chatTextField:sendFileWithPathname:)])
		{
			NSArray	*files = [pboard propertyListForType:NSFilenamesPboardType];
			
			NSEnumerator *filePathEnumerator = [files objectEnumerator];
			NSString *filePath;
			
			while (filePath = [filePathEnumerator nextObject])
				[delegate chatTextField:tf sendFileWithPathname:filePath];
			
			wasProcessed = YES;
		}
	}
	
	return wasProcessed;
}


#pragma mark -


@interface LPChatTextFieldEditor : NSTextView
{
@public
	LPChatTextField *m_chatTextField;
}
@end


@implementation LPChatTextFieldEditor

- (NSArray *)acceptableDragTypes
{
	NSArray *retTypes = [super acceptableDragTypes];
	
	if (![retTypes containsObject:NSFilenamesPboardType])
		retTypes = [retTypes arrayByAddingObject:NSFilenamesPboardType];
	
	return retTypes;
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
	NSPasteboard *pb = [sender draggingPasteboard];
	
	if ([[pb types] containsObject:NSFilenamesPboardType]) {
		[self setBackgroundColor:[NSColor selectedTextBackgroundColor]];
		return NSDragOperationCopy;
	}
	else
		return [super draggingEntered:sender];
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender
{
	NSPasteboard *pb = [sender draggingPasteboard];
	
	if ([[pb types] containsObject:NSFilenamesPboardType])
		return NSDragOperationCopy;
	else
		return [super draggingUpdated:sender];
}

- (void)draggingExited:(id <NSDraggingInfo>)sender
{
	NSPasteboard *pb = [sender draggingPasteboard];
	
	if ([[pb types] containsObject:NSFilenamesPboardType]) {
		[self setBackgroundColor:[NSColor whiteColor]];
	}
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
	NSPasteboard *pb = [sender draggingPasteboard];
	
	if ([[pb types] containsObject:NSFilenamesPboardType]) {
		[self setBackgroundColor:[NSColor whiteColor]];
		return YES;
	}
	else
		return [super prepareForDragOperation:sender];
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
	return ( PerformDragOperation(sender, m_chatTextField) ?
			 YES :
			 [super performDragOperation:sender] );
}

@end


#pragma mark -


@implementation LPChatTextField

- (void)p_updateRegisteredDraggedTypes
{
	NSArray *registeredTypes = [self registeredDraggedTypes];
	
	if (![registeredTypes containsObject:NSFilenamesPboardType]) {
		NSArray *newRegisteredTypes = [registeredTypes arrayByAddingObject:NSFilenamesPboardType];
		[self registerForDraggedTypes:newRegisteredTypes];
	}
}

- initWithFrame:(NSRect)frameRect
{
	if (self = [super initWithFrame:frameRect]) {
		[self p_updateRegisteredDraggedTypes];
	}
	return self;
}

- (void)awakeFromNib
{
	[self p_updateRegisteredDraggedTypes];
	[super awakeFromNib];
}

- (void)dealloc
{
	[m_customFieldEditor release];
	[super dealloc];
}

- (id)customFieldEditor
{
	if (!m_customFieldEditor) {
		m_customFieldEditor = [[LPChatTextFieldEditor alloc] initWithFrame:[self bounds]];
		[m_customFieldEditor setFieldEditor:YES];
		((LPChatTextFieldEditor *)m_customFieldEditor)->m_chatTextField = self;
	}
	return m_customFieldEditor;
}

#pragma mark File Dragging Methods

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
	NSPasteboard *pb = [sender draggingPasteboard];
	
	if ([[pb types] containsObject:NSFilenamesPboardType]) {
		[self setBackgroundColor:[NSColor selectedTextBackgroundColor]];
		return NSDragOperationCopy;
	}
	else
		return [super draggingEntered:sender];
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender
{
	NSPasteboard *pb = [sender draggingPasteboard];
	
	if ([[pb types] containsObject:NSFilenamesPboardType])
		return NSDragOperationCopy;
	else
		return [super draggingUpdated:sender];
}

- (void)draggingExited:(id <NSDraggingInfo>)sender
{
	NSPasteboard *pb = [sender draggingPasteboard];
	
	if ([[pb types] containsObject:NSFilenamesPboardType]) {
		[self setBackgroundColor:[NSColor whiteColor]];
	}
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
	NSPasteboard *pb = [sender draggingPasteboard];
	
	if ([[pb types] containsObject:NSFilenamesPboardType]) {
		[self setBackgroundColor:[NSColor whiteColor]];
		return YES;
	}
	else
		return [super prepareForDragOperation:sender];
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
	return ( PerformDragOperation(sender, self) ?
			 YES :
			 [super performDragOperation:sender] );
}

@end
