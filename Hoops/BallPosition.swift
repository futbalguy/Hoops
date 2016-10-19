//
//  BallPosition.swift
//  Hoops
//
//  Created by Kyle Rokita on 3/20/15.
//  Copyright (c) 2015 RokShop. All rights reserved.
//

import UIKit
import SceneKit

class BallPosition {

    var position : SCNVector3
    var date : Date
    
    init(position:SCNVector3) {
        
        self.position = position
        self.date = Date()
    }
}
