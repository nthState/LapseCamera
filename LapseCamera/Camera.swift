//
//  Camera.swift
//  LapseCamera
//
//  Created by Chris Davis on 15/04/2021.
//

import Foundation
import AVFoundation
import Metal
import os.log
import Combine

typealias ImageBufferHandler = ((_ imageBuffer: CMSampleBuffer) -> ())

class Camera: NSObject {
  
  private enum SessionStatus {
    case success
    case notAuthorized
    case configurationFailed
  }
  
  static var shared: Camera = Camera()
  
  public var shouldTakePhoto: Bool = true
  
  private var sessionStatus = SessionStatus.success
  
  var imageBufferHandler: ImageBufferHandler?

  public let photoComplete = PassthroughSubject<Bool, Never>()
  
  var cameraSize: CGSize!
  
  let captureSession: AVCaptureSession = AVCaptureSession()
  private let sessionQueue = DispatchQueue(label: "camera_session")
  private let dataOutputQueue = DispatchQueue(label: "data_session")
  public var photoOutput = AVCapturePhotoOutput()

  /// The capture input that provides media from the designated device to a capture session
  public var videoInput: AVCaptureDeviceInput!
  /// The capture output that records video and provides access to video frames for processing.
  public let videoDataOutput = AVCaptureVideoDataOutput()
  
  var textureCache: CVMetalTextureCache? /// Texture cache we will use for converting frame images to textures
  var metalDevice = MTLCreateSystemDefaultDevice() /// `MTLDevice` we need to initialize texture cache
  
  override init() {
    super.init()
    
    setupSession()
  }
  
}

extension Camera {
  
  fileprivate func setupSession() {
    
    if sessionStatus != .success {
      return
    }
    
    let defaultCaptureDevice = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInDualCamera, .builtInDualWideCamera, .builtInTelephotoCamera, .builtInWideAngleCamera], mediaType: .video, position: .back).devices.first
    
    
    guard let videoDevice = defaultCaptureDevice else {
      sessionStatus = .configurationFailed
      return
    }
    
    do {
      videoInput = try AVCaptureDeviceInput(device: videoDevice)
    }
    catch let error {
      sessionStatus = .configurationFailed
      os_log("%{PUBLIC}@", log: OSLog.general, type: .debug, "setupSession: \(error)")
      return
    }
    
    cameraSize = getCaptureResolution(device: videoDevice)
    
    captureSession.beginConfiguration()
    captureSession.sessionPreset = AVCaptureSession.Preset.photo
    
    guard captureSession.canAddInput(videoInput) else {
      sessionStatus = .configurationFailed
      captureSession.commitConfiguration()
      return
    }
    captureSession.addInput(videoInput)
    captureSession.sessionPreset = .photo
    
    // Live video for camera preview
    if captureSession.canAddOutput(videoDataOutput) {
      captureSession.addOutput(videoDataOutput)
      videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
      videoDataOutput.setSampleBufferDelegate(self, queue: dataOutputQueue)
      let connection = videoDataOutput.connection(with: .video)
      connection?.videoOrientation = .portrait
    }
    else {
      sessionStatus = .configurationFailed
      captureSession.commitConfiguration()
      return
    }
    
    // Photo output for capturing images
    if captureSession.canAddOutput(photoOutput) {
      captureSession.addOutput(photoOutput)
      photoOutput.isHighResolutionCaptureEnabled = true
    }
    else {
      sessionStatus = .configurationFailed
      captureSession.commitConfiguration()
      return
    }
    
    captureSession.commitConfiguration()
    
  }
  
  private func getCaptureResolution(device: AVCaptureDevice) -> CGSize {
    // Define default resolution
    var resolution = CGSize(width: 0, height: 0)
    
    // Get video dimensions
    let formatDescription = device.activeFormat.formatDescription
    let dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)
    resolution = CGSize(width: Int(dimensions.height), height: Int(dimensions.width))
    
    // Return resolution
    return resolution
  }
  
}

extension Camera {
  
  public func start() {
    captureSession.startRunning()
    
    photoOutput.setPreparedPhotoSettingsArray([getCameraSettings()], completionHandler: nil)
  }
  
}

extension Camera: AVCapturePhotoCaptureDelegate {
  
  public func getCameraSettings() -> AVCapturePhotoSettings {
    let photoSettings: AVCapturePhotoSettings
    
    if self.photoOutput.availablePhotoCodecTypes.contains(.jpeg) {
      photoSettings = AVCapturePhotoSettings(format:
                                              [AVVideoCodecKey: AVVideoCodecType.jpeg])
    }
    else {
      photoSettings = AVCapturePhotoSettings()
    }
    photoSettings.flashMode = .auto
    
    return photoSettings
  }
  
  public func takePhoto() {
    
    guard shouldTakePhoto else {
      photoComplete.send(true)
      return
    }
    
    sessionQueue.async {
      self.photoOutput.capturePhoto(with: self.getCameraSettings(), delegate: self)
    }
    
  }
  
  func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {

    photoComplete.send(error != nil)
    
  }
  
}

// MARK: AVCaptureVideoDataOutputSampleBufferDelegate Methods

extension Camera: AVCaptureVideoDataOutputSampleBufferDelegate {
  
  public func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    
  }
  
  public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    
    if let imageBufferHandler = imageBufferHandler {
      imageBufferHandler(sampleBuffer)
    }
    
  }
  
}
