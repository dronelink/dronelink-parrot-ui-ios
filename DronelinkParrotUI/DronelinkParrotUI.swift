//
//  DronelinkParrotUI.swift
//  DronelinkParrotUI
//
//  Created by Jim McAndrew on 11/21/19.
//  Copyright © 2019 Dronelink. All rights reserved.
//

import Foundation
import UIKit

extension DronelinkParrotUI {
    public static let shared = DronelinkParrotUI()
    internal static let bundle = Bundle.init(for: DronelinkParrotUI.self)
    internal static func loadImage(named: String, renderingMode: UIImage.RenderingMode = .alwaysTemplate) -> UIImage? {
        return UIImage(named: named, in: DronelinkParrotUI.bundle, compatibleWith: nil)?.withRenderingMode(renderingMode)
    }
}

public class DronelinkParrotUI: NSObject {
}
