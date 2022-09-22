//
//  DronelinkParrotUI.swift
//  DronelinkParrotUI
//
//  Created by Jim McAndrew on 11/21/19.
//  Copyright © 2019 Dronelink. All rights reserved.
//
import Foundation
import UIKit
import DronelinkCoreUI
import DronelinkParrot
import GroundSdk

extension DronelinkParrotUI {
    public static let shared = DronelinkParrotUI()
    internal static let bundle = Bundle.init(for: DronelinkParrotUI.self)
    internal static func loadImage(named: String, renderingMode: UIImage.RenderingMode = .alwaysTemplate) -> UIImage? {
        return UIImage(named: named, in: DronelinkParrotUI.bundle, compatibleWith: nil)?.withRenderingMode(renderingMode)
    }
}

public class DronelinkParrotUI: NSObject {
}

extension ParrotDroneSessionManager: WidgetFactoryProvider {
    public var widgetFactory: WidgetFactory? { ParrotWidgetFactory(session: session) }
}

open class ParrotWidgetFactory: WidgetFactory {
    open override func createVideoFeedWidget(channel: UInt? = nil, current: Widget? = nil, overlays: Bool = true) -> Widget? {
        if session == nil {
            return nil
        }

        return current is ParrotCameraFeedWidget ? current : ParrotCameraFeedWidget()
    }
}
