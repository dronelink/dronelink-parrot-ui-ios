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

//FIXME
//extension ParrotDroneSessionManager: WidgetFactory {
//    public func createMainMenuWidget(current: Widget? = nil) -> Widget? { nil }
//
//    public func createCameraFeedWidget(current: Widget? = nil, primary: Bool = true) -> Widget? {
//        guard let session = session else {
//            return nil
//        }
//
//        return current is ParrotCameraFeedWidget ? current : ParrotCameraFeedWidget()
//    }
//
//    public func createStatusBackgroundWidget(current: Widget? = nil) -> Widget? {
//        GenericWidgetFactory.shared.createStatusBackgroundWidget(current: current)
//    }
//
//    public func createStatusForegroundWidget(current: Widget? = nil) -> Widget? {
//        GenericWidgetFactory.shared.createStatusForegroundWidget(current: current)
//    }
//
//    public func createRemainingFlightTimeWidget(current: Widget? = nil) -> Widget? { nil }
//
//    public func createFlightModeWidget(current: Widget? = nil) -> Widget? { nil}
//
//    public func createGPSWidget(current: Widget? = nil) -> Widget? { nil }
//
//    public func createVisionWidget(current: Widget? = nil) -> Widget? { nil }
//
//    public func createUplinkWidget(current: Widget? = nil) -> Widget? { nil }
//
//    public func createDownlinkWidget(current: Widget? = nil) -> Widget? { nil }
//
//    public func createBatteryWidget(current: Widget? = nil) -> Widget? { nil }
//
//    public func createDistanceUserWidget(current: Widget? = nil) -> Widget? { nil }
//
//    public func createDistanceHomeWidget(current: Widget? = nil) -> Widget? { nil }
//
//    public func createAltitudeWidget(current: Widget? = nil) -> Widget? { nil }
//
//    public func createHorizontalSpeedWidget(current: Widget? = nil) -> Widget? { nil }
//
//    public func createVerticalSpeedWidget(current: Widget? = nil) -> Widget? { nil }
//
//    public func createCameraGeneralSettingsWidget(current: Widget? = nil) -> Widget? { nil }
//
//    public func createCameraModeWidget(current: Widget? = nil) -> Widget? { nil }
//
//    public func createCameraCaptureWidget(current: Widget? = nil) -> Widget? { nil }
//
//    public func createCameraExposureSettingsWidget(current: Widget? = nil) -> Widget? { nil }
//
//    public func createCompassWidget(current: Widget?) -> Widget? { nil }
//}
