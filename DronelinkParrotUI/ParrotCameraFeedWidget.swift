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

public class ParrotCameraFeedWidget: DelegateWidget {
    public let streamView = StreamView(frame: CGRect.zero)
    private var streamServerRef: Ref<StreamServer>?
    private var liveStreamRef: Ref<CameraLive>?

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(streamView)
        streamView.snp.makeConstraints { [weak self] make in
            make.edges.equalToSuperview()
        }
    }

    public override func onOpened(session: DroneSession) {
        super.onOpened(session: session)

        streamServerRef = (session.drone as? ParrotDroneAdapter)?.drone.getPeripheral(Peripherals.streamServer) { [weak self] streamServer in
            if let self = self, let streamServer = streamServer {
                streamServer.enabled = true
                self.liveStreamRef = streamServer.live { liveStream in
                    if let liveStream = liveStream {
                        self.streamView.setStream(stream: liveStream)
                        _ = liveStream.play()
                    }
                }
            }
        }
    }

    public override func onClosed(session: DroneSession) {
        super.onClosed(session: session)

        DispatchQueue.main.async { [weak self] in
            self?.liveStreamRef = nil
            self?.streamView.setStream(stream: nil)
        }
    }
}
