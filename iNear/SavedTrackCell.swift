//
//  SavedTrackCell.swift
//  v-Space
//
//  Created by Сергей Сейтов on 30.03.17.
//  Copyright © 2017 Сергей Сейтов. All rights reserved.
//

import UIKit

class SavedTrackCell: UITableViewCell {

    @IBOutlet weak var lastPhoto: UIImageView!
    @IBOutlet weak var placeLabel: UILabel!
    @IBOutlet weak var distanceLabel: UILabel!
    @IBOutlet weak var startDateLabel: UILabel!
    @IBOutlet weak var finishDateLabel: UILabel!
    
    var track:Track? {
        didSet {
            placeLabel.text = track!.place
            startDateLabel.text = textDateFormatter().string(from: (track!.startDate! as Date))
            finishDateLabel.text = textDateFormatter().string(from: (track!.finishDate! as Date))
            distanceLabel.text = String(format: "%.1f km", track!.distance)
            lastPhoto.image = UIImage(named: "logo")
        }
    }
}
