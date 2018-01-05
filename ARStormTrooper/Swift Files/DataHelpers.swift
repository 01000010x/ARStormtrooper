//
//  DataHelpers.swift
//  ARStormTrooper
//
//  Created by Baptiste Leguey on 05/01/2018.
//  Copyright © 2018 Baptiste Leguey. All rights reserved.
//

import Foundation

enum ModelAnimations: String {
    case AgitatedIdle
    case BackFlip
    case BlockHit
    case Dancing
    case HeadButt
    case LeftTurn
    case NeutralIdle
    case Punched
    case Punched2
    case ReactFrontKick
    case RightTurn
    case Spin
    case StandingUp
    case StaticStormtrooper
    case ThumbUp

    static let allValues = [AgitatedIdle, BackFlip, BlockHit, Dancing, HeadButt, LeftTurn, NeutralIdle,
                            Punched, Punched2, ReactFrontKick, RightTurn, Spin, StandingUp, StaticStormtrooper, ThumbUp]
}

enum ModelAnimationGroups: String {
    case TapHead
    case TapHeadAgain
    case Backflip
}
