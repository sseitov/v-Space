//
//  UserCell.swift
//  v-Space
//
//  Created by Сергей Сейтов on 22.10.2017.
//  Copyright © 2017 Сергей Сейтов. All rights reserved.
//

import UIKit
import SDWebImage

class UserCell: UITableViewCell {

    @IBOutlet weak var userImage: UIImageView!
    @IBOutlet weak var userName: UILabel!
    
    var uid:String? {
        didSet {
            AuthModel.shared.userData(uid!, data: { user in
                if user != nil {
                    if let name = user!["displayName"] as? String {
                        self.userName.text = name
                    }
                    if let photoURLStr = user!["photoURL"] as? String, let url = URL(string: photoURLStr) {
                        self.userImage.sd_setImage(with: url, completed: nil)
                    }
                }
            })
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        userImage.setupCircle()
    }

}
