//
//  MDAudioTitleView.m
//  MDAudioPlayerSample
//
//  Created by Mathieu Bolard on 30/05/13.
//
//

#import "MDAudioTitleView.h"

@implementation MDAudioTitleView
@synthesize titleLabel;
@synthesize artistLabel;
@synthesize albumLabel;

- (id)initWithNavigationItem:(UINavigationItem *)navItem
{
    CGFloat width = navItem.titleView.frame.size.width;
    self = [super initWithFrame:CGRectMake(0.0, 0.0, width, 44)];
    //self = [super initWithFrame:CGRectMake(0.0, 0.0, width, 60)];
    if (self) {
        // Initialization code
        self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(60, 15, width-125, 12)];
        titleLabel.font = [UIFont boldSystemFontOfSize:12];
        titleLabel.backgroundColor = [UIColor clearColor];
        titleLabel.textColor = [UIColor whiteColor];
        titleLabel.shadowColor = [UIColor blackColor];
        titleLabel.shadowOffset = CGSizeMake(0, -1);
        titleLabel.textAlignment = NSTextAlignmentCenter;
        titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [self addSubview:titleLabel];
        
        self.artistLabel = [[UILabel alloc] initWithFrame:CGRectMake(60, 3, width-125, 12)];
        artistLabel.font = [UIFont boldSystemFontOfSize:12];
        artistLabel.backgroundColor = [UIColor clearColor];
        artistLabel.textColor = [UIColor lightGrayColor];
        artistLabel.shadowColor = [UIColor blackColor];
        artistLabel.shadowOffset = CGSizeMake(0, -1);
        artistLabel.textAlignment = NSTextAlignmentCenter;
        artistLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        artistLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [self addSubview:artistLabel];
        
        self.albumLabel = [[UILabel alloc] initWithFrame:CGRectMake(60, 28, width-125, 12)];
        albumLabel.backgroundColor = [UIColor clearColor];
        albumLabel.font = [UIFont boldSystemFontOfSize:12];
        albumLabel.textColor = [UIColor lightGrayColor];
        albumLabel.shadowColor = [UIColor blackColor];
        albumLabel.shadowOffset = CGSizeMake(0, -1);
        albumLabel.textAlignment = NSTextAlignmentCenter;
        albumLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        albumLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [self addSubview:albumLabel];
    }
    return self;
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    // Drawing code
}
*/

@end
