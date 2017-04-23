//
//  LastTrackCell.swift
//  v-Space
//
//  Created by Сергей Сейтов on 30.03.17.
//  Copyright © 2017 Сергей Сейтов. All rights reserved.
//

import UIKit

protocol LastTrackCellDelegate {
    func saveLastTrack()
}

class LastTrackCell: UITableViewCell {

    @IBOutlet weak var statusSwitch: UISwitch!
    @IBOutlet weak var statusLabel: UILabel!
    
    var delegate:LastTrackCellDelegate? {
        didSet {
            statusSwitch.isOn = LocationManager.shared.isRunning()
            if !statusSwitch.isOn {
                statusLabel.text = "Tracker not running"
                statusLabel.textColor = UIColor.lightGray
                accessoryType = .none
            } else {
                let count = LocationManager.shared.lastTrackSize()
                if count < 2 {
                    statusLabel.text = "Current track has \(count) point"
                    statusLabel.textColor = UIColor.lightGray
                    accessoryType = .none
                } else {
                    statusLabel.text = "Current track has \(count) points"
                    statusLabel.textColor = UIColor.mainColor()
                    accessoryType = .disclosureIndicator
                }
            }
        }
    }
    
    @IBAction func switchStatus(_ sender: UISwitch) {
        if sender.isOn {
            LocationManager.shared.startInBackground()
            statusLabel.text = "Tracker starting"
        } else {
            LocationManager.shared.stop()
            statusLabel.text = "Tracker not running"
            delegate?.saveLastTrack()
        }
        statusLabel.textColor = UIColor.lightGray
    }

}
