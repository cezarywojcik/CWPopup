//
//  SamplePopupViewController.swift
//  DimPresentViewController
//
//  Created by admin on 3/8/16.
//  Copyright © 2016 __ASIAINFO__. All rights reserved.
//

import UIKit

class SamplePopupViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let toolBarBG = UIToolbar(frame: CGRect(x: 0, y: 44, width: 200, height: 106))
        view.addSubview(toolBarBG)
        view.sendSubviewToBack(toolBarBG)
    }

}
