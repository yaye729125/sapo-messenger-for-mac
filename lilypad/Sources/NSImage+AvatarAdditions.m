//
//  NSImage+AvatarAdditions.m
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jpavao@co.sapo.pt>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "NSImage+AvatarAdditions.h"


@implementation NSImage (AvatarAdditions)

- (NSImage *)framedAvatarImage
{
	NSImage *mask = [NSImage imageNamed:@"chatWindowAvatarMask"];
	NSImage *shadow = [NSImage imageNamed:@"chatWindowAvatarShadow"];
	NSImage *framedAvatar = [[mask copy] autorelease];
	NSRect  framedAvatarRect = { { 0.0 , 0.0 } , [framedAvatar size] };
	NSRect  shadowRect = { { 0.0 , 0.0 } , [shadow size] };
	NSRect  imgRect = { { 0.0 , 0.0 } , [self size] };
	
	[framedAvatar lockFocus];
	[self drawInRect:NSInsetRect(framedAvatarRect, 2.0, 2.0) fromRect:imgRect operation:NSCompositeSourceAtop fraction:1.0];
	[shadow drawInRect:framedAvatarRect fromRect:shadowRect operation:NSCompositeDestinationOver fraction:1.0];
	[framedAvatar unlockFocus];
	
	return framedAvatar;
}

@end
