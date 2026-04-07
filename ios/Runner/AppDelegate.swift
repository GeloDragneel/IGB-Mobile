import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var blurView: UIVisualEffectView?
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Add observer for app entering background
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(appDidEnterBackground),
      name: UIApplication.didEnterBackgroundNotification,
      object: nil
    )
    
    // Add observer for app becoming active
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(appWillEnterForeground),
      name: UIApplication.willEnterForegroundNotification,
      object: nil
    )
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  @objc private func appDidEnterBackground() {
    // Add blur overlay when app enters background to prevent screenshots
    guard let window = window else { return }
    
    let blurEffect = UIBlurEffect(style: .dark)
    blurView = UIVisualEffectView(effect: blurEffect)
    blurView?.frame = window.bounds
    blurView?.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    blurView?.tag = 999
    
    window.addSubview(blurView!)
  }
  
  @objc private func appWillEnterForeground() {
    // Remove blur overlay when app enters foreground
    window?.viewWithTag(999)?.removeFromSuperview()
    blurView = nil
  }
  
  deinit {
    NotificationCenter.default.removeObserver(self)
  }
}
