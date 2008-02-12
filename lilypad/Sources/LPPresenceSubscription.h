//
//  LPPresenceSubscription.h
//  Lilypad
//
//	Copyright (C) 2006-2008 PT.COM,  All rights reserved.
//	Author: Joao Pavao <jpavao@co.sapo.pt>
//
//	For more information on licensing, read the README file.
//	Para mais informações sobre o licenciamento, leia o ficheiro README.
//

#import <Cocoa/Cocoa.h>


typedef enum _PresenceSubscriptionState {
	LPAuthorizationGranted,
	LPAuthorizationRequested,
	LPAuthorizationLost
} LPPresenceSubscriptionState;


@class LPContactEntry;


@interface LPPresenceSubscription : NSObject
{
	NSDate							*m_date;
	LPPresenceSubscriptionState		m_state;
	LPContactEntry					*m_contactEntry;
	
	NSString						*m_nickname;
	NSString						*m_reason;
	
	BOOL							m_requiresUserIntervention;
}

+ (LPPresenceSubscription *)presenceSubscriptionWithState:(LPPresenceSubscriptionState)state contactEntry:(LPContactEntry *)entry date:(NSDate *)date;
+ (LPPresenceSubscription *)presenceSubscriptionWithState:(LPPresenceSubscriptionState)state contactEntry:(LPContactEntry *)entry nickname:(NSString *)nickname reason:(NSString *)reason date:(NSDate *)date;
- initWithState:(LPPresenceSubscriptionState)state contactEntry:(LPContactEntry *)entry nickname:(NSString *)nickname reason:(NSString *)reason date:(NSDate *)date;

- (NSDate *)date;
- (LPPresenceSubscriptionState)state;
- (LPContactEntry *)contactEntry;
- (NSString *)nickname;
- (NSString *)reason;

// Possible actions to take
- (void)approveRequest;
- (void)rejectRequest;
- (void)sendRequest;
- (void)removeContactEntry;

// Returns true if any of the action methods above need to be called in order to resolve this subscription request.
- (BOOL)requiresUserIntervention;

@end
