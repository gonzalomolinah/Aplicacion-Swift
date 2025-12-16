//
//  Item.swift
//  MochilaAlarma
//
//  Created by Gonzalo on 15-12-25.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
