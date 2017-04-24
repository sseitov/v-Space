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
    @IBOutlet weak var dateLabel: UILabel!
    
    var track:Track? {
        didSet {
            placeLabel.text = track!.place
            dateLabel.text = textDateFormatter().string(from: (track!.finishDate! as Date))
            lastPhoto.image = UIImage(named: "logo")
        }
    }
}
