# Imam Ali Center for iPhone

This SwiftUI app adapts the [Imam Ali Center website](https://imamalicenter.org/) for iPhone. It targets iOS 17 and later. Use Xcode with an installed iOS Simulator runtime.

## Preview on a separate iPhone

Double-click **Preview.command** in Finder. The launcher builds and runs the app on **IAC • App Preview**. To see its screen, open Simulator and choose **File → Open Simulator → [iOS version] → IAC • App Preview**. The launcher prints the version and device ID in Terminal.

The launcher reuses the project’s verified device ID or creates a dedicated iPhone. Its device receipt and Xcode build files live in `.iac-preview` beside the project. It leaves the simulator running for you to explore.

## Open in Xcode

Open **ImamAliCenter.xcodeproj**, choose the **ImamAliCenter** scheme, select **IAC • App Preview** as the destination, and press **⌘R**. The launcher creates this destination on first use if needed. For a physical iPhone, choose your development team in the app target’s **Signing & Capabilities** settings.

## Content and connectivity

The native home, directory, contact details and Springfield prayer calculations are bundled. The weekly schedule refreshes from the Center’s homepage and uses the last valid schedule, or the bundled one, when offline. Prayer times use the same AlAdhan settings and local calculation as the Center’s website. The app also includes read-only copies of the site’s detail pages and selected photos for offline reading. In a detail page, use the ••• menu to read the saved copy. The bundled content reflects the website on November 4, 2026.

An internet connection is needed for current website content, maps, media, inquiry forms and donations. Those actions keep the Center’s published destinations and verification steps. Phone calls, email and directions open through the device’s available apps.
