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
    
    private var ringPlayer:AVAudioPlayer?
    private var busyPlayer:AVAudioPlayer?

    var isLoud = false {
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

    override func viewDidLoad() {
        super.viewDidLoad()
        setupBackButton()
        
        remoteView.delegate = self
        ARDAppClient.enableLoudspeaker(true)

        if userName != nil {
            setupTitle(userName!)
        }
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.hangUpCall),
                                               name: hangUpCallNotification,
                                               object: nil)

        if callID == nil {
            callID = UUID().uuidString
            PushManager.shared.callRequest(callID!, toID: userID!, success: { isSuccess in
                if !isSuccess {
                    self.showMessage(LOCALIZE("requestError"), messageType: .error, messageHandler: {
                        self.goBack()
                    })
                } else {
                    self.ringPlayer = try? AVAudioPlayer(contentsOf: Bundle.main.url(forResource: "calling", withExtension: "wav")!)
                    self.ringPlayer?.numberOfLoops = -1
                    self.ringPlayer!.prepareToPlay()
                    self.ringPlayer?.play()
                    
                    self.ringView.isHidden = false
                    var gifs:[UIImage] = []
                    for i in 0..<24 {
                        gifs.append(UIImage(named: "ring_frame_\(i).gif")!)
                    }
                    self.ringView.animationImages = gifs
                    self.ringView.animationDuration = 2
                    self.ringView.animationRepeatCount = 0
                    self.ringView.startAnimating()
                }
            })
        } else {
            ringView.isHidden = true
            SVProgressHUD.show()
            PushManager.shared.pushCommand(self.userID!, command:"accept", success: { result in
                SVProgressHUD.dismiss()
                if !result {
                    self.showMessage(LOCALIZE("requestError"), messageType: .error)
                } else {
                    self.connect()
                }
            })
        }
    }

    override func goBack() {
        if callID != nil {
            yesNoQuestion("Want you hang up?", acceptLabel: "Yes", cancelLabel: "Cancel", acceptHandler: {
                SVProgressHUD.show()
                PushManager.shared.pushCommand(self.userID!, command:"hangup", success: { result in
                    SVProgressHUD.dismiss()
                    if !result {
                        self.showMessage(LOCALIZE("requestError"), messageType: .error)
                    }
                })
                if self.rtcClient != nil {
                    self.disconnect()
                    self.dismiss(animated: true, completion: nil)
                }
            })
        } else {
            if self.busyPlayer != nil {
                self.busyPlayer?.stop()
                self.busyPlayer = nil
                dismiss(animated: true, completion: nil)
            } else if self.rtcClient != nil {
                self.disconnect()
                dismiss(animated: true, completion: nil)
            }
        }

    }
    
    func connect() {
        rtcClient = ARDAppClient(delegate: self)
        let settings = ARDSettingsModel()
        rtcClient?.connectToRoom(withId: callID,
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
    
    @objc func acceptCall() {
        ringPlayer?.stop()
        ringPlayer = nil
        ringView.stopAnimating()
        ringView.isHidden = true
        connect()
    }
    
    @objc func hangUpCall() {
        if self.ringPlayer != nil {
            self.ringPlayer?.stop()
            self.ringPlayer = nil
            
            self.busyPlayer = try? AVAudioPlayer(contentsOf: Bundle.main.url(forResource: "busy", withExtension: "wav")!)
            self.busyPlayer?.numberOfLoops = -1
            self.busyPlayer!.prepareToPlay()
            self.busyPlayer?.play()
            callID = nil
        } else {
            callID = nil
            goBack()
        }
    }
    
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
    }
    
    func appClient(_ client: ARDAppClient!, didCreateLocalCapturer localCapturer: RTCCameraVideoCapturer!) {
        print("================== didCreateLocalCapturer \(Thread.current)")
        DispatchQueue.main.async {
            self.localView.captureSession = localCapturer.captureSession
            self.localView.setupBorder(UIColor.yellow, radius: 5, width: 2)
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
