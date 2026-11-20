#import "FacePreviewViewController.h"
#import "HermesBundles.h"

@interface FacePreviewViewController ()
@property (nonatomic, retain, direct) __kindof NTKFaceBundle *faceBundle;
@property (nullable, nonatomic, retain, direct) NTKFaceViewController *faceViewController;
@end

@implementation FacePreviewViewController

- (instancetype)initWithFaceBundle:(__kindof NTKFaceBundle *)faceBundle {
    self = [super init];
    if (self != nil) {
        self.faceBundle = faceBundle;
        self.title = [HermesBundles galleryTitleForDevice:CLKDevice.currentDevice fromBundle:faceBundle] ?: [[faceBundle class] identifier] ?: NSStringFromClass([faceBundle class]);
    }
    return self;
}

- (void)dealloc {
    [_faceViewController release];
    [_faceBundle release];
    [super dealloc];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    [self configureTapGesture];
}

- (void)configureTapGesture __attribute__((objc_direct)) {
    UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didTapFace:)];
    [self.view addGestureRecognizer:tapGestureRecognizer];
    [tapGestureRecognizer release];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self loadFaceViewController];
}

- (void)loadFaceViewController __attribute__((objc_direct)) {
    if (self.faceViewController != nil) return;
    NTKFace * _Nullable face = [HermesBundles defaultFaceForDevice:CLKDevice.currentDevice fromBundle:self.faceBundle];
    if (face == nil) {
        NSLog(@"No default face for bundle: %@", self.faceBundle);
        return;
    }
    NTKFaceViewController *faceViewController = [[NTKFaceViewController alloc] initWithFace:face configuration:nil];
    [self addChildViewController:faceViewController];
    faceViewController.view.userInteractionEnabled = NO;
    faceViewController.view.frame = self.view.bounds;
    faceViewController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:faceViewController.view];
    [faceViewController didMoveToParentViewController:self];
    self.faceViewController = faceViewController;
    [faceViewController release];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self unloadFaceViewController];
}

- (void)unloadFaceViewController __attribute__((objc_direct)) {
    NTKFaceViewController * _Nullable faceViewController = self.faceViewController;
    [faceViewController willMoveToParentViewController:nil];
    [faceViewController.view removeFromSuperview];
    [faceViewController removeFromParentViewController];
    self.faceViewController = nil;
}

- (void)didTapFace:(UITapGestureRecognizer *)sender {
    id<FacePreviewViewControllerDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(facePreviewViewController:didSelectFaceBundle:)]) {
        [delegate facePreviewViewController:self didSelectFaceBundle:self.faceBundle];
    }
}

@end
