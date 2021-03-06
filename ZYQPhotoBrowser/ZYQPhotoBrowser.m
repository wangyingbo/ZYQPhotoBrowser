//
//  ZYQPhotoBrowser.m
//  ZYQPhotoBrowser
//
//  Created by Michael Waterfall on 14/10/2010.
//  Copyright 2010 d3i. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "ZYQPhotoBrowser.h"
#import "ZYQZoomingScrollView.h"
#import <objc/runtime.h>
#import <libkern/OSAtomic.h>

#ifndef ZYQPhotoBrowserLocalizedStrings
#define ZYQPhotoBrowserLocalizedStrings(key) \
NSLocalizedStringFromTableInBundle((key), nil, [NSBundle bundleWithPath:[[NSBundle bundleForClass: [ZYQPhotoBrowser class]] pathForResource:@"ZYQPBLocalizations" ofType:@"bundle"]], nil)
#endif

// Private
@interface ZYQPhotoBrowser () {
	// Data
    NSMutableArray *_photos;

	// Views
	UIScrollView *_pagingScrollView;

    // Gesture
    UIPanGestureRecognizer *_panGesture;

	// Paging
    NSMutableSet *_visiblePages, *_recycledPages;
    NSUInteger _pageIndexBeforeRotation;
    NSUInteger _currentPageIndex;

    // Buttons
    UIButton *_doneButton;

    // Title
    UILabel *_titleLabel;

	// Toolbar
	UIToolbar *_toolbar;
	UIBarButtonItem *_previousButton, *_nextButton, *_actionButton;
    UIBarButtonItem *_counterButton;
    UILabel *_counterLabel;

    // Actions
#if __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_8_0
    UIAlertController *_actionsSheet;
#else
    UIActionSheet *_actionsSheet;
#endif
    UIActivityViewController *activityViewController;

    // Control
    NSTimer *_controlVisibilityTimer;

    // Appearance
    //UIStatusBarStyle _previousStatusBarStyle;
	BOOL _statusBarOriginallyHidden;

    // Present
    UIView *_senderViewForAnimation;

    // Misc
    BOOL _performingLayout;
	BOOL _rotating;
    BOOL _viewIsActive; // active as in it's in the view heirarchy
    BOOL _autoHide;
    NSInteger _initalPageIndex;

    BOOL _isdraggingPhoto;

    CGRect _senderViewOriginalFrame;
    //UIImage *_backgroundScreenshot;

    UIWindow *_applicationWindow;

	// iOS 7
    UIViewController *_applicationTopViewController;
    int _previousModalPresentationStyle;
}

// Private Properties
#if __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_8_0
@property (nonatomic, strong) UIAlertController *actionsSheet;
#else
@property (nonatomic, strong) UIActionSheet *actionsSheet;
#endif
@property (nonatomic, strong) UIActivityViewController *activityViewController;

// Private Methods

// Layout
- (void)performLayout;

// Paging
- (void)tilePages;
- (BOOL)isDisplayingPageForIndex:(NSUInteger)index;
- (ZYQZoomingScrollView *)pageDisplayedAtIndex:(NSUInteger)index;
- (ZYQZoomingScrollView *)pageDisplayingPhoto:(id<ZYQPhoto>)photo;
- (ZYQZoomingScrollView *)dequeueRecycledPage;
- (void)configurePage:(ZYQZoomingScrollView *)page forIndex:(NSUInteger)index;
- (void)didStartViewingPageAtIndex:(NSUInteger)index;

// Frames
- (CGRect)frameForPagingScrollView;
- (CGRect)frameForPageAtIndex:(NSUInteger)index;
- (CGSize)contentSizeForPagingScrollView;
- (CGPoint)contentOffsetForPageAtIndex:(NSUInteger)index;
- (CGRect)frameForToolbarAtOrientation:(UIInterfaceOrientation)orientation;
- (CGRect)frameForDoneButtonAtOrientation:(UIInterfaceOrientation)orientation;
- (CGRect)frameForCaptionView:(ZYQCaptionView *)captionView atIndex:(NSUInteger)index;

// Toolbar
- (void)updateToolbar;

// Navigation
- (void)jumpToPageAtIndex:(NSUInteger)index;
- (void)gotoPreviousPage;
- (void)gotoNextPage;

// Controls
- (void)cancelControlHiding;
- (void)hideControlsAfterDelay;
- (void)setControlsHidden:(BOOL)hidden animated:(BOOL)animated permanent:(BOOL)permanent;
//- (void)toggleControls;
- (BOOL)areControlsHidden;

// Interactions
- (void)handleSingleTap;

// Data
- (NSUInteger)numberOfPhotos;
- (id<ZYQPhoto>)photoAtIndex:(NSUInteger)index;
- (UIImage *)imageForPhoto:(id<ZYQPhoto>)photo;
- (void)loadAdjacentPhotosIfNecessary:(id<ZYQPhoto>)photo;
- (void)releaseAllUnderlyingPhotos;

@end

// ZYQPhotoBrowser
@implementation ZYQPhotoBrowser

// Properties
@synthesize displayDoneButton = _displayDoneButton, displayTitle=_displayTitle, displayToolbar = _displayToolbar, displayActionButton = _displayActionButton, displayCounterLabel = _displayCounterLabel, useWhiteBackgroundColor = _useWhiteBackgroundColor, doneButtonImage = _doneButtonImage;
@synthesize leftArrowImage = _leftArrowImage, rightArrowImage = _rightArrowImage, leftArrowSelectedImage = _leftArrowSelectedImage, rightArrowSelectedImage = _rightArrowSelectedImage, actionButtonImage = _actionButtonImage, actionButtonSelectedImage = _actionButtonSelectedImage;
@synthesize displayArrowButton = _displayArrowButton, actionButtonTitles = _actionButtonTitles;
@synthesize arrowButtonsChangePhotosAnimated = _arrowButtonsChangePhotosAnimated;
@synthesize forceHideStatusBar = _forceHideStatusBar;
@synthesize useZoomAnimation = _useZoomAnimation;
@synthesize disableVerticalSwipe = _disableVerticalSwipe;
@synthesize dismissOnTouch = _dismissOnTouch;
@synthesize actionsSheet = _actionsSheet, activityViewController = _activityViewController;
@synthesize customBackgroud = _customBackgroud;
@synthesize gifSupportImageViewClass = _gifSupportImageViewClass;
@synthesize trackTintColor = _trackTintColor, progressTintColor = _progressTintColor;
@synthesize delegate = _delegate;

#pragma mark - NSObject

