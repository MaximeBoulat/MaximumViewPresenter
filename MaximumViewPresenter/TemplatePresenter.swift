//
//  LockerDetailPresenter.swift
//  MockLockerApp
//
//  Created by Maxime Boulat on 8/4/19.
//  Copyright © 2019 Maxime Boulat. All rights reserved.
//

import Foundation

class TemplatePresenter: PresenterProtocol {
	
	typealias DataSource = Data
	typealias InterfaceStateMap = InterfaceState
	typealias InputMap = Input
	
	var renderData: ((DataSource) -> Void)?
	
	var interfaceState: InterfaceStateMap = .loading {
		didSet {
			switch interfaceState {
			case .ready:
				break
			case .cleanup:
				break
			default:
				break
			}
		}
	}

	func processInput(input: InputMap) {
		
	}

}

extension TemplatePresenter {
	
	static var storyboardId: String {
		return "LockerDetailVC"
	}
	
	struct Data {
		var placeholder: String = "hello"
	}
	
	enum Input {
		case primary
		case secondary
	}
	
}
