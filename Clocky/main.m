// Clocky main.m — patched for older watchOS (weak-linked private frameworks)
// Changes vs original:
//  1. spUtils_setRunningExtensionlessWKApp is now weak_import + NULL check
//  2. SPApplication existence is checked before use; graceful fallback
#import <Foundation/Foundation.h>
#import <_UIKitPrivate/_UIKitPrivate.h>
#import <_WatchKitPrivate/_WatchKitPrivate.h>
#import "AppDelegate.h"

// Weak import: on watchOS versions where WatchKit lacks this symbol,
// taking its address yields NULL instead of aborting in dyld.
extern void spUtils_setRunningExtensionlessWKApp(BOOL flag) __attribute__((weak_import));

int main(int argc, char * argv[]) {
    if (&spUtils_setRunningExtensionlessWKApp != NULL) {
        spUtils_setRunningExtensionlessWKApp(YES);
    } else {
        NSLog(@"Clocky: spUtils_setRunningExtensionlessWKApp not available on this watchOS; continuing without it");
    }

    Class spApplicationClass = NSClassFromString(@"SPApplication");
    if (spApplicationClass == nil) {
        NSLog(@"Clocky: SPApplication class not available on this watchOS version");
    }

    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    Class principalClass = spApplicationClass;
    if (principalClass == nil) {
        // Runtime lookup only — no static link dependency on public UIKit.
        principalClass = NSClassFromString(@"UIApplication");
    }
    if (principalClass == nil) {
        NSLog(@"Clocky: neither SPApplication nor UIApplication is available on this watchOS; exiting");
        [pool release];
        return 1;
    }
    NSString *delegateClassName = NSStringFromClass([AppDelegate class]);
    int result = UIApplicationMain(argc, argv, NSStringFromClass(principalClass), delegateClassName);
    [pool release];
    return result;
}
