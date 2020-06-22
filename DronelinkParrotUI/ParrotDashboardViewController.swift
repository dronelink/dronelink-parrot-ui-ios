//
//  ParrotDashboardViewController.swift
//  DronelinkParrotUI
//
//  Created by Jim McAndrew on 11/21/19.
//  Copyright © 2019 Dronelink. All rights reserved.
//

import Foundation
import UIKit
import DronelinkCore
import DronelinkCoreUI
import DronelinkParrot
import GroundSdk
import MaterialComponents.MaterialPalettes
import MaterialComponents.MaterialProgressView

open class ParrotDashboardViewController: UIViewController {
    public static func create(droneSessionManager: DroneSessionManager, mapCredentialsKey: String) -> ParrotDashboardViewController {
        let dashboardViewController = ParrotDashboardViewController()
        dashboardViewController.mapCredentialsKey = mapCredentialsKey
        dashboardViewController.modalPresentationStyle = .fullScreen
        dashboardViewController.droneSessionManager = droneSessionManager
        return dashboardViewController
    }
    
    private var droneSessionManager: DroneSessionManager!
    public var session: DroneSession?
    private var missionExecutor: MissionExecutor?
    private var funcExecutor: FuncExecutor?
    private var mapViewController: UIViewController!
    private var mapCredentialsKey = ""
    private let primaryViewToggleButton = UIButton(type: .custom)
    private let mapMoreButton = UIButton(type: .custom)
    private let dismissButton = UIButton(type: .custom)
    private let statusLabel = UILabel()
    private let statusGradient = CAGradientLayer()
    private var videoPreviewerView = StreamView(frame: CGRect.zero)
    private let reticalImageView = UIImageView()
    private let topBarBackgroundView = UIView()
    private let batteryProgressView = MDCProgressView()
    
    private var instrumentsViewController: InstrumentsViewController?
    private var telemetryViewController: TelemetryViewController?
    private var missionViewController: MissionViewController?
    private var missionExpanded: Bool { missionViewController?.expanded ?? false }
    private var funcViewController: FuncViewController?
    private var funcExpanded = false
    private var primaryViewToggled = false
    private var videoPreviewerPrimary = true
    private let defaultPadding = 10
    private var primaryView: UIView { return videoPreviewerPrimary || portrait ? videoPreviewerView : mapViewController.view }
    private var secondaryView: UIView { return primaryView == videoPreviewerView ? mapViewController.view : videoPreviewerView }
    private var portrait: Bool { return UIScreen.main.bounds.width < UIScreen.main.bounds.height }
    private var tablet: Bool { return UIDevice.current.userInterfaceIdiom == .pad }
    private var statusWidgetHeight: CGFloat { return tablet ? 50 : 40 }
    
    private let updateInterval: TimeInterval = 1.0
    private var updateTimer: Timer?
    
    private var streamServerRef: Ref<StreamServer>?
    private var liveStreamRef: Ref<CameraLive>?
    
    private var virtualSticks = false
    private var controlSession: DroneControlSession?
    private var takeoffLandButton = UIButton()
    private let joystickLeftView = UIView()
    private let joystickRightView = UIView()
    
    private var joystickLeftActive = false
    private var joystickRightActive = false
    private var vertical = 0.0
    private var yaw = 0.0
    private var pitch = 0.0
    private var roll = 0.0
    
    private let batteryProgressLowColor = MDCPalette.red.accent400
    private let batteryProgressMediumColor = MDCPalette.amber.accent400
    private let batteryProgressHightColor = MDCPalette.green.accent400
    
