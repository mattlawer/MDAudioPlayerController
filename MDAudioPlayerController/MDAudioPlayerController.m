//
//  AudioPlayer.m
//  MobileTheatre
//
//  Created by Matt Donnelly on 27/03/2010.
//  Copyright 2010 Apple Inc. All rights reserved.
//

#import "MDAudioPlayerController.h"
#import "MDAudioFile.h"
#import "MDAudioTitleView.h"
#import "MDAudioPlayerTableViewCell.h"

#import <MediaPlayer/MediaPlayer.h>


@interface MDAudioPlayerController () {
    UINavigationBar *_savedBar;
}
- (BOOL)isModal;
- (UIImage *)reflectedImage:(UIImageView *)fromImage withHeight:(NSUInteger)height;
@end

@implementation MDAudioPlayerController

static MDAudioPlayerController* _sharedInstance = nil;
static const CGFloat kDefaultReflectionFraction = 0.65;
static const CGFloat kDefaultReflectionOpacity = 0.40;

void interruptionListenerCallback (void *userData, UInt32 interruptionState);
CGImageRef CreateGradientImage(int pixelsWide, int pixelsHigh);
CGContextRef MyCreateBitmapContext(int pixelsWide, int pixelsHigh);

@synthesize soundFiles;
@synthesize soundFilesPath;

@synthesize player;
@synthesize gradientLayer;

@synthesize playButton;
@synthesize pauseButton;
@synthesize nextButton;
@synthesize previousButton;
@synthesize toggleButton;
@synthesize repeatButton;
@synthesize shuffleButton;

@synthesize currentTime;
@synthesize duration;
@synthesize indexLabel;
@synthesize titleView;

@synthesize volumeSlider;
@synthesize progressSlider;

@synthesize songTableView;

@synthesize artworkView;
@synthesize reflectionView;
@synthesize containerView;
@synthesize overlayView;

@synthesize updateTimer;

@synthesize interrupted;
@synthesize repeatAll;
@synthesize repeatOne;
@synthesize shuffle;


+ (MDAudioPlayerController *)sharedInstance {
    @synchronized(self) {
        if (nil == _sharedInstance)
            _sharedInstance = [[MDAudioPlayerController alloc] initWithSoundFiles:nil atPath:@"/" andSelectedIndex:0];
    }
    return _sharedInstance;
}
+ (BOOL) sharedInstanceExist {
    return (_sharedInstance != nil);
}

- (UIModalPresentationStyle) modalPresentationStyle {
#if (__IPHONE_OS_VERSION_MAX_ALLOWED >= 30200)
    if ([[UIDevice currentDevice] respondsToSelector: @selector(userInterfaceIdiom)])
        return ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) ? UIModalPresentationFormSheet : UIModalPresentationCurrentContext;
#endif
    return UIModalPresentationCurrentContext;
}

void interruptionListenerCallback (void *userData, UInt32 interruptionState)
{
	MDAudioPlayerController *vc = (MDAudioPlayerController *)userData;
	if (interruptionState == kAudioSessionBeginInterruption)
		vc.interrupted = YES;
	else if (interruptionState == kAudioSessionEndInterruption)
		vc.interrupted = NO;
}

-(void)updateCurrentTimeForPlayer:(AVAudioPlayer *)p
{
	NSString *current = [NSString stringWithFormat:@"%d:%02d", (int)p.currentTime / 60, (int)p.currentTime % 60, nil];
	NSString *dur = [NSString stringWithFormat:@"-%d:%02d", (int)((int)(p.duration - p.currentTime)) / 60, (int)((int)(p.duration - p.currentTime)) % 60, nil];
	duration.text = dur;
	currentTime.text = current;
	progressSlider.value = p.currentTime;
}

- (void)updateCurrentTime
{
	[self updateCurrentTimeForPlayer:self.player];
}

- (void)updateViewForPlayerState:(AVAudioPlayer *)p
{
    if (!p) 
        p = player;
	titleView.titleLabel.text = [[soundFiles objectAtIndex:selectedIndex] title];
	titleView.artistLabel.text = [[soundFiles objectAtIndex:selectedIndex] artist];
	titleView.albumLabel.text = [[soundFiles objectAtIndex:selectedIndex] album];
	
	[self updateCurrentTimeForPlayer:p];
	
	if (updateTimer) 
		[updateTimer invalidate];
	
	if (p.playing)
	{
        pauseButton.hidden = NO;
        playButton.hidden = YES;
        
		updateTimer = [NSTimer scheduledTimerWithTimeInterval:.01 target:self selector:@selector(updateCurrentTime) userInfo:nil repeats:YES];
	}
	else
	{
        pauseButton.hidden = YES;
        playButton.hidden = NO;
        
		updateTimer = nil;
	}
	
	if (![songTableView superview]) 
	{
		[artworkView setImage:[[soundFiles objectAtIndex:selectedIndex] coverImage]];
		reflectionView.image = [self reflectedImage:artworkView withHeight:artworkView.bounds.size.height * kDefaultReflectionFraction];
	}
    else {
        [songTableView reloadData];
    }
	
	if (repeatOne || repeatAll || shuffle)
		nextButton.enabled = YES;
	else	
		nextButton.enabled = [self canGoToNextTrack];
	previousButton.enabled = [self canGoToPreviousTrack];
}