- (id)init {
    if ((self = [super init])) {
        // Defaults
        self.hidesBottomBarWhenPushed = YES;
		
        _currentPageIndex = 0;
		_performingLayout = NO; // Reset on view did appear
		_rotating = NO;
        _viewIsActive = NO;
        _visiblePages = [NSMutableSet new];
        _recycledPages = [NSMutableSet new];
        _photos = [NSMutableArray new];

        _initalPageIndex = 0;
        _autoHide = YES;
        _autoHideInterface = YES;

        _displayDoneButton = YES;
        _displayTitle=NO;
        _doneButtonImage = nil;

        _displayToolbar = YES;
        _displayActionButton = YES;
        _displayArrowButton = YES;
        _displayCounterLabel = NO;

        _forceHideStatusBar = NO;
        _useZoomAnimation = NO;
		_disableVerticalSwipe = NO;
		
		_dismissOnTouch = NO;

        _useWhiteBackgroundColor = NO;
        _leftArrowImage = _rightArrowImage = _leftArrowSelectedImage = _rightArrowSelectedImage = nil;

        _arrowButtonsChangePhotosAnimated = YES;

        _backgroundScaleFactor = 1.0;
        _animationDuration = 0.28;
        _senderViewForAnimation = nil;
        _scaleImage = nil;

        _isdraggingPhoto = NO;
        
        _doneButtonRightInset = 20.f;
        _doneButtonTopInset = 30.f;
        _doneButtonSize = CGSizeMake(55.f, 26.f);

		if ([self respondsToSelector:@selector(automaticallyAdjustsScrollViewInsets)]) {
            self.automaticallyAdjustsScrollViewInsets = NO;
		}
		
        _applicationWindow = [[[UIApplication sharedApplication] delegate] window];
		self.modalPresentationStyle = UIModalPresentationCustom;
		self.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
		self.modalPresentationCapturesStatusBarAppearance = YES;
		self.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;

        // Listen for ZYQPhoto notifications
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleZYQPhotoLoadingDidEndNotification:)
                                                     name:ZYQPhoto_LOADING_DID_END_NOTIFICATION
                                                   object:nil];
    }
	
    return self;
}

- (id)initWithPhotos:(NSArray *)photosArray {
    if ((self = [self init])) {
		_photos = [[NSMutableArray alloc] initWithArray:photosArray];
	}
	return self;
}

- (id)initWithPhotos:(NSArray *)photosArray animatedFromView:(UIView*)view {
    if ((self = [self init])) {
		_photos = [[NSMutableArray alloc] initWithArray:photosArray];
        _senderViewForAnimation = view;
	}
	return self;
}

- (id)initWithPhotoURLs:(NSArray *)photoURLsArray {
    if ((self = [self init])) {
        NSArray *photosArray = [ZYQPhoto photosWithURLs:photoURLsArray];
		_photos = [[NSMutableArray alloc] initWithArray:photosArray];
	}
	return self;
}

- (id)initWithPhotoURLs:(NSArray *)photoURLsArray animatedFromView:(UIView*)view {
    if ((self = [self init])) {
        NSArray *photosArray = [ZYQPhoto photosWithURLs:photoURLsArray];
		_photos = [[NSMutableArray alloc] initWithArray:photosArray];
        _senderViewForAnimation = view;
	}
	return self;
}

- (void)dealloc {
    _pagingScrollView.delegate = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self releaseAllUnderlyingPhotos];
}

- (void)releaseAllUnderlyingPhotos {
    for (id p in _photos) { if (p != [NSNull null]) [p unloadUnderlyingImage]; } // Release photos
}

- (void)didReceiveMemoryWarning {
	// Release any cached data, images, etc that aren't in use.
    [self releaseAllUnderlyingPhotos];
	[_recycledPages removeAllObjects];

	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
}

#pragma mark - Pan Gesture

- (void)panGestureRecognized:(id)sender {
    // Initial Setup
    ZYQZoomingScrollView *scrollView = [self pageDisplayedAtIndex:_currentPageIndex];
    //ZYQTapDetectingImageView *scrollView.photoImageView = scrollView.photoImageView;

    static float firstX, firstY;

    float viewHeight = scrollView.frame.size.height;
    float viewHalfHeight = viewHeight/2;

    CGPoint translatedPoint = [(UIPanGestureRecognizer*)sender translationInView:self.view];

    // Gesture Began
    if ([(UIPanGestureRecognizer*)sender state] == UIGestureRecognizerStateBegan) {
        [self setControlsHidden:YES animated:YES permanent:YES];

        firstX = [scrollView center].x;
        firstY = [scrollView center].y;

        _senderViewForAnimation.hidden = (_currentPageIndex == _initalPageIndex);

        _isdraggingPhoto = YES;
        [self setNeedsStatusBarAppearanceUpdate];
    }

    translatedPoint = CGPointMake(firstX, firstY+translatedPoint.y);
    [scrollView setCenter:translatedPoint];

    float newY = scrollView.center.y - viewHalfHeight;
    float newAlpha = 1 - fabsf(newY)/viewHeight; //abs(newY)/viewHeight * 1.8;

    self.view.opaque = YES;

    self.view.backgroundColor = [UIColor colorWithWhite:(_useWhiteBackgroundColor ? 1 : 0) alpha:newAlpha];

    // Gesture Ended
    if ([(UIPanGestureRecognizer*)sender state] == UIGestureRecognizerStateEnded) {
        if(scrollView.center.y > viewHalfHeight+40 || scrollView.center.y < viewHalfHeight-40) // Automatic Dismiss View
        {
            if (_senderViewForAnimation && _currentPageIndex == _initalPageIndex) {
                [self performCloseAnimationWithScrollView:scrollView];
                return;
            }

            CGFloat finalX = firstX, finalY;

            CGFloat windowsHeigt = [_applicationWindow frame].size.height;

            if(scrollView.center.y > viewHalfHeight+30) // swipe down
                finalY = windowsHeigt*2;
            else // swipe up
                finalY = -viewHalfHeight;

            CGFloat animationDuration = 0.35;

            [UIView beginAnimations:nil context:NULL];
            [UIView setAnimationDuration:animationDuration];
            [UIView setAnimationCurve:UIViewAnimationCurveEaseIn];
            [UIView setAnimationDelegate:self];
            [scrollView setCenter:CGPointMake(finalX, finalY)];
            self.view.backgroundColor = [UIColor colorWithWhite:0 alpha:0];
            [UIView commitAnimations];

            [self performSelector:@selector(doneButtonPressed:) withObject:self afterDelay:animationDuration];
        }
        else // Continue Showing View
        {
            _isdraggingPhoto = NO;
            [self setNeedsStatusBarAppearanceUpdate];
            [self setControlsHidden:NO animated:YES permanent:YES];

            self.view.backgroundColor = [UIColor colorWithWhite:(_useWhiteBackgroundColor ? 1 : 0) alpha:1];

            CGFloat velocityY = (.35*[(UIPanGestureRecognizer*)sender velocityInView:self.view].y);

            CGFloat finalX = firstX;
            CGFloat finalY = viewHalfHeight;

            CGFloat animationDuration = (ABS(velocityY)*.0002)+.2;

            [UIView beginAnimations:nil context:NULL];
            [UIView setAnimationDuration:animationDuration];
            [UIView setAnimationCurve:UIViewAnimationCurveEaseOut];
            [UIView setAnimationDelegate:self];
            [scrollView setCenter:CGPointMake(finalX, finalY)];
            [UIView commitAnimations];
        }
    }
}

#pragma mark - Animation

