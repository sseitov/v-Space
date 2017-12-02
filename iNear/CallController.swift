//
//  CallController.swift
//  v-Space
//
//  Created by Сергей Сейтов on 16.11.2017.
//  Copyright © 2017 Сергей Сейтов. All rights reserved.
//

import UIKit
import Firebase
import SVProgressHUD

let acceptCallNotification = Notification.Name("ACCEPT_CALL")
let hangUpCallNotification = Notification.Name("HANGUP_CALL")

class CallController: UIViewController {

    @IBOutlet weak var callView: UIView!
    @IBOutlet weak var ringView: UIImageView!
    @IBOutlet weak var remoteView: RTCEAGLVideoView!
    @IBOutlet weak var localView: RTCCameraPreviewView!
    @IBOutlet weak var videoButton: UIBarButtonItem!
    @IBOutlet weak var loudButton: UIBarButtonItem!

    var userName:String?
    var userID:String?
    var callID:String?
    
    var rtcClient:ARDAppClient?
    var videoTrack:RTCVideoTrack?
    var videoSize:CGSize = CGSize()
    var cameraController:ARDCaptureController?

    var isLoud = true {
        didSet {
            if isLoud {
                loudButton.image = UIImage(named: "loudOn")
            } else {
                loudButton.image = UIImage(named: "loudOff")
            }
        }
    }
    var isVideo = true {
        didSet {
            if isVideo {
                videoButton.image = UIImage(named: "videoOn")
            } else {
                videoButton.image = UIImage(named: "videoOff")
            }
        }
    }

    deinit {
        print("&&&&&&&&&&&&&&&&&&& DEINIT")
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupBackButton()
        setupTitle(userName!)

        remoteView.delegate = self

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.hangUpCall),
                                               name: hangUpCallNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.acceptCall),
                                               name: acceptCallNotification,
                                               object: nil)

        if callID == nil {
            callID = UUID().uuidString
            SVProgressHUD.show()
            PushManager.shared.callRequest(callID!, toID: userID!, success: { isSuccess in
                SVProgressHUD.dismiss()
                if !isSuccess {
                    self.showMessage("requestError".localized, messageType: .error, messageHandler: {
                        self.callID = nil
                        self.goBack()
                    })
                } else {
                    self.callView.isHidden = false
                    var gifs:[UIImage] = []
                    for i in 0..<24 {
                        gifs.append(UIImage(named: "ring_frame_\(i).gif")!)
                    }
                    self.ringView.animationImages = gifs
                    self.ringView.animationDuration = 2
                    self.ringView.animationRepeatCount = 0
                    self.ringView.startAnimating()
                    
                    Ringtone.shared.playCall()
                }
            })
        } else {
            callView.isHidden = true
            connect()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        MainApp().closeCall()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if videoTrack != nil {
            updateVideoSize()
        }
        resizePreview()
    }

    // MARK: - Video views resizing

    func updateVideoSize() {
        if videoSize.width > 0 && videoSize.height > 0 {
            var remoteVideoFrame = AVMakeRect(aspectRatio: videoSize, insideRect: view.bounds)
            var scale:CGFloat = 1
            if (remoteVideoFrame.size.width > remoteVideoFrame.size.height) {
                // Scale by height.
                scale = view.bounds.size.height / remoteVideoFrame.size.height;
            } else {
                // Scale by width.
                scale = view.bounds.size.width / remoteVideoFrame.size.width;
            }
            remoteVideoFrame.size.height *= scale;
            remoteVideoFrame.size.width *= scale;
            remoteView.frame = remoteVideoFrame
            remoteView.center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        }
    }

    private func IS_PORTRAIT() -> Bool {
        return UIScreen.main.bounds.size.width < UIScreen.main.bounds.size.height;
    }

    func resizePreview() {
        let maxWidth:CGFloat = 640
        let maxHeight:CGFloat = 480

        let maxVal = max(maxWidth, maxHeight)
        let minVal = min(maxWidth, maxHeight)
        let previewAspect = maxVal/minVal

        var previewWidth:CGFloat = 0
        var previewHeight:CGFloat = 0
        let previewSize:CGFloat = IS_PAD() ? 180 : 120
    
        if (IS_PORTRAIT()) {
            previewWidth = previewSize
            previewHeight = previewSize * previewAspect
        } else {
            previewHeight = previewSize
            previewWidth = previewSize * previewAspect
        }

        let aCircle:CAShapeLayer = CAShapeLayer()
        let path:UIBezierPath = UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: previewSize, height: previewSize))
        aCircle.path = path.cgPath
    
        if (IS_PORTRAIT()) {
            aCircle.position = CGPoint(x: 0, y: (previewHeight - previewSize)/2)
        } else {
            aCircle.position = CGPoint(x: (previewWidth - previewSize)/2, y: 0)
        }

        localView.layer.mask = aCircle
        localView.clipsToBounds = true

        let pos = previewPosition(previewSize: CGSize(width:previewWidth, height:previewHeight), size: previewSize)
        localView.frame = CGRect(x: pos.x, y: pos.y, width: previewWidth, height: previewHeight)
    }
    
    private func previewPosition(previewSize:CGSize, size:CGFloat) -> CGPoint {
        var rightPadding:CGFloat = 0
        var bottomPadding:CGFloat = 0
        
        if (IS_PORTRAIT()) {
            rightPadding = 20;
            bottomPadding = 20 - (previewSize.height - size)/2;
        } else {
            bottomPadding = 20;
            rightPadding = 20 - (previewSize.width - size)/2;
        }
        let x = self.view.frame.size.width - round(rightPadding) - previewSize.width
        let y = self.view.frame.size.height - round(bottomPadding) - previewSize.height;
        return CGPoint(x: x, y: y);
    }
    
    // MARK: - Notifications
    
    @objc func acceptCall() {
        ringView.stopAnimating()
        callView.isHidden = true
        connect()
    }
    
    @objc func hangUpCall() {
        self.ringView.stopAnimating()
        self.ringView.image = UIImage(named: "ring_frame_0.gif")
        if rtcClient != nil {
            disconnect()
            goBack()
        } else {
            Ringtone.shared.playBusy()
        }
    }

    // MARK: - Commands

    override func goBack() {
        if rtcClient != nil {
            yesNoQuestion("Want you hang up?", acceptLabel: "Yes", cancelLabel: "Cancel", acceptHandler: {
                SVProgressHUD.show()
                PushManager.shared.pushCommand(self.userID!, command:"hangup", success: { _ in
                    SVProgressHUD.dismiss()
                    self.disconnect()
                    self.dismiss(animated: true, completion: nil)
                })
            })
        } else {
            Ringtone.shared.stop()
            SVProgressHUD.show()
            PushManager.shared.pushCommand(self.userID!, command:"hangup", success: { _ in
                SVProgressHUD.dismiss()
                self.dismiss(animated: true, completion: nil)
            })
        }
    }
    
    func connect() {
        Ringtone.shared.stop()
        rtcClient = ARDAppClient(delegate: self)
        let settings = ARDSettingsModel()
        rtcClient?.connectToRoom(withId: callID!,
                                 settings: settings,
                                 isLoopback: false,
                                 isAudioOnly: false,
                                 shouldMakeAecDump: false,
                                 shouldUseLevelControl: false)
    }
    
    func disconnect() {
        videoTrack?.remove(remoteView)
        videoTrack = nil
        remoteView.renderFrame(nil)
        
        localView.captureSession = nil
        cameraController?.stopCapture()
        cameraController = nil
        rtcClient?.disconnect()
        ARDAppClient.hangUp()
        rtcClient = nil
    }
    
    @IBAction func muteVideo(_ sender: UIBarButtonItem) {
        if isVideo {
            cameraController?.stopCapture()
            isVideo = false
        } else {
            cameraController?.startCapture()
            isVideo = true
        }
    }
    
    @IBAction func switchSpeaker(_ sender: UIBarButtonItem) {
        ARDAppClient.enableLoudspeaker(!isLoud)
        isLoud = ARDAppClient.isLoudSpeaker()
    }

}

