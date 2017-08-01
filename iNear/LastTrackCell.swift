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
    func accessDenied()
}

class LastTrackCell: UITableViewCell {

    @IBOutlet weak var statusSwitch: UISwitch!
    @IBOutlet weak var statusLabel: UILabel!
    
    var delegate:LastTrackCellDelegate? {
        didSet {
            statusSwitch.isOn = Model.shared.trackerIsRunning()
            if !statusSwitch.isOn {
                statusLabel.text = NSLocalizedString("Tracker not running", comment: "").uppercased()
                statusLabel.textColor = UIColor.lightGray
                accessoryType = .none
            } else {
                statusLabel.text = String(format: NSLocalizedString("trackFormat", comment: ""),
                                          Model.shared.lastTrackDistance(),
                                          Model.shared.lastTrackSpeed())
                statusLabel.textColor = UIColor.mainColor()
                let count = Model.shared.lastTrackSize()
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
            LocationManager.shared.registered({ enabled in
                if enabled {
                    Model.shared.clearLastTrack()
                    LocationManager.shared.startInBackground()
                    self.statusLabel.text = NSLocalizedString("Tracker starting", comment: "").uppercased()
                } else {
                    sender.isOn = false
                    self.delegate?.accessDenied()
                }
            })
        } else {
            LocationManager.shared.stop()
            statusLabel.text = NSLocalizedString("Tracker not running", comment: "").uppercased()
            delegate?.saveLastTrack()
        }
        accessoryType = .none
        statusLabel.textColor = UIColor.lightGray
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        statusLabel.text = NSLocalizedString("Tracker not running", comment: "").uppercased()
        accessoryType = .none
    }
}
