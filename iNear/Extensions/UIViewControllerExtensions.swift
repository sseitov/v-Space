//
//  UIViewControllerExtensions.swift
//  iNear
//
//  Created by Сергей Сейтов on 28.11.16.
//  Copyright © 2016 Сергей Сейтов. All rights reserved.
//

import UIKit

enum MessageType {
    case error, success, information
}

class TitleView : UILabel {
    var prompt:UILabel?
   
    override func layoutSubviews() {
        super.layoutSubviews()
        if prompt != nil {
            prompt!.frame = CGRect(x: 0, y: -20, width: Int(frame.size.width), height: 20)
        }
    }
}

extension UIViewController {
    
    func setupTitle(_ text:String, promptText:String? = nil) {
        let label = TitleView(frame: CGRect(x: 0, y: 0, width: 200, height: 44))
        label.textAlignment = .center
        label.font = UIFont(name: "HelveticaNeue-CondensedBold", size: 15)
        label.text = text
        label.textColor = UIColor.white
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        if promptText != nil {
            navigationItem.prompt = ""
            label.clipsToBounds = false
            label.prompt = UILabel(frame: CGRect(x: 0, y: -20, width: label.frame.size.width, height: 20))
            label.prompt!.textAlignment = .center
            label.prompt!.font = UIFont(name: "HelveticaNeue-CondensedBold", size: 15)
            label.prompt!.textColor = UIColor.white
            label.prompt!.text = promptText!
            label.addSubview(label.prompt!)
        }
        navigationItem.titleView = label
    }
    
    func changeTitle(_ text:String) {
        if let title = navigationItem.titleView as? TitleView {
            title.text = text
        }
    }
    
    func setupBackButton() {
        navigationItem.leftBarButtonItem?.target = self
        navigationItem.leftBarButtonItem?.action = #selector(UIViewController.goBack)
    }
    
    func goBack() {
         _ = self.navigationController!.popViewController(animated: true)
    }
    
    // MARK: - alerts
    
    func showMessage(_ error:String, messageType:MessageType, messageHandler: (() -> ())? = nil) {
        var title:String = ""
        switch messageType {
        case .success:
            title = "Success"
        case .information:
            title = "Information"
        default:
            title = "Error"
        }
        let alert = LGAlertView.decoratedAlert(withTitle:title, message: error, cancelButtonTitle: "OK", cancelButtonBlock: { alert in
            if messageHandler != nil {
                messageHandler!()
            }
        })
        alert!.titleLabel.textColor = messageType == .error ? UIColor.errorColor() : UIColor.mainColor()
        alert?.show()
    }
    
    func createQuestion(_ question:String, acceptTitle:String, cancelTitle:String, acceptHandler:@escaping () -> (), cancelHandler: (() -> ())? = nil) -> LGAlertView? {
        
        let alert = LGAlertView.alert(
            withTitle: "Attention!",
            message: question,
            cancelButtonTitle: cancelTitle,
            otherButtonTitle: acceptTitle,
            cancelButtonBlock: { alert in
                if cancelHandler != nil {
                    cancelHandler!()
                }
        },
            otherButtonBlock: { alert in
                alert?.dismiss()
                acceptHandler()
        })
        return alert
    }

}
