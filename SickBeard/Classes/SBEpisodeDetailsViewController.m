//
//  SBEpisodeDetailsViewController.m
//  SickBeard
//
//  Created by Colin Humber on 9/1/11.
//  Copyright (c) 2011 Colin Humber. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "SBEpisodeDetailsViewController.h"
#import "SBEpisode.h"
#import "SBShow.h"
#import "SickbeardAPIClient.h"
#import "PRPAlertView.h"
#import "NSDate+Utilities.h"
#import "SBEpisodeDetailsHeaderView.h"
#import "SBSectionHeaderView.h"
#import "SBCellBackground.h"

#define kDefaultDescriptionFontSize 13;
#define kDefaultDescriptionFrame CGRectMake(20, 9, 280, 162)

@interface SBEpisodeDetailsViewController () <UIActionSheetDelegate> {
	BOOL _isTransitioning;
}

- (IBAction)swipeLeft:(id)sender;
- (IBAction)swipeRight:(id)sender;
- (void)updateHeaderView;

@property (nonatomic, strong) IBOutlet SBEpisodeDetailsHeaderView *currentHeaderView;
@property (nonatomic, strong) IBOutlet SBEpisodeDetailsHeaderView *nextHeaderView;
@property (nonatomic, strong) IBOutlet SBCellBackground *headerContainerView;
@property (nonatomic, strong) IBOutlet UIView *containerView;

@property (nonatomic, strong) IBOutlet UITextView *descriptionTextView;
@property (nonatomic, strong) IBOutlet NINetworkImageView *showPosterImageView;
@property (nonatomic, strong) IBOutlet UIActivityIndicatorView *spinner;
@property (nonatomic, strong) IBOutlet SBSectionHeaderView *headerView;
@property (nonatomic, strong) IBOutlet SBCellBackground *episodeDescriptionBackground;

@end

@implementation SBEpisodeDetailsViewController

#pragma mark - View lifecycle
// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
	[TestFlight passCheckpoint:@"Viewed episode details"];
	
	self.title = NSLocalizedString(@"Details", @"Details");

	[self.showPosterImageView setPathToNetworkImage:[[self.apiClient bannerURLForTVDBID:self.episode.show.tvdbID] absoluteString]];

	self.headerView.sectionLabel.text = NSLocalizedString(@"Episode Summary", @"Episode Summary");
	self.episodeDescriptionBackground.grouped = YES;
	
	[self updateHeaderView];
	[self loadData];
	
	if ([UIScreen mainScreen].bounds.size.height == 568) {
		self.episodeDescriptionBackground.height += 88;
		self.descriptionTextView.height += 88;
	}
	
    [super viewDidLoad];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark - Loading
- (void)updateHeaderView {	
	self.currentHeaderView.titleLabel.text = self.episode.name;
	self.currentHeaderView.seasonLabel.text = [NSString stringWithFormat:NSLocalizedString(@"Season %d, episode %d", @"Season %d, episode %d"), self.episode.season, self.episode.number];
		
	if (self.episode.airDate) {
		if ([self.episode.airDate isToday]) {
			self.currentHeaderView.airDateLabel.text = NSLocalizedString(@"Airing today", @"Airing today");
		}
		else if ([self.episode.airDate isLaterThanDate:[NSDate date]]) {
			self.currentHeaderView.airDateLabel.text = [NSString stringWithFormat:NSLocalizedString(@"Airing on %@", @"Airing on %@"), [self.episode.airDate displayString]];
		}
		else {
			self.currentHeaderView.airDateLabel.text = [NSString stringWithFormat:NSLocalizedString(@"Aired on %@", @"Aired on %@"), [self.episode.airDate displayString]];
		}												  
	}
	else {
		self.currentHeaderView.airDateLabel.text = NSLocalizedString(@"Unknown air date", @"Unknown air date");
	}
}

