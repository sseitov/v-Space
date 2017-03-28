//
//  PhotoController.swift
//  Popppins
//
//  Created by Сергей Сейтов on 02.12.16.
//  Copyright © 2016 Aoge He. All rights reserved.
//

import UIKit

class PhotoController: UIViewController, UIScrollViewDelegate {

    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var photoView: UIImageView!
    
    var image:UIImage?
    var date:Date?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if date != nil {
            setupTitle("Picture was sent \(Model.shared.textDateFormatter.string(from: date!))")
        }
        if image != nil {
            photoView.image = image
        }
        setupBackButton()
        
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 5.0
        scrollView.contentSize = photoView.frame.size
    }
    
    // MARK: - Scrollview delegate
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return photoView
    }
    
    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
    }

    override func goBack() {
        _ = navigationController?.popViewController(animated: true)
    }

}