extension CallController : ARDAppClientDelegate {
    
    func appClient(_ client: ARDAppClient!, didError error: Error!) {
        DispatchQueue.main.async {
            self.showMessage("Error: \(error.localizedDescription)", messageType: .error, messageHandler: {
                self.goBack()
            })
        }
    }
    
    func appClient(_ client: ARDAppClient!, didChange state: ARDAppClientState) {
        switch state {
        case .connecting:
            break
        case .connected:
            break
        case .disconnected:
            break
        }
    }
    
    func appClient(_ client: ARDAppClient!, didChange state: RTCIceConnectionState) {
        switch state {
        case .new:
            print("$$$$$ new")
        case .checking:
            print("$$$$$ checking")
        case .connected:
            print("$$$$$ connected")
        case .completed:
            print("$$$$$ completed")
        case .failed:
            print("$$$$$ failed")
        case .disconnected:
            print("$$$$$ disconnected")
        case .closed:
            print("$$$$$ closed")
        case .count:
            print("$$$$$ count")
        }
    }
    
    func appClient(_ client: ARDAppClient!, didGetStats stats: [Any]!) {
    }
    
    func appClient(_ client: ARDAppClient!, didReceiveLocalVideoTrack localVideoTrack: RTCVideoTrack!) {
        print("================== didReceiveLocalVideoTrack \(Thread.current)")
    }
    
    func appClient(_ client: ARDAppClient!, didCreateLocalCapturer localCapturer: RTCCameraVideoCapturer!) {
        print("================== didCreateLocalCapturer \(Thread.current)")
        DispatchQueue.main.async {
            self.localView.captureSession = localCapturer.captureSession
            self.cameraController = ARDCaptureController(capturer: localCapturer, settings: ARDSettingsModel())
            self.cameraController?.startCapture()
            self.isVideo = true
        }
    }
    
    func appClient(_ client: ARDAppClient!, didReceiveRemoteVideoTrack remoteVideoTrack: RTCVideoTrack!) {
        print("================== didReceiveRemoteVideoTrack \(Thread.current)")
        videoTrack = remoteVideoTrack
        videoTrack?.add(self.remoteView)
    }
    
    func appClient(_ client: ARDAppClient!, didReceiveRemoteAudioTracks remoteAudioTrack: RTCAudioTrack!) {
        ARDAppClient.enableLoudspeaker(true)
        isLoud = ARDAppClient.isLoudSpeaker()
    }
    
}

extension CallController : RTCEAGLVideoViewDelegate {
    
    func videoView(_ videoView: RTCEAGLVideoView, didChangeVideoSize size: CGSize) {
        print("================== didChangeVideoSize \(Thread.current)")
        videoSize = size
        updateVideoSize()
    }
}

