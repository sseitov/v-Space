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
  
    @IBOutlet var refreshButton: WKInterfaceButton!
    @IBOutlet var trackerButton: WKInterfaceButton!
    @IBOutlet var clearButton: WKInterfaceButton!
    @IBOutlet var showButton: WKInterfaceButton!
    @IBOutlet var counter: WKInterfaceLabel!
    
    private var session:WCSession?
    private var trackerRunning = false
    private var lastLocation:[String:Any]?
//    private var trackSize:Int = 0
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        if WCSession.isSupported() {
            session = WCSession.default()
            session!.delegate = self
            session!.activate()
            enableButtons(0)
        }
    }
    
    override func willActivate() {
        super.willActivate()
        refreshStatus()
    }
    
    override func didDeactivate() {
        super.didDeactivate()
    }

    private func formattedDate(date:Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM HH:mm:ss"
        return formatter.string(from: date).uppercased()
    }

    private func enableButtons(_ size:Int) {
        clearButton.setEnabled(size > 1)
        showButton.setEnabled(size > 1)
        let text = size > 0 ? "\(size)" : ""
        self.counter.setText(text)

    }
    
    @IBAction func refreshStatus() {
        session!.sendMessage(["command" : "status"], replyHandler: { status in
            DispatchQueue.main.async {
                if let isRunning = status["isRunning"] as? Bool {
                    self.trackerRunning = isRunning
                } else {
                    self.trackerRunning = false
                }
                if self.trackerRunning {
                    self.trackerButton.setBackgroundImageNamed("stopTrack")
                } else {
                    self.trackerButton.setBackgroundImageNamed("startTrack")
                }

                if let date = status["lastDate"] as? Date {
                    self.refreshButton.setTitle(self.formattedDate(date: date))
                } else {
                    self.refreshButton.setTitle("REFRESH")
                }
                
                self.lastLocation = status["lastLocation"] as? [String:Any]
                if let size = status["trackSize"] as? Int {
                    self.enableButtons(size)
                } else {
                    self.enableButtons(0)
                }
            }
        }, errorHandler: { error in
            DispatchQueue.main.async {
                self.presentAlert(withTitle: "", message: "User not published his location.", preferredStyle: .alert, actions: [])
            }
        })
    }
    
    @IBAction func controlTracker() {
        let command = trackerRunning ? ["command" : "stop"] : ["command" : "start"]
        session!.sendMessage(command, replyHandler: { result in
            DispatchQueue.main.async {
                if let isRunning = result["result"] as? Bool {
                    self.trackerRunning = isRunning
                    if isRunning {
                        self.trackerButton.setBackgroundImageNamed("stopTrack")
                    } else {
                        self.trackerButton.setBackgroundImageNamed("startTrack")
                    }
                } else {
                    self.trackerButton.setBackgroundImageNamed("startTrack")
                }
            }
        }, errorHandler: { error in
            DispatchQueue.main.async {
                self.presentAlert(withTitle: "", message: "User not published his location.", preferredStyle: .alert, actions: [])
            }
        })
    }
    
    @IBAction func clearTrack() {
        session!.sendMessage(["command": "clear"], replyHandler: { result in
            DispatchQueue.main.async {
                self.enableButtons(0)
            }
        }, errorHandler: { error in
            DispatchQueue.main.async {
                self.presentAlert(withTitle: "", message: "User not published his location.", preferredStyle: .alert, actions: [])
            }
        })
    }
    
    override func contextForSegue(withIdentifier segueIdentifier: String) -> Any? {
        if segueIdentifier == "showTrack" {
            return lastLocation
        } else {
            return nil
        }
    }
}

extension InterfaceController {
    
    @available(iOS 9.3, *)
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        refreshStatus()
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
