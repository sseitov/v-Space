//
//  InterfaceController.swift
//  Watch Extension
//
//  Created by Сергей Сейтов on 11.12.16.
//  Copyright © 2016 Сергей Сейтов. All rights reserved.
//

import WatchKit
import Foundation
import WatchConnectivity

class InterfaceController: WKInterfaceController, WCSessionDelegate {
  
    @IBOutlet var speedSwitch: WKInterfaceSwitch!
    @IBOutlet var controlButton: WKInterfaceButton!
    @IBOutlet var statusLabel: WKInterfaceLabel!
    
    private var session:WCSession?
    
    private var trackerRunning = false
    private var speedShow = false
    private var speed:Double = 0
    private var distance:Double = 0
    private let statusFont = UIFont(name: "HelveticaNeue-CondensedBold", size: 44)
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        if WCSession.isSupported() {
            session = WCSession.default
            session!.delegate = self
            session!.activate()
        }
        updateUI()
    }
    
    override func willActivate() {
        super.willActivate()
        refresh()
    }
    
    override func didDeactivate() {
        super.didDeactivate()
    }
    
    @IBAction func showSpeed(_ value: Bool) {
        speedShow = value
        if speedShow {
            speedSwitch.setTitle("SPEED")
            setStatusSpeed()
        } else {
            speedSwitch.setTitle("DISTANCE")
            setStatusDistance()
        }
    }
    
    @IBAction func controlTracker() {
        let command = trackerRunning ? ["command" : "stop"] : ["command" : "start"]
        session!.sendMessage(command, replyHandler: { result in
            DispatchQueue.main.async {
                if let isRunning = result["result"] as? Bool {
                    self.trackerRunning = isRunning
                } else {
                    self.trackerRunning = false
                }
                self.updateUI()
            }
        }, errorHandler: { error in
            DispatchQueue.main.async {
                self.presentAlert(withTitle: "", message: "User not published his location.", preferredStyle: .alert, actions: [])
            }
        })
    }
    
    func refresh() {
        session!.sendMessage(["command" : "status"], replyHandler: { status in
            DispatchQueue.main.async {
                if let distance = status["distance"] as? Double {
                    self.distance = distance
                } else {
                    self.distance = 0
                }
                if let speed = status["speed"] as? Double {
                    self.speed = speed
                } else {
                    self.distance = 0
                }
                if let isRunning = status["isRunning"] as? Bool {
                    self.trackerRunning = isRunning
                } else {
                    self.trackerRunning = false
                }
                self.updateUI()
            }
        }, errorHandler: { error in
            DispatchQueue.main.async {
                self.presentAlert(withTitle: "", message: "Connection Error.", preferredStyle: .alert, actions: [])
            }
        })
    }
    
    func updateUI() {
        if trackerRunning {
            controlButton.setBackgroundImageNamed("stopTrack")
            speedSwitch.setEnabled(true)
            if speedShow {
                setStatusSpeed()
            } else {
                setStatusDistance()
            }
        } else {
            controlButton.setBackgroundImageNamed("startTrack")
            speedSwitch.setEnabled(false)
            setStatusOff()
        }
    }
    
    private func setStatusSpeed() {
        let status = NSAttributedString(string: String(format: "%.1f", speed),
                                        attributes: [NSAttributedStringKey.font : statusFont!])
        statusLabel.setAttributedText(status)
        statusLabel.setTextColor(UIColor.color(0, 219, 123, 1))
    }
    
    private func setStatusDistance() {
        let status = NSAttributedString(string: String(format: "%.2f", distance),
                                        attributes: [NSAttributedStringKey.font : statusFont!])
        statusLabel.setAttributedText(status)
        statusLabel.setTextColor(UIColor.white)
    }
    
    private func setStatusOff() {
        let status = NSAttributedString(string: "OFF", attributes: [NSAttributedStringKey.font : statusFont!])
        statusLabel.setAttributedText(status)
        statusLabel.setTextColor(UIColor.lightGray)
    }
}

extension InterfaceController {
    
    @available(iOS 9.3, *)
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        refresh()
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("sessionDidBecomeInactive")
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        print("sessionDidDeactivate")
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        print("sessionReachabilityDidChange")
    }
    
    // Receiver
    func session(session: WCSession, didReceiveApplicationContext applicationContext: [String : AnyObject]) {
        print("didReceiveApplicationContext")
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        print("didReceiveMessage")
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        print("didReceiveMessage replyHandler")
    }

}
