//
//  ContactCell.swift
//  iNear
//
//  Created by Сергей Сейтов on 01.12.16.
//  Copyright © 2016 Сергей Сейтов. All rights reserved.
//

import UIKit
import SDWebImage

class ContactCell: UITableViewCell {

    @IBOutlet weak var contactView: UIImageView!
    @IBOutlet weak var background: UIView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var contactLabel: UILabel!
    @IBOutlet weak var statusView: UIImageView!

    fileprivate var user:User?
    var contact:Contact? {
        didSet {
            if currentUser() == nil || contact == nil {
                return
            }
            if contact!.initiator! == currentUser()!.uid! {
                user = Model.shared.getUser(contact!.requester!)
            } else {
                user = Model.shared.getUser(contact!.initiator!)
            }
            if user!.name != nil {
                nameLabel.text = user!.name
            } else {
                nameLabel.text = user!.email
            }
            let unread = Model.shared.unreadCountInChat(user!.uid!)
            statusView.isHidden = unread == 0
            
            contactView.image = user!.getImage()
            contactLabel.font = UIFont.condensedFont()
            switch contact!.getContactStatus() {
            case .requested:
                if contact!.requester! == currentUser()!.uid {
                    contactLabel.text = "REQUEST FOR CHAT"
                } else {
                    contactLabel.text = "WAITING..."
                }
            case .rejected:
                contactLabel.text = "REJECTED"
            case .approved:
                contactLabel.font = UIFont.mainFont()
                if let message = Model.shared.lastMessageInChat(user!.uid!) {
                    contactLabel.text = message.text
                } else {
                    contactLabel.text = ""
                }
            }
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contactView.setupCircle()
        background.setupBorder(UIColor.clear, radius: 35)
    }
  
    override func setSelected(_ selected: Bool, animated: Bool) {
        if IS_PAD() {
            super.setSelected(selected, animated: animated)
            nameLabel.font = selected ? UIFont.condensedFont() : UIFont.mainFont()
        } else {
            nameLabel.font = UIFont.condensedFont()
        }
    }

}
