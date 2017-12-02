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

extension UIViewController {
 
    func setupTitle(_ text:String, color:UIColor = UIColor.white) {
        let label = UILabel(frame: CGRect(x: 0, y: 0, width: 200, height: 44))
        label.textAlignment = .center
        label.font = UIFont(name: "HelveticaNeue-CondensedBold", size: 15)
        label.text = text
        label.textColor = color
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        navigationItem.titleView = label
    }

    func changeTitle(_ text:String) {
        if let title = navigationItem.titleView as? UILabel {
            title.text = text
        }
    }
    
    func setupBackButton() {
        navigationItem.leftBarButtonItem?.target = self
        navigationItem.leftBarButtonItem?.action = #selector(UIViewController.goBack)
    }
    
    @objc func goBack() {
         _ = self.navigationController!.popViewController(animated: true)
    }
    
    // MARK: - alerts
    
    func showMessage(_ error:String, messageType:MessageType, messageHandler: (() -> ())? = nil) {
        var title:String = ""
        switch messageType {
        case .success:
            title = ""
        case .information:
            title = "Information".localized.uppercased()
        default:
            title = "Error".localized.uppercased()
        }
        let alert = LGAlertView.decoratedAlert(withTitle:title.uppercased(), message: error, cancelButtonTitle: "OK", cancelButtonBlock: { alert in
            if messageHandler != nil {
                messageHandler!()
            }
        })
        alert!.titleLabel.textColor = messageType == .error ? UIColor.errorColor() : UIColor.mainColor()
        alert?.show()
    }
    
    func createQuestion(_ question:String, acceptTitle:String, cancelTitle:String, acceptHandler:@escaping () -> (), cancelHandler: (() -> ())? = nil) -> LGAlertView? {
        
        let alert = LGAlertView.alert(
            withTitle: "Attention".localized.uppercased(),
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
    
    func yesNoQuestion(_ question:String, acceptLabel:String, cancelLabel:String, acceptHandler:@escaping () -> (), cancelHandler: (() -> ())? = nil) {
        
        let alert = LGAlertView.alert(
            withTitle: Bundle.main.infoDictionary?["CFBundleName"] as? String,
            message: question,
            cancelButtonTitle: cancelLabel,
            otherButtonTitle: acceptLabel,
            cancelButtonBlock: { alert in
                if cancelHandler != nil {
                    cancelHandler!()
                }
        },
            otherButtonBlock: { alert in
                alert?.dismiss()
                acceptHandler()
        })
        alert?.titleLabel.textColor = UIColor.mainColor()
        alert?.cancelButton.backgroundColor = UIColor.gray
        alert?.otherButton.backgroundColor = UIColor.mainColor()
        alert?.show()
    }

}
