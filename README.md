# Flutter Local Wi-Fi Share 📱📡

A powerful, cross-platform Flutter application that enables seamless file sharing between devices connected to the same Wi-Fi network. No internet connection required!

## 🚀 Features

- **Cross-Platform**: Run the app on Android, iOS, and macOS.
- **Web Interface**: Devices without the app (like Windows/Linux PCs) can upload and download files via a modern web browser.
- **Auto-Discovery**: Instantly find other devices running the app using Zeroconf/mDNS (Bonsoir).
- **Direct App Transfer**: Browse files on nearby devices and download them directly within the app.
- **Manual IP Connect**: Connect directly to a specific device IP if discovery is restricted on the network.
- **Share From Other Apps**: Send files to the app from your gallery or file manager using the system share menu.
- **Fast Transfer**: Transfers occur directly over the local network (LAN) for maximum speed.
- **Privacy & Security**: Data never leaves your local network.

## 📸 Screenshots

| Home Screen | Direct Transfer | Web Interface |
|:---:|:---:|:---:|
| *(Add Screenshot)* | *(Add Screenshot)* | *(Add Screenshot)* |

## 🛠 Usage

1. **Connect**: Ensure all devices are on the same Wi-Fi network.
2. **Start**: Open the app on your device.
3. **Share**:
    - **App-to-App**: Nearby devices appear automatically. Tap a device to **Browse** its shared files, **Download** them, or **Send** your own files to it.
    - **Web Browser**: On a PC or other device, open the URL displayed on the app (e.g., `http://192.168.1.5:8080`).
    - **Manual Connect**: Use the "Connect to IP manually" button if a device doesn't appear automatically.

## 📦 Installation Service

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/flutter_share.git
   ```
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Run the app:
   ```bash
   flutter run
   ```

4. **Release Build (Android)**:
   ```bash
   flutter build appbundle --release
   ```

## 📝 Notes

- **Android**: Requires permissions for Wi-Fi state and local file access. 
- **iOS**: Requires Local Network usage permission.
- **macOS**: App Sandbox entitlement is required for file access/network client.

---
*Built with Flutter* 💙
