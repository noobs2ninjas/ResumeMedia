//
//  ViewController.swift
//  TouchTesting
//
//  Created by Nathan Kellert on 11/16/17.
//  Copyright © 2017 Nathan Kellert. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        let demoView = DemoView(frame: self.view.frame)
        self.view = demoView
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

