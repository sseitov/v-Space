//
//  TrackerCell.swift
//  iNear
//
//  Created by Сергей Сейтов on 03.03.17.
//  Copyright © 2017 Сергей Сейтов. All rights reserved.
//

import UIKit

protocol TrackerCellDelegate {
    func trackerStatusChanged()
}

class TrackerCell: UITableViewCell {

    @IBOutlet weak var trackerSwitch: UISwitch!

    var delegate:TrackerCellDelegate? {
        didSet {
            trackerSwitch.isOn = LocationManager.shared.isRunning()
        }
    }
    
    @IBAction func runTracker(_ sender: UISwitch) {
        if sender.isOn {
            LocationManager.shared.startInBackground()
        } else {
            LocationManager.shared.stop()
        }
        delegate?.trackerStatusChanged()
    }

}