- (void)performPresentAnimation {
    self.view.alpha = 0.0f;
    _pagingScrollView.alpha = 0.0f;

    UIImage *imageFromView = _scaleImage ? _scaleImage : [self getImageFromView:_senderViewForAnimation];

    _senderViewOriginalFrame = [_senderViewForAnimation.superview convertRect:_senderViewForAnimation.frame toView:nil];

    UIView *fadeView = [[UIView alloc] initWithFrame:_applicationWindow.bounds];
    fadeView.backgroundColor = [UIColor clearColor];
    [_applicationWindow addSubview:fadeView];

    UIImageView *resizableImageView = [[UIImageView alloc] initWithImage:imageFromView];
    resizableImageView.frame = _senderViewOriginalFrame;
    resizableImageView.clipsToBounds = YES;
    resizableImageView.contentMode = _senderViewForAnimation ? _senderViewForAnimation.contentMode : UIViewContentModeScaleAspectFill;
    resizableImageView.backgroundColor = [UIColor clearColor];
    [_applicationWindow addSubview:resizableImageView];
    _senderViewForAnimation.hidden = YES;

    void (^completion)() = ^() {
        self.view.alpha = 1.0f;
        _pagingScrollView.alpha = 1.0f;
        resizableImageView.backgroundColor = [UIColor colorWithWhite:(_useWhiteBackgroundColor) ? 1 : 0 alpha:1];
        [fadeView removeFromSuperview];
        [resizableImageView removeFromSuperview];
    };

    [UIView animateWithDuration:_animationDuration animations:^{
        fadeView.backgroundColor = self.useWhiteBackgroundColor ? [UIColor whiteColor] : [UIColor blackColor];
    } completion:nil];

    CGRect finalImageViewFrame = [self animationFrameForImage:imageFromView presenting:YES scrollView:nil];

    if(_useZoomAnimation)
    {
        [self animateView:resizableImageView
                  toFrame:finalImageViewFrame
               completion:completion];
    }
    else
    {
        [UIView animateWithDuration:_animationDuration animations:^{
            resizableImageView.layer.frame = finalImageViewFrame;
        } completion:^(BOOL finished) {
            completion();
        }];
    }
}

- (void)performCloseAnimationWithScrollView:(ZYQZoomingScrollView*)scrollView {
    if ([_delegate respondsToSelector:@selector(willDisappearPhotoBrowser:)]) {
        [_delegate willDisappearPhotoBrowser:self];
    }

    float fadeAlpha = 1 - fabs(scrollView.frame.origin.y)/scrollView.frame.size.height;

    UIImage *imageFromView = [scrollView.photo underlyingImage];
    if (!imageFromView && [scrollView.photo respondsToSelector:@selector(placeholderImage)]) {
        imageFromView = [scrollView.photo placeholderImage];
    }

    UIView *fadeView = [[UIView alloc] initWithFrame:_applicationWindow.bounds];
    fadeView.backgroundColor = self.useWhiteBackgroundColor ? [UIColor whiteColor] : [UIColor blackColor];
    fadeView.alpha = fadeAlpha;
    [_applicationWindow addSubview:fadeView];

    CGRect imageViewFrame = [self animationFrameForImage:imageFromView presenting:NO scrollView:scrollView];

    UIImageView *resizableImageView = [[UIImageView alloc] initWithImage:imageFromView];
    resizableImageView.frame = imageViewFrame;
    resizableImageView.contentMode = _senderViewForAnimation ? _senderViewForAnimation.contentMode : UIViewContentModeScaleAspectFill;
    resizableImageView.backgroundColor = [UIColor clearColor];
    resizableImageView.clipsToBounds = YES;
    [_applicationWindow addSubview:resizableImageView];
    self.view.hidden = YES;

    void (^completion)() = ^() {
        _senderViewForAnimation.hidden = NO;
        _senderViewForAnimation = nil;
        _scaleImage = nil;

        [fadeView removeFromSuperview];
        [resizableImageView removeFromSuperview];

        [self prepareForClosePhotoBrowser];
        [self dismissPhotoBrowserAnimated:NO];
    };

    [UIView animateWithDuration:_animationDuration animations:^{
        fadeView.alpha = 0;
        self.view.backgroundColor = [UIColor clearColor];
    } completion:nil];

    CGRect senderViewOriginalFrame = _senderViewForAnimation.superview ? [_senderViewForAnimation.superview convertRect:_senderViewForAnimation.frame toView:nil] : _senderViewOriginalFrame;

    if(_useZoomAnimation)
    {
        [self animateView:resizableImageView
                  toFrame:senderViewOriginalFrame
               completion:completion];
    }
    else
    {
        [UIView animateWithDuration:_animationDuration animations:^{
            resizableImageView.layer.frame = senderViewOriginalFrame;
        } completion:^(BOOL finished) {
            completion();
        }];
    }
}

- (CGRect)animationFrameForImage:(UIImage *)image presenting:(BOOL)presenting scrollView:(UIScrollView *)scrollView
{
    if (!image) {
        return CGRectZero;
    }

    CGSize imageSize = image.size;

    CGFloat maxWidth = CGRectGetWidth(_applicationWindow.bounds);
    CGFloat maxHeight = CGRectGetHeight(_applicationWindow.bounds);

    CGRect animationFrame = CGRectZero;

    CGFloat aspect = imageSize.width / imageSize.height;
    if (maxWidth / aspect <= maxHeight) {
        animationFrame.size = CGSizeMake(maxWidth, maxWidth / aspect);
    }
    else {
        animationFrame.size = CGSizeMake(maxHeight * aspect, maxHeight);
    }

    animationFrame.origin.x = roundf((maxWidth - animationFrame.size.width) / 2.0f);
    animationFrame.origin.y = roundf((maxHeight - animationFrame.size.height) / 2.0f);

    if (!presenting) {
        animationFrame.origin.y += scrollView.frame.origin.y;
    }

    return animationFrame;
}

#pragma mark - Genaral

- (void)prepareForClosePhotoBrowser {
    // Gesture
    [_applicationWindow removeGestureRecognizer:_panGesture];

    _autoHide = NO;

    // Controls
    [NSObject cancelPreviousPerformRequestsWithTarget:self]; // Cancel any pending toggles from taps
}

- (void)dismissPhotoBrowserAnimated:(BOOL)animated {
    self.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;

    if ([_delegate respondsToSelector:@selector(photoBrowser:willDismissAtPageIndex:)])
        [_delegate photoBrowser:self willDismissAtPageIndex:_currentPageIndex];

    [self dismissViewControllerAnimated:animated completion:^{
        if ([_delegate respondsToSelector:@selector(photoBrowser:didDismissAtPageIndex:)])
            [_delegate photoBrowser:self didDismissAtPageIndex:_currentPageIndex];

//		if (SYSTEM_VERSION_LESS_THAN(@"8.0"))
//		{
//			_applicationTopViewController.modalPresentationStyle = _previousModalPresentationStyle;
//		}
    }];
}

- (UIButton*)customToolbarButtonImage:(UIImage*)image imageSelected:(UIImage*)selectedImage action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    [button setImage:image forState:UIControlStateNormal];
    [button setImage:selectedImage forState:UIControlStateDisabled];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [button setContentMode:UIViewContentModeCenter];
    [button setFrame:[self getToolbarButtonFrame:image]];
    return button;
}

- (CGRect)getToolbarButtonFrame:(UIImage *)image{
    BOOL const isRetinaHd = ((float)[[UIScreen mainScreen] scale] > 2.0f);
    float const defaultButtonSize = isRetinaHd ? 66.0f : 44.0f;
    CGFloat buttonWidth = (image.size.width > defaultButtonSize) ? image.size.width : defaultButtonSize;
    CGFloat buttonHeight = (image.size.height > defaultButtonSize) ? image.size.width : defaultButtonSize;
    return CGRectMake(0,0, buttonWidth, buttonHeight);
}

