import Flutter
import UIKit
import UserNotifications

class SceneDelegate: FlutterSceneDelegate {
  /// Must stay in sync with `ColdLinkReader._key` on the Dart side. The
  /// `flutter.` prefix is what the shared-preferences plugin prepends on iOS.
  static let coldLinkKey = "flutter.rdp_cold_link"

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)

    guard
      let response = connectionOptions.notificationResponse,
      let destination = Self.destination(
        inside: response.notification.request.content.userInfo
      )
    else { return }

    let defaults = UserDefaults.standard
    defaults.set(destination, forKey: Self.coldLinkKey)
    defaults.synchronize()

    #if DEBUG
    NSLog("[RDP.LINK] captured cold-start destination")
    #endif
  }

  private static func destination(
    inside payload: [AnyHashable: Any]
  ) -> String? {
    let candidates = ["deep_link", "target", "url", "deeplink", "link"]

    func firstValue(in dictionary: [AnyHashable: Any]) -> String? {
      for candidate in candidates {
        guard let value = dictionary[candidate] as? String else { continue }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
      }
      return nil
    }

    if let direct = firstValue(in: payload) { return direct }

    for container in ["payload", "data"] {
      if let nested = payload[container] as? [AnyHashable: Any],
         let value = firstValue(in: nested) {
        return value
      }
    }
    return nil
  }
}