-(void)updateViewForPlayerInfo:(AVAudioPlayer*)p
{
	duration.text = [NSString stringWithFormat:@"%d:%02d", (int)p.duration / 60, (int)p.duration % 60, nil];
	indexLabel.text = [NSString stringWithFormat:@"%d of %d", (selectedIndex + 1), [soundFiles count]];
    
    if ([MPNowPlayingInfoCenter class])  {
        /* we're on iOS 5, so set up the now playing center */
        if ([self.player isPlaying]) {
            MDAudioFile *audio_f = (MDAudioFile *)[soundFiles objectAtIndex:selectedIndex];
            MPMediaItemArtwork *albumArt = [[MPMediaItemArtwork alloc] initWithImage:[audio_f coverImage]];
            
            NSDictionary *currentlyPlayingTrackInfo = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[audio_f title], [NSNumber numberWithFloat:[audio_f duration]], albumArt, nil] forKeys:[NSArray arrayWithObjects:MPMediaItemPropertyTitle, MPMediaItemPropertyPlaybackDuration, MPMediaItemPropertyArtwork, nil]];
            [albumArt release];
            [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = currentlyPlayingTrackInfo;
        }else {
            [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = nil;
        }
        
    }
}

- (MDAudioPlayerController *)initWithSoundFiles:(NSMutableArray *)songs atPath:(NSString *)path andSelectedIndex:(int)index
{
	if (self = [super init]) 
	{
		self.soundFiles = songs;
		self.soundFilesPath = path;
		selectedIndex = index;
				
		NSError *error = nil;
				
		AVAudioPlayer *newPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:[(MDAudioFile *)[soundFiles objectAtIndex:selectedIndex] filePath] error:&error];
        self.player = newPlayer;
        [newPlayer release];
		[player setNumberOfLoops:0];
		player.delegate = self;
				
		[self updateViewForPlayerInfo:player];
		[self updateViewForPlayerState:player];
		
		if (error)
			NSLog(@"%@", error);
	}
	
	return self;
}

