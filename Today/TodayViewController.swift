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
            
    @IBOutlet weak var nonActive: UILabel!
    @IBOutlet weak var headerView: UIView!
    @IBOutlet weak var distance: UILabel!
    @IBOutlet weak var speed: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.openApp))
        self.view.addGestureRecognizer(tap)
        self.extensionContext?.widgetLargestAvailableDisplayMode = .compact
        refresh()
    }
    
    func widgetPerformUpdate(completionHandler: (@escaping (NCUpdateResult) -> Void)) {
        refresh()
        completionHandler(NCUpdateResult.newData)
    }
    
    func refresh() {
        if Model.shared.isRunning() {
            nonActive.isHidden = true
            headerView.isHidden = false
            distance.isHidden = false
            speed.isHidden = false
            distance.text = String(format: "%.2f", Model.shared.lastTrackDistance())
            speed.text = String(format: "%.1f", Model.shared.lastTrackSpeed())
        } else {
            nonActive.isHidden = false
            headerView.isHidden = true
            distance.isHidden = true
            speed.isHidden = true
        }
    }
    
    func openApp() {
        extensionContext?.open(URL(string: "iNearby://")!, completionHandler: nil)
    }

}
