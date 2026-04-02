import Cocoa
import WebKit

class LuminaWindow: NSObject, NSApplicationDelegate, WKNavigationDelegate {
    var window: NSWindow!
    var webView: WKWebView!
    let port = 3457

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Get screen size for fullscreen-ish window
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let frame = screen.visibleFrame

        // Create window
        window = NSWindow(
            contentRect: frame,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Lumina FX"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = NSColor(red: 0.027, green: 0.035, blue: 0.051, alpha: 1.0) // #07090d
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.fullScreenPrimary]

        // Configure WKWebView with permissions for audio, localStorage, WebSocket
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        config.mediaTypesRequiringUserActionForPlayback = []
        config.preferences.javaScriptCanOpenWindowsAutomatically = true

        // Allow localStorage persistence
        let dataStore = WKWebsiteDataStore.default()
        config.websiteDataStore = dataStore

        webView = WKWebView(frame: window.contentView!.bounds, configuration: config)
        webView.autoresizingMask = [.width, .height]
        webView.navigationDelegate = self
        webView.setValue(false, forKey: "drawsBackground") // Transparent until loaded

        window.contentView?.addSubview(webView)

        // Wait for server to be ready, then load
        pollServer()

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func pollServer(attempt: Int = 0) {
        let url = URL(string: "http://localhost:\(port)")!
        var request = URLRequest(url: url, timeoutInterval: 2)
        request.httpMethod = "HEAD"

        URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                DispatchQueue.main.async {
                    self?.webView.load(URLRequest(url: url))
                }
            } else if attempt < 30 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self?.pollServer(attempt: attempt + 1)
                }
            } else {
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = "Lumina FX server did not start"
                    alert.informativeText = "Could not connect to localhost:\(self?.port ?? 3457) after 30 seconds."
                    alert.runModal()
                }
            }
        }.resume()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    // Handle navigation to open external links in default browser
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url {
            if url.host == "localhost" || url.host == "127.0.0.1" {
                decisionHandler(.allow)
            } else {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
            }
        } else {
            decisionHandler(.allow)
        }
    }
}

// Launch
let app = NSApplication.shared
let delegate = LuminaWindow()
app.delegate = delegate
app.run()