    public override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        if #available(iOS 13.0, *) {
            overrideUserInterfaceStyle = .dark
        }
        
        videoPreviewerPrimary = droneSessionManager.session != nil
        
        view.backgroundColor = UIColor.black
        
        videoPreviewerView.addShadow()
        videoPreviewerView.backgroundColor = UIColor(displayP3Red: 35/255, green: 35/255, blue: 35/255, alpha: 1)
        view.addSubview(videoPreviewerView)
        
        reticalImageView.isUserInteractionEnabled = false
        reticalImageView.contentMode = .scaleAspectFit
        view.addSubview(reticalImageView)
        
        topBarBackgroundView.backgroundColor = DronelinkUI.Constants.overlayColor
        view.addSubview(topBarBackgroundView)
        
        statusGradient.colors = [DronelinkUI.Constants.overlayColor.cgColor]
        statusGradient.startPoint = CGPoint(x: 0, y: 0)
        statusGradient.endPoint = CGPoint(x: 1, y: 0)
        topBarBackgroundView.layer.insertSublayer(statusGradient, at: 0)
        
        batteryProgressView.trackTintColor = UIColor.white.withAlphaComponent(0.15)
        view.addSubview(batteryProgressView)
        
        dismissButton.tintColor = UIColor.white
        dismissButton.setImage(DronelinkParrotUI.loadImage(named: "dronelink-logo"), for: .normal)
        dismissButton.imageView?.contentMode = .scaleAspectFit
        dismissButton.imageEdgeInsets = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        dismissButton.addTarget(self, action: #selector(onDismiss(sender:)), for: .touchUpInside)
        view.addSubview(dismissButton)
        
        if Device.legacy {
            updateMapMapbox()
        }
        else {
            updateMapMicrosoft()
        }
        
        statusLabel.textColor = UIColor.white
        statusLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        view.addSubview(statusLabel)
        statusLabel.snp.makeConstraints { make in
            make.top.equalTo(dismissButton)
            make.bottom.equalTo(dismissButton)
            make.left.equalTo(dismissButton.snp.right).offset(5)
            make.right.equalToSuperview().offset(-5)
        }
        
        let instrumentsViewController = InstrumentsViewController.create(droneSessionManager: self.droneSessionManager)
        addChild(instrumentsViewController)
        view.addSubview(instrumentsViewController.view)
        instrumentsViewController.didMove(toParent: self)
        self.instrumentsViewController = instrumentsViewController
        
        primaryViewToggleButton.tintColor = UIColor.white
        primaryViewToggleButton.setImage(DronelinkParrotUI.loadImage(named: "vector-arrange-below"), for: .normal)
        primaryViewToggleButton.addTarget(self, action: #selector(onPrimaryViewToggle(sender:)), for: .touchUpInside)
        view.addSubview(primaryViewToggleButton)
        
        mapMoreButton.tintColor = UIColor.white
        mapMoreButton.setImage(DronelinkParrotUI.loadImage(named: "outline_layers_white_36pt"), for: .normal)
        mapMoreButton.addTarget(self, action: #selector(onMapMore(sender:)), for: .touchUpInside)
        view.addSubview(mapMoreButton)
        
        let telemetryViewController = TelemetryViewController.create(droneSessionManager: self.droneSessionManager)
        addChild(telemetryViewController)
        view.addSubview(telemetryViewController.view)
        telemetryViewController.didMove(toParent: self)
        self.telemetryViewController = telemetryViewController
        
        if virtualSticks {
            joystickLeftView.addShadow()
            joystickLeftView.backgroundColor = DronelinkUI.Constants.overlayColor
            view.addSubview(joystickLeftView)
            joystickLeftView.snp.makeConstraints { make in
                make.width.equalTo(200)
                make.height.equalTo(200)
                make.top.equalToSuperview().offset(50)
                make.left.equalToSuperview().offset(50)
            }
            
            joystickLeftView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(onJoystickLeftTapGesture(recognizer:))))
            joystickLeftView.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(onJoystickLeftPanGesture(recognizer:))))
            
            joystickRightView.addShadow()
            joystickRightView.backgroundColor = DronelinkUI.Constants.overlayColor
            view.addSubview(joystickRightView)
            joystickRightView.snp.makeConstraints { make in
                make.width.equalTo(200)
                make.height.equalTo(200)
                make.top.equalToSuperview().offset(50)
                make.right.equalToSuperview().offset(-50)
            }
            
            joystickRightView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(onJoystickRightTapGesture(recognizer:))))
            joystickRightView.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(onJoystickRightPanGesture(recognizer:))))

            
            takeoffLandButton.setTitle("Takeoff", for: .normal)
            takeoffLandButton.addTarget(self, action: #selector(onTakeoffLand(sender:)), for: .touchUpInside)
            view.addSubview(takeoffLandButton)
            takeoffLandButton.snp.makeConstraints { make in
                make.width.equalTo(250)
                make.height.equalTo(35)
                make.top.equalToSuperview()
                make.centerX.equalToSuperview()
            }
        }
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Dronelink.shared.add(delegate: self)
        droneSessionManager?.add(delegate: self)
        updateTimer = Timer.scheduledTimer(timeInterval: updateInterval, target: self, selector: #selector(update), userInfo: nil, repeats: true)
    }
    
    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        Dronelink.shared.remove(delegate: self)
        droneSessionManager?.remove(delegate: self)
        session?.remove(delegate: self)
        missionExecutor?.remove(delegate: self)
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    override public func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        view.setNeedsUpdateConstraints()
    }
    
    override public func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        view.setNeedsUpdateConstraints()
    }
    
    @objc func update() {
        if let status = (session as? ParrotDroneSession)?.status {
            statusLabel.text = status.display
            statusGradient.colors = [status.level.color!.withAlphaComponent(0.5).cgColor, DronelinkUI.Constants.overlayColor.cgColor]
        }
        else {
            statusLabel.text = "ParrotDashboardViewController.disconnected".localized
            statusGradient.colors = [DronelinkUI.Constants.overlayColor.cgColor]
        }
        statusGradient.frame = topBarBackgroundView.bounds
        let batteryPercent = Float(session?.state?.value.batteryPercent ?? 0)
        batteryProgressView.setProgress(batteryPercent, animated: true)
        if batteryPercent < 0.5 {
            batteryProgressView.progressTintColor = batteryProgressLowColor?.interpolate(batteryProgressMediumColor, percent: CGFloat(batteryPercent / 0.5))
        }
        else {
            batteryProgressView.progressTintColor = batteryProgressMediumColor?.interpolate(batteryProgressHightColor, percent: CGFloat((batteryPercent - 0.5) / 0.5))
        }
    }
    
    override public func updateViewConstraints() {
        super.updateViewConstraints()
        updateConstraints()
    }
    
    open func updateConstraints() {
        view.sendSubviewToBack(reticalImageView)
        view.sendSubviewToBack(primaryView)
        view.bringSubviewToFront(secondaryView)
        view.bringSubviewToFront(primaryViewToggleButton)
        view.bringSubviewToFront(mapMoreButton)
        if let instrumentsView = instrumentsViewController?.view {
            view.bringSubviewToFront(instrumentsView)
        }
        if let telemetryView = telemetryViewController?.view {
            view.bringSubviewToFront(telemetryView)
        }
        
        if virtualSticks {
            view.bringSubviewToFront(takeoffLandButton)
            view.bringSubviewToFront(joystickLeftView)
            view.bringSubviewToFront(joystickRightView)
        }
        
        primaryView.snp.remakeConstraints { make in
            if (portrait && !tablet) {
                make.top.equalTo(topBarBackgroundView.safeAreaLayoutGuide.snp.bottom).offset(statusWidgetHeight * 2)
            }
            else {
                make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
            }
            
            if (portrait) {
                make.left.equalToSuperview()
                make.right.equalToSuperview()
                make.height.equalTo(UIScreen.main.bounds.width * 2/3)
            }
            else {
                make.left.equalToSuperview()
                make.right.equalToSuperview()
                make.bottom.equalToSuperview()
            }
        }
        
        secondaryView.snp.remakeConstraints { make in
            if (portrait) {
                make.top.equalTo(primaryView.snp.bottom).offset(tablet ? 0 : statusWidgetHeight * 2)
                make.right.equalToSuperview()
                make.left.equalToSuperview()
                make.bottom.equalToSuperview()
            }
            else {
                if tablet {
                    make.width.equalTo(view.snp.width).multipliedBy(funcViewController == nil || !funcExpanded ? 0.4 : 0.30)
                }
                else {
                    make.width.equalTo(view.snp.width).multipliedBy(funcViewController == nil || !funcExpanded ? 0.28 : 0.18)
                }
                
                make.height.equalTo(secondaryView.snp.width).multipliedBy(0.5)
                make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-defaultPadding)
                if !portrait, funcExpanded, let funcViewController = funcViewController {
                    make.left.equalTo(funcViewController.view.snp.right).offset(defaultPadding)
                }
                else {
                    make.left.equalTo(view.safeAreaLayoutGuide.snp.left).offset(defaultPadding)
                }
            }
        }
        
        reticalImageView.snp.remakeConstraints { make in
            make.center.equalTo(videoPreviewerView)
            make.height.equalTo(videoPreviewerView)
        }
        
        primaryViewToggleButton.isHidden = portrait
        primaryViewToggleButton.snp.remakeConstraints { make in
            make.left.equalTo(secondaryView.snp.left).offset(defaultPadding)
            make.top.equalTo(secondaryView.snp.top).offset(defaultPadding)
            make.width.equalTo(30)
            make.height.equalTo(30)
        }
        
        mapMoreButton.snp.remakeConstraints { make in
            make.left.equalTo(primaryViewToggleButton)
            make.top.equalTo(portrait ? secondaryView.snp.top : primaryViewToggleButton.snp.bottom).offset(defaultPadding)
            make.width.equalTo(30)
            make.height.equalTo(30)
        }
        
        topBarBackgroundView.snp.remakeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
            make.left.equalToSuperview()
            make.right.equalToSuperview()
            make.height.equalTo(statusWidgetHeight)
        }
        
        batteryProgressView.snp.remakeConstraints { make in
            make.left.equalTo(topBarBackgroundView.snp.left)
            make.right.equalTo(topBarBackgroundView.snp.right)
            make.height.equalTo(4)
            make.top.equalTo(topBarBackgroundView.snp.bottom)
        }
        
        dismissButton.isEnabled = !(missionExecutor?.engaged ?? false)
        dismissButton.snp.remakeConstraints { make in
            make.left.equalToSuperview().offset(10)
            make.top.equalTo(topBarBackgroundView.snp.top)
            make.width.equalTo(statusWidgetHeight * 1.25)
            make.height.equalTo(statusWidgetHeight)
        }
        
        instrumentsViewController?.view.snp.remakeConstraints { make in
            if portrait && !tablet {
                make.top.equalTo(topBarBackgroundView.snp.bottom).offset(8)
            }
            else {
                make.top.equalTo(topBarBackgroundView.snp.top).offset(5)
            }
            make.height.equalTo(30)
            make.right.equalTo(view.safeAreaLayoutGuide.snp.right)
            make.width.equalTo(260)
        }
        
        telemetryViewController?.view.snp.remakeConstraints { make in
            if (portrait) {
                make.bottom.equalTo(secondaryView.snp.top).offset(tablet ? -defaultPadding : -2)
                make.left.equalTo(view.safeAreaLayoutGuide.snp.left).offset(defaultPadding)
            }
            else {
                make.bottom.equalTo(secondaryView.snp.bottom)
                make.left.equalTo(secondaryView.snp.right).offset(defaultPadding)
            }
            make.height.equalTo(tablet ? 85 : 75)
            make.width.equalTo(tablet ? 350 : 275)
        }
        
        updateConstraintsMission()
        updateConstraintsFunc()
    }
    
    func updateConstraintsMission() {
        if let missionViewController = missionViewController {
            view.bringSubviewToFront(missionViewController.view)
            missionViewController.view.snp.remakeConstraints { make in
                if (portrait && tablet) {
                    make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-defaultPadding)
                    make.left.equalTo(view.safeAreaLayoutGuide.snp.left).offset(defaultPadding)
                    make.width.equalToSuperview().multipliedBy(0.45)
                    if (missionExpanded) {
                        make.top.equalTo(secondaryView.snp.top).offset(defaultPadding)
                    }
                    else {
                        make.height.equalTo(80)
                    }
                    return
                }
                
                if (portrait) {
                    make.right.equalToSuperview()
                    make.left.equalToSuperview()
                    make.bottom.equalToSuperview()
                    if (missionExpanded) {
                        make.height.equalTo(secondaryView.snp.height).multipliedBy(0.5)
                    }
                    else {
                        make.height.equalTo(100)
                    }
                    return
                }
                
                make.top.equalTo(topBarBackgroundView.snp.bottom).offset(defaultPadding)
                make.left.equalTo(view.safeAreaLayoutGuide.snp.left).offset(defaultPadding)
                if (tablet) {
                    make.right.equalTo(secondaryView.snp.right)
                }
                else {
                    make.width.equalToSuperview().multipliedBy(0.4)
                }
                
                if (missionExpanded) {
                    if (tablet) {
                        make.height.equalTo(180)
                    }
                    else {
                        make.bottom.equalTo(secondaryView.snp.top).offset(-Double(defaultPadding) * 1.5)
                    }
                }
                else {
                    make.height.equalTo(80)
                }
            }
        }
    }
    
    func updateConstraintsFunc() {
        if let funcViewController = funcViewController {
            view.bringSubviewToFront(funcViewController.view)
            funcViewController.view.snp.remakeConstraints { make in
                let large = tablet || portrait
                if (funcExpanded) {
                    if (portrait) {
                        make.height.equalTo(tablet ? 550 : 300)
                    }
                    else {
                        make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-defaultPadding)
                    }
                }
                else {
                    make.height.equalTo(165)
                }
                
                if (portrait && tablet) {
                    make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-defaultPadding)
                    make.left.equalTo(view.safeAreaLayoutGuide.snp.left).offset(defaultPadding)
                    make.width.equalTo(large ? 350 : 310)
                    return
                }
                
                if (portrait) {
                    make.right.equalToSuperview()
                    make.left.equalToSuperview()
                    make.top.equalTo(secondaryView.snp.top)
                    return
                }
                
                make.top.equalTo(topBarBackgroundView.snp.bottom).offset(defaultPadding)
                make.left.equalTo(view.safeAreaLayoutGuide.snp.left).offset(defaultPadding)
                make.width.equalTo(large ? 350 : 310)
            }
        }
    }
    
    @objc func onPrimaryViewToggle(sender: Any) {
        primaryViewToggled = true
        videoPreviewerPrimary = !videoPreviewerPrimary
        updateConstraints()
        view.animateLayout()
    }
    
    private func updateMapMicrosoft() {
        if let mapViewController = mapViewController {
            mapViewController.view.removeFromSuperview()
            mapViewController.removeFromParent()
        }
        
        let mapViewController = MicrosoftMapViewController.create(droneSessionManager: droneSessionManager, credentialsKey: mapCredentialsKey)
        self.mapViewController = mapViewController
        addChild(mapViewController)
        view.addSubview(mapViewController.view)
        mapViewController.didMove(toParent: self)
        view.setNeedsUpdateConstraints()
    }
    
    private func updateMapMapbox() {
        if let mapViewController = mapViewController {
            mapViewController.view.removeFromSuperview()
            mapViewController.removeFromParent()
        }
        
        let mapViewController = MapboxMapViewController.create(droneSessionManager: droneSessionManager)
        self.mapViewController = mapViewController
        addChild(mapViewController)
        view.addSubview(mapViewController.view)
        mapViewController.didMove(toParent: self)
        view.setNeedsUpdateConstraints()
    }
    
    @objc func onMapMore(sender: Any) {
        if let mapViewController = mapViewController as? MicrosoftMapViewController {
            mapViewController.onMore(sender: sender, actions: [
                UIAlertAction(title: "ParrotDashboardViewController.map.mapbox".localized, style: .default, handler: { _ in
                    self.updateMapMapbox()
                })
            ])
        }
        else if let mapViewController = mapViewController as? MapboxMapViewController {
            mapViewController.onMore(sender: sender, actions: [
                UIAlertAction(title: "ParrotDashboardViewController.map.microsoft".localized, style: .default, handler: { _ in
                    self.updateMapMicrosoft()
                })
            ])
        }
    }
    
    @objc func onDismiss(sender: Any) {
        dismiss(animated: true)
    }
    
    private func apply(userInterfaceSettings: Mission.UserInterfaceSettings?) {
        reticalImageView.image = nil
        if let reticalImageUrl = userInterfaceSettings?.reticalImageUrl {
            reticalImageView.kf.setImage(with: URL(string: reticalImageUrl))
        }
        
        view.setNeedsUpdateConstraints()
    }
    
    //work-around for this: https://github.com/flutter/flutter/issues/35784
    override public func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {}
    override public func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {}
    override public func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {}
    override public func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {}
    
    @objc func onTakeoffLand(sender: Any) {
        if let controlSession = controlSession {
            controlSession.deactivate()
            self.controlSession = nil
            session?.drone.startLanding(finished: nil)
            takeoffLandButton.setTitle("Takeoff", for: .normal)
        }
        else {
            controlSession = session?.createControlSession()
            Thread.detachNewThread(self.execute)
            takeoffLandButton.setTitle("Land", for: .normal)
        }
    }
    
    @objc func onJoystickLeftTapGesture(recognizer: UITapGestureRecognizer) {
        if recognizer.state == .ended {
            joystickLeftActive = false
        }
    }
    
    @objc func onJoystickLeftPanGesture(recognizer: UIPanGestureRecognizer) {
        let translation = recognizer.translation(in: joystickLeftView)
        if let view = recognizer.view {
            vertical = Double(max(-1, min(1, (-translation.y / view.frame.height) * 2)))
            yaw = Double(max(-1, min(1, (translation.x / view.frame.width) * 2)))
            joystickLeftActive = true
        }
    }
    
    @objc func onJoystickRightTapGesture(recognizer: UITapGestureRecognizer) {
        if recognizer.state == .ended {
            joystickRightActive = false
        }
    }
    
    @objc func onJoystickRightPanGesture(recognizer: UIPanGestureRecognizer) {
        let translation = recognizer.translation(in: joystickLeftView)
        if let view = recognizer.view {
            roll = Double(max(-1, min(1, (translation.x / view.frame.width) * 2)))
            pitch = Double(max(-1, min(1, (translation.y / view.frame.height) * 2)))
            joystickRightActive = true
        }
    }
    
    func execute() {
        let updateInterval = 0.1
        while controlSession != nil {
            if let disengageReason = controlSession?.disengageReason {
                NSLog("disengageReason=\(disengageReason.display)")
                break
            }
            
            if controlSession?.activate() ?? false, let flightController = (self.session?.drone as? ParrotDroneAdapter)?.flightController {
                flightController.set(yawRotationSpeed: self.joystickLeftActive ? Int(yaw * 100) : 0)
                flightController.set(verticalSpeed: self.joystickLeftActive ? Int(vertical * 100) : 0)
                flightController.set(pitch: self.joystickRightActive ? Int(pitch * 100) : 0)
                flightController.set(roll: self.joystickRightActive ? Int(roll * 100) : 0)
            }
            
            Thread.sleep(forTimeInterval: updateInterval)
        }
    }
}

