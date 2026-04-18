//
//  Item.swift
//  lingfeed
//
//  Created by Alexey Mashkov on 18.04.2026.
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