- (void)loadData {
	[UIView animateWithDuration:0.3 
					 animations:^{
						 self.descriptionTextView.alpha = 0;
					 }];
	
	NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
							self.episode.show.tvdbID, @"tvdbid",
							[NSNumber numberWithInt:self.episode.season], @"season",
							[NSNumber numberWithInt:self.episode.number], @"episode", nil];

	[self.spinner startAnimating];
	
	[self.apiClient runCommand:SickBeardCommandEpisode
									   parameters:params
										  success:^(AFHTTPRequestOperation *operation, id JSON) {
											  NSString *result = [JSON objectForKey:@"result"];
											  
											  if ([result isEqualToString:RESULT_SUCCESS]) {
												  self.episode.episodeDescription = [[JSON objectForKey:@"data"] objectForKey:@"description"];												  
											  }
											  else {
												  self.episode.episodeDescription = NSLocalizedString(@"Unable to retrieve episode description", @"Unable to retrieve episode description");
											  }
											  
											  [self.descriptionTextView flashScrollIndicators];
											  
											  self.descriptionTextView.text = self.episode.episodeDescription;

											  [UIView animateWithDuration:0.3
															   animations:^{
																   self.descriptionTextView.alpha = 1;
															   }];
											  
											  [self.spinner stopAnimating];
										  }
										  failure:^(AFHTTPRequestOperation *operation, NSError *error) {
											  [self.spinner stopAnimating];
											  [PRPAlertView showWithTitle:NSLocalizedString(@"Error retrieving episode", @"Error retrieving episode") 
																  message:[NSString stringWithFormat:NSLocalizedString(@"Could not retrieve episode details \n%@", @"Could not retrieve episode details \n%@"), error.localizedDescription] 
															  buttonTitle:NSLocalizedString(@"OK", @"OK")];											  
										  }];
}

#pragma mark - Gestures
- (void)transitionToEpisodeFromDirection:(NSString*)direction {
	_isTransitioning = YES;
		
	CATransition *transition = [CATransition animation];
	transition.duration = 0.2;
	transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
	transition.type = kCATransitionPush;
	transition.subtype = direction;
	transition.delegate = self;
	
	[self.containerView.layer addAnimation:transition forKey:nil];
	self.currentHeaderView.hidden = YES;
	self.nextHeaderView.hidden = NO;
	
	id tmp = self.nextHeaderView;
	self.nextHeaderView = self.currentHeaderView;
	self.currentHeaderView = tmp;	
}

- (IBAction)swipeLeft:(id)sender {
	if (self.dataSource) {
		SBBaseEpisode *nextEpisode = [self.dataSource nextEpisode];

		if (!_isTransitioning && nextEpisode) {
			self.episode = nextEpisode;
			[self loadData];
			[self transitionToEpisodeFromDirection:kCATransitionFromRight];
			[self updateHeaderView];
		}
	}
}

- (IBAction)swipeRight:(id)sender {
	if (self.dataSource) {
		SBBaseEpisode *previousEpisode = [self.dataSource previousEpisode];

		if (!_isTransitioning && previousEpisode) {
			self.episode = previousEpisode;
			[self loadData];
			[self transitionToEpisodeFromDirection:kCATransitionFromLeft];
			[self updateHeaderView];
		}
	}
}

- (void)animationDidStop:(CAAnimation*)theAnimation finished:(BOOL)flag {
    _isTransitioning = NO;
}

#pragma mark - Actions
- (IBAction)episodeAction:(id)sender {
	UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:@"" 
															 delegate:self 
													cancelButtonTitle:NSLocalizedString(@"Cancel", @"Cancel") 
											   destructiveButtonTitle:nil 
													 otherButtonTitles:NSLocalizedString(@"Search", @"Search"), NSLocalizedString(@"Set Status", @"Set Status"), nil];
	actionSheet.tag = 998;
	[actionSheet showInView:self.view];
}

