# WhatsApp OSINT Bridge: User Guide

The **WhatsApp OSINT Bridge** transforms WhatsApp Web into a powerful intelligence dashboard, overlaying realtime entity analysis and one-click OSINT lookups directly onto your chats.

## 1. Installation (One-Time Setup)

Since this is a developer extension, you need to load it manually into Chrome:

1.  Open Chrome and navigate to `chrome://extensions`.
2.  Enable **Developer mode** (toggle in the top-right corner).
3.  Click **Load unpacked** (top-left).
4.  Select the `extension` folder inside your project directory:
    - Path: `d:\Automation\AIProject\exiftool\extension`
5.  The "ExifTool Architect // OSINT Bridge" extension should now appear in your list.

## 2. Activation

1.  Ensure your **ExifTool Backend** is running:
    ```bash
    cd d:\Automation\AIProject\exiftool
    node server.js
    ```
2.  Open [WhatsApp Web](https://web.whatsapp.com).
3.  The bridge activates automatically. You will see a "Status: Active" indicator or simply notice the new overlays appearing on messages.

## 3. Features & Usage

### 🛡️ Entity Highlighter

The bridge scans incoming messages for actionable intelligence entities. When detected, a **Shield Icon** (🛡️) appears next to the entity.

- **Phone Numbers**: Detects international formats (e.g., `+1-555-0199`).
- **Emails**: Highlights email addresses for identity checks.
- **Crypto Addresses**: Identifies Bitcoin (BTC) and Ethereum (ETH) wallets.
- **URLs**: Flags suspicious or analyzable links.

### 🧠 Intelligence Report (The Overlay)

**Click the Shield Icon** (🛡️) to open the Intelligence Report overlay.

This dashboard gives you instant access to external OSINT tools for the detected entity:

- **Phone**: Direct links to _WhatsApp Direct_, _TrueCaller_, and _Sync.me_.
- **Username (Email)**: Quick search on _Sherlock_ or _WhatsMyName_.
- **Domain**: Check reputation on _VirusTotal_, _UrlScan_, or _Whois_.

### 🖼️ Media Analysis

When you view an image in WhatsApp:

1.  Look for the **"Analyze Media"** button overlaid on the image viewer.
2.  Click it to instantly:
    - Extract hidden metadata (EXIF/GPS).
    - Perform a Reverse Image Search (Google Lens, Bing, Yandex).

## 4. Troubleshooting

- **"Connection Error"**: Ensure the backend server is running on `http://localhost:3001`.
- **Extension not updating**: If you make code changes, go back to `chrome://extensions` and click the refresh (undo) icon on the extension card.
