import AVFoundation
import Flutter
import GoogleSignIn
import Intents
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {

  // Store channel references for later use
  private var badgeChannel: FlutterMethodChannel?
  private var dndChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    // Initialize Google Sign-In
    if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
      let plist = NSDictionary(contentsOfFile: path),
      let clientId = plist["CLIENT_ID"] as? String
    {
      GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientId)
    }

    GeneratedPluginRegistrant.register(with: self)

    // Setup platform channels using FlutterPluginRegistry
    setupPlatformChannels()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func setupPlatformChannels() {
    // Get the Flutter view controller - use window property from FlutterAppDelegate
    guard let window = self.window,
      let controller = window.rootViewController as? FlutterViewController
    else {
      print("⚠️ Failed to get FlutterViewController")
      return
    }

    // Badge channel
    badgeChannel = FlutterMethodChannel(
      name: "com.lectio_divina/badge",
      binaryMessenger: controller.binaryMessenger)
    badgeChannel?.setMethodCallHandler { [weak self] (call, result) in
      if call.method == "clearBadge" {
        DispatchQueue.main.async {
          UIApplication.shared.applicationIconBadgeNumber = 0
          UNUserNotificationCenter.current().removeAllDeliveredNotifications()
          result(true)
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    // Do Not Disturb channel
    dndChannel = FlutterMethodChannel(
      name: "sk.lectio.divina/do_not_disturb",
      binaryMessenger: controller.binaryMessenger)
    dndChannel?.setMethodCallHandler { [weak self] (call, result) in
      switch call.method {
      case "checkDndPermissions":
        self?.checkDndPermissions(result: result)
      case "requestDndPermissions":
        self?.requestDndPermissions(result: result)
      case "activateIOSFocus":
        if let arguments = call.arguments as? [String: Any] {
          self?.activateIOSFocus(arguments: arguments, result: result)
        } else {
          result(
            FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
        }
      case "deactivateIOSFocus":
        self?.deactivateIOSFocus(result: result)
      case "activateIOSSilent":
        self?.activateIOSSilent(result: result)
      case "deactivateIOSSilent":
        self?.deactivateIOSSilent(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  // Handle Google Sign-In URL scheme
  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    if GIDSignIn.sharedInstance.handle(url) {
      return true
    }
    return super.application(app, open: url, options: options)
  }

  // MARK: - Do Not Disturb Methods

  private func checkDndPermissions(result: @escaping FlutterResult) {
    // Na iOS, Focus modes nie sú dostupné cez API pre third-party aplikácie
    // Môžeme len skontrolovať notification permissions
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      DispatchQueue.main.async {
        let hasPermissions = settings.authorizationStatus == .authorized
        result(hasPermissions)
      }
    }
  }

  private func requestDndPermissions(result: @escaping FlutterResult) {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) {
      granted, _ in
      DispatchQueue.main.async {
        result(granted)
      }
    }
  }

  private func activateIOSFocus(arguments: [String: Any], result: @escaping FlutterResult) {
    // iOS Focus API nie je dostupné pre third-party aplikácie
    // Namiesto toho použijeme fallback na silent mode
    if #available(iOS 15.0, *) {
      // Môžeme vytvoriť Intent pre Shortcuts app, ale nie priamo aktivovať Focus
      // Fallback na silent mode
      activateIOSSilent(result: result)
    } else {
      activateIOSSilent(result: result)
    }
  }

  private func deactivateIOSFocus(result: @escaping FlutterResult) {
    // Deaktivácia cez silent mode fallback
    deactivateIOSSilent(result: result)
  }

  private func activateIOSSilent(result: @escaping FlutterResult) {
    // Na iOS nemôžeme programaticky zapnúť skutočný Do Not Disturb
    // Apple to z bezpečnostných dôvodov nepovoľuje third-party aplikáciám
    //
    // Môžeme len:
    // 1. Nakonfigurovať audio session pre prioritu nášho audia
    // 2. Informovať používateľa ako aktivovať DND manuálne
    // 3. Použiť Shortcuts/Siri pre automatizáciu (ak má používateľ nastavené)

    do {
      let audioSession = AVAudioSession.sharedInstance()
      // Nastav kategóriu pre background playback s priority
      try audioSession.setCategory(
        .playback, mode: .spokenAudio,
        options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers])
      try audioSession.setActive(true)

      // Skontroluj či je používateľ už v DND režime
      if isInDoNotDisturbMode() {
        // Používateľ už má DND zapnutý
        result(true)
        return
      }

      // Zobraz alert s možnosťami pre používateľa
      DispatchQueue.main.async {
        self.showDoNotDisturbPrompt()
      }

      result(true)
    } catch {
      result(
        FlutterError(
          code: "AUDIO_SESSION_ERROR", message: "Failed to configure audio session",
          details: error.localizedDescription))
    }
  }

  // Skontroluje či je zariadenie v Do Not Disturb režime
  private func isInDoNotDisturbMode() -> Bool {
    // Na iOS nie je priamy spôsob ako zistiť DND stav
    // Môžeme len odhadnúť na základe notification settings
    var isInDND = false

    let semaphore = DispatchSemaphore(value: 0)
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      // Ak sú notifikácie zakázané a nie je to kvôli chýbajúcim permissionom
      isInDND = settings.authorizationStatus == .authorized && settings.alertSetting == .disabled
      semaphore.signal()
    }
    semaphore.wait()

    return isInDND
  }

  // Zobrazí prompt pre aktiváciu Do Not Disturb
  private func showDoNotDisturbPrompt() {
    guard let window = self.window,
      let rootViewController = window.rootViewController as? FlutterViewController
    else {
      return
    }

    let alert = UIAlertController(
      title: "Režim Nerušiť - Lectio Divina",
      message:
        "Pre najlepší duchovný zážitok aktivujte 'Nerušiť' manuálne:\n\n1. Prejdite do Control Center (potiahnite zhora)\n2. Stlačte ikonu 'Nerušiť' 🌙\n3. Alebo aktivujte Focus režim 'Modlitba' ak ho máte nastavený",
      preferredStyle: .alert
    )

    // Tlačidlo pre otvorenie nastavení
    alert.addAction(
      UIAlertAction(title: "Otvoriť nastavenia", style: .default) { _ in
        if let url = URL(string: UIApplication.openSettingsURLString) {
          UIApplication.shared.open(url)
        }
      })

    // Tlačidlo pre pokračovanie bez DND
    alert.addAction(UIAlertAction(title: "Pokračovať bez DND", style: .cancel))

    // Tlačidlo "Už mám zapnuté"
    alert.addAction(UIAlertAction(title: "Už mám zapnuté", style: .default))

    rootViewController.present(alert, animated: true)
  }

  private func deactivateIOSSilent(result: @escaping FlutterResult) {
    do {
      let audioSession = AVAudioSession.sharedInstance()
      try audioSession.setCategory(.playback, mode: .default, options: [])

      // Odstráň DND instruction notifikáciu
      UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [
        "dnd_instruction"
      ])

      result(true)
    } catch {
      result(
        FlutterError(
          code: "AUDIO_SESSION_ERROR", message: "Failed to reset audio session",
          details: error.localizedDescription))
    }
  }
}
