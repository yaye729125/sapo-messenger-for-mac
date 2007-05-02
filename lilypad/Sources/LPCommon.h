//
//  LPCommon.h
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
// Common strings and other definitions.
//

#import <Cocoa/Cocoa.h>


#define LPInvalidID		(-1)


// Presence types
typedef enum _LPStatus {
	LPStatusAvailable,
	LPStatusAway,
	LPStatusExtendedAway,
	LPStatusDoNotDisturb,
	LPStatusInvisible,
	LPStatusChat,
	LPStatusOffline,
	LPStatusConnecting,    // This one doesn't exist in the bridge. It's specific to the Cocoa side of Leapfrog
	LPStatusTypesCount
} LPStatus;


// Functions for converting between LPStatus and status string representations (used by the bridge)
LPStatus	LPStatusFromStatusString (NSString *statusStr);
NSString *	LPStatusStringFromStatus (LPStatus status);
NSImage  *	LPStatusIconFromStatus (LPStatus status);


// Returns the absolute path to our application's "Application Support" folder (normally it's inside "~/Library"),
// creating it first if necessary.
NSString *LPOurApplicationSupportFolderPath (void);
NSString *LPChatTranscriptsFolderPath (void);


// Value Transformers for Cocoa Bindings
extern NSString *LPStatusStringFromStatusTransformerName;
@interface LPStatusStringFromStatusTransformer : NSValueTransformer {}
@end

extern NSString *LPStatusIconFromStatusTransformerName;
@interface LPStatusIconFromStatusTransformer : NSValueTransformer {}
@end

extern NSString *LPPhoneNrStringFromPhoneJIDTransformerName;
@interface LPPhoneNrStringFromPhoneJIDTransformer : NSValueTransformer {}
@end


extern NSString *LPCurrentTuneStatusLegacyPrefix;
extern const unichar LPCurrentTuneStatusUnicharPrefix;

@interface NSString (StatusStringAdditions)
- (NSString *)stringByRemovingNewLineCharacters;
- (NSString *)prettyStatusString;
@end
