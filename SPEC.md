# ScreenTextGrab — specification

**Tagline:** Drag a box over any pixels on screen and the recognized text lands on your clipboard.

**Category:** Menu Bar Utility

**Inspired by (paid):** TextSniper ($9.99 one-time)

**Frameworks:** SwiftUI, AppKit, Vision, ScreenCaptureKit, CoreGraphics, ServiceManagement, UserNotifications

**Donation URL (Support button):** https://ko-fi.com/leodavidai

## Spec

What the paid app does and evidence of demand. TextSniper is a menu bar utility sold for roughly ten dollars one time. You press a hotkey, drag a rectangle over text in a video, PDF, image or remote desktop, and the text is copied to the clipboard. It is recommended repeatedly in Mac utility roundups, holds a 4.8 out of 5 rating on Capterra, and is a staple answer to the question of how to copy text from an image. Our clean-room version reproduces that one job well and for free.

Feature set for our version. A global hotkey starts region selection. After the drag, the app captures only that rectangle, runs on-device text recognition, copies the result to the clipboard and shows a small notification with a preview of the first line. Options include accurate or fast recognition, choice of recognition languages from the languages the system supports, automatic language detection, keeping or removing line breaks, and trimming whitespace. A second hotkey is optional and scans the entire main display. A short history of the last twenty captures is kept in memory only, shown in the menu so a lost copy can be recovered. An optional QR and barcode mode reads codes in the same region and copies the payload.

UI spec. This is a MenuBarExtra app with no Dock icon. The menu lists Capture Text, Capture Full Screen, Recent Captures with each entry clickable to copy again, Settings, and Quit. The Settings window has fields for the hotkey recorder, recognition level picker, language multi-select, a toggle for joining lines, a toggle for playing a sound, a toggle for notifications, and a launch at login switch. States: idle, selecting with a dimmed full-screen overlay and crosshair, processing with a brief spinner in the menu bar icon, and done. Escape cancels selection. Empty state for Recent Captures reads Nothing captured yet. If no text is found, the notification says No text found and the clipboard is left untouched.

Technical approach. The overlay is a borderless NSWindow per screen at a screen saver level that tracks mouse drag and draws a selection rectangle with a size readout. The region is captured with ScreenCaptureKit single-frame screenshot support, converted to a CGImage and handed to a Vision text recognition request, with the recognition languages set from settings and language correction enabled in accurate mode. Observations are sorted top to bottom and then left to right using bounding boxes and joined into a string. The string is written to the general pasteboard. The hotkey can be registered with the Carbon hot key API for a reliable global shortcut without Accessibility permission. Screen Recording permission is required and is requested on first capture by calling the system preflight and request functions for screen capture access, with an inline explanation window that offers a button to open the Privacy and Security pane. Settings persist through AppStorage in UserDefaults. Launch at login uses SMAppService main app registration.

Edge cases and error handling. Handle Retina scale by capturing at pixel resolution of the selection. Handle multiple displays by creating overlays for each and using the display under the pointer. If permission is denied, show a clear message and never crash. Very small selections under ten points are ignored. Rotated or vertical text is attempted by retrying recognition on the image rotated by ninety degrees when the first pass finds nothing and a setting for this is on. Cancel cleanly if the user switches Spaces. Keep no images on disk and release image buffers right after recognition to protect privacy.