- (void) setSoundFiles:(NSMutableArray *)songs atPath:(NSString *)path selectedIndex:(int)index {
    self.soundFiles = songs;
    self.soundFilesPath = path;
    selectedIndex = index;
    
    
    if (self.player.playing == YES) {
        
        [self.player stop];
	}

    NSError *error = nil;
    AVAudioPlayer *newPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:[(MDAudioFile *)[soundFiles objectAtIndex:selectedIndex] filePath] error:&error];
    self.player = newPlayer;
    [newPlayer release];
    [player setNumberOfLoops:0];
    player.delegate = self;
    player.volume = 1.0;
    
    [self.songTableView reloadData];
    
    [player play];
    
    [self updateViewForPlayerInfo:player];
    [self updateViewForPlayerState:player];
    
    if (error)
        NSLog(@"%@", error);
}

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	self.view.backgroundColor = [UIColor blackColor];
    self.view.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
	
	
	updateTimer = nil;
    CGFloat width = self.view.frame.size.width;
    CGFloat height = self.view.frame.size.height;
	
    self.toggleButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 34, 30)];
    [toggleButton setImage:[UIImage imageWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"AudioPlayerAlbumInfo" ofType:@"png" inDirectory:@"MDAudioPlayer.bundle"]] forState:UIControlStateNormal];
    [toggleButton addTarget:self action:@selector(showSongFiles) forControlEvents:UIControlEventTouchUpInside];
    
    UIBarButtonItem *songsListBarButton = [[UIBarButtonItem alloc] initWithCustomView:self.toggleButton];
    self.navigationItem.rightBarButtonItem = songsListBarButton;
    [songsListBarButton release];
    
	
    // Setup audio session
    NSError *setCategoryErr = nil;
	NSError *activationErr  = nil;
	
	[[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error: &setCategoryErr];
	[[AVAudioSession sharedInstance] setActive:YES error: &activationErr];
	[[AVAudioSession sharedInstance] setDelegate: self];
	
	MDAudioFile *selectedSong = [self.soundFiles objectAtIndex:selectedIndex];
	
    self.titleView = [[MDAudioTitleView alloc] initWithNavigationItem:self.navigationItem];
    titleView.titleLabel.text = [selectedSong title];
    titleView.artistLabel.text = [selectedSong artist];
    titleView.albumLabel.text = [selectedSong album];

	
	duration.adjustsFontSizeToFitWidth = YES;
	currentTime.adjustsFontSizeToFitWidth = YES;
	progressSlider.minimumValue = 0.0;	
	
	self.containerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, height)];
    self.containerView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[self.view addSubview:containerView];
	
	self.artworkView = [[UIImageView alloc] initWithFrame:CGRectMake(1, 1, width-2, height-96)];
	[artworkView setImage:[selectedSong coverImage]];
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(showOverlayView)];
    UITapGestureRecognizer *tap2 = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(showSongFiles)];
    [tap requireGestureRecognizerToFail:tap2];
    tap.numberOfTapsRequired = 1;
    tap2.numberOfTapsRequired = 2;
    [artworkView addGestureRecognizer:tap];
    [artworkView addGestureRecognizer:tap2];
    [tap release];
    [tap2 release];
    artworkView.contentMode = UIViewContentModeScaleAspectFit;
    artworkView.userInteractionEnabled = YES;
	artworkView.backgroundColor = [UIColor clearColor];
    artworkView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[containerView addSubview:artworkView];
	
	self.reflectionView = [[UIImageView alloc] initWithFrame:CGRectMake(0, height - 96, width, 96)];
	reflectionView.image = [self reflectedImage:artworkView withHeight:artworkView.bounds.size.height * kDefaultReflectionFraction];
	reflectionView.alpha = kDefaultReflectionFraction;
    reflectionView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
	[self.containerView addSubview:reflectionView];
	
	self.songTableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, width, height-92)];
	self.songTableView.delegate = self;
	self.songTableView.dataSource = self;
	self.songTableView.separatorColor = [UIColor colorWithRed:0.986 green:0.933 blue:0.994 alpha:0.10];
	self.songTableView.backgroundColor = [UIColor clearColor];
	self.songTableView.contentInset = UIEdgeInsetsMake(0, 0, 37, 0); 
	self.songTableView.showsVerticalScrollIndicator = NO;
    self.songTableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	
	gradientLayer = [[CAGradientLayer alloc] init];
	gradientLayer.frame = CGRectMake(0.0, self.containerView.bounds.size.height - 96, self.containerView.bounds.size.width, 48);
	gradientLayer.colors = [NSArray arrayWithObjects:(id)[UIColor clearColor].CGColor, (id)[UIColor colorWithWhite:0.0 alpha:0.5].CGColor, (id)[UIColor blackColor].CGColor, (id)[UIColor blackColor].CGColor, nil];
	gradientLayer.zPosition = INT_MAX;
	
	/*! HACKY WAY OF REMOVING EXTRA SEPERATORS */
	
	UIView *v = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 10)];
	v.backgroundColor = [UIColor clearColor];
	[self.songTableView setTableFooterView:v];
	[v release];
	v = nil;
    
	UIImageView *buttonBackground = [[UIImageView alloc] initWithFrame:CGRectMake(0, height-96, self.view.bounds.size.width, 96)];
	buttonBackground.image = [[UIImage imageWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"AudioPlayerBarBackground" ofType:@"png" inDirectory:@"MDAudioPlayer.bundle"]] stretchableImageWithLeftCapWidth:0 topCapHeight:0];
    buttonBackground.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
	[self.view addSubview:buttonBackground];
	[buttonBackground release];
	buttonBackground  = nil;
    
	self.playButton = [[UIButton alloc] initWithFrame:CGRectMake((width/2)-20, height-90, 40, 40)];
	[playButton setImage:[UIImage imageWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"play" ofType:@"png" inDirectory:@"MDAudioPlayer.bundle"]] forState:UIControlStateNormal];
	[playButton addTarget:self action:@selector(play) forControlEvents:UIControlEventTouchUpInside];
	playButton.showsTouchWhenHighlighted = YES;
    playButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin;
	[self.view addSubview:playButton];
    
	self.pauseButton = [[UIButton alloc] initWithFrame:CGRectMake((width/2)-20, height-90, 40, 40)];
	[pauseButton setImage:[UIImage imageWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"pause" ofType:@"png" inDirectory:@"MDAudioPlayer.bundle"]] forState:UIControlStateNormal];
	[pauseButton addTarget:self action:@selector(play) forControlEvents:UIControlEventTouchUpInside];
	pauseButton.showsTouchWhenHighlighted = YES;
    pauseButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin;
    pauseButton.hidden = YES;
    [self.view addSubview:pauseButton];
	
	self.nextButton = [[UIButton alloc] initWithFrame:CGRectMake((width/2)+90, height-90, 40, 40)];
	[nextButton setImage:[UIImage imageWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"nexttrack" ofType:@"png" inDirectory:@"MDAudioPlayer.bundle"]] 
				forState:UIControlStateNormal];
	[nextButton addTarget:self action:@selector(next) forControlEvents:UIControlEventTouchUpInside];
	nextButton.showsTouchWhenHighlighted = YES;
	nextButton.enabled = [self canGoToNextTrack];
    nextButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin;
	[self.view addSubview:nextButton];
	
	self.previousButton = [[UIButton alloc] initWithFrame:CGRectMake((width/2)-130, height-90, 40, 40)];
	[previousButton setImage:[UIImage imageWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"prevtrack" ofType:@"png" inDirectory:@"MDAudioPlayer.bundle"]] 
                    forState:UIControlStateNormal];
	[previousButton addTarget:self action:@selector(previous) forControlEvents:UIControlEventTouchUpInside];
	previousButton.showsTouchWhenHighlighted = YES;
	previousButton.enabled = [self canGoToPreviousTrack];
    previousButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin;
	[self.view addSubview:previousButton];
	
	self.volumeSlider = [[MPVolumeView alloc] initWithFrame:CGRectMake((width/2)-110, height-40, 220, 25)];
    
    volumeSlider.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin;
	[self.view addSubview:volumeSlider];
	
	[self updateViewForPlayerInfo:player];
	[self updateViewForPlayerState:player];
}