- (void)searchForEpisode {
	NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
							self.episode.show.tvdbID, @"tvdbid", 
							[NSNumber numberWithInt:self.episode.season], @"season",
							[NSNumber numberWithInt:self.episode.number], @"episode", nil];

	[[SBNotificationManager sharedManager] queueNotificationWithText:NSLocalizedString(@"Searching for episode", @"Searching for episode")
																type:SBNotificationTypeInfo];

	[self.apiClient runCommand:SickBeardCommandEpisodeSearch
									   parameters:params 
										  success:^(AFHTTPRequestOperation *operation, id JSON) {
											  NSString *result = [JSON objectForKey:@"result"];
											  
											  if ([result isEqualToString:RESULT_SUCCESS]) {
												  [[SBNotificationManager sharedManager] queueNotificationWithText:NSLocalizedString(@"Episode found and is downloading", @"Episode found and is downloading")
																											  type:SBNotificationTypeSuccess];
											  }
											  else {
												  [[SBNotificationManager sharedManager] queueNotificationWithText:JSON[@"message"]
																											  type:SBNotificationTypeSuccess];
											  }
										  }
										  failure:^(AFHTTPRequestOperation *operation, NSError *error) {
											  [PRPAlertView showWithTitle:NSLocalizedString(@"Error retrieving shows", @"Error retrieving shows") 
																  message:[NSString stringWithFormat:@"Could not retrieve shows \n%@", error.localizedDescription] 
															  buttonTitle:NSLocalizedString(@"OK", @"OK")];
										  }];
}

- (void)showEpisodeStatusActionSheet {
	UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:@"" 
															  delegate:self 
													 cancelButtonTitle:NSLocalizedString(@"Cancel", @"Cancel") 
												destructiveButtonTitle:nil 
													 otherButtonTitles:
															[SBEpisode episodeStatusAsString:EpisodeStatusWanted], 
															[SBEpisode episodeStatusAsString:EpisodeStatusSkipped], 
															[SBEpisode episodeStatusAsString:EpisodeStatusArchived], 
															[SBEpisode episodeStatusAsString:EpisodeStatusIgnored], nil];
	actionSheet.tag = 999;
	[actionSheet showInView:self.view];
}

- (void)performSetEpisodeStatus:(EpisodeStatus)status {
	NSString *statusString = [[SBEpisode episodeStatusAsString:status] lowercaseString];
	
	NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
							self.episode.show.tvdbID, @"tvdbid", 
							[NSNumber numberWithInt:self.episode.season], @"season",
							[NSNumber numberWithInt:self.episode.number], @"episode",
							statusString, @"status", nil];
	
	[[SBNotificationManager sharedManager] queueNotificationWithText:[NSString stringWithFormat:NSLocalizedString(@"Setting episode status to %@", @"Setting episode status to %@"), statusString]
																type:SBNotificationTypeInfo];
	
	[self.apiClient runCommand:SickBeardCommandEpisodeSetStatus
									   parameters:params 
										  success:^(AFHTTPRequestOperation *operation, id JSON) {
											  NSString *result = [JSON objectForKey:@"result"];
											  
											  if ([result isEqualToString:RESULT_SUCCESS]) {
												  [[SBNotificationManager sharedManager] queueNotificationWithText:NSLocalizedString(@"Status successfully set!", @"Status successfully set!")
																											  type:SBNotificationTypeSuccess];
											  }
											  else {
												  [[SBNotificationManager sharedManager] queueNotificationWithText:JSON[@"message"]
																											  type:SBNotificationTypeError];
											  }
										  }
										  failure:^(AFHTTPRequestOperation *operation, NSError *error) {
											  [PRPAlertView showWithTitle:NSLocalizedString(@"Error setting status", @"Error setting status") 
																  message:error.localizedDescription 
															  buttonTitle:NSLocalizedString(@"OK", @"OK")];	
										  }];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
	if (actionSheet.tag == 998) {
		if (buttonIndex == 0) {
			[TestFlight passCheckpoint:@"Searched for episode"];
			[self searchForEpisode];
		}
		else if (buttonIndex == 1) {
			[self showEpisodeStatusActionSheet];
		}
	}
	else {
		if (buttonIndex < 4) {
			[TestFlight passCheckpoint:@"Set episode status"];
			[self performSetEpisodeStatus:buttonIndex];
		}
	}
}	

@end
