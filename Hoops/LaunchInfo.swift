//
//  LaunchInfo.swift
//  Hoops
//
//  Created by Kyle Rokita on 3/24/15.
//  Copyright (c) 2015 RokShop. All rights reserved.
//

import UIKit
import SceneKit

class LaunchInfo {
    
    var position : SCNVector3!
    var date : NSDate!
    var initialVelocity : SCNVector3!
    
    init(position:SCNVector3, initialVelocity:SCNVector3) {
        
        self.position = position
        self.date = NSDate()
        self.initialVelocity = initialVelocity
        
    }
}