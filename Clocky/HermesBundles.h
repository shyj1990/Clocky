#import <Foundation/Foundation.h>
#import <NanoTimeKit/NanoTimeKit.h>

NS_ASSUME_NONNULL_BEGIN

// Port of mightywhite's HermesEnabler PR #93 ("Original Hermès, App Only")
// into Clocky: fetch Apple's genuine Hermès NanoTimeKit face bundles by
// temporarily switching CLKDevice.collectionType inside this app process.
// No MobileGestalt writes, no system Face Gallery changes; the original
// collection type is always restored.
@interface HermesBundles : NSObject

// Loads the plugin face bundles that carry Hermès faces but are not loaded
// by default (Zeus, Hermes2025 where present). Idempotent; failures are
// tolerated as long as at least one bundle loads. Safe to call repeatedly.
+ (BOOL)loadHermesPluginBundles;

// Fetches every Hermès face bundle that exists on this watchOS build.
// Returns an empty array when the device category or private APIs make it
// impossible; never throws.
+ (NSArray<__kindof NTKFaceBundle *> *)hermesBundlesForDevice:(CLKDevice *)device;

// YES when the given bundle identifier belongs to a Hermès face bundle.
+ (BOOL)isHermesBundleIdentifier:(nullable NSString *)identifier;

// Calls -defaultFaceForDevice: on the bundle, temporarily switching the
// device's collection type when the bundle is a Hermès one.
+ (nullable __kindof NTKFace *)defaultFaceForDevice:(CLKDevice *)device
                                         fromBundle:(__kindof NTKFaceBundle *)faceBundle;

// Calls -galleryTitleForDevice: with the same temporary collection switch.
+ (nullable NSString *)galleryTitleForDevice:(CLKDevice *)device
                                  fromBundle:(__kindof NTKFaceBundle *)faceBundle;

@end

NS_ASSUME_NONNULL_END
