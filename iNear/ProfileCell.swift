//
//  ProfileCell.swift
//  iNear
//
//  Created by Сергей Сейтов on 03.03.17.
//  Copyright © 2017 Сергей Сейтов. All rights reserved.
//

import UIKit

protocol ProfileCellDelegate {
    func signOut()
}

class ProfileCell: UITableViewCell {

    @IBOutlet weak var accountType: UILabel!
    @IBOutlet weak var account: UILabel!
    @IBOutlet weak var signButton: UIButton!

    var delegate:ProfileCellDelegate?
    
    @IBAction func signOut(_ sender: Any) {
        delegate?.signOut()
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        signButton.setupBorder(UIColor.clear, radius: 10)
    }
}
