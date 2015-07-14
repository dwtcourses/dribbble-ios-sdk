//
//  ViewController.m
//  DribbbleSDKExample
//
//  Created by Dmitry Salnikov on 6/11/15.
//  Copyright (c) 2015 Agilie. All rights reserved.
//

#import "MainViewController.h"
#import "LoginViewController.h"
#import "DribbbleSDK.h"
#import <BlocksKit+UIKit.h>
#import "ApiCallFactory.h"
#import "ApiCallWrapper.h"
#import "TestApiViewController.h"
#import "AppDelegate.h"

typedef void(^UserUploadImageBlock)(NSURL *fileUrl, NSData *imageData);

// SDK setup constants

static NSString * const kIDMOAuth2ClientId = @"<YOUR CLIENT ID>";
static NSString * const kIDMOAuth2ClientSecret = @"<YOUR CLIENT SECRET>";
static NSString * const kIDMOAuth2ClientAccessToken = @"<YOUR ACCESS TOKEN>";

static NSString * const kIDMOAuth2RedirectURL = @"<YOUR APP REDIRECT URL>";
static NSString * const kIDMOAuth2AuthorizationURL = @"https://dribbble.com/oauth/authorize";
static NSString * const kIDMOAuth2TokenURL = @"https://dribbble.com/oauth/token";

static NSString * const kBaseApiUrl = @"https://api.dribbble.com/v1/";

// ---

static NSString * kCellIdentifier = @"cellIdentifier";
static NSString * kSegueIdentifierAuthorize = @"authorizeSegue";
static NSString * kSegueIdentifierTestApi = @"testApiSegue";

@interface MainViewController () <UITableViewDelegate, UITableViewDataSource>

@property (strong, nonatomic) DRApiClient *apiClient;
@property (strong, nonatomic) AppDelegate *delegate;
@property (strong, nonatomic) NSArray *apiCallWrappers;

@property (copy, nonatomic) UserUploadImageBlock userUploadImageBlock;
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet UIButton *signInButton;
@property (weak, nonatomic) IBOutlet UIButton *signOutButton;

@end

@implementation MainViewController

#pragma mark - View LifeCycle

- (void)viewDidLoad {
    [super viewDidLoad];
    self.delegate = [AppDelegate delegate];
    [self setupApiClient];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    self.signOutButton.hidden = ![self.apiClient isUserAuthorized];
    self.signInButton.hidden = [self.apiClient isUserAuthorized];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:kSegueIdentifierAuthorize]) {
        LoginViewController *loginViewController = (LoginViewController *)segue.destinationViewController;
        loginViewController.apiClient = self.apiClient;
        loginViewController.authCompletionHandler = ^(BOOL success) {
            NSLog(@"Signed in successfully? %d", success);
            [self loadMockData];
        };
    } else if ([segue.identifier isEqualToString:kSegueIdentifierTestApi]) {
        TestApiViewController *testApiController = (TestApiViewController *)segue.destinationViewController;
        testApiController.apiCallWrapper = sender;
        testApiController.apiClient = self.apiClient;
    }
}

#pragma mark - Internal

- (void)setupApiClient {
    DRApiClientSettings *settings = [[DRApiClientSettings alloc] initWithBaseUrl:kBaseApiUrl
                                                               oAuth2RedirectUrl:kIDMOAuth2RedirectURL
                                                          oAuth2AuthorizationUrl:kIDMOAuth2AuthorizationURL
                                                                  oAuth2TokenUrl:kIDMOAuth2TokenURL
                                                                        clientId:kIDMOAuth2ClientId
                                                                    clientSecret:kIDMOAuth2ClientSecret
                                                               clientAccessToken:kIDMOAuth2ClientAccessToken
                                                                          scopes:[NSSet setWithObjects:kDRPublicScope, kDRWriteScope, kDRUploadScope, kDRCommentScope, nil]];
    self.apiClient = [[DRApiClient alloc] initWithSettings:settings];
    __weak typeof(self) weakSelf = self;
    self.apiClient.defaultErrorHandler = ^ (NSError *error) {
        if (error.domain == NSURLErrorDomain && ![weakSelf.apiClient isUserAuthorized]) {
            [weakSelf performSegueWithIdentifier:kSegueIdentifierAuthorize sender:nil];
        } else {
            if (error.code != 404) {
                [UIAlertView bk_showAlertViewWithTitle:@"Error" message:[error localizedDescription] cancelButtonTitle:@"OK" otherButtonTitles:nil handler:nil];
            }
        }
    };
    
    
    if (!self.delegate.user) {
        [self loadMockData];
    }
    
    self.apiCallWrappers = [ApiCallFactory demoApiCallWrappers];
    [self.tableView reloadData];
}

- (void)loadMockData {
    [self.apiClient loadUserInfoWithResponseHandler:^(DRApiResponse *response) {
        if (response.object) {
            self.delegate.user = response.object;
        }
        
        [self.apiClient loadShotsWithUser:self.delegate.user.userId params:@{} responseHandler:^(DRApiResponse *response) {
            if (response.object) {
                if ([response.object isKindOfClass:[NSArray class]]) {
                    if ([response.object count]) {
                        DRShot *shot = [response.object firstObject];
                        if(shot) {
                            self.delegate.shot = shot;
                            [self.apiClient loadCommentsWithShot:shot.shotId params:@{} responseHandler:^(DRApiResponse *response) {
                                if (response.object) {
                                    for (DRComment *comment in response.object) {
                                        if (([comment.body isEqualToString:@"<p>API test updated comment</p>"] || [comment.body isEqualToString:@"<p>API test comment</p>"]) &&
                                            comment.user.userId == self.delegate.user.userId) {
                                            self.delegate.comment = comment;
                                            self.apiCallWrappers = [ApiCallFactory demoApiCallWrappers];
                                            [self.tableView reloadData];
                                        }
                                    }
                                    [self.apiClient loadAttachmentsWithShot:shot.shotId params:@{} responseHandler:^(DRApiResponse *response) {
                                        if (response.object && [response.object isKindOfClass:[NSArray class]]) {
                                            DRShotAttachment *attachment = [response.object lastObject];
                                            self.delegate.attachment = attachment;
                                            self.apiCallWrappers = [ApiCallFactory demoApiCallWrappers];
                                            [self.tableView reloadData];
                                        }
                                    }];
                                }
                            }];
                        }
                    }
                }
            }
        }];
        
        self.apiCallWrappers = [ApiCallFactory demoApiCallWrappers];
        [self.tableView reloadData];
    }];
}

#pragma mark - IBActions

- (IBAction)pressSignOut:(id)sender {
    [self.apiClient logout];
    self.delegate.user = nil;
    self.delegate.shot = nil;
    self.delegate.comment = nil;
    self.delegate.attachment = nil;
    self.signOutButton.hidden = ![self.apiClient isUserAuthorized];
    self.signInButton.hidden = [self.apiClient isUserAuthorized];
}

#pragma mark - Table View Delegate + Data Source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.apiCallWrappers count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kCellIdentifier];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    
    ApiCallWrapper *wrapper = self.apiCallWrappers[indexPath.row];
    cell.textLabel.text = wrapper.title;
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    ApiCallWrapper *wrapper = self.apiCallWrappers[indexPath.row];
    [self performSegueWithIdentifier:kSegueIdentifierTestApi sender:wrapper];
}

@end
