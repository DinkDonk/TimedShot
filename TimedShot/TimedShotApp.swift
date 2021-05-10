//
//  TimedShotApp.swift
//  TimedShot
//
//  Created by Rune Warhuus on 08/05/2021.
//

import SwiftUI
import Intents
import Photos

@main
struct TimedShotApp: App {
    @Environment(\.scenePhase) private var scenePhase
    
    func makeDonation() {
        let intent = ShootIntent()
        
        intent.suggestedInvocationPhrase = "Shoot for 15 seconds"
        
        let interaction = INInteraction(intent: intent, response: nil)
        
        interaction.donate { error in
            if error != nil {
                if let error = error as NSError? {
                    print(
                     "Donation failed: %@" + error.localizedDescription)
                }
            } else {
				print("Successfully donated interaction " + intent.suggestedInvocationPhrase!)
            }
        }
    }
    
    var body: some Scene {
		WindowGroup {
			CameraView()
        }
        .onChange(of: scenePhase) { phase in
            INPreferences.requestSiriAuthorization({ status in
                // Handle errors here
            })
			
			PHPhotoLibrary.requestAuthorization({ status in
				// Handle errors here
			})
            
            makeDonation()
		}
    }
}