// Gestion du control du player hors de l'app
- (void)remoteControlReceivedWithEvent:(UIEvent *)event
{
	//NSLog(@"UIEventTypeRemoteControl: %d - %d", event.type, event.subtype);
	
    switch (event.subtype) {
        //Other    
        case UIEventSubtypeNone:{
            NSLog(@"UIEventSubtypeNone");
        }break;
        case UIEventSubtypeMotionShake:{
            NSLog(@"UIEventSubtypeMotionShake");
        }break;
            
        // Seek
        case UIEventSubtypeRemoteControlBeginSeekingBackward:{
            NSLog(@"UIEventSubtypeRemoteControlBeginSeekingBackward");
        }break;
        case UIEventSubtypeRemoteControlEndSeekingBackward:{
            NSLog(@"UIEventSubtypeRemoteControlEndSeekingBackward");
        }break;
        case UIEventSubtypeRemoteControlBeginSeekingForward:{
            NSLog(@"UIEventSubtypeRemoteControlBeginSeekingForward");
        }break;
        case UIEventSubtypeRemoteControlEndSeekingForward:{
            NSLog(@"UIEventSubtypeRemoteControlEndSeekingForward");
        }break;
            
        // Player
        case UIEventSubtypeRemoteControlTogglePlayPause:{
            NSLog(@"UIEventSubtypeRemoteControlTogglePlayPause");
            [self play];
        }break;
        case UIEventSubtypeRemoteControlPlay:{
            NSLog(@"UIEventSubtypeRemoteControlPlay");
            [self.player play];
            [self updateViewForPlayerInfo:player];
            [self updateViewForPlayerState:player];
        }break;
        case UIEventSubtypeRemoteControlPause:{
            NSLog(@"UIEventSubtypeRemoteControlPause");
            [self.player pause];
            [self updateViewForPlayerInfo:player];
            [self updateViewForPlayerState:player];
        }break;
        case UIEventSubtypeRemoteControlStop:{
            NSLog(@"UIEventSubtypeRemoteControlStop");
            [self.player stop];
            [self updateViewForPlayerInfo:player];
            [self updateViewForPlayerState:player];
        }break;
        case UIEventSubtypeRemoteControlNextTrack:{
            NSLog(@"UIEventSubtypeRemoteControlNextTrack");
            if ([self canGoToNextTrack]) {
                [self next];
            }
            
        }break;
        case UIEventSubtypeRemoteControlPreviousTrack:{
            NSLog(@"UIEventSubtypeRemoteControlPreviousTrack");
            if ([self canGoToPreviousTrack]) {
                [self previous];
            }
            
        }break;
    }
}

- (BOOL)canBecomeFirstResponder {
    return YES;
}



- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleBlackOpaque animated:YES];
    if ([self isModal]) {
        UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(dismissAudioPlayer)];
        self.navigationItem.leftBarButtonItem = doneButton;
        [doneButton release];
    }else {
        _savedBar = [[[UINavigationBar alloc] init] retain];
        _savedBar.barStyle = self.navigationController.navigationBar.barStyle;
        _savedBar.tintColor = self.navigationController.navigationBar.tintColor;
    }
    if ([self.navigationController.navigationBar respondsToSelector:@selector(setBackgroundImage:forBarMetrics:)]) {
        [self.navigationController.navigationBar setBackgroundImage:[UIImage imageWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"AudioPlayerNavBar" ofType:@"png" inDirectory:@"MDAudioPlayer.bundle"]] forBarMetrics:UIBarMetricsDefault];
    }
    [self.navigationController.navigationBar setBarStyle:UIBarStyleBlack];
    [self.navigationItem setTitleView:self.titleView];
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
    [self becomeFirstResponder];
    // Handle Audio Remote Control events (only available under iOS 4
	if ([[UIApplication sharedApplication] respondsToSelector:@selector(beginReceivingRemoteControlEvents)]){
		[[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
	}
    	
	[self updateViewForPlayerInfo:player];
	[self updateViewForPlayerState:player];
}

- (void) viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [[UIApplication sharedApplication] endReceivingRemoteControlEvents];
    [self resignFirstResponder];
    self.navigationItem.leftBarButtonItem = nil;
    [updateTimer invalidate]; updateTimer = nil;
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
    if (![self isModal]) {
        self.navigationController.navigationBar.barStyle = _savedBar.barStyle;
        self.navigationController.navigationBar.tintColor = _savedBar.tintColor;
        if ([self.navigationController.navigationBar respondsToSelector:@selector(setBackgroundImage:forBarMetrics:)]) {
            [self.navigationController.navigationBar setBackgroundImage:nil forBarMetrics:UIBarMetricsDefault];
        }
        [_savedBar release];
        [self.navigationController popViewControllerAnimated:YES];
    }
	/*[player release];
     player = nil;*/
}

