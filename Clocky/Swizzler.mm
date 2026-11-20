// Clocky Swizzler.mm — patched for older watchOS (weak-linked private frameworks)
// Changes vs original:
//  - NanoTimeKit classes are checked with NSClassFromString before use
//  - assert() replaced with graceful bail-outs (a hard abort in +load would
//    kill the app at startup on watchOS versions missing these APIs)
#import "Swizzler.h"
#import <Foundation/Foundation.h>
#include <objc/runtime.h>

namespace swizzler {

namespace NTKFaceDescriptor {
namespace isAvailableForDevice {

BOOL (* _Nullable original)(::NTKFaceDescriptor *self, SEL _cmd, CLKDevice *device);

BOOL custom(::NTKFaceDescriptor *self, SEL _cmd, CLKDevice *device) {
    return YES;
}

void swizzle() {
    Class descriptorClass = NSClassFromString(@"NTKFaceDescriptor");
    if (descriptorClass == nil) {
        NSLog(@"Clocky: NTKFaceDescriptor unavailable on this watchOS; skipping swizzle");
        return;
    }
    Method method = class_getInstanceMethod(descriptorClass, @selector(isAvailableForDevice:));
    if (method == NULL) {
        NSLog(@"Clocky: -[NTKFaceDescriptor isAvailableForDevice:] not found; skipping swizzle");
        return;
    }
    original = reinterpret_cast<decltype(original)>(method_getImplementation(method));
    method_setImplementation(method, reinterpret_cast<IMP>(custom));
}

}
}

namespace NTKFace {
namespace isRestrictedForDevice {

BOOL (* _Nullable original)(Class self, SEL _cmd, CLKDevice *device);

BOOL custom(Class self, SEL _cmd, CLKDevice *device) {
    return NO;
}

void swizzle() {
    Class managerClass = NSClassFromString(@"NTKFaceBundleManager");
    if (managerClass == nil) {
        NSLog(@"Clocky: NTKFaceBundleManager unavailable on this watchOS; skipping swizzle");
        return;
    }
    id manager = [managerClass performSelector:@selector(sharedManager)];
    if (manager == nil) {
        return;
    }
    id loader = [manager performSelector:@selector(loader)];
    if (loader == nil) {
        return;
    }
    SEL enumerateSel = @selector(enumerateFaceBundleClassesIgnoringCache:withBlock:);
    if (![loader respondsToSelector:enumerateSel]) {
        NSLog(@"Clocky: -enumerateFaceBundleClassesIgnoringCache:withBlock: not available; skipping swizzle");
        return;
    }

    [loader enumerateFaceBundleClassesIgnoringCache:NO withBlock:^(__kindof NTKFaceBundle *faceBundle) {
        Class faceClass = faceBundle.faceClass;
        if (faceClass == nil) {
            return;
        }
        Method method = class_getClassMethod(faceClass, @selector(isRestrictedForDevice:));
        if (method != NULL) {
            original = reinterpret_cast<decltype(original)>(method_getImplementation(method));
            method_setImplementation(method, reinterpret_cast<IMP>(custom));
        }
    }];
}

}
}

}
