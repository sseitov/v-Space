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
                statusLabel.text = "Tracker not running".uppercased()
                statusLabel.textColor = UIColor.lightGray
                accessoryType = .none
            } else {
                statusLabel.text = String(format: "DISTANCE km\t%.2f\nSPEED km/h\t\t%.1f",
                                          LocationManager.shared.lastTrackDistance(),
                                          LocationManager.shared.lastTrackSpeed())
                statusLabel.textColor = UIColor.mainColor()
                let count = LocationManager.shared.lastTrackSize()
                if count < 2 {
                    accessoryType = .none
                } else {
                    accessoryType = .disclosureIndicator
                }
            }
        }
    }
    
    @IBAction func switchStatus(_ sender: UISwitch) {
        if sender.isOn {
            LocationManager.shared.startInBackground()
            statusLabel.text = "Tracker starting".uppercased()
        } else {
            LocationManager.shared.stop()
            statusLabel.text = "Tracker not running".uppercased()
            accessoryType = .none
            delegate?.saveLastTrack()
        }
        statusLabel.textColor = UIColor.lightGray
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        statusLabel.text = "Tracker not running".uppercased()
        accessoryType = .none
    }
}
