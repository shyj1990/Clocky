// HermesBundles.m — port of mightywhite's HermesEnabler PR #93 into Clocky.
//
// Mechanism (validated upstream on watchOS 26 simulator + physical Series 6):
//   1. Temporarily set CLKDevice.collectionType = 5 (Hermès collection) inside
//      this app process only.
//   2. Fetch genuine Apple-installed Hermès face bundles via
//      -[NTKFaceBundleManager faceBundleForBundleIdentifier:onDevice:forMigration:].
//   3. Restore the original collection type in @finally — always.
//
// No MobileGestalt access, no system face-store writes. Every private API is
// guarded so unsupported watchOS builds fail closed instead of crashing.
#import "HermesBundles.h"
#import <dlfcn.h>
#import <objc/message.h>
#import <objc/runtime.h>

static BOOL sPluginBundlesLoaded = NO;

// Face bundle identifiers from Clocky's FaceCategories.plist ("Hermès"
// category) plus the identifiers used by upstream PR #93. Bundles that do
// not exist on the running watchOS build simply return nil and are skipped.
static NSArray<NSString *> *HermesBundleIdentifiers(void) {
    static dispatch_once_t once;
    static NSArray<NSString *> *identifiers;
    dispatch_once(&once, ^{
        identifiers = @[
            @"com.apple.NTKZeusFaceBundle.NTKZeusAnalogFaceBundle",
            @"com.apple.NTKZeusFaceBundle.NTKZeusSpectrumFaceBundle",
            @"com.apple.NTKPoodleFaceBundle",
            @"com.apple.NTKHadesFaceBundle",
            @"com.apple.NTKBellonaFaceBundle",
            @"com.apple.NTKSquallFaceBundle",
            @"com.apple.NTKSecretariatFaceBundle",
            @"com.apple.NTKHermes2025FaceBundle",
            @"com.apple.NTKHermes2026FaceBundle",
            @"com.apple.Hermes2025Face",
        ];
    });
    return identifiers;
}

static BOOL Responds(id object, NSString *name) {
    return object != nil && [object respondsToSelector:NSSelectorFromString(name)];
}

// The original collection type must be 1 (standard watch). This mirrors
// upstream PR #93's fail-closed behaviour for unexpected device categories.
static BOOL CanToggleCollectionType(CLKDevice *device, unsigned *originalOut) {
    unsigned original = Responds(device, @"collectionType")
        ? ((unsigned(*)(id, SEL))objc_msgSend)(device, NSSelectorFromString(@"collectionType"))
        : 0;
    if (originalOut != NULL) *originalOut = original;
    return original == 1 && Responds(device, @"setCollectionType:");
}

// Runs |block| while the device temporarily reports the Hermès collection
// type. Returns block's result, or nil when the switch is not possible.
static id WithHermesCollectionType(CLKDevice *device, id (^)(void) block) {
    unsigned original = 0;
    if (!CanToggleCollectionType(device, &original)) {
        return nil;
    }
    SEL setSel = NSSelectorFromString(@"setCollectionType:");
    ((void(*)(id, SEL, unsigned))objc_msgSend)(device, setSel, 5);
    if (((unsigned(*)(id, SEL))objc_msgSend)(device, NSSelectorFromString(@"collectionType")) != 5) {
        return nil;
    }
    id result = nil;
    @try {
        result = block();
    } @catch (NSException *exception) {
        NSLog(@"Clocky Hermes: fetch failed: %@", exception);
        result = nil;
    } @finally {
        ((void(*)(id, SEL, unsigned))objc_msgSend)(device, setSel, original);
    }
    return result;
}

@implementation HermesBundles