- (BOOL)isModal {
    return self.presentingViewController.presentedViewController == self
    || self.navigationController.presentingViewController.presentedViewController == self.navigationController
    || [self.tabBarController.presentingViewController isKindOfClass:[UITabBarController class]];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
#if (__IPHONE_OS_VERSION_MAX_ALLOWED >= 30200)
    if ([[UIDevice currentDevice] respondsToSelector: @selector(userInterfaceIdiom)])
        return ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) ? (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown) : (interfaceOrientation == UIInterfaceOrientationPortrait);
#endif
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)dismissAudioPlayer
{
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:YES];
    if ([self isModal]) {
        [self dismissViewControllerAnimated:YES completion:^{}];
    }
	
    [self becomeFirstResponder];
    // Handle Audio Remote Control events (only available under iOS 4
	if ([[UIApplication sharedApplication] respondsToSelector:@selector(beginReceivingRemoteControlEvents)]){
		[[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
	}
}

- (void)showSongFiles
{
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:0.6];
	
	[UIView setAnimationTransition:([self.songTableView superview] ?
									UIViewAnimationTransitionFlipFromLeft : UIViewAnimationTransitionFlipFromRight)
						   forView:self.toggleButton cache:YES];
	if ([songTableView superview])
		[self.toggleButton setImage:[UIImage imageWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"AudioPlayerAlbumInfo" ofType:@"png" inDirectory:@"MDAudioPlayer.bundle"]] forState:UIControlStateNormal];
	else
		[self.toggleButton setImage:self.artworkView.image forState:UIControlStateNormal];
	
	[UIView commitAnimations];
	
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:0.6];
	
	[UIView setAnimationTransition:([self.songTableView superview] ?
									UIViewAnimationTransitionFlipFromLeft : UIViewAnimationTransitionFlipFromRight)
						   forView:self.containerView cache:YES];
	if ([songTableView superview])
	{
		[self.songTableView removeFromSuperview];
        self.artworkView.contentMode = UIViewContentModeScaleAspectFit;
		[self.artworkView setImage:[[soundFiles objectAtIndex:selectedIndex] coverImage]];
		[self.containerView addSubview:reflectionView];
		
		[gradientLayer removeFromSuperlayer];
	}
	else
	{
        artworkView.contentMode = UIViewContentModeScaleToFill;
		[self.artworkView setImage:[UIImage imageWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"AudioPlayerTableBackground" ofType:@"png" inDirectory:@"MDAudioPlayer.bundle"]]];
		[self.reflectionView removeFromSuperview];
		[self.overlayView removeFromSuperview];
		[self.containerView addSubview:songTableView];
		
		[[self.containerView layer] insertSublayer:gradientLayer atIndex:0];
	}
	
	[UIView commitAnimations];
}

