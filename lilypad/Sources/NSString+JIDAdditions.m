//
//  NSString+JIDAdditions.m
//  Lilypad
//
//	Copyright (C) 2006-2007 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jppavao@criticalsoftware.com>
//
//	For more information on licensing, read the README file.
//	Para mais informa›es sobre o licenciamento, leia o ficheiro README.
//

#import "NSString+JIDAdditions.h"



@implementation NSString (JIDAdditions)

- (NSString *)bareJIDComponent
{
	return [[self componentsSeparatedByString:@"/"] objectAtIndex:0];
}

- (NSString *)JIDResourceNameComponent
{
	NSArray *jidComponents = [self componentsSeparatedByString:@"/"];
	
	if ([jidComponents count] > 1)
		return [jidComponents lastObject];
	else
		return nil;
}

- (NSString *)JIDUsernameComponent
{
	NSArray *jidComponents = [[self bareJIDComponent] componentsSeparatedByString:@"@"];
	
	if ([jidComponents count] > 1)
		return [jidComponents objectAtIndex:0];
	else
		return nil;
}

- (NSString *)JIDHostnameComponent
{
	return [[[self bareJIDComponent] componentsSeparatedByString:@"@"] lastObject];
}

- (BOOL)isPhoneJID
{
	NSString *hostname = [self JIDHostnameComponent];
	
	return ( [hostname isEqualToString:@"phone.im.sapo.pt"] ||
			 [hostname isEqualToString:@"sms.im.sapo.pt"] );
}

- (NSString *)userPresentablePhoneNrRepresentation
{
	NSString *result = nil;
	NSString *phoneNrComponent = [self JIDUsernameComponent];
	NSString *hostComponent = [self JIDHostnameComponent];
	BOOL	 isOldFormatJID = ([hostComponent isEqualToString:@"sms.im.sapo.pt"] && ([phoneNrComponent length] == 9));
	
	if ([phoneNrComponent hasPrefix:@"00351"] || isOldFormatJID) {
		// Portuguese Phone Nr
		NSString *phoneNr = (isOldFormatJID ? phoneNrComponent : [phoneNrComponent substringFromIndex:5]);
		
		if ([phoneNr length] == 9) {
			unichar	chars[9];
			[phoneNr getCharacters:chars];
			
			NSString *formatStr = nil;
			
			if ([phoneNr hasPrefix:@"91"] ||
				[phoneNr hasPrefix:@"93"] ||
				[phoneNr hasPrefix:@"96"] ||
				([phoneNr hasPrefix:@"21"] && (chars[2] != ((unichar)'0'))) ||   /* "21" except "210" */
				[phoneNr hasPrefix:@"22"])
			{
				formatStr = @"%C%C %C%C%C %C%C %C%C";
			}
			else if ([phoneNr hasPrefix:@"7"] || [phoneNr hasPrefix:@"8"]) {
				formatStr = @"%C%C%C %C%C%C %C%C%C";
			}
			else {
				formatStr = @"%C%C%C %C%C %C%C %C%C";
			}
			
			result = [NSString stringWithFormat:formatStr,
				chars[0], chars[1], chars[2], chars[3], chars[4], chars[5], chars[6], chars[7], chars[8]];
		}
		else {
			result = phoneNr;
		}
	}
	else if ([phoneNrComponent hasPrefix:@"00"]) {
		result = [NSString stringWithFormat:@"+%@", [phoneNrComponent substringFromIndex:2]];
	}
	else {
		result = phoneNrComponent;
	}
	
	return result;
}

- (NSString *)internalPhoneNrRepresentation
{
	NSString *result = nil;
	
	// Cleanup spaces and other chars from the string
	NSMutableString	*cleanedUpPhoneNr = [NSMutableString string];
	NSCharacterSet	*charSet = [NSCharacterSet characterSetWithCharactersInString:@" \t\n-_()[]{},.;:/|"];
	NSRange			searchRange = { 0, [self length] };
	NSRange			foundCharRange;
	
	do {
		foundCharRange = [self rangeOfCharacterFromSet:charSet options:0 range:searchRange];
		
		if (foundCharRange.location != NSNotFound) {
			[cleanedUpPhoneNr appendString:[self substringWithRange:NSMakeRange(searchRange.location,
																				foundCharRange.location - searchRange.location)]];
			searchRange.location = foundCharRange.location + foundCharRange.length;
			searchRange.length = [self length] - searchRange.location;
		}
		else {
			[cleanedUpPhoneNr appendString:[self substringWithRange:searchRange]];
		}
	} while (foundCharRange.location != NSNotFound && searchRange.length > 0);
	
	
	if ([cleanedUpPhoneNr hasPrefix:@"00"]) {
		result = cleanedUpPhoneNr;
	}
	else if ([cleanedUpPhoneNr hasPrefix:@"+"]) {
		result = [NSString stringWithFormat:@"00%@", [cleanedUpPhoneNr substringFromIndex:1]];
	}
	else {
		result = [NSString stringWithFormat:@"00351%@", cleanedUpPhoneNr];
	}
	
	return result;
}

- (NSString *)internalPhoneJIDRepresentation
{
	return [NSString stringWithFormat:@"%@@phone.im.sapo.pt", [self internalPhoneNrRepresentation]];
}

- (NSString *)userPresentableJIDAsPerAgentsDictionary:(NSDictionary *)sapoAgentsDict
{
	NSString *res = self;
	
	if ([self isPhoneJID]) {
		res = [self userPresentablePhoneNrRepresentation];
	}
	else {
		NSString *username = [self JIDUsernameComponent];
		NSString *host = [self JIDHostnameComponent];
		
		if (host != nil && [[sapoAgentsDict objectForKey:host] objectForKey:@"transport"] != nil) {
			NSArray *realJIDComponents = [username componentsSeparatedByString:@"%"];
			NSString *transportName = [[sapoAgentsDict objectForKey:host] objectForKey:@"name"];
			
			NSString *address = nil;
			
			if ([realJIDComponents count] >= 2) {
				address = [NSString stringWithFormat:@"%@@%@",
					[realJIDComponents objectAtIndex:0],
					[realJIDComponents objectAtIndex:1]];
			}
			else if ([realJIDComponents count] == 1) {
				address = [realJIDComponents objectAtIndex:0];
			}
			else {
				address = host;
			}
			
			res = [NSString stringWithFormat:@"%@ (%@)", address, (transportName ? transportName : @"unknown network")];
		}
	}
	
	return res;
}

@end

