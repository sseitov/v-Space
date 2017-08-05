//
//  PhotoCollectionController.swift
//  v-Space
//
//  Created by Sergey Seitov on 01.08.17.
//  Copyright © 2017 Сергей Сейтов. All rights reserved.
//

import UIKit
import SVProgressHUD

class PhotoCollectionController: UICollectionViewController {

    var track:Track?
    
    private var photos:[Photo] = []
    private var deleteButton:UIBarButtonItem!
    private var selectedIndexes:[IndexPath] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        if track != nil {
            let dateStr = textShortDateFormatter().string(from: (track!.finishDate! as Date))
            setupTitle("\(track!.place!) (\(NSLocalizedString("Photo", comment: "")))\n\(dateStr)")
            photos = track!.allPhotos().sorted(by: { photo1, photo2 in
                return photo1.date < photo2.date
            })
            
            self.isEditing = false
            
            deleteButton = UIBarButtonItem(barButtonSystemItem: .trash,
                                           target: self,
                                           action: #selector(self.doDelete))
            deleteButton.tintColor = UIColor.mainColor()
            let stretch = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
            setToolbarItems([stretch, deleteButton, stretch], animated: false)
        }
        setupBackButton()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setToolbarHidden(true, animated: true)
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        guard let flowLayout = collectionView!.collectionViewLayout as? UICollectionViewFlowLayout else {
            return
        }
        
        coordinator.animate(alongsideTransition: { (context: UIViewControllerTransitionCoordinatorContext) in
            flowLayout.invalidateLayout()
        }) { (context: UIViewControllerTransitionCoordinatorContext) in
        }

    }
    
    // MARK: UICollectionViewDataSource

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return photos.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "photo", for: indexPath) as! PhotoCell
        if self.isEditing {
            cell.isSelected = selectedIndexes.contains(indexPath)
            cell.shake(!cell.isSelected)
        } else {
            cell.isSelected = false
            cell.shake(false)
        }
        cell.photo = photos[indexPath.row]
        return cell
    }

    // MARK: UICollectionViewDelegate

    func columns() -> CGFloat {
        if UIInterfaceOrientationIsLandscape(UIApplication.shared.statusBarOrientation) {
            return 3
        } else {
            return 2
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: IndexPath) -> CGSize {
        let w = (self.view.frame.size.width - 40.0) / columns()
        return CGSize(width: w, height: w*1.4)
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if self.isEditing {
            if let index = selectedIndexes.index(of: indexPath) {
                selectedIndexes.remove(at: index)
            } else {
                selectedIndexes.append(indexPath)
            }
            collectionView.reloadData()
            refreshToolbar()
        } else {
            performSegue(withIdentifier: "showPhoto", sender: photos[indexPath.row])
        }
    }
    
    // MARK: Selection control
    
    @IBAction func switchSelect(_ button:UIBarButtonItem) {
        if self.isEditing {
            button.image = UIImage(named: "check_on")
        } else {
            button.image = UIImage(named: "check_off")
        }
        self.isEditing = !self.isEditing
        selectedIndexes.removeAll()
        refreshToolbar()
        collectionView?.reloadData()
    }
    
    private func refreshToolbar() {
        navigationController?.setToolbarHidden(!(self.isEditing && selectedIndexes.count > 0), animated: true)
    }

    private func selectedPhotos() -> [Photo] {
        var selected:[Photo] = []
        for index in self.selectedIndexes {
            selected.append(self.photos[index.row])
        }
        return selected
    }
    
    func doDelete() {
        let q = createQuestion(NSLocalizedString("deleteAsk", comment: ""), acceptTitle: "Ok", cancelTitle: "Cancel", acceptHandler:
        {
            SVProgressHUD.show()
            Model.shared.deletePhotosFromTrack(self.track!, photos: self.selectedPhotos(), result: { error in
                SVProgressHUD.dismiss()
                if error != nil {
                    self.showMessage(error!.localizedDescription, messageType: .error)
                } else {
                    self.photos = self.track!.allPhotos().sorted(by: { photo1, photo2 in
                        return photo1.date < photo2.date
                    })
                    self.switchSelect(self.navigationItem.rightBarButtonItem!)
                }
            })
        })
        q?.show()
    }
    
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showPhoto" {
            let next = segue.destination as! PhotoController
            next.photo = sender as? Photo
        }
    }

}
