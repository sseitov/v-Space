//
//  CustomAlerts.swift
//  iNear
//
//  Created by Сергей Сейтов on 28.11.16.
//  Copyright © 2016 Сергей Сейтов. All rights reserved.
//

import UIKit

typealias CompletionBlock = (Void) -> Void
typealias CompletionTextBlock = (String) -> Void

// MARK: - Text input

class EmailInput: LGAlertView, TextFieldContainerDelegate {
    
    @IBOutlet weak var inputField: TextFieldContainer!
    var handler:CompletionTextBlock?
  
    class func getEmail(cancelHandler:CompletionBlock?, acceptHandler:CompletionTextBlock?) -> EmailInput? {
        if let textInput = Bundle.main.loadNibNamed("EmailInput", owner: nil, options: nil)?.first as? EmailInput {
            textInput.inputField.delegate = textInput
            textInput.inputField.placeholder = "input email"
            textInput.inputField.textType = .emailAddress
            textInput.cancelButtonBlock = { alert in
                cancelHandler!()
            }
            textInput.otherButtonBlock = { alert in
                if textInput.inputField.text().isEmail() {
                    textInput.dismiss()
                    acceptHandler!(textInput.inputField.text())
                } else {
                    textInput.showErrorMessage("Email should have xxxx@domain.prefix format.", animated: true)
                }
            }
            textInput.handler = acceptHandler
            
            UIApplication.shared.sendAction(#selector(UIApplication.resignFirstResponder), to: nil, from: nil, for: nil)
            NotificationCenter.default.addObserver(textInput, selector: #selector(LGAlertView.keyboardWillChange(_:)), name: Notification.Name.UIKeyboardWillChangeFrame, object: nil)
            
            return textInput
        } else {
            return nil
        }
    }

    func textDone(_ sender:TextFieldContainer, text:String?) {
        if !sender.text().isEmail() {
            showErrorMessage("Email should have xxxx@domain.prefix format.", animated: true)
            sender.activate(true)
        } else {
            dismiss()
            handler!(sender.text())
        }
    }
    
    func textChange(_ sender:TextFieldContainer, text:String?) -> Bool {
        return true
    }
    
    override func show() {
        super.show()
        inputField.activate(true)
    }
    
    func showInView(_ view:UIView) {
        superView = view
        show()
        inputField.activate(true)
    }
}

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
