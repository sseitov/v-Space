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
    @IBOutlet weak var stateView: UIView!
    @IBOutlet weak var distance: UILabel!
    @IBOutlet weak var speed: UILabel!
    
    var delegate:LastTrackCellDelegate? {
        didSet {
            statusSwitch.isOn = Model.shared.trackerIsRunning()
            if !statusSwitch.isOn {
                stateView.isHidden = true
                statusLabel.text = NSLocalizedString("Tracker not running", comment: "").uppercased()
                accessoryType = .none
            } else {
                distance.text = String(format: "%.2f", Model.shared.lastTrackDistance())
                speed.text = String(format: "%.1f", Model.shared.lastTrackSpeed())
                stateView.isHidden = false
                if Model.shared.lastTrackSize() < 2 {
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
            stateView.isHidden = true
            statusLabel.text = NSLocalizedString("Tracker not running", comment: "").uppercased()
            delegate?.saveLastTrack()
        }
        accessoryType = .none
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        statusLabel.text = NSLocalizedString("Tracker not running", comment: "").uppercased()
        stateView.isHidden = true
        accessoryType = .none
    }
}