- (void)showOverlayView
{	
	if (overlayView == nil) 
	{		
		self.overlayView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 66)];
		overlayView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.6];
		overlayView.opaque = NO;
		
		self.progressSlider = [[UISlider alloc] initWithFrame:CGRectMake(54, 12, self.view.bounds.size.width-108, 18)];
		[progressSlider setThumbImage:[UIImage imageWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"ScrubberKnob" ofType:@"png" inDirectory:@"MDAudioPlayer.bundle"]]
						   forState:UIControlStateNormal];
		[progressSlider setMinimumTrackImage:[[UIImage imageWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"VolumeBlueTrack" ofType:@"png" inDirectory:@"MDAudioPlayer.bundle"]] stretchableImageWithLeftCapWidth:5 topCapHeight:3] forState:UIControlStateNormal];
		[progressSlider setMaximumTrackImage:[[UIImage imageWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"VolumeWhiteTrack" ofType:@"png" inDirectory:@"MDAudioPlayer.bundle"]] stretchableImageWithLeftCapWidth:5 topCapHeight:3] forState:UIControlStateNormal];
		[progressSlider addTarget:self action:@selector(progressSliderMoved:) forControlEvents:UIControlEventValueChanged];
		progressSlider.maximumValue = player.duration;
		progressSlider.minimumValue = 0.0;	
        progressSlider.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		[overlayView addSubview:progressSlider];
		
		self.indexLabel = [[UILabel alloc] initWithFrame:CGRectMake((self.view.bounds.size.width/2)-32, 0, 64, 18)];
		indexLabel.font = [UIFont boldSystemFontOfSize:12];
		indexLabel.shadowOffset = CGSizeMake(0, -1);
		indexLabel.shadowColor = [UIColor blackColor];
		indexLabel.backgroundColor = [UIColor clearColor];
		indexLabel.textColor = [UIColor lightGrayColor];
		indexLabel.textAlignment = NSTextAlignmentCenter;
        indexLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
		[overlayView addSubview:indexLabel];
		
		self.duration = [[UILabel alloc] initWithFrame:CGRectMake(self.view.bounds.size.width-48, 15, 48, 18)];
		duration.font = [UIFont boldSystemFontOfSize:12];
		duration.shadowOffset = CGSizeMake(0, -1);
		duration.shadowColor = [UIColor blackColor];
		duration.backgroundColor = [UIColor clearColor];
		duration.textColor = [UIColor lightGrayColor];
        duration.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
		[overlayView addSubview:duration];
		
		self.currentTime = [[UILabel alloc] initWithFrame:CGRectMake(0, 15, 48, 18)];
		currentTime.font = [UIFont boldSystemFontOfSize:12];
		currentTime.shadowOffset = CGSizeMake(0, -1);
		currentTime.shadowColor = [UIColor blackColor];
		currentTime.backgroundColor = [UIColor clearColor];
		currentTime.textColor = [UIColor lightGrayColor];
		currentTime.textAlignment = NSTextAlignmentRight;
		[overlayView addSubview:currentTime];
		
		duration.adjustsFontSizeToFitWidth = YES;
		currentTime.adjustsFontSizeToFitWidth = YES;
		
		self.repeatButton = [[UIButton alloc] initWithFrame:CGRectMake(10, 34, 32, 28)];
		[repeatButton setImage:[UIImage imageWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"repeat_off" ofType:@"png" inDirectory:@"MDAudioPlayer.bundle"]] 
					  forState:UIControlStateNormal];
		[repeatButton addTarget:self action:@selector(toggleRepeat) forControlEvents:UIControlEventTouchUpInside];
		[overlayView addSubview:repeatButton];
		
		self.shuffleButton = [[UIButton alloc] initWithFrame:CGRectMake(self.view.bounds.size.width-40, 34, 32, 28)];
		[shuffleButton setImage:[UIImage imageWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"shuffle_off" ofType:@"png" inDirectory:@"MDAudioPlayer.bundle"]] 
					  forState:UIControlStateNormal];
		[shuffleButton addTarget:self action:@selector(toggleShuffle) forControlEvents:UIControlEventTouchUpInside];
        shuffleButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
		[overlayView addSubview:shuffleButton];
	}
	
	[self updateViewForPlayerInfo:player];
	[self updateViewForPlayerState:player];
	
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:0.4];
	[UIView setAnimationCurve:UIViewAnimationCurveEaseIn];
	
	if ([overlayView superview])
		[overlayView removeFromSuperview];
	else
		[containerView addSubview:overlayView];
	
	[UIView commitAnimations];
}

- (void)toggleShuffle
{
	if (shuffle)
	{
		shuffle = NO;
		[shuffleButton setImage:[UIImage imageWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"shuffle_off" ofType:@"png" inDirectory:@"MDAudioPlayer.bundle"]] forState:UIControlStateNormal];
	}
	else
	{
		shuffle = YES;
		[shuffleButton setImage:[UIImage imageWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"shuffle_on" ofType:@"png" inDirectory:@"MDAudioPlayer.bundle"]] forState:UIControlStateNormal];
	}
	
	[self updateViewForPlayerInfo:player];
	[self updateViewForPlayerState:player];
}

- (void)toggleRepeat
{
	if (repeatOne)
	{
		[repeatButton setImage:[UIImage imageWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"repeat_off" ofType:@"png" inDirectory:@"MDAudioPlayer.bundle"]] 
					  forState:UIControlStateNormal];
		repeatOne = NO;
		repeatAll = NO;
	}
	else if (repeatAll)
	{
		[repeatButton setImage:[UIImage imageWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"repeat_on_1" ofType:@"png" inDirectory:@"MDAudioPlayer.bundle"]]
					  forState:UIControlStateNormal];
		repeatOne = YES;
		repeatAll = NO;
	}
	else
	{
		[repeatButton setImage:[UIImage imageWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"repeat_on" ofType:@"png" inDirectory:@"MDAudioPlayer.bundle"]]
					  forState:UIControlStateNormal];
		repeatOne = NO;
		repeatAll = YES;
	}
	
	[self updateViewForPlayerInfo:player];
	[self updateViewForPlayerState:player];
}

