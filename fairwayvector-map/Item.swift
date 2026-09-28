//
//  Item.swift
//  fairwayvector-map
//
//  Created by Joel spolen on 2026-09-28.
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
