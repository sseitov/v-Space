//
//  TodayViewController.swift
//  Today
//
//  Created by Сергей Сейтов on 01.03.17.
//  Copyright © 2017 Сергей Сейтов. All rights reserved.
//

import UIKit
import NotificationCenter

class TodayViewController: UIViewController, NCWidgetProviding {
            
    @IBOutlet weak var recordButton: UIButton!
    @IBOutlet weak var trashButton: UIButton!
    @IBOutlet weak var observeButton: UIButton!
    @IBOutlet weak var dateButton: UIButton!
    @IBOutlet weak var trackCounter: UILabel!
    @IBOutlet weak var observeLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        dateButton.setupBorder(UIColor.clear, radius: 15)
        self.extensionContext?.widgetLargestAvailableDisplayMode = .compact
    }
    
    private func formattedDate(_ date:Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM HH:mm:ss"
        return formatter.string(from: date).uppercased()
    }

    private func enableTrackerButtons(_ count:Int) {
        trashButton.alpha = count > 1 ? 1 : 0.4
        trashButton.isEnabled = count > 1
        observeButton.alpha = count > 1 ? 1 : 0.4
        observeButton.isEnabled = count > 1
        trackCounter.text = count > 1 ? "CLEAR \(count)" : ""
        observeLabel.text = count > 1 ? "SHOW TRACK" : ""
    }
    
    func widgetPerformUpdate(completionHandler: (@escaping (NCUpdateResult) -> Void)) {
        self.refresh()
        completionHandler(NCUpdateResult.newData)
    }
    
    @IBAction func refresh() {
        if let date = LocationManager.shared.myLastLocationDate() {
            dateButton.setTitle("LAST POINT: \(formattedDate(date))", for: .normal)
        } else {
            dateButton.setTitle("REFRESH STATUS", for: .normal)
        }
        if LocationManager.shared.isRunning() {
            recordButton.setImage(UIImage(named: "stop"), for: .normal)
        } else {
            recordButton.setImage(UIImage(named: "location"), for: .normal)
        }
        enableTrackerButtons(LocationManager.shared.trackSize())
    }
    
    @IBAction func startTracker(_ sender: UIButton) {
        if LocationManager.shared.isRunning() {
            LocationManager.shared.stop()
            recordButton.setImage(UIImage(named: "location"), for: .normal)
        } else {
            LocationManager.shared.start()
            recordButton.setImage(UIImage(named: "stop"), for: .normal)
        }
    }
    
    @IBAction func clearTracker(_ sender: Any) {
        LocationManager.shared.clearTrack()
        dateButton.setTitle("REFRESH STATUS", for: .normal)
        enableTrackerButtons(LocationManager.shared.trackSize())
    }
    
    @IBAction func openApp(_ sender: Any) {
        extensionContext?.open(URL(string: "iNearby://")!, completionHandler: nil)
    }

}