- (BOOL)canGoToNextTrack
{
	if (selectedIndex + 1 == [self.soundFiles count]) 
		return NO;
	else
		return YES;
}

- (BOOL)canGoToPreviousTrack
{
	if (selectedIndex == 0)
		return NO;
	else
		return YES;
}

-(void)play
{
    
	if (self.player.playing == YES) 
	{
		[self.player pause];
	}
	else
	{
		if ([self.player play]) 
		{
			
		}
		else
		{
			NSLog(@"Could not play %@\n", self.player.url);
		}
	}
	
	
	[self updateViewForPlayerInfo:player];
	[self updateViewForPlayerState:player];
}

- (void)previous
{
	NSUInteger newIndex = selectedIndex - 1;
	[self setSelectedIndex:newIndex];
}

- (void)next
{
	NSUInteger newIndex;
	
	if (shuffle)
	{
		newIndex = rand() % [soundFiles count];
	}
	else if (repeatOne)
	{
		newIndex = selectedIndex;
	}
	else if (repeatAll)
	{
		if (selectedIndex + 1 == [self.soundFiles count])
			newIndex = 0;
		else
			newIndex = selectedIndex + 1;
	}
	else
	{
		newIndex = selectedIndex + 1;
	}
	
	[self setSelectedIndex:newIndex];
}

- (void)progressSliderMoved:(UISlider *)sender
{
	player.currentTime = sender.value;
	[self updateCurrentTimeForPlayer:player];
}


#pragma mark -
#pragma mark AVAudioPlayer delegate


- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)p successfully:(BOOL)flag
{
	if (flag == NO)
		NSLog(@"Playback finished unsuccessfully");
	
	if ([self canGoToNextTrack])
		 [self next];
	else if (interrupted)
		[self.player play];
	else
		[self.player stop];
		 
	[self updateViewForPlayerInfo:player];
	[self updateViewForPlayerState:player];
}

- (void)playerDecodeErrorDidOccur:(AVAudioPlayer *)p error:(NSError *)error
{
	NSLog(@"ERROR IN DECODE: %@\n", error);
	
	UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Decode Error" 
														message:[NSString stringWithFormat:@"Unable to decode audio file with error: %@", [error localizedDescription]] 
													   delegate:self 
											  cancelButtonTitle:@"OK" 
											  otherButtonTitles:nil];
	[alertView show];
	[alertView release];
}

- (void)audioPlayerBeginInterruption:(AVAudioPlayer *)player
{
	// perform any interruption handling here
	printf("(apbi) Interruption Detected\n");
	[[NSUserDefaults standardUserDefaults] setFloat:[self.player currentTime] forKey:@"Interruption"];
}

- (void)audioPlayerEndInterruption:(AVAudioPlayer *)player
{
	// resume playback at the end of the interruption
	printf("(apei) Interruption ended\n");
	[self.player play];
	
	// remove the interruption key. it won't be needed
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"Interruption"];
}

#pragma mark Table view methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)aTableView 
{
    return 1;
}

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)aTableView numberOfRowsInSection:(NSInteger)section 
{	
    return [soundFiles count];
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)aTableView cellForRowAtIndexPath:(NSIndexPath *)indexPath 
{    
    static NSString *CellIdentifier = @"Cell";
    
    MDAudioPlayerTableViewCell *cell = (MDAudioPlayerTableViewCell *)[aTableView dequeueReusableCellWithIdentifier:CellIdentifier];
	if (cell == nil)
	{
		cell = [[[MDAudioPlayerTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];//initWithFrame:CGRectZero reuseIdentifier:CellIdentifier] autorelease];
	}
	
	cell.title = [[soundFiles objectAtIndex:indexPath.row] title];
	cell.number = [NSString stringWithFormat:@"%d.", (indexPath.row + 1)];
	cell.duration = [[soundFiles objectAtIndex:indexPath.row] durationInMinutes];

	cell.isEven = indexPath.row % 2;
	
	if (selectedIndex == indexPath.row)
		cell.isSelectedIndex = YES;
	else
		cell.isSelectedIndex = NO;
	
	return cell;
}

- (void) setSelectedIndex:(NSUInteger)index {
    if ([soundFiles count]<=index)
        return;
    
    selectedIndex = index;
	
	for (MDAudioPlayerTableViewCell *cell in [songTableView visibleCells])
	{
		cell.isSelectedIndex = NO;
	}
	
	MDAudioPlayerTableViewCell *cell = (MDAudioPlayerTableViewCell *)[songTableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:index inSection:0]];
	cell.isSelectedIndex = YES;
	
	NSError *error = nil;
	AVAudioPlayer *newAudioPlayer =[[AVAudioPlayer alloc] initWithContentsOfURL:[(MDAudioFile *)[soundFiles objectAtIndex:selectedIndex] filePath] error:&error];
	
	if (error)
		NSLog(@"%@", error);
	
	[player stop];
	self.player = newAudioPlayer;
	[newAudioPlayer release];
	
	player.delegate = self;
	player.volume = 1.0;
	[player prepareToPlay];
	[player setNumberOfLoops:0];
	[player play];
	
	[self updateViewForPlayerInfo:player];
	[self updateViewForPlayerState:player];
}

- (void)tableView:(UITableView *)aTableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
	[aTableView deselectRowAtIndexPath:indexPath animated:YES];
	
	[self setSelectedIndex:indexPath.row];
}

