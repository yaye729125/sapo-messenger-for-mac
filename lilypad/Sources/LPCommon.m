//
//  LPCommon.m
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Authors: Joao Pavao <jppavao@criticalsoftware.com>
//           Jason Kim <jason@512k.org>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import "LPCommon.h"


// Presence type strings to be passed to and returned by the bridge
static NSString *LPStatusAvailableString       = @"Online";
static NSString *LPStatusAwayString            = @"Away";
static NSString *LPStatusExtendedAwayString    = @"ExtendedAway";
static NSString *LPStatusDoNotDisturbString    = @"DoNotDisturb";
static NSString *LPStatusInvisibleString       = @"Invisible";
static NSString *LPStatusChatString            = @"Chat";
static NSString *LPStatusOfflineString         = @"Offline";
static NSString *LPStatusConnectingString      = @"LPStatusConnecting";


LPStatus LPStatusFromStatusString (NSString *statusStr)
{
	if ([statusStr isEqualToString: LPStatusAvailableString]) {
		return LPStatusAvailable;
	}
	else if ([statusStr isEqualToString: LPStatusAwayString]) {
		return LPStatusAway;
	}
	else if ([statusStr isEqualToString: LPStatusExtendedAwayString]) {
		return LPStatusExtendedAway;
	}
	else if ([statusStr isEqualToString: LPStatusDoNotDisturbString]) {
		return LPStatusDoNotDisturb;
	}
	else if ([statusStr isEqualToString: LPStatusInvisibleString]) {
		return LPStatusInvisible;
	}
	else if ([statusStr isEqualToString: LPStatusChatString]) {
		return LPStatusChat;
	}
	else if ([statusStr isEqualToString: LPStatusOfflineString]) {
		return LPStatusOffline;
	}
	else if ([statusStr isEqualToString: LPStatusConnectingString]) {
		return LPStatusConnecting;
	}
	else {
		[NSException raise:@"LPInvalidStatusStringException"
					format:@"The status string refers an unknown type of status"];
		return -1;
	}
}


NSString *LPStatusStringFromStatus (LPStatus status)
{
	switch (status) {
		case LPStatusAvailable:		return LPStatusAvailableString;
		case LPStatusAway:			return LPStatusAwayString;
		case LPStatusExtendedAway:	return LPStatusExtendedAwayString;
		case LPStatusDoNotDisturb:	return LPStatusDoNotDisturbString;
		case LPStatusInvisible:		return LPStatusInvisibleString;
		case LPStatusChat:			return LPStatusChatString;
		case LPStatusOffline:		return LPStatusOfflineString;
		case LPStatusConnecting:	return LPStatusConnectingString;

		default:
			[NSException raise:@"LPInvalidStatusException"
						format:@"The status string refers an unknown type of status"];
			return nil;
	}
}


NSImage *LPStatusIconFromStatus (LPStatus status)
{
	NSString *imageName = nil;
	
	switch (status) {
		case LPStatusAvailable:		imageName = @"iconAvailable";	break;
		case LPStatusAway:			imageName = @"iconAway";		break;
		case LPStatusExtendedAway:	imageName = @"iconXA";			break;
		case LPStatusDoNotDisturb:	imageName = @"iconDND";			break;
		case LPStatusInvisible:		imageName = @"iconInvisible";	break;
		case LPStatusChat:			imageName = @"iconAvailable";	break;
		case LPStatusOffline:		imageName = @"iconOffline";		break;
		case LPStatusConnecting:	imageName = @"iconConnecting";	break;
			
		default:
			[NSException raise:@"LPInvalidStatusException"
						format:@"The status string refers an unknown type of status"];
			return nil;
	}
	
	NSImage *img = [NSImage imageNamed:imageName];
	[img setSize:NSMakeSize(16.0, 16.0)];
	
	return img;
}