- (UIImage*)getImageFromView:(UIView *)view {
    UIGraphicsBeginImageContextWithOptions(view.bounds.size, YES, 2);
    [view.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

- (UIViewController *)topviewController
{
    UIViewController *topviewController = [UIApplication sharedApplication].keyWindow.rootViewController;

    while (topviewController.presentedViewController) {
        topviewController = topviewController.presentedViewController;
    }

    return topviewController;
}

#pragma mark - View Lifecycle

- (void)viewDidLoad {
    // View
	self.view.backgroundColor = [UIColor colorWithWhite:(_useWhiteBackgroundColor ? 1 : 0) alpha:1];

    self.view.clipsToBounds = YES;

	// Setup paging scrolling view
	CGRect pagingScrollViewFrame = [self frameForPagingScrollView];
	_pagingScrollView = [[UIScrollView alloc] initWithFrame:pagingScrollViewFrame];
    //_pagingScrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	_pagingScrollView.pagingEnabled = YES;
	_pagingScrollView.delegate = self;
	_pagingScrollView.showsHorizontalScrollIndicator = NO;
	_pagingScrollView.showsVerticalScrollIndicator = NO;
	_pagingScrollView.backgroundColor = [UIColor clearColor];
    _pagingScrollView.contentSize = [self contentSizeForPagingScrollView];
	[self.view addSubview:_pagingScrollView];

    // Transition animation
    [self performPresentAnimation];

    UIInterfaceOrientation currentOrientation = [UIApplication sharedApplication].statusBarOrientation;

    // Toolbar
    _toolbar = [[UIToolbar alloc] initWithFrame:[self frameForToolbarAtOrientation:currentOrientation]];
    _toolbar.backgroundColor = [UIColor clearColor];
    _toolbar.clipsToBounds = YES;
    _toolbar.translucent = YES;
    [_toolbar setBackgroundImage:[UIImage new]
              forToolbarPosition:UIToolbarPositionAny
                      barMetrics:UIBarMetricsDefault];

    // Close Button
    _doneButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [_doneButton setFrame:[self frameForDoneButtonAtOrientation:currentOrientation]];
    [_doneButton setAlpha:1.0f];
    [_doneButton addTarget:self action:@selector(doneButtonPressed:) forControlEvents:UIControlEventTouchUpInside];

    if(!_doneButtonImage) {
        [_doneButton setTitleColor:[UIColor colorWithWhite:0.9 alpha:0.9] forState:UIControlStateNormal|UIControlStateHighlighted];
        [_doneButton setTitle:ZYQPhotoBrowserLocalizedStrings(@"Done") forState:UIControlStateNormal];
        [_doneButton.titleLabel setFont:[UIFont boldSystemFontOfSize:11.0f]];
        [_doneButton setBackgroundColor:[UIColor colorWithWhite:0.1 alpha:0.5]];
        _doneButton.layer.cornerRadius = 3.0f;
        _doneButton.layer.borderColor = [UIColor colorWithWhite:0.9 alpha:0.9].CGColor;
        _doneButton.layer.borderWidth = 1.0f;
        _doneButtonSize = _doneButton.frame.size;
    }
    else {
        [_doneButton setImage:_doneButtonImage forState:UIControlStateNormal];
        _doneButton.contentMode = UIViewContentModeScaleAspectFit;
    }
    
    _titleLabel = [[UILabel alloc] init];
    [_titleLabel setFrame:[self frameForTitleLabelAtOrientation:currentOrientation]];
    [_titleLabel setAlpha:1.0f];
    _titleLabel.textAlignment = NSTextAlignmentCenter;
    _titleLabel.backgroundColor = [UIColor clearColor];
    [_titleLabel setFont:[UIFont boldSystemFontOfSize:17]];
    if(_useWhiteBackgroundColor == NO) {
        _titleLabel.textColor = [UIColor whiteColor];
        _titleLabel.shadowColor = [UIColor darkTextColor];
        _titleLabel.shadowOffset = CGSizeMake(0, 1);
    }
    else {
        _titleLabel.textColor = [UIColor blackColor];
    }

    UIImage *leftButtonImage = (_leftArrowImage == nil) ?
    [UIImage imageNamed:@"ZYQPhotoBrowser.bundle/images/ZYQPhotoBrowser_arrowLeft.png"]          : _leftArrowImage;

    UIImage *rightButtonImage = (_rightArrowImage == nil) ?
    [UIImage imageNamed:@"ZYQPhotoBrowser.bundle/images/ZYQPhotoBrowser_arrowRight.png"]         : _rightArrowImage;

    UIImage *leftButtonSelectedImage = (_leftArrowSelectedImage == nil) ?
    [UIImage imageNamed:@"ZYQPhotoBrowser.bundle/images/ZYQPhotoBrowser_arrowLeftSelected.png"]  : _leftArrowSelectedImage;

    UIImage *rightButtonSelectedImage = (_rightArrowSelectedImage == nil) ?
    [UIImage imageNamed:@"ZYQPhotoBrowser.bundle/images/ZYQPhotoBrowser_arrowRightSelected.png"] : _rightArrowSelectedImage;

    // Arrows
    _previousButton = [[UIBarButtonItem alloc] initWithCustomView:[self customToolbarButtonImage:leftButtonImage
                                                                                   imageSelected:leftButtonSelectedImage
                                                                                          action:@selector(gotoPreviousPage)]];

    _nextButton = [[UIBarButtonItem alloc] initWithCustomView:[self customToolbarButtonImage:rightButtonImage
                                                                               imageSelected:rightButtonSelectedImage
                                                                                      action:@selector(gotoNextPage)]];

    // Counter Label
    _counterLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 95, 40)];
    _counterLabel.textAlignment = NSTextAlignmentCenter;
    _counterLabel.backgroundColor = [UIColor clearColor];
    _counterLabel.font = [UIFont fontWithName:@"Helvetica" size:17];

    if(_useWhiteBackgroundColor == NO) {
        _counterLabel.textColor = [UIColor whiteColor];
        _counterLabel.shadowColor = [UIColor darkTextColor];
        _counterLabel.shadowOffset = CGSizeMake(0, 1);
    }
    else {
        _counterLabel.textColor = [UIColor blackColor];
    }

    // Counter Button
    _counterButton = [[UIBarButtonItem alloc] initWithCustomView:_counterLabel];

    // Action Button
    if(_actionButtonImage != nil && _actionButtonSelectedImage != nil) {
        _actionButton = [[UIBarButtonItem alloc] initWithCustomView:[self customToolbarButtonImage:_actionButtonImage
                                                                                   imageSelected:_actionButtonSelectedImage
                                                                                          action:@selector(actionButtonPressed:)]];
    }
    else {
        _actionButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction
                                                                  target:self
                                                                  action:@selector(actionButtonPressed:)];
    }

    // Gesture
    _panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panGestureRecognized:)];
    [_panGesture setMinimumNumberOfTouches:1];
    [_panGesture setMaximumNumberOfTouches:1];

    // Update
    //[self reloadData];

	// Super
    [super viewDidLoad];
}

- (void)viewWillAppear:(BOOL)animated {
    // Update
    [self reloadData];


    if ([_delegate respondsToSelector:@selector(willAppearPhotoBrowser:)]) {
        [_delegate willAppearPhotoBrowser:self];
    }

    // Super
	[super viewWillAppear:animated];

    // Status Bar
    _statusBarOriginallyHidden = [UIApplication sharedApplication].statusBarHidden;

    // Update UI
	[self hideControlsAfterDelay];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    _viewIsActive = YES;
}

// Release any retained subviews of the main view.
- (void)viewDidUnload {
	_currentPageIndex = 0;
    _pagingScrollView = nil;
    _visiblePages = nil;
    _recycledPages = nil;
    _toolbar = nil;
    _doneButton = nil;
    _titleLabel = nil;
    _previousButton = nil;
    _nextButton = nil;

    [super viewDidUnload];
}

#pragma mark - Status Bar

- (UIStatusBarStyle)preferredStatusBarStyle {
    return _useWhiteBackgroundColor ? UIStatusBarStyleDefault : UIStatusBarStyleLightContent;
}

