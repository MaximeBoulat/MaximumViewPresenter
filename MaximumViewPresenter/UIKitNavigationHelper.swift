//
//  UIKitNavigationHelper.swift
//  MaximumViewPresenter
//
//  Created by Maxime Boulat on 1/25/20.
//  Copyright © 2020 Maxime Boulat. All rights reserved.
//

import Foundation
import UIKit

public protocol PresenterProtocol {
	
	associatedtype DataSource
	associatedtype InterfaceStateMap
	associatedtype InputMap
	
	var interfaceState: InterfaceStateMap { get set }
	
	func processInput(input: InputMap)
}

public protocol PresentedProtocol {
	
	associatedtype Presenter: PresenterProtocol
	var presenter: Presenter? { get set }
	var renderData: ((Presenter.DataSource)-> Void)? { get set }
}

public protocol DataProviding {
	
	func fetchData() -> Data
}

public enum InterfaceState {
	case loading
	case ready
	case busy
	case cleanup
}

public enum TransitionType {
	case containment(viewTag: Int)
	case modal(animated: Bool)
	case navStack
}

extension TransitionType: Equatable {}

internal struct ScreenItem {
	
	var screen: UIViewController
	var identifier: AnyHashable
	
	var parentIdentifier: AnyHashable?
	var next: (transition: TransitionType, identifier: AnyHashable)? = nil
	
	var children: [Int : AnyHashable] = [:]
	
	init(screen: UIViewController,
		 identifier: AnyHashable,
		 parentIdentifier: AnyHashable? = nil) {
		self.screen = screen
		self.identifier = identifier
		self.parentIdentifier = parentIdentifier
	}
}

public class UIKitNavigationHelper {
	
	var cache: [AnyHashable: ScreenItem] = [:]
	var dispatchQueue: OperationQueue = {
		let result = OperationQueue()
		result.maxConcurrentOperationCount = 1
		return result
	}()
	
	public init(rootViewController: UIViewController, identifier: AnyHashable) {
		let screenItem = ScreenItem(screen: rootViewController, identifier: identifier)
		cache[identifier] = screenItem
	}
	
	public func basePush(origin: AnyHashable,
				  destination: UIViewController,
				  identifier: AnyHashable,
				  transition: TransitionType) -> Bool {
		
		var result = false
		
		guard var found = cache[origin] else {
			return false
		}
		
		
		switch transition {
		case .modal, .navStack:
			result = majorTransitionHelper(found: &found,
										   transition: transition,
										   destination: destination,
										   identifier: identifier)
			
		case .containment (let viewTag):
			
			result = containmentHelper(found: &found,
									   viewTag: viewTag,
									   destination: destination,
									   identifier: identifier)
		}
		
		return result
		
	}
	
	public func rewind(origin: AnyHashable) -> Bool {
		
		let result = false
		
		guard var found = cache[origin] else {
			return false
		}
		
		rewindHelper(found: found)
		
		// Update the daisy chain
		found.next = nil
		cache[origin] = found
		
		return result
	}
	
	public func pop(screen: AnyHashable) -> Bool {
		
		guard let found = cache[screen],
			let parentIdentifier = found.parentIdentifier,
			let parent = cache[parentIdentifier],
			let transitionType = parent.next?.transition else {
				return false
		}
		
		rewindHelper(found: found)
		trimGraph(screen: found)
		
		return pop(screen: found.screen, transitionType: transitionType)
		
	}
	
	private func majorTransitionHelper(found: inout ScreenItem,
									   transition: TransitionType,
									   destination: UIViewController,
									   identifier: AnyHashable) -> Bool {
		
		rewindHelper(found: found)
		
		// Update the daisy chain
		found.next = (transition: transition, identifier: identifier)
		cache[found.identifier] = found
		
		// Append the node to the graph
		let screenItem = ScreenItem(screen: destination,
									identifier: identifier,
									parentIdentifier: found.identifier)
		cache[identifier] = screenItem
		
		var theDestination: UIViewController
		
		if transition == TransitionType.navStack {
			theDestination = destination
		} else {
			theDestination = UINavigationController(rootViewController: destination)
			theDestination.modalPresentationStyle = .overCurrentContext
		}
		
		dispatchTransition(transition: transition,
						   origin: found.screen,
						   destination: theDestination)
		
		return true
	}
	
	private func containmentHelper(found: inout ScreenItem,
								   viewTag: Int,
								   destination: UIViewController,
								   identifier: AnyHashable) -> Bool {
		
		var result: Bool
		var theDestination: UIViewController
		
		// Check existing
		
		if let existingChildScreenIdentifier = found.children[viewTag] {
			// There is already a view controller in there, is it the same?
			if existingChildScreenIdentifier == identifier {
				// Its the same, bail?
				result = false
				
				// Its another view controller, we need to remove existing and replace
			} else if let outgoing = cache[existingChildScreenIdentifier] {
				
				_ = pop(screen: outgoing.screen, transitionType: .containment(viewTag: viewTag))
				
				// trim graph
				trimGraph(screen: outgoing)
				
				// trim children
				found.children[viewTag] = identifier
				cache[found.identifier] = found
				
				cache[identifier] = ScreenItem(screen: destination, identifier: identifier)
				
				theDestination = UINavigationController(rootViewController: destination)
				dispatchTransition(transition: .containment(viewTag: viewTag),
								   origin: found.screen,
								   destination: theDestination)
				
				result = true
				
			} else {
				
				// We messed up....
				result = false
			}
			// There is no child in that slot
		} else {
			
			// Update the children
			found.children[viewTag] = identifier
			cache[found.identifier] = found
			
			// Start tracking new screen
			cache[identifier] = ScreenItem(screen: destination, identifier: identifier)
			
			theDestination = UINavigationController(rootViewController: destination)
			
			dispatchTransition(transition: .containment(viewTag: viewTag),
							   origin: found.screen,
							   destination: theDestination)
			
			result = true
			
		}
		
		return result
	}
	
