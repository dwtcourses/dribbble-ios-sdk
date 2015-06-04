//
//  DREnums.h
//  DribbbleRunner
//
//  Created by Vladimir Zgonik on 19.03.15.
//  Copyright (c) 2015 Agilie. All rights reserved.
//

#ifndef DribbbleRunner_DREnums_h
#define DribbbleRunner_DREnums_h

typedef NS_ENUM(NSUInteger, DRShotCategoryType) {
    DRShotCategoryFeaturedShots,
    DRShotCategoryPopular,
    DRShotCategoryRecent,
    DRShotCategoryTeams,
    DRShotCategoryDebuts,
    DRShotCategoryPlayoffs,
    DRShotCategoryGifs
};

typedef NS_ENUM(NSInteger, DRPanDirection) {
    DRPanDirectionNone,
    DrPanDirectionUp,
    DRPanDirectionDown,
    DRPanDirectionLeft,
    DRPanDirectionRight
};

#endif
