//
//  ParrotCameraFeedWidget.swift
//  DronelinkParrotUI
//
//  Created by Jim McAndrew on 12/4/20.
//  Copyright © 2020 Dronelink. All rights reserved.
//
import DronelinkCore
import DronelinkCoreUI
import DronelinkParrot
import GroundSdk

public class ParrotCameraFeedWidget: UpdatableWidget {
    
    public let thermalStreamView = ThermalStreamView(frame: CGRect.zero)
    // Drone:
    /// Current drone instance.
    private var drone: Drone?
    /// Reference to the current drone state.
    private var droneStateRef: Ref<DeviceState>?
    /// Reference to the current drone stream server peripheral.
    private var streamServerRef: Ref<StreamServer>?
    /// Reference to the current drone live stream.
    private var liveStreamRef: Ref<CameraLive>?
    /// Reference to the current drone thermal control  peripheral.
    private var thermalCtrlRef: Ref<ThermalControl>?
    /// Reference to the current drone thermal camera peripheral.
    private var thermalCameraRef: Ref<ThermalCamera>?
    /// `true` if the drone thermal render is initialized.
    private var droneThermalRenderInitialized = false
    
    // Local Thermal Processing Part:
    /// Thermal video processing.
    private var tproc = ThermalProcVideo()
    /// Relative thermal palette.
    private var relativePalette : ThermalProcRelativePalette!
    /// Absolute thermal palette.
    private var absolutePalette : ThermalProcAbsolutePalette!
    /// Spot thermal palette.
    private var spotPalette : ThermalProcSpotPalette!
    
    private var channel: UInt = 0
    private var camera: Camera?
    private var cameraState: CameraStateAdapter? { session?.cameraState(channel: channel)?.value }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(thermalStreamView)
        thermalStreamView.snp.makeConstraints { [weak self] make in
            make.edges.equalToSuperview()
        }
        