extension ParrotDashboardViewController: DronelinkDelegate {
    public func onRegistered(error: String?) {
    }
    
    public func onMissionLoaded(executor: MissionExecutor) {
        DispatchQueue.main.async {
            self.missionExecutor = executor
            let missionViewController = MissionViewController.create(droneSessionManager: self.droneSessionManager, delegate: self)
            self.addChild(missionViewController)
            self.view.addSubview(missionViewController.view)
            missionViewController.didMove(toParent: self)
            self.missionViewController = missionViewController
            executor.add(delegate: self)
            self.apply(userInterfaceSettings: executor.userInterfaceSettings)
        }
    }
    
    public func onMissionUnloaded(executor: MissionExecutor) {
        DispatchQueue.main.async {
            self.missionExecutor = nil
            if let missionViewController = self.missionViewController {
                missionViewController.view.removeFromSuperview()
                missionViewController.removeFromParent()
                self.missionViewController = nil
            }
            executor.remove(delegate: self)
            self.apply(userInterfaceSettings: nil)
        }
    }
    
    public func onFuncLoaded(executor: FuncExecutor) {
        DispatchQueue.main.async {
            self.funcExecutor = executor
            self.funcExpanded = false
            let funcViewController = FuncViewController.create(droneSessionManager: self.droneSessionManager, delegate: self)
            self.addChild(funcViewController)
            self.view.addSubview(funcViewController.view)
            funcViewController.didMove(toParent: self)
            self.funcViewController = funcViewController
            self.apply(userInterfaceSettings: executor.userInterfaceSettings)
        }
    }
    
