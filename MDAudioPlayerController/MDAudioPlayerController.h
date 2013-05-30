//
//  AudioPlayer.h
//  MobileTheatre
//
//  Created by Matt Donnelly on 27/03/2010.
//  Copyright 2010 Apple Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <QuartzCore/QuartzCore.h>

@class MDAudioTitleView;
@class MPVolumeView;

@interface MDAudioPlayerController : UIViewController <AVAudioPlayerDelegate, UITableViewDelegate, UITableViewDataSource>
{
	NSMutableArray		*soundFiles;
	NSString			*soundFilesPath;
	NSUInteger			selectedIndex;
	
	AVAudioPlayer		*player;
	
	CAGradientLayer		*gradientLayer;
	
	UIButton			*playButton;
	UIButton			*pauseButton;
	UIButton			*nextButton;
	UIButton			*previousButton;
	UIButton			*toggleButton;
	UIButton			*repeatButton;
	UIButton			*shuffleButton;
	UILabel				*currentTime;
	UILabel				*duration;
	MDAudioTitleView    *titleView;
	UILabel				*indexLabel;
	MPVolumeView		*volumeSlider;
	UISlider			*progressSlider;
	
	UITableView			*songTableView;
	
	UIImageView         *artworkView;
	UIImageView			*reflectionView;
	UIView				*containerView;
	UIView				*overlayView;
	
	NSTimer				*updateTimer;
	
	BOOL				interrupted;
	BOOL				repeatAll;
	BOOL				repeatOne;
	BOOL				shuffle;
}

@property (nonatomic, retain) NSMutableArray *soundFiles;
@property (nonatomic, copy) NSString *soundFilesPath;

@property (nonatomic, retain) AVAudioPlayer *player;

@property (nonatomic, retain) CAGradientLayer *gradientLayer;

@property (nonatomic, retain) UIButton *playButton;
@property (nonatomic, retain) UIButton *pauseButton;
@property (nonatomic, retain) UIButton *nextButton;
@property (nonatomic, retain) UIButton *previousButton;
@property (nonatomic, retain) UIButton *toggleButton;
@property (nonatomic, retain) UIButton *repeatButton;
@property (nonatomic, retain) UIButton *shuffleButton;

@property (nonatomic, retain) UILabel *currentTime;
@property (nonatomic, retain) UILabel *duration;
@property (nonatomic, retain) UILabel *indexLabel;;
@property (nonatomic, retain) MDAudioTitleView *titleView;

@property (nonatomic, retain) MPVolumeView *volumeSlider;
@property (nonatomic, retain) UISlider *progressSlider;

@property (nonatomic, retain) UITableView *songTableView;

@property (nonatomic, retain) UIImageView *artworkView;
@property (nonatomic, retain) UIImageView *reflectionView;
@property (nonatomic, retain) UIView *containerView;
@property (nonatomic, retain) UIView *overlayView;

@property (nonatomic, retain) NSTimer *updateTimer;

@property (nonatomic, assign) BOOL interrupted;
@property (nonatomic, assign) BOOL repeatAll;
@property (nonatomic, assign) BOOL repeatOne;
@property (nonatomic, assign) BOOL shuffle;

+ (MDAudioPlayerController *)sharedInstance;
+ (BOOL) sharedInstanceExist;

- (MDAudioPlayerController *)initWithSoundFiles:(NSMutableArray *)songs atPath:(NSString *)path andSelectedIndex:(int)index;
- (void) setSoundFiles:(NSMutableArray *)songs atPath:(NSString *)path selectedIndex:(int)index;
- (void) setSelectedIndex:(NSUInteger)index;
- (void)dismissAudioPlayer;
- (void)showSongFiles;
- (void)showOverlayView;

- (BOOL)canGoToNextTrack;
- (BOOL)canGoToPreviousTrack;

- (void)play;
- (void)previous;
- (void)next;
- (void)progressSliderMoved:(UISlider*)sender;

- (void)toggleShuffle;
- (void)toggleRepeat;


- (void)updateViewForPlayerState:(AVAudioPlayer *)p;
-(void)updateViewForPlayerInfo:(AVAudioPlayer*)p;

@end

