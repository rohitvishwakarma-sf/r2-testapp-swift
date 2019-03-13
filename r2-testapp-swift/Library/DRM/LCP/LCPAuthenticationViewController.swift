//
//  LCPAuthenticationViewController.swift
//  r2-testapp-swift
//
//  Created by Mickaël Menu on 01.03.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

#if LCP

import SafariServices
import UIKit
import ReadiumLCP


protocol LCPAuthenticationDelegate: AnyObject {
    
    func authenticate(_ license: LCPAuthenticatedLicense, with passphrase: String)
    func didCancelAuthentication(of license: LCPAuthenticatedLicense)

}

class LCPAuthenticationViewController: UIViewController {
    
    weak var delegate: LCPAuthenticationDelegate?
    
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var hintLabel: UILabel!
    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var passphraseField: UITextField!
    @IBOutlet weak var supportButton: UIButton!
    
    private let license: LCPAuthenticatedLicense
    private let reason: LCPAuthenticationReason
    private let supportLinks: [(Link, URL)]
    
    init(license: LCPAuthenticatedLicense, reason: LCPAuthenticationReason) {
        self.license = license
        self.reason = reason
        self.supportLinks = license.supportLinks
            .compactMap { link -> (Link, URL)? in
                guard let url = URL(string: link.href), UIApplication.shared.canOpenURL(url) else {
                    return nil
                }
                return (link, url)
            }

        super.init(nibName: nil, bundle: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChangeFrame(_:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChangeFrame(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        var provider = license.document.provider
        if let providerHost = URL(string: provider)?.host {
            provider = providerHost
        }
        
        supportButton.isHidden = supportLinks.isEmpty

        switch reason {
        case .passphraseNotFound:
            titleLabel.text = "Passphrase Required"
        case .invalidPassphrase:
            titleLabel.text = "Incorrect Passphrase"
            passphraseField.layer.borderWidth = 1
            passphraseField.layer.borderColor = UIColor.red.cgColor
        }
        
        messageLabel.text = "In order to open it, we need to know the passphrase required by: \(provider).\nTo help you remember it, the following hint is available."
        hintLabel.text = license.hint
    }

    @IBAction func authenticate(_ sender: Any) {
        let passphrase = passphraseField.text ?? ""
        delegate?.authenticate(license, with: passphrase)
        dismiss(animated: true)
    }
    
    @IBAction func cancel(_ sender: Any) {
        delegate?.didCancelAuthentication(of: license)
        dismiss(animated: true)
    }
    
    @IBAction func showSupportLink(_ sender: Any) {
        guard !supportLinks.isEmpty else {
            return
        }
        
        func open(_ url: URL) {
            if #available(iOS 10, *) {
                UIApplication.shared.open(url)
            } else {
                UIApplication.shared.openURL(url)
            }
        }
        
        if let (_, url) = supportLinks.first, supportLinks.count == 1 {
            open(url)
            return
        }
        
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        for (link, url) in supportLinks {
            let title: String = {
                if let title = link.title {
                    return title
                }
                if let scheme = url.scheme {
                    switch scheme {
                    case "http", "https":
                        return "Website"
                    case "tel":
                        return "Phone"
                    case "mailto":
                        return "Mail"
                    default:
                        break
                    }
                }
                return "Support"
            }()
            
            let action = UIAlertAction(title: title, style: .default) { _ in
                open(url)
            }
            alert.addAction(action)
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = alert.popoverPresentationController, let sender = sender as? UIView {
            popover.sourceView = sender
            var rect = sender.bounds
            rect.origin.x = sender.center.x - 1
            rect.size.width = 2
            popover.sourceRect = rect
        }
        present(alert, animated: true)
    }
    
    @IBAction func showHintLink(_ sender: Any) {
        guard let href = license.hintLink?.href, let url = URL(string: href) else {
            return
        }
        
        let browser = SFSafariViewController(url: url)
        browser.modalPresentationStyle = .currentContext
        present(browser, animated: true)
    }
    
    /// Makes sure the form contents in scrollable when the keyboard is visible.
    @objc func keyboardWillChangeFrame(_ note: Notification) {
        guard let window = UIApplication.shared.keyWindow, let scrollView = scrollView, let scrollViewSuperview = scrollView.superview, let info = note.userInfo else {
            return
        }

        var keyboardHeight: CGFloat = 0
        if note.name == UIResponder.keyboardWillChangeFrameNotification {
            guard let keyboardFrame = info[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
                return
            }
            keyboardHeight = keyboardFrame.height
        }
        
        // Calculates the scroll view offsets in the coordinate space of of our window
        let scrollViewFrame = scrollViewSuperview.convert(scrollView.frame, to: window)

        var contentInset = scrollView.contentInset
        // Bottom inset is the part of keyboard that is covering the tableView
        contentInset.bottom = keyboardHeight - (window.frame.height - scrollViewFrame.height - scrollViewFrame.origin.y) + 16

        self.scrollView.contentInset = contentInset
        self.scrollView.scrollIndicatorInsets = contentInset
    }

}


extension LCPAuthenticationViewController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        authenticate(textField)
        return false
    }
    
}

#endif
