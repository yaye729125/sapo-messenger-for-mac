//
//  LFBoolean.h
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Authors: Joao Pavao <jppavao@criticalsoftware.com>
//           Jason Kim <jason@512k.org>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//
//
// A trivial wrapper object for BOOLs; utilized by LFPlatformBridge to differentiate boolean
// parameters from numerical (int) parameters stored in NSNumbers when invoking methods across the
// bridge.
//
// This class should only be used with the bridging mechanism, and never for any other purpose.
//

#import <Foundation/Foundation.h>


@interface LFBoolean : NSObject
{
	BOOL _value;
}
+ (LFBoolean *)yes;
+ (LFBoolean *)no;
- (id)initWithValue:(BOOL)value;
- (BOOL)boolValue;
- (NSString *)description;
@end
