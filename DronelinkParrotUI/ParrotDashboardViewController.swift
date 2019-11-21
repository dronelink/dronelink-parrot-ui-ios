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

public class ParrotDashboardViewController: UIViewController {
    public static func create(droneSessionManager: DroneSessionManager) -> ParrotDashboardViewController {
        let dashboardViewController = ParrotDashboardViewController()
        dashboardViewController.modalPresentationStyle = .fullScreen
        dashboardViewController.droneSessionManager = droneSessionManager
        return dashboardViewController
    }
    
    private var droneSessionManager: DroneSessionManager!
    private var session: DroneSession?
    private var missionExecutor: MissionExecutor?
    private var mapViewController: MapViewController!
    private let primaryViewToggleButton = UIButton(type: .custom)
    private let dismissButton = UIButton(type: .custom)
    private var videoPreviewerView = StreamView(frame: CGRect.zero)
    private let topBarBackgroundView = UIView()
    
    private var telemetryViewController: TelemetryViewController?
    private var missionViewController: MissionViewController?
    private var missionExpanded = false
    private var videoPreviewerPrimary = true
    private let defaultPadding = 10
    private var primaryView: UIView { return videoPreviewerPrimary || portrait ? videoPreviewerView : mapViewController.view }
    private var secondaryView: UIView { return primaryView == videoPreviewerView ? mapViewController.view : videoPreviewerView }
    private var portrait: Bool { return UIScreen.main.bounds.width < UIScreen.main.bounds.height }
    private var tablet: Bool { return UIDevice.current.userInterfaceIdiom == .pad }
    private var statusWidgetHeight: CGFloat { return tablet ? 50 : 40 }
    
    private var streamServerRef: Ref<StreamServer>?
    private var liveStreamRef: Ref<CameraLive>?
    
    public override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor.black
        
        videoPreviewerView.addShadow()
        videoPreviewerView.backgroundColor = UIColor(displayP3Red: 35/255, green: 35/255, blue: 35/255, alpha: 1)
        view.addSubview(videoPreviewerView)
        
        topBarBackgroundView.backgroundColor = DronelinkUI.Constants.overlayColor
        view.addSubview(topBarBackgroundView)
        
        dismissButton.tintColor = UIColor.white
        dismissButton.setImage(DronelinkParrotUI.loadImage(named: "dronelink-logo"), for: .normal)
        dismissButton.imageView?.contentMode = .scaleAspectFit
        dismissButton.imageEdgeInsets = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        dismissButton.addTarget(self, action: #selector(onDismiss(sender:)), for: .touchUpInside)
        view.addSubview(dismissButton)
        
        let mapViewController = MapViewController.create(droneSessionManager: self.droneSessionManager)
        self.mapViewController = mapViewController
        addChild(mapViewController)
        view.addSubview(mapViewController.view)
        mapViewController.didMove(toParent: self)
        
        primaryViewToggleButton.tintColor = UIColor.white
        primaryViewToggleButton.setImage(DronelinkParrotUI.loadImage(named: "vector-arrange-below"), for: .normal)
        primaryViewToggleButton.addTarget(self, action: #selector(onPrimaryViewToggle(sender:)), for: .touchUpInside)
        view.addSubview(primaryViewToggleButton)
        
        let telemetryViewController = TelemetryViewController.create(droneSessionManager: self.droneSessionManager)
        addChild(telemetryViewController)
        view.addSubview(telemetryViewController.view)
        telemetryViewController.didMove(toParent: self)
        self.telemetryViewController = telemetryViewController
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Dronelink.shared.add(delegate: self)
        droneSessionManager?.add(delegate: self)
    }
    
    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        Dronelink.shared.remove(delegate: self)
        droneSessionManager?.remove(delegate: self)
    }
    
    override public func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        view.setNeedsUpdateConstraints()
    }
    
    override public func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        view.setNeedsUpdateConstraints()
    }
    
    override public func updateViewConstraints() {
        super.updateViewConstraints()
        updateConstraints()
    }
    
    func updateConstraints() {
        view.sendSubviewToBack(primaryView)
        view.bringSubviewToFront(secondaryView)
        view.bringSubviewToFront(primaryViewToggleButton)
        if let telemetryView = telemetryViewController?.view {
            view.bringSubviewToFront(telemetryView)
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
                make.width.equalTo(view.snp.width).multipliedBy(tablet ? 0.4 : 0.28)
                make.height.equalTo(secondaryView.snp.width).multipliedBy(0.5)
                make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-defaultPadding)
                make.left.equalTo(view.safeAreaLayoutGuide.snp.left).offset(defaultPadding)
            }
        }
        
        primaryViewToggleButton.isHidden = portrait
        primaryViewToggleButton.snp.remakeConstraints { make in
            make.left.equalTo(secondaryView.snp.left).offset(defaultPadding)
            make.top.equalTo(secondaryView.snp.top).offset(defaultPadding)
            make.width.equalTo(30)
            make.height.equalTo(30)
        }
        
        topBarBackgroundView.snp.remakeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
            make.left.equalToSuperview()
            make.right.equalToSuperview()
            make.height.equalTo(statusWidgetHeight)
        }
        
        dismissButton.isEnabled = !(missionExecutor?.engaged ?? false)
        dismissButton.snp.remakeConstraints { make in
            make.left.equalToSuperview().offset(10)
            make.top.equalTo(topBarBackgroundView.snp.top)
            make.width.equalTo(statusWidgetHeight * 1.25)
            make.height.equalTo(statusWidgetHeight)
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
                    make.bottom.equalTo(secondaryView.snp.top).offset(-Double(defaultPadding) * 1.5)
                }
                else {
                    make.height.equalTo(80)
                }
            }
        }
    }
    
    @objc func onPrimaryViewToggle(sender: Any) {
        videoPreviewerPrimary = !videoPreviewerPrimary
        updateConstraints()
        view.animateLayout()
    }
    
    @objc func onDismiss(sender: Any) {
        dismiss(animated: true)
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
            self.view.setNeedsUpdateConstraints()
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
            self.view.setNeedsUpdateConstraints()
        }
    }
}

extension ParrotDashboardViewController: DroneSessionManagerDelegate {
    public func onOpened(session: DroneSession) {
        DispatchQueue.main.async {
            self.session = session
            self.view.setNeedsUpdateConstraints()
            
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
        DispatchQueue.main.async {
            self.session = nil
            self.liveStreamRef = nil
            self.videoPreviewerView.setStream(stream: nil)
            self.view.setNeedsUpdateConstraints()
        }
    }
}

extension ParrotDashboardViewController: MissionExecutorDelegate {
    public func onMissionEstimated(executor: MissionExecutor, duration: TimeInterval) {}
    
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
    public func onExpandToggle() {
        missionExpanded = !missionExpanded
        updateConstraintsMission()
        view.animateLayout()
    }
}
