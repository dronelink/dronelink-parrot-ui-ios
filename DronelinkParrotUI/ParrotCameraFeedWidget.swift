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
    
    public let streamView = StreamView(frame: CGRect.zero)
    public let thermalStreamView = ThermalStreamView(frame: CGRect.zero)
    private var streamServerRef: Ref<StreamServer>?
    private var liveStreamRef: Ref<CameraLive>?
    private var thermalControlRef: Ref<ThermalControl>?
    
    private var camera: Camera?
    
    /** Thermal video processing. */
    private var tproc : ThermalProcVideo? = nil
    /** Relative thermal palette. */
    private var relativePalette: ThermalProcRelativePalette? = nil
    /** Absolute thermal palette. */
    private var absolutePalette: ThermalProcAbsolutePalette? = nil
    /** Spot thermal palette. */
    private var spotPalette: ThermalProcSpotPalette? = nil
    
    private var droneThermalRenderInitialized = false
    
    private var channel: UInt = 0
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(thermalStreamView)
        thermalStreamView.snp.makeConstraints { [weak self] make in
            make.edges.equalToSuperview()
        }
        
        tproc = ThermalProcVideo()
        // Initialize local thermal palettes.
        initThermalPalettes()
        // Initialize local thermal processing.
        initThermalProc()
    }
    
    public func setChannel(channel: UInt) {
        self.channel = channel
        self.liveStreamRef?.value?.stop()
        changeMode()
        startDroneMonitors()
    }
    
    private func initThermalPalettes() {
        // Initialize relative thermal palette
        initRelativeThermalPalette()
        // Initialize absolute thermal palette
        initAbsoluteThermalPalette()
        // Initialize spot thermal palette
        initSpotThermalPalette()
    }
    
    private func initRelativeThermalPalette() {
        let thermalColors = [ThermalProcColor.init(red: 0.0, green: 0.0, blue: 1.0, position: 0.0), ThermalProcColor.init(red: 1.0, green: 0.0, blue: 0.0, position: 1.0)]
        relativePalette = ThermalProcPaletteFactory.createRelativePalette(thermalColors, boundariesUpdate: nil)
    }
    
    private func initAbsoluteThermalPalette() {
        let thermalColors = [ThermalProcColor.init(red: 0.34, green: 0.16, blue: 0.0, position: 0.0), ThermalProcColor.init(red: 0.40, green: 0.0, blue: 0.60, position: 0.5), ThermalProcColor.init(red: 1.0, green: 1.0, blue: 0.0, position: 1.0)]
        absolutePalette = ThermalProcPaletteFactory.createAbsolutePalette(thermalColors)
        absolutePalette?.lowestTemperature = 300.0
        absolutePalette?.highestTemperature = 310.0
        absolutePalette?.isLimited = true
    }
    
    private func initSpotThermalPalette() {
        let thermalColors = [ThermalProcColor.init(red: 0.0, green: 1.0, blue: 0.0, position: 0.0), ThermalProcColor.init(red: 1.0, green: 0.5, blue: 0.0, position: 1.0)]
        spotPalette = ThermalProcPaletteFactory.createSpotPalette(thermalColors)
        // Highlight temperature higher than the threshold.
        spotPalette?.temperatureType = ThermalProcTemperatureType.hot
        // `spotPalette.temperatureType = TProcPaletteFactory.SpotPalette.TemperatureType.COLD`
        // to highlight temperature lower than the threshold.

        // Set the threshold at the 60% of the temperature range of the rendered scene.
        spotPalette?.threshold = 0.6
    }
    
    private func initThermalProc() {
        tproc?.renderingMode = ThermalProcRenderingMode.blended
        tproc?.blendingRate = 0.5
        tproc?.probePosition = CGPoint(x: 0.5, y: 0.5)

        // Use the relative palette
        if let palette = relativePalette {
            tproc?.palette = palette
        }
    }
    
    public override func onOpened(session: DroneSession) {
        super.onOpened(session: session)
        startDroneMonitors()
    }
    
    public override func onClosed(session: DroneSession) {
        super.onClosed(session: session)
        resetCamera()
    }
    
    private func startDroneMonitors() {
        // Monitor thermal control peripheral.
        monitorThermalControl()
        // Monitor thermal camera.
        monitorThermalCamera()
        // Monitor stream server.
        monitorStreamServer()

    }
    
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
    
    private func monitorLiveStream(streamServer: StreamServerDesc.ApiProtocol) {
        // Prevent monitoring restart
        if (liveStreamRef != nil || self.session == nil ) { return }

        // Monitor the live stream.
        liveStreamRef = streamServer.live { liveStream in
            // Called when the live stream is available and when it changes.
            // Start to play the live stream only if the thermal camera is active.
            if let liveStream = liveStream {
                if (self.camera?.isActive == true) {
                    self.startVideoStream(liveStream: liveStream)
                }
            }
        }
    }
    
    private func startVideoStream(liveStream: CameraLive) {
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
    
    private func monitorThermalControl() {
        // Prevent monitoring restart
        if (self.thermalControlRef != nil || self.session == nil ) { return }
        
        self.thermalControlRef = (self.session!.drone as? ParrotDroneAdapter)?.drone.getPeripheral(Peripherals.thermalControl) { [weak self] thermalControl in
            if let self = self, let thermalControl = thermalControl {
                
                self.changeMode()

                // Warning: TProc and TProcStreamView should not be used in EMBEDDED mode,
                // the stream should be displayed directly by a GsdkStreamView.

                // In order to the drone video recording look like the local render,
                // send a thermal render settings.
                if (!self.droneThermalRenderInitialized && thermalControl.setting.mode != ThermalControlMode.disabled) {
                    self.sendThermalRenderSettings(thermalControl: thermalControl)
                    self.droneThermalRenderInitialized = true
                }
            }
        }
    }
    
    private func monitorThermalCamera() {
        // Prevent monitoring restart
        if (self.session == nil) { return }
        
        self.camera = (session?.cameraState(channel: self.channel)?.value as? ParrotCameraAdapter)?.camera
        if let camera = self.camera {
            if let liveStream = self.liveStreamRef?.value {
                if (camera.isActive == true && liveStream.playState != CameraLivePlayState.playing) {
                    self.startVideoStream(liveStream: liveStream)
                }
            }
        }
    }
    
    private func changeMode() {
        var mode = ThermalControlMode.disabled
        switch self.channel {
        case 1:
            mode = ThermalControlMode.standard
        default:
            mode = ThermalControlMode.disabled
        }
        // Active the thermal camera, if not yet done.
        if (self.thermalControlRef?.value?.setting.mode != mode) {
            self.thermalControlRef?.value?.setting.mode = mode
        }
    }
    
    public override func update() {
        if let camera = self.camera {
            if let liveStream = self.liveStreamRef?.value {
                if (camera.isActive == true && liveStream.playState != CameraLivePlayState.playing) {
                    self.startVideoStream(liveStream: liveStream)
                }
            }
        }
    }
    
    private func sendThermalRenderSettings(thermalControl: ThermalControl) {
        // To optimize, do not send settings that have not changed.

        // Send rendering mode.
        thermalControl.sendRendering(rendering: ThermalRendering(mode: thermalRenderingModeGsdk(), blendingRate: tproc!.blendingRate))

        // Send emissivity .
        thermalControl.sendEmissivity(tproc!.emissivity)

        // Send Background Temperature.
        thermalControl.sendBackgroundTemperature(tproc!.backgroundTemp)

        // Send thermal palette.
        if let palette = tproc?.palette.toGsdk() {
            thermalControl.sendPalette(palette)
        }
    }
    
    private func thermalRenderingModeGsdk() -> ThermalRenderingMode {
        switch tproc?.renderingMode {
        case .blended:
            return ThermalRenderingMode.blended
        case .monochrome:
            return ThermalRenderingMode.monochrome
        case .thermal:
            return ThermalRenderingMode.thermal
        case .visible:
            return ThermalRenderingMode.visible
        default:
            return ThermalRenderingMode.visible
        }
    }
    
    private func resetCamera() {
        DispatchQueue.main.async { [weak self] in
            self?.liveStreamRef = nil
            self?.camera = nil
            self?.thermalControlRef = nil
            self?.streamView.setStream(stream: nil)
            self?.thermalStreamView.setStream(stream: nil)
        }
    }
}

