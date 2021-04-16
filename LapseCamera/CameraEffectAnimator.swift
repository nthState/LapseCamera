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
  private let blurRelativeStartOffsetPercentage: TimeInterval = 0.25
  private let blurFinish: Float = 20
  
  // MARK: - Aberration
  
  private let red: Float = 9
  private let green: Float = 10.0
  private let blue: Float = 10.0
  private let aberration: Float = -1.4 // Number is just random, feels ok, hard to get from After Effects
  
  // MARK: - Frame Counters
  
  public var start: Date = Date()
  
}

extension CameraEffectAnimator {
  
  private func getBlur(interval: TimeInterval) -> Float {
    
    guard interval > (totalDuration * blurRelativeStartOffsetPercentage) else {
      return 0.0
    }
    
    guard (interval > totalDuration) == false else {
      return blurFinish
    }
    
    let t: Float = Float(interval - (totalDuration * blurRelativeStartOffsetPercentage)) / Float(totalDuration)
    
    let percent = easeInQuint(x: t)
    
    //print("blur: \(percent), at \(t)")
    return percent * blurFinish
  }
  
  private func getDistortion(interval: TimeInterval) -> Float {
    
    guard (interval > totalDuration) == false else {
      return aberration
    }
    
    let t: Float = Float(interval) / Float(totalDuration)
    
    let percent = easeOutCirc(x: t)
    
    //print("distortion: \(percent), at \(t)")
    return percent * aberration
  }
  
  private func getAberration(interval: TimeInterval) -> (Int, Int, Int) {
    
    guard (interval > totalDuration) == false else {
      return (Int(red), Int(green), Int(blue))
    }
    
    let t: Float = Float(interval) / Float(totalDuration)
    
    let percent = easeOutCirc(x: t)
    
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
  
  func easeOutQuint(x: Float) -> Float {
    return 1 - pow(1 - x, 5);
  }
  
  func easeOutCirc(x: Float) -> Float {
    return sqrt(1 - pow(x - 1, 2));
  }
  
  func easeInQuint(x: Float) -> Float {
  return x * x * x * x * x;
  }
  
}