+ (BOOL)loadHermesPluginBundles {
    if (sPluginBundlesLoaded) {
        return YES;
    }
    NSString *root = @"/System/Library/NanoTimeKit/FaceBundles";
    BOOL anyLoaded = NO;
    // Only the plugin-style bundles need an explicit load; standalone
    // bundles (Poodle, Hades, Bellona, ...) are resolved by the manager.
    for (NSString *name in @[@"NTKZeusFaceBundle.bundle", @"NTKHermes2025FaceBundle.bundle"]) {
        NSString *path = [root stringByAppendingPathComponent:name];
        if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
            continue;  // e.g. Hermes2025 does not exist on older watchOS
        }
        NSBundle *bundle = [NSBundle bundleWithPath:path];
        NSError *error = nil;
        if (bundle != nil && [bundle loadAndReturnError:&error]) {
            anyLoaded = YES;
        } else {
            NSLog(@"Clocky Hermes: failed to load %@: %@", name, error);
        }
    }
    sPluginBundlesLoaded = YES;
    return anyLoaded;
}

+ (NSArray<__kindof NTKFaceBundle *> *)hermesBundlesForDevice:(CLKDevice *)device {
    id manager = NTKFaceBundleManager.sharedManager;
    SEL fetchSel = NSSelectorFromString(@"faceBundleForBundleIdentifier:onDevice:forMigration:");
    if (manager == nil || ![manager respondsToSelector:fetchSel]) {
        NSLog(@"Clocky Hermes: faceBundleForBundleIdentifier:onDevice:forMigration: unavailable");
        return @[];
    }
    [self loadHermesPluginBundles];

    NSMutableArray<__kindof NTKFaceBundle *> *bundles = [NSMutableArray array];
    NSMutableSet<NSString *> *seen = [NSMutableSet set];
    id fetched = WithHermesCollectionType(device, ^{
        NSMutableArray<__kindof NTKFaceBundle *> *found = [NSMutableArray array];
        for (NSString *identifier in HermesBundleIdentifiers()) {
            __kindof NTKFaceBundle *bundle = ((id(*)(id, SEL, id, id, BOOL))objc_msgSend)(
                manager, fetchSel, identifier, device, NO);
            if (bundle == nil || bundle.faceClass == nil) {
                continue;  // not present on this watchOS build
            }
            [found addObject:bundle];
        }
        return found;
    });
    for (__kindof NTKFaceBundle *bundle in fetched) {
        NSString *identifier = [[bundle class] identifier];
        if (identifier != nil && ![seen containsObject:identifier]) {
            [seen addObject:identifier];
            [bundles addObject:bundle];
        }
    }
    if (bundles.count > 0) {
        NSLog(@"Clocky Hermes: %lu Hermès bundle(s) available", (unsigned long)bundles.count);
    }
    return [bundles copy];
}

+ (BOOL)isHermesBundleIdentifier:(NSString *)identifier {
    if (identifier == nil) {
        return NO;
    }
    return [HermesBundleIdentifiers() containsObject:identifier];
}

+ (nullable __kindof NTKFace *)defaultFaceForDevice:(CLKDevice *)device
                                         fromBundle:(__kindof NTKFaceBundle *)faceBundle {
    if (![self isHermesBundleIdentifier:[[faceBundle class] identifier]]) {
        return [faceBundle defaultFaceForDevice:device];
    }
    id face = WithHermesCollectionType(device, ^{
        return [faceBundle defaultFaceForDevice:device];
    });
    return face;
}

+ (nullable NSString *)galleryTitleForDevice:(CLKDevice *)device
                                  fromBundle:(__kindof NTKFaceBundle *)faceBundle {
    if (![self isHermesBundleIdentifier:[[faceBundle class] identifier]]) {
        return [faceBundle galleryTitleForDevice:device];
    }
    if (!Responds(faceBundle, @"galleryTitleForDevice:")) {
        return nil;
    }
    id title = WithHermesCollectionType(device, ^{
        return ((id(*)(id, SEL, id))objc_msgSend)(
            faceBundle, NSSelectorFromString(@"galleryTitleForDevice:"), device);
    });
    return title;
}

@end
