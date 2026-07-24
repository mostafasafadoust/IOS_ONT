import SwiftUI
import WebKit

struct WebAutomationView: UIViewRepresentable {
    @ObservedObject var session: HuaweiWebSession

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.websiteDataStore = .nonPersistent()

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = false
        webView.isOpaque = false
        webView.backgroundColor = .clear
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }
        session.attach(webView)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        session.attach(uiView)
    }
}