	private func dispatchTransition(transition: TransitionType,
									origin: UIViewController,
									destination: UIViewController) {
		// Forward
		dispatchQueue.addOperation {
			let blocker = DispatchSemaphore(value: 0)
			DispatchQueue.main.async { [unowned self] in
				
				self.routePush(transitionType: transition,
							   origin: origin,
							   destination: destination) { (message) in
								
								if let incoming = message {
									print(incoming)
								}
								
								blocker.signal()
				}
			}
			blocker.wait()
		}
	}
	
	private func rewindHelper(found: ScreenItem) {
		
		// Break the chain if needed
		if let next = found.next {
			
			var nextCandidate: (transition: TransitionType, identifier: AnyHashable)? = next
			
			while let next = nextCandidate,
				let nextScreen = cache[next.identifier] {
					
					trimGraph(screen: nextScreen)
					nextScreen.children.forEach {
						if let child = cache[$0.value] {
							trimGraph(screen: child)
						}
					}
					
					nextCandidate = nextScreen.next
			}
			
			let foundScreen = found.screen
			
			// Backward
			dispatchQueue.addOperation {
				let blocker = DispatchSemaphore(value: 0)
				DispatchQueue.main.async { [unowned self] in
					
					self.rewind(transitionType: next.transition, screen: foundScreen) { (message) in
						
						if let incoming = message {
							print(incoming)
						}
						
						blocker.signal()
					}
				}
				blocker.wait()
			}
		}
	}
	
	
	private func routePush(transitionType: TransitionType,
						   origin: UIViewController,
						   destination: UIViewController,
						   completion: ((String?) -> Void)?) {
		
		switch transitionType {
		case .modal (let animated):
			origin.present(destination, animated: animated) {
				completion?(nil)
			}
		case .containment(let viewTag):
			
			if let container = origin.view.viewWithTag(viewTag) {
				destination.willMove(toParent: origin)
				destination.view.translatesAutoresizingMaskIntoConstraints = false
				container.addSubview(destination.view)
				origin.addChild(destination)
				destination.didMove(toParent: origin)
				destination.view.constrainEdgesToSuperview()
				completion?(nil)
			} else {
				// Could not find the container, bail
				completion?("Could not find container")
			}
			
		case .navStack:
			var message: String?
			if let existing = origin.navigationController {
				existing.pushViewController(destination, animated: true)
			} else {
				message = "Failed to find navigation controller to push onto"
			}
			completion?(message)
		}
		
		print("============> transition complete!")
		
	}
	
	private func rewind(transitionType: TransitionType,
						screen: UIViewController,
						completion: ((String?) -> Void)?) {
		
		switch transitionType {
		case .containment:
			screen.children.forEach {
				$0.willMove(toParent: nil)
				$0.view.removeFromSuperview()
				$0.removeFromParent()
			}
			completion?(nil)
		case .modal (let animated):
			if let presented = screen.presentedViewController {
				
				//				recursiveDismiss(screen: presented)
				
				screen.dismiss(animated: animated) {
					completion?(nil)
				}
			} else {
				completion?("Failed to find presented view controller to dismiss")
			}
		case .navStack:
			var message: String?
			if let existing = screen.navigationController {
				existing.popToViewController(screen, animated: true)
			} else {
				message = "Failed to find navigation controller to pop"
			}
			completion?(message)
		}
	}
	
	private func recursiveDismiss(screen: UIViewController) {
		
		if let presented = screen.presentedViewController {
			recursiveDismiss(screen: presented)
			screen.dismiss(animated: true)
		}
	}
	
	private func pop(screen: UIViewController, transitionType: TransitionType) -> Bool {
		
		var result: Bool
		
		switch transitionType {
		case .containment:
			screen.navigationController?.willMove(toParent: nil)
			screen.navigationController?.view.removeFromSuperview()
			screen.navigationController?.removeFromParent()
			result = true
		case .modal(let animated):
			screen.dismiss(animated: animated, completion: nil)
			result = true
		case .navStack:
			if let visible = screen.navigationController?.visibleViewController, visible === screen {
				screen.navigationController?.popViewController(animated: true)
				result = true
			} else {
				result = false
			}
		}
		
		return result
	}
	
	private func trimGraph(screen: ScreenItem) {
		// trim the graph
		cache.removeValue(forKey: screen.identifier)
		
		// Update dependencies
		if let parentIdentifier = screen.parentIdentifier,
			var parent = cache[parentIdentifier] {
			parent.next = nil
			cache[parentIdentifier] = parent
		}
	}
	
}

extension UIView {
	
	func constrainEdgesToSuperview(withMargin margin: CGFloat = 0.0) {
		if let superview = superview {
			self.translatesAutoresizingMaskIntoConstraints = false
			NSLayoutConstraint.activate([
				(self.topAnchor.constraint(equalTo: superview.topAnchor, constant: margin)),
				(self.bottomAnchor.constraint(equalTo: superview.bottomAnchor, constant: -margin)),
				(self.leftAnchor.constraint(equalTo: superview.leftAnchor, constant: margin)),
				(self.rightAnchor.constraint(equalTo: superview.rightAnchor, constant: -margin))
				])
		}
	}
}