    public func onFuncUnloaded(executor: FuncExecutor) {
        DispatchQueue.main.async {
            self.funcExecutor = nil
            if let funcViewController = self.funcViewController {
                funcViewController.view.removeFromSuperview()
                funcViewController.removeFromParent()
                self.funcViewController = nil
            }
            
            if self.missionExecutor == nil {
                self.apply(userInterfaceSettings: nil)
            }
            else {
                self.view.setNeedsUpdateConstraints()
            }
        }
    }
}

extension ParrotDashboardViewController: DroneSessionManagerDelegate {
    public func onOpened(session: DroneSession) {
        DispatchQueue.main.async {
            self.session = session
            session.add(delegate: self)
            DispatchQueue.main.async {
                if !self.primaryViewToggled {
                    self.videoPreviewerPrimary = true
                }
                self.view.setNeedsUpdateConstraints()
            }
            
            self.streamServerRef = (self.session?.drone as? ParrotDroneAdapter)?.drone.getPeripheral(Peripherals.streamServer) { [weak self] streamServer in
                if let self = self, let streamServer = streamServer {
                    streamServer.enabled = true
                    self.liveStreamRef = streamServer.live { liveStream in
                        if let liveStream = liveStream {
                            self.videoPreviewerView.setStream(stream: liveStream)
                            _ = liveStream.play()
                        }
                    }
                }
            }
        }
    }
    
