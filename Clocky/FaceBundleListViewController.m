#import "FaceBundleListViewController.h"
#import "FaceCategory.h"
#import "FacePageViewController.h"
#import "HermesBundles.h"
#include <assert.h>

@interface FaceBundleListViewController () <FacePageViewControllerDelegate>
@property (nullable, nonatomic, copy, direct) NSArray<FaceCategory *> *categories;
@property (nullable, nonatomic, retain, direct) UICollectionViewCellRegistration *cellRegistration;
@end

@implementation FaceBundleListViewController

- (void)dealloc {
    [_categories release];
    [_cellRegistration release];
    [super dealloc];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self configureNavigation];
    [self loadCategories];
    [self configureCellRegistration];
}

- (void)configureNavigation __attribute__((objc_direct)) {
    self.title = @"Categories";
    UIBarButtonItem *dismissButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(didSelectDismiss:)];
    self.navigationItem.rightBarButtonItem = dismissButton;
    [dismissButton release];
}

- (void)loadCategories __attribute__((objc_direct)) {
    NSURL * _Nullable categoriesURL = [NSBundle.mainBundle URLForResource:@"FaceCategories" withExtension:@"plist"];
    NSArray<NSDictionary<NSString *, NSObject *> *> * _Nullable definitions = categoriesURL != nil ? [NSArray arrayWithContentsOfURL:categoriesURL] : nil;
    NSMutableArray<NSString *> *names = [[NSMutableArray alloc] initWithCapacity:definitions.count + 1];
    NSMutableArray<NSArray<NSString *> *> *identifiers = [[NSMutableArray alloc] initWithCapacity:definitions.count + 1];
    for (NSObject *definition in definitions) {
        if (![definition isKindOfClass:[NSDictionary class]]) continue;
        NSDictionary<NSString *, NSObject *> *entry = (NSDictionary<NSString *, NSObject *> *)definition;
        NSObject *name = entry[@"name"];
        NSObject *faceIdentifiers = entry[@"identifiers"];
        if (![name isKindOfClass:[NSString class]] || ![faceIdentifiers isKindOfClass:[NSArray class]]) continue;
        [names addObject:(NSString *)name];
        [identifiers addObject:(NSArray<NSString *> *)faceIdentifiers];
    }
    [names addObject:@"Others"];
    [identifiers addObject:@[]];
    NSMutableArray<NSMutableArray<__kindof NTKFaceBundle *> *> *groups = [[NSMutableArray alloc] initWithCapacity:names.count];
    for (NSUInteger index = 0; index < names.count; index++) {
        [groups addObject:[NSMutableArray array]];
    }
    NSMutableSet<NSString *> *seenIdentifiers = [NSMutableSet set];
    __block void(^addToGroups)(__kindof NTKFaceBundle *) = ^(__kindof NTKFaceBundle *faceBundle) {
        NSString * _Nullable identifier = [[faceBundle class] identifier];
        NSUInteger categoryIndex = names.count - 1;
        for (NSUInteger index = 0; identifier != nil && index + 1 < identifiers.count; index++) {
            if ([identifiers[index] containsObject:identifier]) {
                categoryIndex = index;
                break;
            }
        }
        if (identifier != nil) {
            if ([seenIdentifiers containsObject:identifier]) return;
            [seenIdentifiers addObject:identifier];
        }
        [groups[categoryIndex] addObject:faceBundle];
    };
    [NTKFaceBundleManager.sharedManager enumerateFaceBundlesOnDevice:CLKDevice.currentDevice includingLegacy:YES withBlock:addToGroups];
    // Hermès bundles are gated by the device collection type and are not
    // returned by the enumeration above; fetch them with a temporary
    // in-process collection switch (see HermesBundles).
    for (__kindof NTKFaceBundle *faceBundle in [HermesBundles hermesBundlesForDevice:CLKDevice.currentDevice]) {
        addToGroups(faceBundle);
    }
    NSMutableArray<FaceCategory *> *categories = [[NSMutableArray alloc] initWithCapacity:names.count];
    for (NSUInteger index = 0; index < names.count; index++) {
        if (groups[index].count == 0) continue;
        FaceCategory *category = [[FaceCategory alloc] initWithName:names[index] faceBundles:groups[index]];
        [categories addObject:category];
        [category release];
    }
    self.categories = categories;
    [categories release];
    [groups release];
    [identifiers release];
    [names release];
}

- (void)configureCellRegistration __attribute__((objc_direct)) {
    self.cellRegistration = [UICollectionViewCellRegistration registrationWithCellClass:[PUICListPlatterCell class] configurationHandler:^(__kindof UICollectionViewCell *cell, NSIndexPath *indexPath, FaceCategory *category) {
        UIListContentConfiguration *contentConfiguration = [UIListContentConfiguration _defaultInsetGroupedCellConfiguration];
        contentConfiguration.text = category.name;
        cell.contentConfiguration = contentConfiguration;
    }];
}

- (void)didSelectDismiss:(UIBarButtonItem *)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.categories.count;
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    UICollectionViewCellRegistration *cellRegistration = self.cellRegistration;
    NSArray<FaceCategory *> *categories = self.categories;
    assert(cellRegistration != nil && categories != nil);
    return [collectionView dequeueConfiguredReusableCellWithRegistration:cellRegistration forIndexPath:indexPath item:categories[indexPath.item]];
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    NSArray<FaceCategory *> *categories = self.categories;
    assert(categories != nil);
    FacePageViewController *pageViewController = [[FacePageViewController alloc] initWithCategory:categories[indexPath.item]];
    pageViewController.faceSelectionDelegate = self;
    [self.navigationController pushViewController:pageViewController animated:YES];
    [pageViewController release];
}

- (void)facePageViewController:(FacePageViewController *)viewController didSelectFaceBundle:(__kindof NTKFaceBundle *)faceBundle {
    id<FaceBundleListViewControllerDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(faceBundleListViewController:didSelectFaceBundle:)]) {
        [delegate faceBundleListViewController:self didSelectFaceBundle:faceBundle];
    }
}

@end
