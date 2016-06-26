//
//  CollisionCategory.swift
//  Hoops
//
//  Created by Kyle Rokita on 3/23/15.
//  Copyright (c) 2015 RokShop. All rights reserved.
//

import UIKit


struct Collisions : OptionSetType, BooleanType {
    private var value: Int
    init(_ rawValue: Int) { self.value = rawValue }
    
    // MARK: _RawOptionSetType
    init(rawValue: Int) { self.value = rawValue }
    
    // MARK: NilLiteralConvertible
    init(nilLiteral: ()) { self.value = 0}
    
    // MARK: RawRepresentable
    var rawValue: Int { return self.value }
    
    // MARK: BooleanType
    var boolValue: Bool { return self.value != 0 }
    
    // MARK: BitwiseOperationsType
    static var allZeros: Collisions { return self.init(0) }
    
    // MARK: User defined bit values
    static var None: Collisions          { return self.init(0) }
    static var Ball: Collisions   { return self.init(1 << 0) }
    static var HoopNet: Collisions  { return self.init(1 << 1) }
    static var HoopNetSpace: Collisions  { return self.init(1 << 9) }

    static var Backboard: Collisions   { return self.init(1 << 2) }
    
    static var Wall: Collisions   { return self.init(1 << 3) }
    static var FrontWall: Collisions   { return self.init(1 << 7) }

    static var Floor: Collisions   { return self.init(1 << 4) }
    static var Rim: Collisions   { return self.init(1 << 5) }
    static var RimPlane: Collisions   { return self.init(1 << 8) }

    static var Pole: Collisions   { return self.init(1 << 6) }

    static var All: Collisions           { return self.init(0b111) }
}

extension Bool {
    init(bitComponents : [BooleanType]) {
        self = bitComponents.reduce(false, combine: {$0.boolValue && $1.boolValue})
    }
}