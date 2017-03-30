//
//  ActionSheet.swift
//  iNear
//
//  Created by Сергей Сейтов on 28.11.16.
//  Copyright © 2016 Сергей Сейтов. All rights reserved.
//

import UIKit

typealias CompletionBlock = (Void) -> Void

// MARK: - Action sheet

class ActionSheet: LGAlertView {

    @IBOutlet weak var firstButton: UIButton!
    @IBOutlet weak var secondButton: UIButton!
    @IBOutlet weak var thirdButton: UIButton!
    
    @IBOutlet weak var heightConstraint: NSLayoutConstraint!
    @IBOutlet weak var thirdButtonHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var cancelConstraint: NSLayoutConstraint!
    
    var handler1:CompletionBlock?
    var handler2:CompletionBlock?
    var handler3:CompletionBlock?
        
    class func create(title:String, actions:[String], handler1:CompletionBlock?, handler2:CompletionBlock?, handler3:CompletionBlock? = nil, cancelHandler:LGAlertViewCancelBlock? = nil) -> ActionSheet? {
        if actions.count < 2 || actions.count > 3 {
            return nil
        }
        if let actionView = Bundle.main.loadNibNamed("ActionSheet", owner: nil, options: nil)?.first as? ActionSheet {
            actionView.titleLabel.text = title
            actionView.firstButton.setTitle(actions[0], for: .normal)
            actionView.secondButton.setTitle(actions[1], for: .normal)
            actionView.cancelButtonBlock = cancelHandler
            actionView.handler1 = handler1
            actionView.handler2 = handler2
            if actions.count == 2 {
                actionView.thirdButtonHeightConstraint.constant = 0
                actionView.heightConstraint.constant = 200
                actionView.cancelConstraint.constant = 20
            } else {
                actionView.thirdButton.setTitle(actions[2], for: .normal)
                actionView.handler3 = handler3
            }
            actionView.cancelButton.setupBorder(UIColor.blue, radius: 15)
            return actionView
        } else {
            return nil
        }
    }
    
    @IBAction func firstAction(_ sender: AnyObject) {
        dismiss()
        if handler1 != nil {
            handler1!()
        }
    }
    
    @IBAction func secondAction(_ sender: AnyObject) {
        dismiss()
        if handler2 != nil {
            handler2!()
        }
    }
    
    @IBAction func thirdAction(_ sender: AnyObject) {
        dismiss()
        if handler3 != nil {
            handler3!()
        }
    }
    
    func showInPopover(host:UIViewController, target:NSObject?) {
        let controller = UIViewController()
        self.popoverHostController = host
        controller.view = self
        controller.view.backgroundColor = UIColor.white
        controller.modalPresentationStyle = .popover
        if (handler3 == nil)  {
            controller.preferredContentSize = CGSize(width: 280, height: 200)
        } else {
            controller.preferredContentSize = CGSize(width: 280, height: 240)
        }
        
        host.present(controller, animated: true, completion: nil)
        
        let popoverPresentationController = controller.popoverPresentationController
        popoverPresentationController?.delegate = self
        if let button = target as? UIBarButtonItem {
            popoverPresentationController?.barButtonItem = button
        } else if let view = target as? UIView {
            popoverPresentationController?.sourceView = host.view
            popoverPresentationController?.sourceRect = view.frame
        }
    }
}

func showAlertInPopover(alert:LGAlertView, popoverHost:UIViewController, target:NSObject?, direction:UIPopoverArrowDirection = .any) {
    let controller = UIViewController()
    alert.titleLabelTopSpace.constant = 50
    alert.popoverHostController = popoverHost
    controller.view = alert
    controller.view.backgroundColor = UIColor.white
    controller.modalPresentationStyle = .popover
    controller.preferredContentSize = CGSize(width: 280, height: 200)
    
    popoverHost.present(controller, animated: true, completion: nil)
    
    let popoverPresentationController = controller.popoverPresentationController
    popoverPresentationController?.permittedArrowDirections = direction
    popoverPresentationController?.delegate = alert
    if let button = target as? UIBarButtonItem {
        popoverPresentationController?.barButtonItem = button
    } else if let view = target as? UIView {
        popoverPresentationController?.sourceView = popoverHost.view
        popoverPresentationController?.sourceRect = view.frame
    }
}
