#import <LocalAuthentication/LocalAuthentication.h>
#import <CoreFoundation/CoreFoundation.h>

// Returned with +1 ownership. The query retains this context before CFRelease.
CFTypeRef rts_no_interaction_context() {
    LAContext *context = [[LAContext alloc] init];
    context.interactionNotAllowed = YES;
    return (CFTypeRef)context;
}