- (BOOL)prefersStatusBarHidden {
    if(_forceHideStatusBar) {
        return YES;
    }

    if(_isdraggingPhoto) {
        if(_statusBarOriginallyHidden) {
            return YES;
        }
        else {
            return NO;
        }
    }
    else {
        return [self areControlsHidden];
    }
}

- (UIStatusBarAnimation)preferredStatusBarUpdateAnimation {
	return UIStatusBarAnimationFade;
}

#pragma mark - Layout

- (void)viewWillLayoutSubviews {
	// Flag
	_performingLayout = YES;

    UIInterfaceOrientation currentOrientation = [UIApplication sharedApplication].statusBarOrientation;

    // Toolbar
    _toolbar.frame = [self frameForToolbarAtOrientation:currentOrientation];

    // Done button
    _doneButton.frame = [self frameForDoneButtonAtOrientation:currentOrientation];

    // Title label
    _titleLabel.frame = [self frameForTitleLabelAtOrientation:currentOrientation];
    
    //Custom Backgroud
    _customBackgroud.frame=self.view.bounds;
    
    // Remember index
	NSUInteger indexPriorToLayout = _currentPageIndex;

	// Get paging scroll view frame to determine if anything needs changing
	CGRect pagingScrollViewFrame = [self frameForPagingScrollView];

	// Frame needs changing
	_pagingScrollView.frame = pagingScrollViewFrame;

	// Recalculate contentSize based on current orientation
	_pagingScrollView.contentSize = [self contentSizeForPagingScrollView];

	// Adjust frames and configuration of each visible page
	for (ZYQZoomingScrollView *page in _visiblePages) {
        NSUInteger index = PAGE_INDEX(page);
		page.frame = [self frameForPageAtIndex:index];
        page.captionView.frame = [self frameForCaptionView:page.captionView atIndex:index];
		[page setMaxMinZoomScalesForCurrentBounds];
	}

	// Adjust contentOffset to preserve page location based on values collected prior to location
	_pagingScrollView.contentOffset = [self contentOffsetForPageAtIndex:indexPriorToLayout];
	[self didStartViewingPageAtIndex:_currentPageIndex]; // initial

	// Reset
	_currentPageIndex = indexPriorToLayout;
	_performingLayout = NO;

    // Super
    [super viewWillLayoutSubviews];
}

- (void)performLayout {
    // Setup
    _performingLayout = YES;
    NSUInteger numberOfPhotos = [self numberOfPhotos];

	// Setup pages
    [_visiblePages removeAllObjects];
    [_recycledPages removeAllObjects];

    // Toolbar
    if (_displayToolbar) {
        [self.view addSubview:_toolbar];
    } else {
        [_toolbar removeFromSuperview];
    }

    // Title
    if(_displayTitle && !self.navigationController.navigationBar)
        [self.view addSubview:_titleLabel];

    // Close button
    if(_displayDoneButton && !self.navigationController.navigationBar)
        [self.view addSubview:_doneButton];
    
    // Toolbar items & navigation
    UIBarButtonItem *fixedLeftSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace
                                                                                    target:self action:nil];
    fixedLeftSpace.width = 32; // To balance action button
    UIBarButtonItem *flexSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                                               target:self action:nil];
    NSMutableArray *items = [NSMutableArray new];

    if (_displayActionButton)
        [items addObject:fixedLeftSpace];
    [items addObject:flexSpace];

    if (numberOfPhotos > 1 && _displayArrowButton)
        [items addObject:_previousButton];

    if(_displayCounterLabel) {
        [items addObject:flexSpace];
        [items addObject:_counterButton];
    }

    [items addObject:flexSpace];
    if (numberOfPhotos > 1 && _displayArrowButton)
        [items addObject:_nextButton];
    [items addObject:flexSpace];

    if(_displayActionButton)
        [items addObject:_actionButton];

    [_toolbar setItems:items];
	[self updateToolbar];

    // Content offset
	_pagingScrollView.contentOffset = [self contentOffsetForPageAtIndex:_currentPageIndex];
    [self tilePages];
    _performingLayout = NO;

	if(! _disableVerticalSwipe) {
		[self.view addGestureRecognizer:_panGesture];
	}
    
    //Custom Backgroud
    if (_customBackgroud) {
        [self.view insertSubview:_customBackgroud atIndex:0];
    }
}

#pragma mark - Data

- (void)reloadData {
    // Get data
    [self releaseAllUnderlyingPhotos];

    // Update
    [self performLayout];

    // Layout
    [self.view setNeedsLayout];
}

- (NSUInteger)numberOfPhotos {
    return _photos.count;
}

- (id<ZYQPhoto>)photoAtIndex:(NSUInteger)index {
    return _photos[index];
}

- (ZYQCaptionView *)captionViewForPhotoAtIndex:(NSUInteger)index {
    ZYQCaptionView *captionView = nil;
    if ([_delegate respondsToSelector:@selector(photoBrowser:captionViewForPhotoAtIndex:)]) {
        captionView = [_delegate photoBrowser:self captionViewForPhotoAtIndex:index];
    } else {
        id <ZYQPhoto> photo = [self photoAtIndex:index];
        if ([photo respondsToSelector:@selector(caption)]) {
            if ([photo caption]) captionView = [[ZYQCaptionView alloc] initWithPhoto:photo];
        }
    }
    captionView.alpha = [self areControlsHidden] ? 0 : 1; // Initial alpha

    return captionView;
}

- (UIImage *)imageForPhoto:(id<ZYQPhoto>)photo {
	if (photo) {
		// Get image or obtain in background
		if ([photo underlyingImage]) {
			return [photo underlyingImage];
		} else {
            [photo loadUnderlyingImageAndNotify];
            if ([photo respondsToSelector:@selector(placeholderImage)]) {
                return [photo placeholderImage];
            }
		}
	}

	return nil;
}

- (void)loadAdjacentPhotosIfNecessary:(id<ZYQPhoto>)photo {
    ZYQZoomingScrollView *page = [self pageDisplayingPhoto:photo];
    if (page) {
        // If page is current page then initiate loading of previous and next pages
        NSUInteger pageIndex = PAGE_INDEX(page);
        if (_currentPageIndex == pageIndex) {
            if (pageIndex > 0) {
                // Preload index - 1
                id <ZYQPhoto> photo = [self photoAtIndex:pageIndex-1];
                if (![photo underlyingImage]) {
                    [photo loadUnderlyingImageAndNotify];
                    ZYQLog(@"Pre-loading image at index %i", pageIndex-1);
                }
            }
            if (pageIndex < [self numberOfPhotos] - 1) {
                // Preload index + 1
                id <ZYQPhoto> photo = [self photoAtIndex:pageIndex+1];
                if (![photo underlyingImage]) {
                    [photo loadUnderlyingImageAndNotify];
                    ZYQLog(@"Pre-loading image at index %i", pageIndex+1);
                }
            }
        }
    }
}

#pragma mark - ZYQPhoto Loading Notification

- (void)handleZYQPhotoLoadingDidEndNotification:(NSNotification *)notification {
    id <ZYQPhoto> photo = [notification object];
    ZYQZoomingScrollView *page = [self pageDisplayingPhoto:photo];
    if (page) {
        if ([photo underlyingImage]) {
            // Successful load
            [page displayImage];
            [self loadAdjacentPhotosIfNecessary:photo];
        } else {
            // Failed to load
            [page displayImageFailure];
            if ([_delegate respondsToSelector:@selector(photoBrowser:imageFailed:imageView:)]) {
                NSUInteger pageIndex = PAGE_INDEX(page);
                [_delegate photoBrowser:self imageFailed:pageIndex imageView:page.photoImageView];
            }
            // make sure the page is completely updated
            [page setNeedsLayout];
        }
    }
}

