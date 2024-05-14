import Cocoa
import FlutterMacOS
import UserNotifications
public class LocalNotifierPlugin: NSObject, FlutterPlugin, UNUserNotificationCenterDelegate {
    var registrar: FlutterPluginRegistrar!
    var channel: FlutterMethodChannel!

    var notificationDict: Dictionary<String, UNNotificationRequest> = [:]

    public override init() {
        super.init()
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound, .badge]) { (granted, error) in
            // Handle error and authorization status
        }
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "local_notifier", binaryMessenger: registrar.messenger)
        let instance = LocalNotifierPlugin()
        instance.registrar = registrar
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "notify":
            notify(call, result: result)
            break
        case "close":
            close(call, result: result)
            break
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    public func notify(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as! Dictionary<String, Any>
        let identifier = args["identifier"] as! String
        let title = args["title"] as? String
        let subtitle = args["subtitle"] as? String
        let body = args["body"] as? String

        let content = UNMutableNotificationContent()
        content.title = title ?? ""
        content.subtitle = subtitle ?? ""
        content.body = body ?? ""
        content.sound = UNNotificationSound.default

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)

        let center = UNUserNotificationCenter.current()
        center.add(request) { (error) in
            if let error = error {
                result(FlutterError(code: "notification_error", message: error.localizedDescription, details: nil))
            } else {
                self.notificationDict[identifier] = request
                result(true)
            }
        }
    }

    public func close(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as! Dictionary<String, Any>
        let identifier = args["identifier"] as! String

        let center = UNUserNotificationCenter.current()
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
        self.notificationDict[identifier] = nil

        _invokeMethod("onLocalNotificationClose", identifier)
        result(true)
    }

    public func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        _invokeMethod("onLocalNotificationClick", response.notification.request.identifier)
        completionHandler()
    }

    public func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        _invokeMethod("onLocalNotificationShow", notification.request.identifier)
        completionHandler([.alert, .sound])
    }

    public func _invokeMethod(_ methodName: String, _ notificationId: String) {
        let args: NSDictionary = [
            "notificationId": notificationId,
        ]
        channel.invokeMethod(methodName, arguments: args, result: nil)
    }
}