NSString *LPOurApplicationSupportFolderPath (void)
{
	NSArray			*dirs = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
	NSString		*appSupportFolderPath = [dirs objectAtIndex:0];
	NSFileManager	*fm = [NSFileManager defaultManager];
	BOOL			isDirectory = NO;
	
	if (![fm fileExistsAtPath:appSupportFolderPath]) {
		[fm createDirectoryAtPath:appSupportFolderPath attributes:nil];
	}
	
	/* Now that we have the Application Support folder path, create the directory for our app. */
	NSString *ourAppDirectoryName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleExecutable"];
	NSString *ourAppDirectoryPath = [appSupportFolderPath stringByAppendingPathComponent:ourAppDirectoryName];
	
	if (![fm fileExistsAtPath:ourAppDirectoryPath isDirectory:&isDirectory]) {
		[fm createDirectoryAtPath:ourAppDirectoryPath attributes:nil];
	}
	else if (!isDirectory) {
		[fm removeItemAtPath:ourAppDirectoryPath error:NULL];
		[fm createDirectoryAtPath:ourAppDirectoryPath attributes:nil];
	}
	
	return ourAppDirectoryPath;
}


NSString *LPOurApplicationCachesFolderPath (void)
{
	NSArray			*dirs = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
	NSString		*cachesFolderPath = [dirs objectAtIndex:0];
	NSFileManager	*fm = [NSFileManager defaultManager];
	BOOL			isDirectory = NO;
	
	if (![fm fileExistsAtPath:cachesFolderPath]) {
		[fm createDirectoryAtPath:cachesFolderPath attributes:nil];
	}
	
	/* Now that we have the Caches folder path, create the directory for our app. */
	NSString *ourAppDirectoryName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleExecutable"];
	NSString *ourAppDirectoryPath = [cachesFolderPath stringByAppendingPathComponent:ourAppDirectoryName];
	
	if (![fm fileExistsAtPath:ourAppDirectoryPath]) {
		[fm createDirectoryAtPath:ourAppDirectoryPath attributes:nil];
	}
	
	/* We add an additional level so that the base caches dir for the app doesn't become too cluttered. Also,
	 * Mac OS X seems to be using the app caches folder to store some private data in some numbered folders.
	 * By having all our data inside this "accounts data" folder, we can trash it at will without messing with
	 * the private data cached by the system. */
	NSString *accountsDataDirectoryPath = [ourAppDirectoryPath stringByAppendingPathComponent:@"accounts data"];
	
	// Make sure it exists
	if (![fm fileExistsAtPath:accountsDataDirectoryPath isDirectory:&isDirectory]) {
		[fm createDirectoryAtPath:accountsDataDirectoryPath attributes:nil];
	}
	else if (!isDirectory) {
		[fm removeItemAtPath:accountsDataDirectoryPath error:NULL];
		[fm createDirectoryAtPath:accountsDataDirectoryPath attributes:nil];
	}
	
	return accountsDataDirectoryPath;
}


NSString *LPDownloadsFolderPath (void)
{
	NSString *folderPath = [[NSUserDefaults standardUserDefaults] stringForKey:@"DownloadsFolder"];
	
	if (folderPath == nil) {
		NSArray *foundFolders = ((floor(NSAppKitVersionNumber) <= NSAppKitVersionNumber10_4) ?
								 nil :
								 NSSearchPathForDirectoriesInDomains(NSDownloadsDirectory, NSUserDomainMask, YES));
		
		if ([foundFolders count] == 0) {
			foundFolders = NSSearchPathForDirectoriesInDomains(NSDesktopDirectory, NSUserDomainMask, YES);
			
			if ([foundFolders count] == 0) {
				// Build the path manually (last resort)
				folderPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Desktop"];
			}
		}
		
		if (folderPath == nil) {
			if ([foundFolders count] > 0) {
				folderPath = [foundFolders objectAtIndex:0];
			}
			else {
				[NSException raise:@"DownloadsFolderNotFoundException"
							format:@"Couldn't determine the filepath where downloads are to be saved."];
			}
		}
	}
	
	NSFileManager *fm = [NSFileManager defaultManager];
	BOOL isDirectory;
	
	if ([fm fileExistsAtPath:folderPath isDirectory:&isDirectory]) {
		if (!isDirectory) {
			NSLog(@"Chat transcripts folder path exists but it isn't a directory!");
			folderPath = nil;
		}
	}
	else {
		// Doesn't exist. Create it!
		[fm createDirectoryAtPath:folderPath attributes:nil];
	}
	
	return folderPath;
}


