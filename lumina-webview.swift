import Cocoa
import WebKit
import UniformTypeIdentifiers

class LuminaWindow: NSObject, NSApplicationDelegate, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
    var window: NSWindow!
    var webView: WKWebView!
    let port = 3457
    var urlPath: String = ""
    var windowTitle: String = "Lumina FX"
    var vizWindow: NSWindow?
    var vizWebView: WKWebView?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let args = CommandLine.arguments
        for i in 0..<args.count {
            if args[i] == "--path" && i + 1 < args.count {
                urlPath = args[i + 1]
            }
            if args[i] == "--title" && i + 1 < args.count {
                windowTitle = args[i + 1]
            }
        }

        let screen = NSScreen.main ?? NSScreen.screens[0]
        let frame = screen.visibleFrame

        window = NSWindow(
            contentRect: frame,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = windowTitle
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = NSColor(red: 0.027, green: 0.035, blue: 0.051, alpha: 1.0)
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.fullScreenPrimary]

        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        config.mediaTypesRequiringUserActionForPlayback = []
        config.preferences.javaScriptCanOpenWindowsAutomatically = true

        let dataStore = WKWebsiteDataStore.default()
        config.websiteDataStore = dataStore

        // Register JS-to-native message handler for viz window
        config.userContentController.add(self, name: "lumina")

        webView = WKWebView(frame: window.contentView!.bounds, configuration: config)
        webView.autoresizingMask = [.width, .height]
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.setValue(false, forKey: "drawsBackground")

        window.contentView?.addSubview(webView)

        pollServer()

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // Handle messages from JS: window.webkit.messageHandlers.lumina.postMessage(...)
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let action = body["action"] as? String else { return }

        if action == "openViz" {
            openVizWindow()
        }
    }

    func openVizWindow() {
        // If viz window already exists, just bring it to front
        if let vw = vizWindow, vw.isVisible {
            vw.makeKeyAndOrderFront(nil)
            return
        }

        let screen = NSScreen.main ?? NSScreen.screens[0]
        let screenFrame = screen.visibleFrame
        let w: CGFloat = 1200
        let h: CGFloat = 700
        let x = screenFrame.origin.x + (screenFrame.width - w) / 2
        let y = screenFrame.origin.y + (screenFrame.height - h) / 2

        let vw = NSWindow(
            contentRect: NSRect(x: x, y: y, width: w, height: h),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        vw.title = "Lumina Viz"
        vw.titlebarAppearsTransparent = true
        vw.titleVisibility = .hidden
        vw.backgroundColor = NSColor(red: 0.027, green: 0.035, blue: 0.051, alpha: 1.0)
        vw.isReleasedWhenClosed = false
        vw.collectionBehavior = [.fullScreenPrimary]

        let vizConfig = WKWebViewConfiguration()
        vizConfig.preferences.setValue(true, forKey: "developerExtrasEnabled")
        vizConfig.mediaTypesRequiringUserActionForPlayback = []
        let vizDataStore = WKWebsiteDataStore.default()
        vizConfig.websiteDataStore = vizDataStore

        let vwv = WKWebView(frame: vw.contentView!.bounds, configuration: vizConfig)
        vwv.autoresizingMask = [.width, .height]
        vwv.navigationDelegate = self
        vwv.setValue(false, forKey: "drawsBackground")

        vw.contentView?.addSubview(vwv)

        let vizURL = URL(string: "http://localhost:\(port)/viz")!
        vwv.load(URLRequest(url: vizURL))

        vw.makeKeyAndOrderFront(nil)

        vizWindow = vw
        vizWebView = vwv
    }

    func pollServer(attempt: Int = 0) {
        let url = URL(string: "http://localhost:\(port)\(urlPath)")!
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

    // Handle <input type="file"> — required for file pickers in WKWebView
    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = parameters.allowsMultipleSelection
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        // Build allowed types from the accept attribute via private API if available,
        // otherwise use known Lumina file types
        var types: [UTType] = []

        // Try to read accepted extensions from WKOpenPanelParameters (private API)
        let exts = (parameters.value(forKey: "_acceptedFileExtensions") as? [String]) ?? []
        if !exts.isEmpty {
            for ext in exts {
                let clean = ext.replacingOccurrences(of: ".", with: "")
                if let ut = UTType(filenameExtension: clean) {
                    types.append(ut)
                }
            }
        }

        // If we got specific types, filter the panel
        if !types.isEmpty {
            panel.allowedContentTypes = types
        }
        // Otherwise: no filter — user sees all files (the web layer validates)

        panel.begin { response in
            if response == .OK {
                completionHandler(panel.urls)
            } else {
                completionHandler(nil)
            }
        }
    }

    // Fallback: also handle window.open() via WKUIDelegate
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url {
            if url.host == "localhost" || url.host == "127.0.0.1" {
                if url.path.contains("viz") {
                    openVizWindow()
                    return nil
                }
                webView.load(navigationAction.request)
            } else {
                NSWorkspace.shared.open(url)
            }
        }
        return nil
    }
}

let app = NSApplication.shared
let delegate = LuminaWindow()
app.delegate = delegate
app.run()
