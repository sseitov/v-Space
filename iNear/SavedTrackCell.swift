//
//  SavedTrackCell.swift
//  v-Space
//
//  Created by Сергей Сейтов on 30.03.17.
//  Copyright © 2017 Сергей Сейтов. All rights reserved.
//

import UIKit
import Photos

class SavedTrackCell: UITableViewCell {

    @IBOutlet weak var lastPhoto: UIImageView!
    @IBOutlet weak var placeLabel: UILabel!
    @IBOutlet weak var startDateLabel: UILabel!
    @IBOutlet weak var finishDateLabel: UILabel!
    
    var track:Track? {
        didSet {
            if track!.allPhotos().count > 0 {
                placeLabel.text = "\(track!.place!) (\(track!.allPhotos().count) \(NSLocalizedString("Photo", comment: "")))"
            } else {
                placeLabel.text = track!.place
            }
            startDateLabel.text = "START: \(textDateFormatter().string(from: (track!.startDate! as Date)))"
            finishDateLabel.text = "FINISH: \(textDateFormatter().string(from: (track!.finishDate! as Date)))"
            if track!.allPhotos().count > 0 {
                let photo = track!.allPhotos()[0]
                
                if let asset = PHAsset.fetchAssets(withLocalIdentifiers: [photo.uid!], options: nil).firstObject {
                    PHImageManager.default().requestImage(for: asset, targetSize: lastPhoto.bounds.size, contentMode: .aspectFit, options: nil, resultHandler: { image, _ in
                        if image != nil {
                            self.lastPhoto.image = image!.withSize(self.lastPhoto.bounds.size).inCircle()
                        } else {
                            self.lastPhoto.image = UIImage(named: "logo")
                        }
                    })
                } else {
                    lastPhoto.image = UIImage(named: "logo")
                }

            } else {
                lastPhoto.image = UIImage(named: "logo")
            }
        }
    }
}
