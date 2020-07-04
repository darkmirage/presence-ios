//
//  PoseMessage.swift
//  Presence
//
//  Created by Raven Jiang on 6/28/20.
//  Copyright © 2020 Apple. All rights reserved.
//

import Foundation
import HandyJSON

let behavior = NSDecimalNumberHandler(roundingMode: .plain, scale: 5, raiseOnExactness: false, raiseOnOverflow: false, raiseOnUnderflow: false, raiseOnDivideByZero: true)

struct PoseMessage: HandyJSON {
    var x: NSDecimalNumber
    var y: NSDecimalNumber
    var z: NSDecimalNumber
    var rx: NSDecimalNumber
    var ry: NSDecimalNumber
    var rz: NSDecimalNumber
    
    init() {
        fatalError("Not implemented")
    }
    
    init(x: Float, y: Float, z: Float, rx: Float, ry: Float, rz: Float) {
        self.x = NSDecimalNumber(value: x).rounding(accordingToBehavior: behavior)
        self.y = NSDecimalNumber(value: y).rounding(accordingToBehavior: behavior)
        self.z = NSDecimalNumber(value: z).rounding(accordingToBehavior: behavior)
        self.rx = NSDecimalNumber(value: rx).rounding(accordingToBehavior: behavior)
        self.ry = NSDecimalNumber(value: ry).rounding(accordingToBehavior: behavior)
        self.rz = NSDecimalNumber(value: rz).rounding(accordingToBehavior: behavior)
    }
}