#pragma mark - Paging

- (void)tilePages {
	// Calculate which pages should be visible
	// Ignore padding as paging bounces encroach on that
	// and lead to false page loads
	CGRect visibleBounds = _pagingScrollView.bounds;
	NSInteger iFirstIndex = (NSInteger) floorf((CGRectGetMinX(visibleBounds)+PADDING*2) / CGRectGetWidth(visibleBounds));
	NSInteger iLastIndex  = (NSInteger) floorf((CGRectGetMaxX(visibleBounds)-PADDING*2-1) / CGRectGetWidth(visibleBounds));
    if (iFirstIndex < 0) iFirstIndex = 0;
    if (iFirstIndex > [self numberOfPhotos] - 1) iFirstIndex = [self numberOfPhotos] - 1;
    if (iLastIndex < 0) iLastIndex = 0;
    if (iLastIndex > [self numberOfPhotos] - 1) iLastIndex = [self numberOfPhotos] - 1;

	// Recycle no longer needed pages
    NSInteger pageIndex;
	for (ZYQZoomingScrollView *page in _visiblePages) {
        pageIndex = PAGE_INDEX(page);
		if (pageIndex < (NSUInteger)iFirstIndex || pageIndex > (NSUInteger)iLastIndex) {
			[_recycledPages addObject:page];
            [page prepareForReuse];
			[page removeFromSuperview];
			ZYQLog(@"Removed page at index %i", PAGE_INDEX(page));
		}
	}
	[_visiblePages minusSet:_recycledPages];
    while (_recycledPages.count > 2) // Only keep 2 recycled pages
        [_recycledPages removeObject:[_recycledPages anyObject]];

	// Add missing pages
	for (NSUInteger index = (NSUInteger)iFirstIndex; index <= (NSUInteger)iLastIndex; index++) {
		if (![self isDisplayingPageForIndex:index]) {
            // Add new page
			ZYQZoomingScrollView *page;
            page = [[ZYQZoomingScrollView alloc] initWithPhotoBrowser:self];
            page.backgroundColor = [UIColor clearColor];
            page.opaque = YES;

			[self configurePage:page forIndex:index];
			[_visiblePages addObject:page];
			[_pagingScrollView addSubview:page];
			ZYQLog(@"Added page at index %i", index);

            // Add caption
            ZYQCaptionView *captionView = [self captionViewForPhotoAtIndex:index];
            captionView.frame = [self frameForCaptionView:captionView atIndex:index];
            [_pagingScrollView addSubview:captionView];
            page.captionView = captionView;
		}
	}
}

- (BOOL)isDisplayingPageForIndex:(NSUInteger)index {
	for (ZYQZoomingScrollView *page in _visiblePages)
		if (PAGE_INDEX(page) == index) return YES;
	return NO;
}

- (ZYQZoomingScrollView *)pageDisplayedAtIndex:(NSUInteger)index {
	ZYQZoomingScrollView *thePage = nil;
	for (ZYQZoomingScrollView *page in _visiblePages) {
		if (PAGE_INDEX(page) == index) {
			thePage = page; break;
		}
	}
	return thePage;
}

- (ZYQZoomingScrollView *)pageDisplayingPhoto:(id<ZYQPhoto>)photo {
	ZYQZoomingScrollView *thePage = nil;
	for (ZYQZoomingScrollView *page in _visiblePages) {
		if (page.photo == photo) {
			thePage = page; break;
		}
	}
	return thePage;
}

- (void)configurePage:(ZYQZoomingScrollView *)page forIndex:(NSUInteger)index {
	page.frame = [self frameForPageAtIndex:index];
    page.tag = PAGE_INDEX_TAG_OFFSET + index;
    page.photo = [self photoAtIndex:index];

    __block __weak ZYQPhoto *photo = (ZYQPhoto*)page.photo;
    __weak ZYQZoomingScrollView* weakPage = page;
    photo.progressUpdateBlock = ^(CGFloat progress){
        [weakPage setProgress:progress forPhoto:photo];
    };
}

- (ZYQZoomingScrollView *)dequeueRecycledPage {
	ZYQZoomingScrollView *page = [_recycledPages anyObject];
	if (page) {
		[_recycledPages removeObject:page];
	}
	return page;
}

// Handle page changes
- (void)didStartViewingPageAtIndex:(NSUInteger)index {
    // Load adjacent images if needed and the photo is already
    // loaded. Also called after photo has been loaded in background
    id <ZYQPhoto> currentPhoto = [self photoAtIndex:index];
    if ([currentPhoto underlyingImage]) {
        // photo loaded so load ajacent now
        [self loadAdjacentPhotosIfNecessary:currentPhoto];
    }
    if ([_delegate respondsToSelector:@selector(photoBrowser:didShowPhotoAtIndex:)]) {
        [_delegate photoBrowser:self didShowPhotoAtIndex:index];
    }
}

#pragma mark - Frame Calculations

- (CGRect)frameForPagingScrollView {
    CGRect frame = self.view.bounds;
    frame.origin.x -= PADDING;
    frame.size.width += (2 * PADDING);
    return frame;
}

- (CGRect)frameForPageAtIndex:(NSUInteger)index {
    // We have to use our paging scroll view's bounds, not frame, to calculate the page placement. When the device is in
    // landscape orientation, the frame will still be in portrait because the pagingScrollView is the root view controller's
    // view, so its frame is in window coordinate space, which is never rotated. Its bounds, however, will be in landscape
    // because it has a rotation transform applied.
    CGRect bounds = _pagingScrollView.bounds;
    CGRect pageFrame = bounds;
    pageFrame.size.width -= (2 * PADDING);
    pageFrame.origin.x = (bounds.size.width * index) + PADDING;
    return pageFrame;
}

- (CGSize)contentSizeForPagingScrollView {
    // We have to use the paging scroll view's bounds to calculate the contentSize, for the same reason outlined above.
    CGRect bounds = _pagingScrollView.bounds;
    return CGSizeMake(bounds.size.width * [self numberOfPhotos], bounds.size.height);
}

- (CGPoint)contentOffsetForPageAtIndex:(NSUInteger)index {
	CGFloat pageWidth = _pagingScrollView.bounds.size.width;
	CGFloat newOffset = index * pageWidth;
	return CGPointMake(newOffset, 0);
}

- (BOOL)isLandscape:(UIInterfaceOrientation)orientation
{
    return UIInterfaceOrientationIsLandscape(orientation);
}

- (CGRect)frameForToolbarAtOrientation:(UIInterfaceOrientation)orientation {
    CGFloat height = 44;

    if ([self isLandscape:orientation])
        height = 32;

    return CGRectMake(0, self.view.bounds.size.height - height, self.view.bounds.size.width, height);
}

- (CGRect)frameForDoneButtonAtOrientation:(UIInterfaceOrientation)orientation {
    CGRect screenBound = self.view.bounds;
    CGFloat screenWidth = screenBound.size.width;

    // if ([self isLandscape:orientation]) screenWidth = screenBound.size.height;

    return CGRectMake(screenWidth - self.doneButtonRightInset - self.doneButtonSize.width, self.doneButtonTopInset, self.doneButtonSize.width, self.doneButtonSize.height);
}

