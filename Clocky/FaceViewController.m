#import "FaceViewController.h"
#import "FaceBundleListViewController.h"
#import "Defines.h"
#import "HermesBundles.h"
#import <NanoTimeKit/NanoTimeKit.h>
#import <CoreMotion/CoreMotion.h>

@interface FaceViewController () <FaceBundleListViewControllerDelegate>
@property (nullable, nonatomic, retain, direct) NTKFaceViewController *faceViewController;
@end

@implementation FaceViewController

- (void)dealloc {
    [_faceViewController release];
    [super dealloc];
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    [self requestMotionPermission];
    [self showInitialFace];
    [self configureLongPressGesture];
}

- (void)requestMotionPermission __attribute__((objc_direct)) {
    if ([CMPedometer isStepCountingAvailable] && [CMPedometer authorizationStatus] == CMAuthorizationStatusNotDetermined) {
        CMPedometer *pedometer = [[CMPedometer alloc] init];
        NSDate *now = [NSDate date];
        [pedometer queryPedometerDataFromDate:[now dateByAddingTimeInterval:-60.0] toDate:now withHandler:^(CMPedometerData * _Nullable data, NSError * _Nullable error) {
            if (error != nil) {
                NSLog(@"Motion permission request failed: %@", error);
            }
        }];
        [pedometer release];
    }
}

- (void)showInitialFace __attribute__((objc_direct)) {
    CLKDevice *device = CLKDevice.currentDevice;
    NSString * _Nullable selectedFaceIdentifier = [NSUserDefaults.standardUserDefaults stringForKey:selectedFaceIdentifierKey()];

    __block __kindof NTKFaceBundle * _Nullable firstBundle = nil;
    __block __kindof NTKFaceBundle * _Nullable matchedBundle = nil;

    [NTKFaceBundleManager.sharedManager enumerateFaceBundlesOnDevice:device includingLegacy:YES withBlock:^(__kindof NTKFaceBundle *faceBundle) {
        if (firstBundle == nil) {
            firstBundle = [faceBundle retain];
        }
        if (selectedFaceIdentifier != nil && matchedBundle == nil) {
            NSString * _Nullable identifier = [[faceBundle class] identifier];
            if ([identifier isEqualToString:selectedFaceIdentifier]) {
                matchedBundle = [faceBundle retain];
            }
        }
    }];

    // Hermès bundles are not returned by the enumeration; if the saved face
    // is one of them, fetch it with the temporary collection switch.
    if (matchedBundle == nil && selectedFaceIdentifier != nil && [HermesBundles isHermesBundleIdentifier:selectedFaceIdentifier]) {
        for (__kindof NTKFaceBundle *faceBundle in [HermesBundles hermesBundlesForDevice:device]) {
            NSString * _Nullable identifier = [[faceBundle class] identifier];
            if ([identifier isEqualToString:selectedFaceIdentifier]) {
                matchedBundle = [faceBundle retain];
                break;
            }
        }
    }
    
    __kindof NTKFaceBundle * _Nullable initialBundle = matchedBundle != nil ? matchedBundle : firstBundle;
    if (initialBundle != nil) {
        [self showFaceFromBundle:initialBundle];
    }
    [matchedBundle release];
    [firstBundle release];
}

- (void)configureLongPressGesture __attribute__((objc_direct)) {
    UILongPressGestureRecognizer *longPressGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(didTriggerLongPressGestureRecognizer:)];
    [self.view addGestureRecognizer:longPressGestureRecognizer];
    [longPressGestureRecognizer release];
}

- (void)showFaceFromBundle:(__kindof NTKFaceBundle *)faceBundle __attribute__((objc_direct)) {
    if (self.faceViewController != nil) {
        [self.faceViewController willMoveToParentViewController:nil];
        [self.faceViewController.view removeFromSuperview];
        [self.faceViewController removeFromParentViewController];
        self.faceViewController = nil;
    }
    
    CLKDevice *device = CLKDevice.currentDevice;
    __kindof NTKFace * _Nullable face = [HermesBundles defaultFaceForDevice:device fromBundle:faceBundle];
    if (face == nil) {
        NSLog(@"No default face for bundle: %@", faceBundle);
        return;
    }
    
    NTKFaceViewController *faceViewController = [[NTKFaceViewController alloc] initWithFace:face configuration:nil];
    [self addChildViewController:faceViewController];
    faceViewController.view.frame = self.view.bounds;
    faceViewController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:faceViewController.view];
    [faceViewController didMoveToParentViewController:self];
    
    self.faceViewController = faceViewController;
    [faceViewController release];
}

- (void)didTriggerLongPressGestureRecognizer:(UILongPressGestureRecognizer *)sender {
    if (sender.state != UIGestureRecognizerStateBegan) return;
    
    FaceBundleListViewController *listViewController = [[FaceBundleListViewController alloc] init];
    listViewController.delegate = self;
    PUICNavigationController *navigationController = [[PUICNavigationController alloc] initWithRootViewController:listViewController];
    [self presentViewController:navigationController animated:YES completion:nil];
    [navigationController release];
    [listViewController release];
}

#pragma mark - FaceBundleListViewControllerDelegate

- (void)faceBundleListViewController:(FaceBundleListViewController *)viewController didSelectFaceBundle:(__kindof NTKFaceBundle *)faceBundle {
    NSString * _Nullable identifier = [[faceBundle class] identifier];
    if (identifier != nil) {
        [NSUserDefaults.standardUserDefaults setObject:identifier forKey:selectedFaceIdentifierKey()];
    }
    
    [self showFaceFromBundle:faceBundle];
    [viewController dismissViewControllerAnimated:YES completion:nil];
}

@end