    public func onClosed(session: DroneSession) {
        self.session = nil
        session.remove(delegate: self)
        DispatchQueue.main.async {
            self.liveStreamRef = nil
            self.videoPreviewerView.setStream(stream: nil)
            self.view.setNeedsUpdateConstraints()
        }
    }
}

extension ParrotDashboardViewController: DroneSessionDelegate {
    public func onInitialized(session: DroneSession) {
        if let cameraState = session.cameraState(channel: 0), !cameraState.value.isSDCardInserted {
            DronelinkUI.shared.showDialog(title: "ParrotDashboardViewController.camera.noSDCard.title".localized, details: "ParrotDashboardViewController.camera.noSDCard.details".localized)
        }
    }
    
    public func onLocated(session: DroneSession) {}
    
    public func onMotorsChanged(session: DroneSession, value: Bool) {}
    
    public func onCommandExecuted(session: DroneSession, command: MissionCommand) {}
    
    public func onCommandFinished(session: DroneSession, command: MissionCommand, error: Error?) {}
    
    public func onCameraFileGenerated(session: DroneSession, file: CameraFile) {}
}

extension ParrotDashboardViewController: MissionExecutorDelegate {
    public func onMissionEstimating(executor: MissionExecutor) {}
    
    public func onMissionEstimated(executor: MissionExecutor, estimate: MissionExecutor.Estimate) {}
    
