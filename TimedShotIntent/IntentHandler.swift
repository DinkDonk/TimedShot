//
//  IntentHandler.swift
//  TimedShotIntent
//
//  Created by Rune Warhuus on 08/05/2021.
//

import Intents

class IntentHandler: INExtension, ShootIntentHandling {
	override func handler(for intent: INIntent) -> Any {
		guard intent is ShootIntent else {
			fatalError("Unknown intent type: \(intent)")
		}
		
		return self
	}
	
	func resolveDuration(for intent: ShootIntent, with completion: @escaping (INTimeIntervalResolutionResult) -> Void) {
		guard let duration = intent.duration?.doubleValue else {
			print("Could not resolve duration")
			completion(INTimeIntervalResolutionResult.needsValue())
			return
		}
		
		completion(INTimeIntervalResolutionResult.success(with: duration))
	}
	
	func handle(intent: ShootIntent, completion: @escaping (ShootIntentResponse) -> Void) {
		let activity = NSUserActivity(activityType: "ShootIntent")
		
		activity.userInfo = [
			"firstInvocation" : true,
			"duration" : intent.duration!
		]
		
		completion(ShootIntentResponse(code: .continueInApp, userActivity: activity))
	}
	
	public func confirm(intent: ShootIntent, completion: @escaping (ShootIntentResponse) -> Void) {
		completion(ShootIntentResponse(code: .ready, userActivity: nil))
	}
}
