//
//  LockerDetailTabBarController.swift
//  MockLockerApp
//
//  Created by Maxime Boulat on 8/4/19.
//  Copyright © 2019 Maxime Boulat. All rights reserved.
//

import UIKit

class TemplateViewController: UIViewController, PresentedProtocol {
	
	typealias Presenter = TemplatePresenter
	var presenter: Presenter?
	
	lazy var renderData: ((Presenter.DataSource) -> Void)? = {[weak self] data in
		
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		presenter?.interfaceState = .ready
	}
	
}
