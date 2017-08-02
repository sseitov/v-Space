//
//  PhotoCell.swift
//  v-Space
//
//  Created by Sergey Seitov on 01.08.17.
//  Copyright © 2017 Сергей Сейтов. All rights reserved.
//

import UIKit
import Photos

class PhotoCell: UICollectionViewCell {
    
    @IBOutlet weak var thumbView: UIImageView!
    @IBOutlet weak var dateView: UILabel!
    @IBOutlet weak var checkView: UIImageView!
    
    var photo:Photo? {
        didSet {
            if photo != nil {
                if let asset = PHAsset.fetchAssets(withLocalIdentifiers: [photo!.uid!], options: nil).firstObject {
                    PHImageManager.default().requestImage(for: asset, targetSize: thumbView.bounds.size, contentMode: .aspectFit, options: nil, resultHandler: { image, _ in
                        self.thumbView.image = image
                    })
                } else {
                    self.thumbView.image = UIImage(named: "photo")
                }
                let date = Date(timeIntervalSince1970: photo!.date)
                dateView.text = textTimeFormatter().string(from: date)
            }
            checkView.isHidden = !isSelected
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        checkView.isHidden = true
    }
    
}
