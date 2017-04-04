//
//  PhotoController.swift
//  v-Space
//
//  Created by Сергей Сейтов on 03.04.17.
//  Copyright © 2017 Сергей Сейтов. All rights reserved.
//

import UIKit
import Photos

class PhotoController: UIViewController, UIScrollViewDelegate {

    @IBOutlet var scrollView: UIScrollView!
    @IBOutlet weak var photoImage: UIImageView!
    
    var photo:Photo?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTitle(textDateFormatter().string(from: photo!.creationDate! as Date))
        setupBackButton()
        
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 5.0

    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        scrollView.contentSize = photoImage.frame.size

        if let asset = PHAsset.fetchAssets(withLocalIdentifiers: [photo!.uid!], options: nil).firstObject {
            PHImageManager.default().requestImage(for: asset, targetSize: photoImage.bounds.size, contentMode: .aspectFit, options: nil, resultHandler: { image, _ in
                self.photoImage.image = image
            })
        } else {
            showMessage("Can not load photo.", messageType: .error)
        }
    }
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return photoImage
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
