//
//  TextInput.swift
//  ispingle
//
//  Created by Сергей Сейтов on 15.03.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

import UIKit

typealias CompletionTextBlock = (String) -> Void

class TextInput: LGAlertView, TextFieldContainerDelegate {

    @IBOutlet weak var inputField: TextFieldContainer!
    var handler:CompletionTextBlock?
    
    class func create(cancelHandler:CompletionBlock?, acceptHandler:CompletionTextBlock?) -> TextInput? {
        if let textInput = Bundle.main.loadNibNamed("TextInput", owner: nil, options: nil)?.first as? TextInput {
            textInput.inputField.delegate = textInput
            textInput.inputField.placeholder = "track name"
            textInput.inputField.autocapitalizationType = .words
            textInput.inputField.textType = .default
            textInput.inputField.returnType = .done
            textInput.cancelButtonBlock = { alert in
                cancelHandler!()
            }
            textInput.otherButtonBlock = { alert in
                if !textInput.inputField.text().isEmpty {
                    textInput.dismiss()
                    acceptHandler!(textInput.inputField.text())
                } else {
                    textInput.showErrorMessage("Track name can not be empty.", animated: true)
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
        if sender.text().isEmpty {
            showErrorMessage("Track name can not be empty.", animated: true)
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
