//
//  ViewController.swift
//  CWPopup-Swift-Demo
//
//  Created by admin on 3/8/16.
//  Copyright © 2016 __ASIAINFO__. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let tap = UITapGestureRecognizer(target: self, action: "dissmissPopup")
        
        tap.delegate = self
        view.addGestureRecognizer(tap)
        useBlurForPopup = true
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func dissmissPopup() {
        if popupViewController != nil {
            dismissPopupViewController(true, completion: { () -> () in
                print(self)
            })
        }
    }
    
    
    @IBAction func buttonPressed(sender: AnyObject) {
        let vc = SamplePopupViewController()
        presentPopupViewController(vc, animated: true) { () -> () in
            print(self)
        }
    }
}

extension ViewController: UIGestureRecognizerDelegate {
    
    func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldReceiveTouch touch: UITouch) -> Bool {
        return touch.view == view
    }
}