    public func onMissionEngaging(executor: MissionExecutor) {}
    
    public func onMissionEngaged(executor: MissionExecutor, engagement: MissionExecutor.Engagement) {
        DispatchQueue.main.async {
            self.view.setNeedsUpdateConstraints()
        }
    }
    
    public func onMissionExecuted(executor: MissionExecutor, engagement: MissionExecutor.Engagement) {}
    
    public func onMissionDisengaged(executor: MissionExecutor, engagement: MissionExecutor.Engagement, reason: Mission.Message) {
        DispatchQueue.main.async {
            self.view.setNeedsUpdateConstraints()
        }
    }
}

extension ParrotDashboardViewController: MissionViewControllerDelegate {
    public func onMissionExpandToggle() {
        updateConstraintsMission()
        view.animateLayout()
    }
}

extension ParrotDashboardViewController: FuncViewControllerDelegate {
    public func onFuncExpanded(value: Bool) {
        funcExpanded = value
        updateConstraints()
        view.animateLayout()
    }
}

extension Mission.MessageLevel {
    var color: UIColor? {
        switch self {
        case .info:
            return MDCPalette.green.accent400
        case .warning:
            return MDCPalette.amber.accent400
        case .danger, .error:
            return MDCPalette.red.accent400
        }
    }
}
