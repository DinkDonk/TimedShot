//
//  CameraView.swift
//  TimedShot
//
//  Created by Rune Warhuus on 08/05/2021.
//

import SwiftUI
import Intents
import AVFoundation
import Photos

class TimerHelper: ObservableObject {
	@Published var timeRemaining: Int = -1
	@Published var timerRunning: Bool = false
}

struct CameraView: View {
	@StateObject var camera = CameraModel()
	@StateObject var timerHelper = TimerHelper()

	let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

	var body: some View {
		ZStack {
			CameraPreview(camera: camera)

			Text("\(timerHelper.timeRemaining)")
				.font(Font.system(size: 100))
				.foregroundColor(.white)
				.padding(.horizontal, 40)
				.padding(.vertical, 20)
				.background(
					Capsule()
						.fill(Color.init(hue: 0, saturation: 100, brightness: 50))
						.opacity(0.75)
				)
				.opacity(timerHelper.timerRunning ? 1 : 0)
		}
		.onAppear(perform: {
			camera.Check()
		})
		.onReceive(timer) { time in
			if (timerHelper.timerRunning && timerHelper.timeRemaining > 0) {
				timerHelper.timeRemaining -= 1
			}

			if (timerHelper.timeRemaining == 0) {
				stop()
			}
		}
		.onContinueUserActivity("ShootIntent", perform: { userActivity in
			guard let userInfo = userActivity.userInfo else { return }
			guard let duration = userInfo[AnyHashable("duration")] as? NSNumber else { return }
			
			shoot(duration: duration.intValue)
		})
	}
	
	func stop() {
		timerHelper.timerRunning = false
		camera.videoOutput.stopRecording()
	}

	func shoot(duration: Int) {
		if (self.timerHelper.timerRunning) {
			print("Already shooting!")
			
			return
		}
		
		print("Shooting for \(duration)")

		self.timerHelper.timeRemaining = duration
		self.timerHelper.timerRunning = true
		
		let outputFileName = NSUUID().uuidString
		let outputFilePath = (NSTemporaryDirectory() as NSString).appendingPathComponent((outputFileName as NSString).appendingPathExtension("mov")!)

		camera.videoOutput.startRecording(to: URL(fileURLWithPath: outputFilePath), recordingDelegate: camera)
	}
}

struct CameraView_Previews: PreviewProvider {
	static var previews: some View {
		CameraView()
	}
}

class CameraModel: NSObject, ObservableObject, AVCaptureFileOutputRecordingDelegate {
	@Published var session = AVCaptureSession()
	@Published var preview: AVCaptureVideoPreviewLayer!
	@Published var videoOutput = AVCaptureMovieFileOutput()
	
	var shooting = false
	
	func Check() {
		switch AVCaptureDevice.authorizationStatus(for: .video) {
		case .authorized: // The user has previously granted access to the camera.
			self.setup()
			
		case .notDetermined: // The user has not yet been asked for camera access.
			AVCaptureDevice.requestAccess(for: .video) { granted in
				if granted {
					self.setup()
				}
			}
			
		case .denied: // The user has previously denied access.
			return
			
		case .restricted: // The user can't grant access due to restrictions.
			return
			
		default:
			return
		}
	}
	
	func selectBestCamera() -> AVCaptureDevice {
		if let device = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back) {
			return device
		} else if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
			return device
		} else {
			fatalError("Missing expected back camera device.")
		}
	}
	
	func setup() {
		self.session.beginConfiguration()
		
		let captureDevice = selectBestCamera()
		
		guard
			let input = try? AVCaptureDeviceInput(device: captureDevice),
			self.session.canAddInput(input)
		else { return }
		
		self.session.addInput(input)
		
		do {
			let audioDevice = AVCaptureDevice.default(for: .audio)
			let audioDeviceInput = try AVCaptureDeviceInput(device: audioDevice!)
			
			if (self.session.canAddInput(audioDeviceInput)) {
				session.addInput(audioDeviceInput)
			} else {
				print("Could not add audio device input to the session")
			}
		} catch {
			print("Could not create audio device input: \(error)")
		}
		
		let audioOutput = AVCaptureAudioDataOutput()
		
		guard self.session.canAddOutput(videoOutput) else { return }
		guard self.session.canAddOutput(audioOutput) else { return }
		
		self.session.addOutput(videoOutput)
		self.session.addOutput(audioOutput)
		
		self.session.commitConfiguration()
		
		let availableVideoCodecTypes = videoOutput.availableVideoCodecTypes
		
		if availableVideoCodecTypes.contains(.hevc) {
			videoOutput.setOutputSettings([AVVideoCodecKey: AVVideoCodecType.hevc], for: videoOutput.connection(with: .video)!)
		}
		
		videoOutput.connection(with: .video)!.videoOrientation = .landscapeLeft
	}
	
	// Started recording
	func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
		// Empty
		print("Started recording")
	}
	
	// Finished recording
	func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
		print("Finished recording")
		
		func cleanup() {
			let path = outputFileURL.path
			
			if (FileManager.default.fileExists(atPath: path)) {
				do {
					try FileManager.default.removeItem(atPath: path)
				} catch {
					print("Could not remove file at url: \(outputFileURL)")
				}
			}
		}
		
		var success = true
		
		if (error != nil) {
			print("Movie file finishing error: \(String(describing: error))")
			success = (((error! as NSError).userInfo[AVErrorRecordingSuccessfullyFinishedKey] as AnyObject).boolValue)!
		}
		
		if (success) {
			// Check the authorization status.
			PHPhotoLibrary.requestAuthorization { status in
				if (status == .authorized) {
					// Save the movie file to the photo library and cleanup.
					PHPhotoLibrary.shared().performChanges({
						let options = PHAssetResourceCreationOptions()
						options.shouldMoveFile = true

						let creationRequest = PHAssetCreationRequest.forAsset()
						creationRequest.addResource(with: .video, fileURL: outputFileURL, options: options)
					}, completionHandler: { success, error in
						if (!success) {
							print("AVCam couldn't save the movie to your photo library: \(String(describing: error))")
						}
						
						cleanup()
					})
				} else {
					cleanup()
				}
			}
		} else {
			cleanup()
		}
		
		UIControl().sendAction(#selector(URLSessionTask.suspend), to: UIApplication.shared, for: nil)
	}
	
}

class MyView: UIView {
	private var captureSession: AVCaptureSession?

	init(session: AVCaptureSession) {
		super.init(frame: .zero)
		self.captureSession = session
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	override class var layerClass: AnyClass {
		AVCaptureVideoPreviewLayer.self
	}
	
	var videoPreviewLayer: AVCaptureVideoPreviewLayer {
		return layer as! AVCaptureVideoPreviewLayer
	}
	
	override func didMoveToSuperview() {
		super.didMoveToSuperview()

		if nil != self.superview {
			self.videoPreviewLayer.session = self.captureSession
			self.videoPreviewLayer.videoGravity = .resizeAspect
			self.captureSession?.startRunning()
		} else {
			self.captureSession?.stopRunning()
		}
	}
}

struct CameraPreview: UIViewRepresentable {
	@ObservedObject var camera: CameraModel
	
	func makeUIView(context: Context) -> MyView {
		MyView(session: camera.session)
	}
	
	func updateUIView(_ uiView: UIViewType, context: Context) {
		//
	}
	
	typealias UIViewType = MyView
}
