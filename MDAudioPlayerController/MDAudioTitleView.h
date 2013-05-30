//
//  MDAudioTitleView.h
//  MDAudioPlayerSample
//
//  Created by Mathieu Bolard on 30/05/13.
//
//

#import <UIKit/UIKit.h>

@interface MDAudioTitleView : UIView {
    UILabel				*titleLabel;
	UILabel				*artistLabel;
	UILabel				*albumLabel;
}

@property (nonatomic, retain) UILabel *titleLabel;
@property (nonatomic, retain) UILabel *artistLabel;
@property (nonatomic, retain) UILabel *albumLabel;

- (id)initWithNavigationItem:(UINavigationItem *)navItem;

@end