- (CGRect)frameForTitleLabelAtOrientation:(UIInterfaceOrientation)orientation {
    CGRect screenBound = self.view.bounds;
    CGFloat screenWidth = screenBound.size.width;
    CGFloat statusBarBottom=[UIApplication sharedApplication].statusBarFrame.origin.y+[UIApplication sharedApplication].statusBarFrame.size.height;
    
    // if ([self isLandscape:orientation]) screenWidth = screenBound.size.height;
    
    return CGRectMake(0, statusBarBottom, screenWidth, 44);
}

- (CGRect)frameForCaptionView:(ZYQCaptionView *)captionView atIndex:(NSUInteger)index {
    CGRect pageFrame = [self frameForPageAtIndex:index];

    CGSize captionSize = [captionView sizeThatFits:CGSizeMake(pageFrame.size.width, 0)];
    CGRect captionFrame = CGRectMake(pageFrame.origin.x, pageFrame.size.height - captionSize.height - (_toolbar.superview?_toolbar.frame.size.height:0), pageFrame.size.width, captionSize.height);

    return captionFrame;
}

#pragma mark - UIScrollView Delegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView  {
    // Checks
    if (!_viewIsActive || _performingLayout || _rotating) return;

    // Tile pages
    [self tilePages];

    // Calculate current page
    CGRect visibleBounds = _pagingScrollView.bounds;
    NSInteger index = (NSInteger) (floorf(CGRectGetMidX(visibleBounds) / CGRectGetWidth(visibleBounds)));
    if (index < 0) index = 0;
    if (index > [self numberOfPhotos] - 1) index = [self numberOfPhotos] - 1;
    NSUInteger previousCurrentPage = _currentPageIndex;
    _currentPageIndex = index;
    if (_currentPageIndex != previousCurrentPage) {
        [self didStartViewingPageAtIndex:index];

        if(_arrowButtonsChangePhotosAnimated) [self updateToolbar];
    }
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
	// Hide controls when dragging begins
    if(_autoHideInterface){
        [self setControlsHidden:YES animated:YES permanent:NO];
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
	// Update toolbar when page changes
	if(! _arrowButtonsChangePhotosAnimated) [self updateToolbar];
}

#pragma mark - Toolbar

- (void)updateToolbar {
    //Title
    if ([_delegate respondsToSelector:@selector(photoBrowser:titleForPhotoAtIndex:)]) {
        _titleLabel.text=[_delegate photoBrowser:self titleForPhotoAtIndex:_currentPageIndex];
    }
    else{
        _titleLabel.text=ZYQPhotoBrowserLocalizedStrings(@"PhotoBrowser");
    }
    
    // Counter
    if ([_delegate respondsToSelector:@selector(photoBrowser:counterForPhotoAtIndex:)]) {
        _counterLabel.text=[_delegate photoBrowser:self counterForPhotoAtIndex:_currentPageIndex];
    }
    else{
        if ([self numberOfPhotos] > 1) {
            _counterLabel.text = [NSString stringWithFormat:@"%lu %@ %lu", (unsigned long)(_currentPageIndex+1), ZYQPhotoBrowserLocalizedStrings(@"of"), (unsigned long)[self numberOfPhotos]];
        } else {
            _counterLabel.text = nil;
        }
    }

	// Buttons
	_previousButton.enabled = (_currentPageIndex > 0);
	_nextButton.enabled = (_currentPageIndex < [self numberOfPhotos]-1);
}

- (void)jumpToPageAtIndex:(NSUInteger)index {
    // Change page
	if (index < [self numberOfPhotos]) {
		CGRect pageFrame = [self frameForPageAtIndex:index];

		if(_arrowButtonsChangePhotosAnimated)
        {
            [_pagingScrollView setContentOffset:CGPointMake(pageFrame.origin.x - PADDING, 0) animated:YES];
        }
        else
        {
            _pagingScrollView.contentOffset = CGPointMake(pageFrame.origin.x - PADDING, 0);
            [self updateToolbar];
        }
	}

	// Update timer to give more time
	[self hideControlsAfterDelay];
}

- (void)gotoPreviousPage { [self jumpToPageAtIndex:_currentPageIndex-1]; }
- (void)gotoNextPage     { [self jumpToPageAtIndex:_currentPageIndex+1]; }

#pragma mark - Control Hiding / Showing

// If permanent then we don't set timers to hide again
- (void)setControlsHidden:(BOOL)hidden animated:(BOOL)animated permanent:(BOOL)permanent {
    // Cancel any timers
    [self cancelControlHiding];

    // Captions
    NSMutableSet *captionViews = [[NSMutableSet alloc] initWithCapacity:_visiblePages.count];
    for (ZYQZoomingScrollView *page in _visiblePages) {
        if (page.captionView) [captionViews addObject:page.captionView];
    }

    // Hide/show bars
    [UIView animateWithDuration:(animated ? 0.1 : 0) animations:^(void) {
        CGFloat alpha = hidden ? 0 : 1;
        [self.navigationController.navigationBar setAlpha:alpha];
        [_toolbar setAlpha:alpha];
        [_doneButton setAlpha:alpha];
        [_titleLabel setAlpha:alpha];
        for (UIView *v in captionViews) v.alpha = alpha;
    } completion:^(BOOL finished) {}];

	// Control hiding timer
	// Will cancel existing timer but only begin hiding if they are visible
	if (!permanent) {
		[self hideControlsAfterDelay];
	}
	
    [self setNeedsStatusBarAppearanceUpdate];
}

- (void)cancelControlHiding {
	// If a timer exists then cancel and release
	if (_controlVisibilityTimer) {
		[_controlVisibilityTimer invalidate];
		_controlVisibilityTimer = nil;
	}
}

// Enable/disable control visiblity timer
- (void)hideControlsAfterDelay {
    if (![self autoHideInterface]) {
        return;
    }

	if (![self areControlsHidden]) {
        [self cancelControlHiding];
		_controlVisibilityTimer = [NSTimer scheduledTimerWithTimeInterval:5 target:self selector:@selector(hideControls) userInfo:nil repeats:NO];
	}
}

- (BOOL)areControlsHidden {
	return (_toolbar.alpha == 0);
}

- (void)hideControls {
	if(_autoHide && _autoHideInterface) {
		[self setControlsHidden:YES animated:YES permanent:NO];
	}
}
- (void)handleSingleTap {
	if (_dismissOnTouch) {
		[self doneButtonPressed:nil];
	} else {
		[self setControlsHidden:![self areControlsHidden] animated:YES permanent:NO];
	}
}


#pragma mark - Properties

-(NSArray *)photos{
    return _photos;
}

- (void)setInitialPageIndex:(NSUInteger)index {
    // Validate
    if (index >= [self numberOfPhotos]) index = [self numberOfPhotos]-1;
    _initalPageIndex = index;
    _currentPageIndex = index;
	if ([self isViewLoaded]) {
        [self jumpToPageAtIndex:index];
        if (!_viewIsActive) [self tilePages]; // Force tiling if view is not visible
    }
}