NSString *LPChatTranscriptsFolderPath (void)
{
	NSString *folderPath = [[NSUserDefaults standardUserDefaults] stringForKey:@"ChatTranscriptsFolderPath"];
	
	if (folderPath == nil) {
		NSArray *foundFolders = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
		
		if ([foundFolders count] > 0) {
			folderPath = [foundFolders objectAtIndex:0];
		} else {
			// Build the path manually (last resort)
			folderPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
		}
		
		NSString *ourFolderName = [NSString stringWithFormat: @"%@ Chat Transcripts",
			[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleExecutable"]];
		
		folderPath = [folderPath stringByAppendingPathComponent:ourFolderName];
	}
	
	NSFileManager *fm = [NSFileManager defaultManager];
	BOOL isDirectory;
	
	if ([fm fileExistsAtPath:folderPath isDirectory:&isDirectory]) {
		if (!isDirectory) {
			NSLog(@"Chat transcripts folder path exists but it isn't a directory!");
			folderPath = nil;
		}
	}
	else {
		// Doesn't exist. Create it!
		[fm createDirectoryAtPath:folderPath attributes:nil];
	}
	
	return folderPath;
}



NSString *LPStatusStringFromStatusTransformerName = @"LPStatusStringFromStatusTransformer";

@implementation LPStatusStringFromStatusTransformer
+ (Class)transformedValueClass { return [NSString class]; }
+ (BOOL)allowsReverseTransformation { return NO; }
- (id)transformedValue:(id)value { return NSLocalizedStringFromTable(LPStatusStringFromStatus([value intValue]),
																	 @"Status", @""); }
@end


NSString *LPStatusIconFromStatusTransformerName = @"LPStatusIconFromStatusTransformer";

@implementation LPStatusIconFromStatusTransformer
+ (Class)transformedValueClass { return [NSImage class]; }
+ (BOOL)allowsReverseTransformation { return NO; }
- (id)transformedValue:(id)value { return LPStatusIconFromStatus([value intValue]); }
@end


NSString *LPPhoneNrStringFromPhoneJIDTransformerName = @"LPPhoneNrStringFromPhoneJIDTransformer";

@implementation LPPhoneNrStringFromPhoneJIDTransformer
+ (Class)transformedValueClass { return [NSString class]; }
+ (BOOL)allowsReverseTransformation { return NO; }
- (id)transformedValue:(id)value { return [value userPresentablePhoneNrRepresentation]; }
- (id)reverseTransformedValue:(id)value { return [value internalPhoneJIDRepresentation]; }
@end



NSString *LPCurrentTuneStatusLegacyPrefix = @"A ouvir : ";
const unichar LPCurrentTuneStatusUnicharPrefix = 0x266B;	// BEAMED EIGHTH NOTES

@implementation NSString (StatusStringAdditions)

- (NSString *)stringByRemovingNewLineCharacters
{
	NSMutableString *oneLineStatus = [self mutableCopy];
	
	[oneLineStatus replaceOccurrencesOfString:@"\n" withString:@" "
									  options:0 range:NSMakeRange(0, [oneLineStatus length])];
	[oneLineStatus replaceOccurrencesOfString:@"\r" withString:@" "
									  options:0 range:NSMakeRange(0, [oneLineStatus length])];
	
	return [oneLineStatus autorelease];
}

- (NSString *)prettyStatusString
{
	NSString *oneLineStatus = [self stringByRemovingNewLineCharacters];
	
	if ([oneLineStatus hasPrefix:LPCurrentTuneStatusLegacyPrefix]) {
		// Translate the current tune prefix: replace it with a small music note
		return [NSString stringWithFormat:@"%C %@",
			LPCurrentTuneStatusUnicharPrefix,
			[oneLineStatus substringFromIndex:[LPCurrentTuneStatusLegacyPrefix length]]];
	} else {
		return oneLineStatus;
	}
}

@end
