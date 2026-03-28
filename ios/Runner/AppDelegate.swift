import Flutter
import UIKit
import YandexMapsMobile
import CoreLocation

private final class LocationPermissionBridge: NSObject, CLLocationManagerDelegate {
  private let channel: FlutterMethodChannel
  private var locationManager: CLLocationManager?
  private var pendingResult: FlutterResult?
  private var pendingTimeoutWorkItem: DispatchWorkItem?

  init(channel: FlutterMethodChannel) {
    self.channel = channel
    super.init()
    channel.setMethodCallHandler(handle)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "status":
      result(currentPayload())
    case "requestWhenInUse":
      requestWhenInUse(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func requestWhenInUse(result: @escaping FlutterResult) {
    guard CLLocationManager.locationServicesEnabled() else {
      result(payload(status: currentStatusString(), servicesEnabled: false))
      return
    }

    ensureLocationManager()

    if pendingResult != nil {
      result(
        FlutterError(
          code: "LOCATION_REQUEST_IN_PROGRESS",
          message: "Location permission request is already in progress.",
          details: nil
        )
      )
      return
    }

    pendingResult = result
    locationManager?.requestWhenInUseAuthorization()

    let timeoutItem = DispatchWorkItem { [weak self] in
      self?.resolvePendingResult()
    }
    pendingTimeoutWorkItem = timeoutItem
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: timeoutItem)
  }

  private func ensureLocationManager() {
    guard locationManager == nil else { return }
    let manager = CLLocationManager()
    manager.delegate = self
    locationManager = manager
  }

  private func authorizationStatus() -> CLAuthorizationStatus {
    if #available(iOS 14.0, *) {
      return locationManager?.authorizationStatus ?? CLLocationManager.authorizationStatus()
    }
    return CLLocationManager.authorizationStatus()
  }

  private func currentStatusString() -> String {
    statusString(authorizationStatus())
  }

  private func payload(status: String, servicesEnabled: Bool) -> [String: Any] {
    [
      "status": status,
      "servicesEnabled": servicesEnabled,
    ]
  }

  private func currentPayload() -> [String: Any] {
    payload(
      status: currentStatusString(),
      servicesEnabled: CLLocationManager.locationServicesEnabled()
    )
  }

  private func statusString(_ status: CLAuthorizationStatus) -> String {
    switch status {
    case .authorizedAlways:
      return "authorizedAlways"
    case .authorizedWhenInUse:
      return "authorizedWhenInUse"
    case .denied:
      return "denied"
    case .restricted:
      return "restricted"
    case .notDetermined:
      return "notDetermined"
    @unknown default:
      return "notDetermined"
    }
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    resolvePendingResultIfFinalStatus()
  }

  func locationManager(
    _ manager: CLLocationManager,
    didChangeAuthorization status: CLAuthorizationStatus
  ) {
    resolvePendingResultIfFinalStatus()
  }

  private func resolvePendingResultIfFinalStatus() {
    if authorizationStatus() == .notDetermined {
      return
    }
    resolvePendingResult()
  }

  private func resolvePendingResult() {
    guard let result = pendingResult else { return }
    pendingTimeoutWorkItem?.cancel()
    pendingTimeoutWorkItem = nil
    pendingResult = nil
    result(currentPayload())
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var locationPermissionBridge: LocationPermissionBridge?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let apiKey = Bundle.main.object(forInfoDictionaryKey: "YANDEX_MAPKIT_API_KEY") as? String,
       !apiKey.isEmpty,
       !apiKey.contains("$(") {
      YMKMapKit.setApiKey(apiKey)
    }

    GeneratedPluginRegistrant.register(with: self)
    let didFinish = super.application(application, didFinishLaunchingWithOptions: launchOptions)

    // Register channel via plugin registrar to avoid dependency on window lifecycle.
    guard let registrar = self.registrar(forPlugin: "LocationPermissionBridge") else {
      return didFinish
    }
    let channel = FlutterMethodChannel(
      name: "hozyain/location_permission",
      binaryMessenger: registrar.messenger()
    )
    locationPermissionBridge = LocationPermissionBridge(channel: channel)

    return didFinish
  }
}