- (void)setGifSupportImageViewClass:(Class)gifSupportImageViewClass{
    if (_gifSupportImageViewClass==gifSupportImageViewClass) {
        return;
    }
    _gifSupportImageViewClass=gifSupportImageViewClass;
    
    [self zyq_hookOrAddWithOriginSeletor:@selector(touchesEnded:withEvent:) originClass:_gifSupportImageViewClass swizzledSelector:@selector(touchesEnded:withEvent:) swizzledClass:NSClassFromString(@"ZYQTapDetectingImageView")];
    [self zyq_hookOrAddWithOriginSeletor:@selector(handleSingleTap:) originClass:_gifSupportImageViewClass swizzledSelector:@selector(handleSingleTap:) swizzledClass:NSClassFromString(@"ZYQTapDetectingImageView")];
    [self zyq_hookOrAddWithOriginSeletor:@selector(handleDoubleTap:) originClass:_gifSupportImageViewClass swizzledSelector:@selector(handleDoubleTap:) swizzledClass:NSClassFromString(@"ZYQTapDetectingImageView")];
    [self zyq_hookOrAddWithOriginSeletor:@selector(handleTripleTap:) originClass:_gifSupportImageViewClass swizzledSelector:@selector(handleTripleTap:) swizzledClass:NSClassFromString(@"ZYQTapDetectingImageView")];
    [self zyq_hookOrAddWithOriginSeletor:@selector(setTapDelegate:) originClass:_gifSupportImageViewClass swizzledSelector:@selector(setTapDelegate:) swizzledClass:NSClassFromString(@"ZYQTapDetectingImageView")];
    [self zyq_hookOrAddWithOriginSeletor:@selector(tapDelegate) originClass:_gifSupportImageViewClass swizzledSelector:@selector(tapDelegate) swizzledClass:NSClassFromString(@"ZYQTapDetectingImageView")];

    
}

-(void)zyq_hookOrAddWithOriginSeletor:(SEL)originalSelector originClass:(Class)originClass swizzledSelector:(SEL)swizzledSelector swizzledClass:(Class)swizzledClass{
    
    Method originalMethod = class_getInstanceMethod(originClass, originalSelector);
    Method swizzledMethod = class_getInstanceMethod(swizzledClass, swizzledSelector);
    
    static OSSpinLock aspect_lock = OS_SPINLOCK_INIT;
    OSSpinLockLock(&aspect_lock);
    
    BOOL success = class_addMethod(originClass, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod));
    if (success) {
        class_replaceMethod(originClass, swizzledSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod));
    } else {
        method_exchangeImplementations(originalMethod, swizzledMethod);
    }
    OSSpinLockUnlock(&aspect_lock);
    
}


#pragma mark - Buttons

- (void)doneButtonPressed:(id)sender {
    if ([_delegate respondsToSelector:@selector(willDisappearPhotoBrowser:)]) {
        [_delegate willDisappearPhotoBrowser:self];
    }

    if (_senderViewForAnimation && _currentPageIndex == _initalPageIndex) {
        ZYQZoomingScrollView *scrollView = [self pageDisplayedAtIndex:_currentPageIndex];
        [self performCloseAnimationWithScrollView:scrollView];
    }
    else {
        _senderViewForAnimation.hidden = NO;
        [self prepareForClosePhotoBrowser];
        [self dismissPhotoBrowserAnimated:YES];
    }
}

- (void)actionButtonPressed:(id)sender {
    id <ZYQPhoto> photo = [self photoAtIndex:_currentPageIndex];

    if ([self numberOfPhotos] > 0 && [photo underlyingImage]) {
        if(!_actionButtonTitles)
        {
            // Activity view
            NSMutableArray *activityItems = [NSMutableArray arrayWithObject:[photo underlyingImage]];
            if (photo.caption) [activityItems addObject:photo.caption];

            self.activityViewController = [[UIActivityViewController alloc] initWithActivityItems:activityItems applicationActivities:nil];

            __typeof__(self) __weak selfBlock = self;

			[self.activityViewController setCompletionWithItemsHandler:^(NSString *activityType, BOOL completed, NSArray *returnedItems, NSError *activityError) {
				[selfBlock hideControlsAfterDelay];
				selfBlock.activityViewController = nil;
			}];

			if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
				[self presentViewController:self.activityViewController animated:YES completion:nil];
			}
			else { // iPad
#if __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_8_0
                
                self.activityViewController.modalPresentationStyle = UIModalPresentationPopover;
                self.activityViewController.preferredContentSize = CGSizeMake(300, 400);

                UIPopoverPresentationController *popover = self.activityViewController.popoverPresentationController;
                [popover setSourceRect:CGRectMake(self.view.frame.size.width/2, self.view.frame.size.height/4, 0, 0)];
                [popover setSourceView:self.view];
                [self presentViewController:self.activityViewController animated:YES completion:nil];
#else
				UIPopoverController *popover = [[UIPopoverController alloc] initWithContentViewController:self.activityViewController];
				[popover presentPopoverFromRect:CGRectMake(self.view.frame.size.width/2, self.view.frame.size.height/4, 0, 0)
										 inView:self.view permittedArrowDirections:UIPopoverArrowDirectionAny
									   animated:YES];
#endif
			}
        }
        else
        {
            // Action sheet
#if __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_8_0
            self.actionsSheet=[UIAlertController alertControllerWithTitle:@"" message:@"" preferredStyle:UIAlertControllerStyleActionSheet];
            for (NSInteger i=0; i<_actionButtonTitles.count; i++) {
                UIAlertAction *alertAction=[UIAlertAction actionWithTitle:_actionButtonTitles[i] style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                    if ([_delegate respondsToSelector:@selector(photoBrowser:didDismissActionSheetWithButtonIndex:photoIndex:)]) {
                        [_delegate photoBrowser:self didDismissActionSheetWithButtonIndex:i photoIndex:_currentPageIndex];
                        return;
                    }
                }];
                [self.actionsSheet addAction:alertAction];
            }
            
            UIAlertAction *cancelAlertAction=[UIAlertAction actionWithTitle:ZYQPhotoBrowserLocalizedStrings(@"Cancel") style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
                [self hideControlsAfterDelay];
            }];
            
            [self.actionsSheet addAction:cancelAlertAction];

            
            [self presentViewController:self.actionsSheet animated:YES completion:nil];
            
#else
            self.actionsSheet = [UIActionSheet new];
            self.actionsSheet.delegate = self;
            for(NSString *action in _actionButtonTitles) {
                [self.actionsSheet addButtonWithTitle:action];
            }
            
            self.actionsSheet.cancelButtonIndex = [self.actionsSheet addButtonWithTitle:ZYQPhotoBrowserLocalizedStrings(@"Cancel")];
            self.actionsSheet.actionSheetStyle = UIActionSheetStyleBlackTranslucent;
            
            if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
                [_actionsSheet showInView:self.view];
            } else {
                [_actionsSheet showFromBarButtonItem:sender animated:YES];
            }
#endif

            
        }

        // Keep controls hidden
        [self setControlsHidden:NO animated:YES permanent:YES];
    }
}

#pragma mark - Action Sheet Delegate

#if __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_8_0
#else
- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if (actionSheet == _actionsSheet) {
        self.actionsSheet = nil;
        
        if (buttonIndex != actionSheet.cancelButtonIndex) {
            if ([_delegate respondsToSelector:@selector(photoBrowser:didDismissActionSheetWithButtonIndex:photoIndex:)]) {
                [_delegate photoBrowser:self didDismissActionSheetWithButtonIndex:buttonIndex photoIndex:_currentPageIndex];
                return;
            }
        }
    }
    
    [self hideControlsAfterDelay]; // Continue as normal...
}
#endif


#pragma mark - Zoom Animation

- (void)animateView:(UIView *)view toFrame:(CGRect)frame completion:(void (^)(void))completion
{
    if ([self conformsToProtocol:objc_getProtocol("ZYQPhotoBrowserCustomProtocol")]) {
        [(ZYQPhotoBrowser<ZYQPhotoBrowserCustomProtocol>*)self animateView:view toFrame:frame completion:completion];
    }
    else{
        [UIView animateWithDuration:0.5 animations:^{
            view.frame=frame;
        } completion:^(BOOL finished) {
            if (completion) {
                completion();
            }
        }];
    }
}
@end
