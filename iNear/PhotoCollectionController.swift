//
//  PhotoCollectionController.swift
//  v-Space
//
//  Created by Sergey Seitov on 01.08.17.
//  Copyright © 2017 Сергей Сейтов. All rights reserved.
//

import UIKit

class PhotoCollectionController: UICollectionViewController {

    var track:Track?
    private var photos:[Photo] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()

        if track != nil {
            let dateStr = textShortDateFormatter().string(from: (track!.finishDate! as Date))
            setupTitle("\(track!.place!) (\(NSLocalizedString("Photo", comment: "")))\n\(dateStr)")
            photos = track!.allPhotos().sorted(by: { photo1, photo2 in
                return photo1.date > photo2.date
            })
        }
        setupBackButton()
        
    }
/*
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        guard let flowLayout = collectionView!.collectionViewLayout as? UICollectionViewFlowLayout else {
            return
        }
        flowLayout.invalidateLayout()
    }
*/
    // MARK: UICollectionViewDataSource

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return photos.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "photo", for: indexPath) as! PhotoCell
        cell.photo = photos[indexPath.row]
        return cell
    }

    // MARK: UICollectionViewDelegate

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: IndexPath) -> CGSize {
        let columns:CGFloat = IS_PAD() ? 3.0 : 2.0
        let w = (self.view.frame.size.width - 40.0) / columns
        return CGSize(width: w, height: w+20)
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        performSegue(withIdentifier: "showPhoto", sender: photos[indexPath.row])
    }
    
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showPhoto" {
            let next = segue.destination as! PhotoController
            next.photo = sender as? Photo
        }
    }

}