extension ThermalProcPalette {
    func toGsdk() -> ThermalPalette? {
        var gsdkPalette: ThermalPalette? = nil
        
        if let relativePalette = self as? ThermalProcRelativePalette {
            let colors: [ThermalColor] = relativePalette.colors.map {
                if let palette = $0 as? ThermalProcColor {
                    return ThermalColor(Double(palette.red), Double(palette.green), Double(palette.blue), Double(palette.position))
                }
                return ThermalColor(0.0, 0.0, 0.0, 0.0)
            }
            gsdkPalette = ThermalRelativePalette(colors: colors, locked: relativePalette.isLocked, lowestTemp: relativePalette.lowestTemperature, highestTemp: relativePalette.highestTemperature)
        }
        
        if let absolutePalette = self as? ThermalProcAbsolutePalette {
            let colors: [ThermalColor] = absolutePalette.colors.map {
                if let palette = $0 as? ThermalProcColor {
                    return ThermalColor(Double(palette.red), Double(palette.green), Double(palette.blue), Double(palette.position))
                }
                return ThermalColor(0.0, 0.0, 0.0, 0.0)
            }
            let outsideColorization = (absolutePalette.isLimited) ? ThermalColorizationMode.limited : ThermalColorizationMode.extended
            gsdkPalette = ThermalAbsolutePalette(colors: colors, lowestTemp: absolutePalette.lowestTemperature, highestTemp: absolutePalette.highestTemperature, outsideColorization: outsideColorization)
        }
        
        if let spotPalette = self as? ThermalProcSpotPalette {
            let colors: [ThermalColor] = spotPalette.colors.map {
                if let palette = $0 as? ThermalProcColor {
                    return ThermalColor(Double(palette.red), Double(palette.green), Double(palette.blue), Double(palette.position))
                }
                return ThermalColor(0.0, 0.0, 0.0, 0.0)
            }
            
            var type: ThermalSpotType = ThermalSpotType.cold
            switch spotPalette.temperatureType {
            case .cold:
                type = ThermalSpotType.cold
            case .hot:
                type = ThermalSpotType.hot
            }

            gsdkPalette = ThermalSpotPalette(colors: colors, type: type, threshold: spotPalette.threshold)
        }
        return gsdkPalette
    }
}
