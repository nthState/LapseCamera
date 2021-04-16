//
//  CameraView.swift
//  LapseCamera
//
//  Created by Chris Davis on 15/04/2021.
//

import Foundation
import UIKit
import AVFoundation
import MetalKit
import LapseCameraEffect
import OSLog
import os.signpost
import Combine

class CameraView: MTKView {
  
  //private let camera: Camera = Camera()
  
  private var internalPixelBuffer: CVPixelBuffer?
  
  private let syncQueue = DispatchQueue(label: "Preview View Sync Queue", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
  
  private var textureCache: CVMetalTextureCache?
  
  private var textureWidth: Int = 0
  
  private var textureHeight: Int = 0
  
  private var renderPipelineState: MTLRenderPipelineState!
  
  private var commandQueue: MTLCommandQueue?
  
  private var vertexCoordBuffer: MTLBuffer!
  
  private var textCoordBuffer: MTLBuffer!
  
  private var sampler: MTLSamplerState!
  
  private var cameraEffect: DistortEffect!
  
  var uiDelegate: Coordinator?
  
  var lastPixelBuffer: CVPixelBuffer?
  
  var pixelBuffer: CVPixelBuffer? {
    didSet {
      syncQueue.sync {
        internalPixelBuffer = pixelBuffer
      }
    }
  }
  
  init() {
    super.init(frame: .zero, device: MTLCreateSystemDefaultDevice())
    
    cameraEffect = try! DistortEffect()
    
    Camera.shared.imageBufferHandler = applyEffect
    
    configureMetal()
    
    createTextureCache()
    
    colorPixelFormat = .bgra8Unorm
    
    // Vertex coordinate takes the gravity into account.
    let vertexData: [Float] = [
      -1, -1, 0.0, 1.0,
      1, -1, 0.0, 1.0,
      -1, 1, 0.0, 1.0,
      1, 1, 0.0, 1.0
    ]
    vertexCoordBuffer = device!.makeBuffer(bytes: vertexData, length: vertexData.count * MemoryLayout<Float>.size, options: [])
    
    let textData: [Float] = [
      0.0, 1.0,
      1.0, 1.0,
      0.0, 0.0,
      1.0, 0.0
    ]
    textCoordBuffer = device?.makeBuffer(bytes: textData, length: textData.count * MemoryLayout<Float>.size, options: [])
    
    Camera.shared.start()
      
  }
  
  required init(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  func configureMetal() {
    let defaultLibrary = device!.makeDefaultLibrary()!
    let pipelineDescriptor = MTLRenderPipelineDescriptor()
    pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
    pipelineDescriptor.vertexFunction = defaultLibrary.makeFunction(name: "vertexPassThrough")
    pipelineDescriptor.fragmentFunction = defaultLibrary.makeFunction(name: "fragmentPassThrough")
    
    // To determine how textures are sampled, create a sampler descriptor to query for a sampler state from the device.
    let samplerDescriptor = MTLSamplerDescriptor()
    samplerDescriptor.sAddressMode = .clampToEdge
    samplerDescriptor.tAddressMode = .clampToEdge
    samplerDescriptor.minFilter = .linear
    samplerDescriptor.magFilter = .linear
    sampler = device!.makeSamplerState(descriptor: samplerDescriptor)
    
    do {
      renderPipelineState = try device!.makeRenderPipelineState(descriptor: pipelineDescriptor)
    } catch {
      fatalError("Unable to create preview Metal view pipeline state. (\(error))")
    }
    
    commandQueue = device!.makeCommandQueue()
  }
  
  func createTextureCache() {
    var newTextureCache: CVMetalTextureCache?
    if CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device!, nil, &newTextureCache) == kCVReturnSuccess {
      textureCache = newTextureCache
    } else {
      assertionFailure("Unable to allocate texture cache")
    }
  }
  
  override func draw(_ rect: CGRect) {
    var pixelBuffer: CVPixelBuffer?
    
    
    syncQueue.sync {
      pixelBuffer = internalPixelBuffer
    }
    
    guard let drawable = currentDrawable,
          let currentRenderPassDescriptor = currentRenderPassDescriptor,
          let previewPixelBuffer = pixelBuffer else {
      return
    }
    
    // Create a Metal texture from the image buffer.
    let width = CVPixelBufferGetWidth(previewPixelBuffer)
    let height = CVPixelBufferGetHeight(previewPixelBuffer)
    
    if textureCache == nil {
      createTextureCache()
    }
    var cvTextureOut: CVMetalTexture?
    CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                              textureCache!,
                                              previewPixelBuffer,
                                              nil,
                                              .bgra8Unorm,
                                              width,
                                              height,
                                              0,
                                              &cvTextureOut)
    guard let cvTexture = cvTextureOut, let texture = CVMetalTextureGetTexture(cvTexture) else {
      print("Failed to create preview texture")
      
      CVMetalTextureCacheFlush(textureCache!, 0)
      return
    }
    
    // Set up command buffer and encoder
    guard let commandQueue = commandQueue else {
      print("Failed to create Metal command queue")
      CVMetalTextureCacheFlush(textureCache!, 0)
      return
    }
    
    guard let commandBuffer = commandQueue.makeCommandBuffer() else {
      print("Failed to create Metal command buffer")
      CVMetalTextureCacheFlush(textureCache!, 0)
      return
    }
    
    guard let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: currentRenderPassDescriptor) else {
      print("Failed to create Metal command encoder")
      CVMetalTextureCacheFlush(textureCache!, 0)
      return
    }
    
    commandEncoder.label = "Preview display"
    commandEncoder.setRenderPipelineState(renderPipelineState!)
    commandEncoder.setVertexBuffer(vertexCoordBuffer, offset: 0, index: 0)
    commandEncoder.setVertexBuffer(textCoordBuffer, offset: 0, index: 1)
    commandEncoder.setFragmentTexture(texture, index: 0)
    commandEncoder.setFragmentSamplerState(sampler, index: 0)
    commandEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
    commandEncoder.endEncoding()
    
    // Draw to the screen.
    commandBuffer.present(drawable)
    commandBuffer.commit()
  }
  
}

extension CameraView {
  
  func applyEffect(_ imageBuffer: CMSampleBuffer) {
    
    guard let videoPixelBuffer = CMSampleBufferGetImageBuffer(imageBuffer),
          let formatDescription = CMSampleBufferGetFormatDescription(imageBuffer) else {
      return
    }
    
    if !cameraEffect.isPrepared {
      /*
       outputRetainedBufferCountHint is the number of pixel buffers the renderer retains. This value informs the renderer
       how to size its buffer pool and how many pixel buffers to preallocate. Allow 3 frames of latency to cover the dispatch_async call.
       */
      cameraEffect.prepare(with: formatDescription, outputRetainedBufferCountHint: 3)
    }
    
    //let start = Date()
    //os_signpost(.begin, log: OSLog.effects, name: "Start GPU Effect")
    
    if let inAnimation = uiDelegate?.parent.takePhoto, inAnimation == false {
      pixelBuffer = videoPixelBuffer
      lastPixelBuffer = videoPixelBuffer
    } else {
      guard let last = lastPixelBuffer else {
        return
      }
      
      let config = CameraEffectAnimator.shared.getEffectConfiguration()
      
      
      pixelBuffer = cameraEffect.apply(pixelBuffer: last, with: config)
    }
    
    //os_log("%{PUBLIC}@", log: OSLog.effects, type: .debug, "GPU Time: \(Date().timeIntervalSince(start))")
    //os_signpost(.end, log: OSLog.effects, name: "Finish GPU Effect")
  }
  
}