- (BOOL)tableView:(UITableView *)table canEditRowAtIndexPath:(NSIndexPath *)indexPath 
{
	return NO;
}


- (CGFloat)tableView:(UITableView *)aTableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return 44;
}


#pragma mark - Image Reflection

CGImageRef CreateGradientImage(int pixelsWide, int pixelsHigh)
{
	CGImageRef theCGImage = NULL;
	
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceGray();
	
	CGContextRef gradientBitmapContext = CGBitmapContextCreate(NULL, pixelsWide, pixelsHigh,
															   8, 0, colorSpace, kCGImageAlphaNone);

	CGFloat colors[] = {0.0, 1.0, 1.0, 1.0};
	
	CGGradientRef grayScaleGradient = CGGradientCreateWithColorComponents(colorSpace, colors, NULL, 2);
	CGColorSpaceRelease(colorSpace);
	
	CGPoint gradientStartPoint = CGPointZero;
	CGPoint gradientEndPoint = CGPointMake(0, pixelsHigh);
	
	CGContextDrawLinearGradient(gradientBitmapContext, grayScaleGradient, gradientStartPoint,
								gradientEndPoint, kCGGradientDrawsAfterEndLocation);
	CGGradientRelease(grayScaleGradient);
	
	theCGImage = CGBitmapContextCreateImage(gradientBitmapContext);
	CGContextRelease(gradientBitmapContext);
	
    return theCGImage;
}

CGContextRef MyCreateBitmapContext(int pixelsWide, int pixelsHigh)
{
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	
	// create the bitmap context
	CGContextRef bitmapContext = CGBitmapContextCreate (NULL, pixelsWide, pixelsHigh, 8,
														0, colorSpace,
														// this will give us an optimal BGRA format for the device:
														(kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst));
	CGColorSpaceRelease(colorSpace);
	
    return bitmapContext;
}

- (UIImage *)reflectedImage:(UIImageView *)fromImage withHeight:(NSUInteger)height
{
    if (height == 0)
		return nil;
    
	// create a bitmap graphics context the size of the image
	CGContextRef mainViewContentContext = MyCreateBitmapContext(fromImage.bounds.size.width, height);
	
	CGImageRef gradientMaskImage = CreateGradientImage(1, height);
	
	CGContextClipToMask(mainViewContentContext, CGRectMake(0.0, 0.0, fromImage.bounds.size.width, height), gradientMaskImage);
	CGImageRelease(gradientMaskImage);

	CGContextTranslateCTM(mainViewContentContext, 0.0, height);
	CGContextScaleCTM(mainViewContentContext, 1.0, -1.0);
	
	CGContextDrawImage(mainViewContentContext, fromImage.bounds, fromImage.image.CGImage);
	
	CGImageRef reflectionImage = CGBitmapContextCreateImage(mainViewContentContext);
	CGContextRelease(mainViewContentContext);
	
	UIImage *theImage = [UIImage imageWithCGImage:reflectionImage];
	
	CGImageRelease(reflectionImage);
	
	return theImage;
}

- (void)viewDidUnload
{
	self.reflectionView = nil;
}

- (void)dealloc
{
	[soundFiles release], soundFiles = nil;
	[soundFilesPath release], soundFiles = nil;
	[player release], player = nil;
	[gradientLayer release], gradientLayer = nil;
	[playButton release], playButton = nil;
	[pauseButton release], pauseButton = nil;
	[nextButton release], nextButton = nil;
	[previousButton release], previousButton = nil;
	[toggleButton release], toggleButton = nil;
	[repeatButton release], repeatButton = nil;
	[shuffleButton release], shuffleButton = nil;
	[currentTime release], currentTime = nil;
	[duration release], duration = nil;
	[indexLabel release], indexLabel = nil;
	[titleView release], titleView = nil;
	[volumeSlider release], volumeSlider = nil;
	[progressSlider release], progressSlider = nil;
	[songTableView release], songTableView = nil;
	[artworkView release], artworkView = nil;
	[reflectionView release], reflectionView = nil;
	[containerView release], containerView = nil;
	[overlayView release], overlayView = nil;
	[updateTimer invalidate], updateTimer = nil;
    _sharedInstance = nil;
	[super dealloc];
}


@end
