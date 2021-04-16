//
//  Animation.swift
//  LapseCamera
//
//  Created by Chris Davis on 15/04/2021.
//

import Foundation
import Metal
import MetalKit
import LapseCameraEffect

typealias CubicBezier = (Float, Float, Float, Float)

/**
 https://cubic-bezier.com/#0,1.2,0.21,0.08
 */
class CameraEffectAnimator {
  
  static var shared: CameraEffectAnimator = CameraEffectAnimator()
  
  /// Total animation duration
  public var totalDuration: TimeInterval = 0.82
  
  // MARK: - Blur
  
  /// X seconds after the animation starts, the blur starts
  private let blurRelativeStartTimeOffset: TimeInterval = 0.05
  private let blurEasing = CubicBezier(1,0,1,1)
  private let blurFinish: Float = 20
  
  // MARK: - Aberration
  
  private let aberrationEasing = CubicBezier(0.17,1.15,1,1)
  private let red: Float = 9
  private let green: Float = 10.0
  private let blue: Float = 10.0
  private let aberration: Float = -1.4 // Number is just random, feels ok, hard to get from After Effects
  
  // MARK: - Frame Counters
  
  public var start: Date = Date()
  
}

extension CameraEffectAnimator {
  
  private func getBlur(interval: TimeInterval) -> Float {
    
    guard interval > blurRelativeStartTimeOffset else {
      return 0.0
    }
    
    guard (interval > totalDuration) == false else {
      return blurFinish
    }
    
    let t: Float = Float(interval) / Float(totalDuration)
    
    let percent = catmullRom(p0: blurEasing.0, p1: blurEasing.1, p2: blurEasing.2, p3: blurEasing.3, t: t)
    
    //print("blur: \(percent), at \(t)")
    return percent * blurFinish
  }
  
  private func getDistortion(interval: TimeInterval) -> Float {
    
    guard (interval > totalDuration) == false else {
      return aberration
    }
    
    let t: Float = Float(interval) / Float(totalDuration)
    
    let percent = cubicLerp(p0: aberrationEasing.0, p1: aberrationEasing.1, p2: aberrationEasing.2, p3: aberrationEasing.3, t: t)
    
    //print("distortion: \(percent), at \(t)")
    return percent * aberration
  }
  
  private func getAberration(interval: TimeInterval) -> (Int, Int, Int) {
    
    guard (interval > totalDuration) == false else {
      return (Int(red), Int(green), Int(blue))
    }
    
    let t: Float = Float(interval) / Float(totalDuration)
    
    let percent = cubicLerp(p0: aberrationEasing.0, p1: aberrationEasing.1, p2: aberrationEasing.2, p3: aberrationEasing.3, t: t)
    
    //print("distortion: \(percent), at \(t)")
    return (Int(red * percent), Int(green * percent), Int(blue * percent))
  }
  
}

extension CameraEffectAnimator {
  
  public func getEffectConfiguration() -> EffectConfiguration {
    
    let interval = Date().timeIntervalSince(start) // seconds
    
    let ab = getAberration(interval: interval)
    return EffectConfiguration(aberration: Aberration(red: ab.0, green: ab.1, blue: ab.2),
                               blur: getBlur(interval: interval),
                               distortion: getDistortion(interval: interval))
  }
  
}

extension CameraEffectAnimator {
  
  private func cubicLerp(p0: Float, p1: Float, p2: Float, p3: Float, t: Float) -> Float {
    let r: Float = 1.0 - t;
    let f0: Float = r * r * r;
    let f1: Float = r * r * t * 3;
    let f2: Float = r * t * t * 3;
    let f3: Float = t * t * t;
    let a = (f0*p0)
    let b = (f1*p1)
    let c = (f2*p2)
    let d = (f3*p3)
    return a + b + c + d
  }
  
  private func catmullRom(p0: Float, p1: Float, p2: Float, p3: Float, t: Float) -> Float {
    return 0.5 * (
      (2 * p1) +
        (-p0 + p2) * t +
        (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t +
        (-p0 + 3 * p1 - 3 * p2 + p3) * t * t * t
    )
  }
  
}