        // Initialize local thermal palettes.
        initThermalPalettes()
        // Initialize local thermal processing.
        initThermalProc()
        startDroneMonitors()
    }
    
    public override func onClosed(session: DroneSession) {
        stopDroneMonitors()
    }
    
    public func switchCamera() {
        self.liveStreamRef?.value?.stop()
        changeMode()
        startDroneMonitors()
    }
    
    public override func update() {
        self.camera = (cameraState as? ParrotCameraAdapter)?.camera
        if let camera = self.camera {
            if let liveStream = self.liveStreamRef?.value {
                if (camera.isActive == true && liveStream.playState != CameraLivePlayState.playing) {
                    self.startVideoStream(liveStream)
                }
            }
        }
    }
    
    /// Initialize thermal palettes.
    private func initThermalPalettes() {
        // Initialize relative thermal palette
        initRelativeThermalPalette()
        
        // Initialize absolute thermal palette
        initAbsoluteThermalPalette()
        
        // Initialize spot thermal palette
        initSpotThermalPalette()
    }
    
    public func isThermalCameraActive() -> Bool {
        return (cameraState as? ParrotCameraAdapter)?.model == "thermal"
    }
    
    /// Initialize relative thermal palette.
    private func initRelativeThermalPalette() {
        // Create a Relative thermal palette:
        //
        // Palette fully used.
        // The lowest color is associated to the coldest temperature of the scene and
        // the highest color is associated to the hottest temperature of the scene.
        // The temperature association can be locked.
        relativePalette = ThermalProcPaletteFactory.createRelativePalette(
            // Colors list:
            //     - Blue as color of the lower palette boundary.
            //     - Red as color of the higher palette boundary.
            [ThermalProcColor.init(red: Float(0.0), green: Float(0.0), blue: Float(1.0), position: Float(0.0)),
             ThermalProcColor.init(red: Float(1.0), green: Float(0.0), blue: Float(0.0), position: Float(1.0))],
            boundariesUpdate: {
                // Called when the temperatures associated to the palette boundaries change.
                print("Blue is associated to \(self.relativePalette.lowestTemperature) kelvin.")
                print("Red is associated to \(self.relativePalette.highestTemperature) kelvin.")
            })
        
        //`relativePalette.isLocked = true` can be used to lock the association between colors and temperatures.
        // If relativePalette.isLocked is false, the association between colors and temperatures is update
        // at each render to match with the temperature range of the scene rendered.
    }
    
    /// Initialize absolute thermal palette.
    private func initAbsoluteThermalPalette() {
        // Create a Absolute thermal palette:
        //
        // Palette used between temperature range set.
        // The palette can be limited or extended for out of range temperatures.
        absolutePalette = ThermalProcPaletteFactory.createAbsolutePalette(
            // Colors list:
            //     - Brown as color of the lower palette boundary.
            //     - Purple as the middle color of the palette.
            //     - Yellow as color of the higher palette boundary.
            [ThermalProcColor.init(red: Float(0.34), green: Float(0.16), blue: Float(0.0), position: Float(0.0)),
             ThermalProcColor.init(red: Float(0.40), green: Float(0.0), blue: Float(0.60), position: Float(0.5)),
             ThermalProcColor.init(red: Float(1.0), green: Float(1.0), blue: Float(0.0), position: Float(1.0))]
        )
        
        // Set a range between 300.0 Kelvin and 310.0 Kelvin.
        // Brown will be associated with 300.0 Kelvin.
        // Yellow will be associated with 310.0 Kelvin.
        // Purple will be associated with the middle range therefore 305.0 Kelvin.
        absolutePalette.lowestTemperature = 300.0
        absolutePalette.highestTemperature = 310.0
        
        // Limit the palette, to render in black color temperatures out of range.
        absolutePalette.isLimited = true
        // If the palette is not limited:
        //    - temperatures lower than `lowestTemperature` are render with the lower palette boundary color.
        //    - temperatures higher than `highestTemperature` are render with the higher palette boundary color.
    }
    
    /// Initialize spot thermal palette.
    private func initSpotThermalPalette() {
        // Create a Spot thermal palette:
        //
        // Palette to highlight cold spots or hot spots.
        //
        // The palette is fully used:
        //     The lowest color is associated to the coldest temperature of the scene and
        //     the highest color is associated to the hottest temperature of the scene.
        // Only temperature hotter or colder than the threshold are shown.
        spotPalette = ThermalProcPaletteFactory.createSpotPalette(
            // Colors list:
            //     - Green as color of the lower palette boundary.
            //     - Orange as color of the higher palette boundary.
            [ThermalProcColor.init(red: Float(0.0), green: Float(1.0), blue: Float(0.0), position: Float(0.0)),
             ThermalProcColor.init(red: Float(1.0), green: Float(0.5), blue: Float(0.0), position: Float(1.0))],
            boundariesUpdate: {
                // Called when the temperatures associated to the palette boundaries change.
                print("Green is associated to \(self.spotPalette.lowestTemperature) kelvin.")
                print("Orange is associated to \(self.spotPalette.highestTemperature) kelvin.")
            })
        
        // Highlight temperature higher than the threshold.
        spotPalette.temperatureType = .hot
        // `spotPalette.temperatureType = .cold` to highlight temperature lower than the threshold.
        // Set the threshold at the 60% of the temperature range of the rendered scene.
        spotPalette.threshold = 0.6
    }
    
    /// Initialize local thermal processing.
    private func initThermalProc() {
        tproc.renderingMode = isThermalCameraActive() ? .blended : .visible
        tproc.blendingRate = 0.5
        tproc.probePosition = CGPoint(x: 0.5, y: 0.5)

        // Use the relative palette
        if let palette = relativePalette {
            tproc.palette = palette
        }
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopDroneMonitors()
    }
    
    /// Starts drone monitors.
    private func startDroneMonitors() {
        // Monitor thermal control peripheral.
        monitorThermalControl()
        // Monitor thermal camera.
        monitorThermalCamera()
        // Monitor stream server.
        monitorStreamServer()
    }
    
    /// Stops drone monitors.
    private func stopDroneMonitors() {
        // Forget references linked to the current drone to stop their monitoring.
        droneStateRef = nil
        streamServerRef = nil
        liveStreamRef = nil
        thermalCtrlRef = nil
        thermalCameraRef = nil
        
        // Reset drone render initialisation state
        droneThermalRenderInitialized = false
    }
    
    /// Monitors the stream server.
    private func monitorStreamServer() {
         // Prevent monitoring restart
        if (streamServerRef != nil || self.session == nil ) { return }
        
        streamServerRef = (self.session!.drone as? ParrotDroneAdapter)?.drone.getPeripheral(Peripherals.streamServer) { [weak self] streamServer in
            if let streamServer = streamServer {
                streamServer.enabled = self?.camera?.isActive == true
                self?.monitorLiveStream(streamServer: streamServer)
            }
        }
     }
    
    /// Monitors the live stream.
    ///
    /// - Parameter streamServer: the stream server.
    private func monitorLiveStream(streamServer: StreamServerDesc.ApiProtocol) {
        // Prevent monitoring restart
        if (liveStreamRef != nil || self.session == nil ) { return }

        // Monitor the live stream.
        liveStreamRef = streamServer.live { liveStream in
            // Called when the live stream is available and when it changes.
            // Start to play the live stream only if the thermal camera is active.
            if let liveStream = liveStream {
                if (self.camera?.isActive == true) {
                    self.startVideoStream(liveStream)
                }
            }
        }
    }

    
    /// Starts the video stream.
    ///
    /// - Parameter liveStream: the stream to start.
    private func startVideoStream(_ liveStream: CameraLive) {
        // Prevent stream restart
        if (liveStream.playState == CameraLivePlayState.playing || self.session == nil ) { return }
        
        // Force the stream server enabling.
        streamServerRef?.value?.enabled = true
        
        // Set thermal Camera model to use according to the drone model.
        thermalStreamView.thermalCamera = (self.session!.model == Drone.Model.anafiUsa.description) ? ThermalProcThermalCamera.boson : ThermalProcThermalCamera.lepton
        
        // Set the live stream as the stream to be render by the stream view.
        thermalStreamView.setStream(stream: liveStream)
        
        // Set the thermal processing instance to use to the thermal stream view.
        thermalStreamView.thermalProc = tproc
        // Play the live stream.
        liveStream.play()
    }
    
    /// Monitors the thermal control peripheral.
    private func monitorThermalControl() {
        // Prevent monitoring restart
        if (self.thermalCtrlRef != nil || self.session == nil ) { return }
        
        self.thermalCtrlRef = (self.session!.drone as? ParrotDroneAdapter)?.drone.getPeripheral(Peripherals.thermalControl) { [weak self] thermalControl in
            if let self = self, let thermalControl = thermalControl {
                // Warning: TProc and TProcStreamView should not be used in EMBEDDED mode,
                // the stream should be displayed directly by a GsdkStreamView.
                // In order to the drone video recording look like the local render,
                // send a thermal render settings.
                if (!self.droneThermalRenderInitialized && thermalControl.setting.mode != ThermalControlMode.disabled) {
                    self.sendThermalRenderSettings(thermalCtrl: thermalControl)
                    self.droneThermalRenderInitialized = true
                }
            }
        }
    }
    
    /// Monitors the thermal camera.
    private func monitorThermalCamera() {
        // Prevent monitoring restart
        if (self.session == nil) { return }
        self.camera = (cameraState as? ParrotCameraAdapter)?.camera
        if let camera = self.camera {
            if let liveStream = self.liveStreamRef?.value {
                if (camera.isActive == true && liveStream.playState != CameraLivePlayState.playing) {
                    self.startVideoStream(liveStream)
                }
            }
        }
    }

    
    private func changeMode() {
        var mode = ThermalControlMode.disabled
        switch (cameraState as? ParrotCameraAdapter)?.model {
        case "main":
            mode = ThermalControlMode.standard
            tproc.renderingMode = ThermalProcRenderingMode.blended
        default:
            mode = ThermalControlMode.disabled
            tproc.renderingMode = ThermalProcRenderingMode.visible
        }
        // Active the thermal camera, if not yet done.
        if (self.thermalCtrlRef?.value?.setting.mode != mode) {
            self.thermalCtrlRef?.value?.setting.mode = mode
        }
    }
    
    // Thermal processing is local only.
    // If you want that the thermal video recorded on the drone look like the local render,
    // you should send thermal rendering settings to the drone.
    /// Sends Thermal Render settings to the drone.
    ///
    /// - Parameter thermalCtrl: thermal control
    private func sendThermalRenderSettings(thermalCtrl: ThermalControl) {
        // To optimize, do not send settings that have not changed.
        // Send thermal rendering and palette only if the drone is connected.
        guard droneThermalRenderInitialized == false && self.droneStateRef?.value?.connectionState == .connected else {
            return
        }
        
        // Send rendering mode.
        thermalCtrl.sendRendering(rendering: thermalRenderingModeGsdk())
        
        // Send emissivity .
        thermalCtrl.sendEmissivity(tproc.emissivity)
        
        // Send Background Temperature.
        thermalCtrl.sendBackgroundTemperature(tproc.backgroundTemp)
        
        // Send thermal palette.
        if let gsdkThermalPalette = thermalPaletteGsdk() {
            thermalCtrl.sendPalette(gsdkThermalPalette)
        }
        
        self.droneThermalRenderInitialized = true
    }
    
    /// Retrieves GroundSdk palette to send to the drone according to the current thermal processing palette.
    ///
    /// - Returns: GroundSdk palette  according to the current thermal processing palette.
    private func thermalPaletteGsdk() -> ThermalPalette? {
        // Convert thermal processing colors to GroundSdk thermal colors.
        var gsdkColors : [ThermalColor] = []
        for color in tproc.palette.colors as! [ThermalProcColor] {
            gsdkColors.append(ThermalColor(Double(color.red), Double(color.green), Double(color.blue), Double(color.position)))
        }
        
        // Convert thermal processing palette to GroundSdk thermal palette.
        var gsdkPalette: ThermalPalette?
        if let relativePalette = tproc.palette as? ThermalProcRelativePalette {
            gsdkPalette = ThermalRelativePalette(colors: gsdkColors, locked: relativePalette.isLocked,
                                                 lowestTemp: relativePalette.lowestTemperature,
                                                 highestTemp: relativePalette.highestTemperature)
        } else if let absolutePalette = tproc.palette as? ThermalProcAbsolutePalette {
            gsdkPalette = ThermalAbsolutePalette(colors: gsdkColors,
                                                 lowestTemp: absolutePalette.lowestTemperature,
                                                 highestTemp: absolutePalette.highestTemperature,
                                                 outsideColorization: absolutePalette.isLimited ? .limited : .extended)
        } else if let spotPalette = tproc.palette as? ThermalProcSpotPalette {
            gsdkPalette = ThermalSpotPalette(colors: gsdkColors,
                                             type: spotPalette.temperatureType == .hot ? .hot: .cold,
                                             threshold: spotPalette.threshold)
        }
        
        return gsdkPalette
    }
    
    /// Retrieves GroundSdk rendering mode to send to the drone according to the current thermal processing.
    ///
    /// - Returns: GroundSdk rendering mode according to the current thermal processing.
    private func thermalRenderingModeGsdk() -> ThermalRendering {
        let renderingMode: ThermalRenderingMode
        // Send rendering mode.
        switch (tproc.renderingMode) {
        case .visible:
            renderingMode = .visible
        case .thermal:
            renderingMode = .thermal
        case .blended:
            renderingMode = .blended
        case .monochrome:
            renderingMode = .monochrome
        default:
            renderingMode = .blended
        }
        
        return ThermalRendering.init(mode: renderingMode, blendingRate: tproc.blendingRate)
    }
}
