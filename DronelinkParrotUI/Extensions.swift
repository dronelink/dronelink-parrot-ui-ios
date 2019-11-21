//
//  Extensions.swift
//  DronelinkParrotUI
//
//  Created by Jim McAndrew on 11/21/19.
//  Copyright © 2019 Dronelink. All rights reserved.
//

import Foundation

import Foundation

extension String {
    internal static let LocalizationMissing = "MISSING STRING LOCALIZATION"
    
    var localized: String {
        let value = DronelinkParrotUI.bundle.localizedString(forKey: self, value: String.LocalizationMissing, table: nil)
        assert(value != String.LocalizationMissing, "String localization missing: \(self)")
        return value
    }
}
