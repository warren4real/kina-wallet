import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  private var privacyCover: UIView?
  private var privacyChannel: FlutterMethodChannel?

  override func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
                      options connectionOptions: UIScene.ConnectionOptions) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    if let controller = window?.rootViewController as? FlutterViewController {
      privacyChannel = FlutterMethodChannel(name: "kina_wallet/privacy",
                                           binaryMessenger: controller.binaryMessenger)
      privacyChannel?.setMethodCallHandler { [weak self] call, result in
        guard call.method == "lockScreenReady" else {
          result(FlutterMethodNotImplemented)
          return
        }
        if self?.window?.windowScene?.activationState == .foregroundActive {
          self?.privacyCover?.removeFromSuperview()
          self?.privacyCover = nil
        }
        result(nil)
      }
    }
  }

  private func coverWallet() {
    guard privacyCover == nil, let window = window else { return }
    window.endEditing(true)
    let cover = UIView(frame: window.bounds)
    cover.backgroundColor = UIColor(red: 16/255, green: 36/255, blue: 67/255, alpha: 1)
    cover.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    let label = UILabel()
    label.text = "Kina Wallet · Locked"
    label.textColor = .white
    label.font = .systemFont(ofSize: 22, weight: .semibold)
    label.translatesAutoresizingMaskIntoConstraints = false
    cover.addSubview(label)
    NSLayoutConstraint.activate([
      label.centerXAnchor.constraint(equalTo: cover.centerXAnchor),
      label.centerYAnchor.constraint(equalTo: cover.centerYAnchor)
    ])
    window.addSubview(cover)
    privacyCover = cover
  }

  override func sceneWillResignActive(_ scene: UIScene) {
    coverWallet()
    super.sceneWillResignActive(scene)
  }

  override func sceneDidEnterBackground(_ scene: UIScene) {
    coverWallet()
    super.sceneDidEnterBackground(scene)
  }
}
