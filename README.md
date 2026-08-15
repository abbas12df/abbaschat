🔐 Nisaba

Private • Secure • Modern Messaging

Nisaba is a privacy-focused messaging application built with Flutter and Firebase, designed to provide secure communication between users while keeping message content protected through client-side encryption.

The application combines modern messaging features with a security-oriented architecture, including End-to-End Encryption (E2EE), encrypted local storage, secure key management, biometric protection, media sharing, voice messages, notifications, and real-time communication.

«⚠️ Security Notice: AbbasChat is an actively developed project. Although the application implements strong cryptographic mechanisms, it should not be considered independently audited or production-grade security software until a professional security audit has been completed.»

---

✨ Features

💬 Messaging

- Real-time private messaging
- Message encryption before transmission
- Text messages
- Image sharing
- File sharing
- Voice messages
- Message timestamps
- Online/offline communication state
- Conversation history
- Local encrypted message storage

🔒 Security & Privacy

AbbasChat is designed around a client-side encryption model.

The application uses:

- AES-256-GCM for message/content encryption
- RSA-2048 for secure key exchange
- Ephemeral session keys
- Key rotation
- Digital signatures
- SHA-256 hashing
- Secure random number generation
- Encrypted local storage
- Android Keystore / iOS Keychain through secure storage
- Biometric authentication
- Application lock
- Screen capture protection

The general concept is:

User A
   │
   │ Encrypt
   ▼
Encrypted Message
   │
   │
   ▼
Firebase / Backend
   │
   │
   ▼
Encrypted Message
   │
   │ Decrypt
   ▼
User B

The backend is intended to transport encrypted data rather than act as the place where plaintext conversations are processed.

---

🛡️ Encryption Architecture

AbbasChat uses a hybrid cryptographic architecture.

Content Encryption

Messages and supported content are encrypted using:

AES-256-GCM

AES-GCM provides:

- Confidentiality
- Integrity
- Authentication of encrypted data

Key Protection

RSA-2048 is used as part of the asymmetric cryptographic layer for protecting session-related encryption material.

Conceptually:

                    ┌─────────────────┐
                    │     User A      │
                    └────────┬────────┘
                             │
                      Generate Session Key
                             │
                             ▼
                    ┌─────────────────┐
                    │   AES-256-GCM   │
                    └────────┬────────┘
                             │
                       Encrypt Content
                             │
                             ▼
                    ┌─────────────────┐
                    │ Encrypted Data  │
                    └────────┬────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │ Firebase / DB   │
                    └────────┬────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │ Encrypted Data  │
                    └────────┬────────┘
                             │
                       Decrypt Locally
                             │
                             ▼
                    ┌─────────────────┐
                    │     User B      │
                    └─────────────────┘

---

🔑 Key Management

The application implements several mechanisms intended to reduce the risk associated with long-lived encryption keys.

Ephemeral Session Keys

A new session encryption key can be generated for message encryption rather than relying on a single static key for all communication.

Key Rotation

Encryption material is periodically rotated.

This limits the amount of information potentially exposed if a key is compromised.

Secure Storage

Sensitive private key material is stored using:

FlutterSecureStorage
        │
        ├── Android → Keystore
        │
        └── iOS → Keychain

Private cryptographic material should never be stored in ordinary application preferences or plaintext files.

---

✍️ Digital Signatures

AbbasChat also includes a digital-signature layer intended to provide message authenticity and tamper detection.

The architecture uses:

Message
   │
   ▼
SHA-256
   │
   ▼
Digital Signature
   │
   ▼
Encrypted Message Bundle

The recipient can verify the signature before accepting the message as authentic.

---

🗄️ Firebase Architecture

AbbasChat uses Firebase as part of its backend infrastructure.

Current project dependencies include:

- Firebase Core
- Firebase Authentication
- Cloud Firestore
- Firebase Storage
- Firebase Realtime Database
- Firebase Cloud Messaging

Firebase is used for backend services such as:

- User authentication
- Real-time data synchronization
- Message metadata
- Encrypted payload transport
- File/media storage
- Push notifications
- User/session related data

The application separates transport/storage infrastructure from the cryptographic processing performed by the client.

---

📁 Media & File Sharing

AbbasChat supports more than simple text messaging.

The application includes support for:

- 🖼️ Images
- 📎 Files
- 🎙️ Voice recordings
- 🔊 Audio playback
- 📂 File selection
- 💾 Local media handling

Relevant Flutter packages include:

image_picker
file_picker
open_filex
mime
record
audioplayers
flutter_image_compress
path_provider

Large File Architecture

Large media should not be converted unnecessarily into huge Base64 strings.

A more efficient architecture is:

Original File
     │
     ▼
Encrypt locally
     │
     ▼
Binary encrypted data
     │
     ▼
Upload / transfer
     │
     ▼
Encrypted storage
     │
     ▼
Download
     │
     ▼
Decrypt locally
     │
     ▼
Original File

This avoids the significant memory and size overhead associated with Base64 encoding.

---

🔐 Local Data Protection

AbbasChat is designed to protect locally stored sensitive information.

The project includes:

- Encrypted Hive storage
- Secure key storage
- Secure local credentials
- Biometric authentication
- Application lock
- Screen protection

Local storage architecture:

Application
     │
     ▼
Encrypted Local Database
     │
     ▼
Encrypted Data
     │
     └── Encryption Key
             │
             ▼
      Secure Storage

---

👤 Authentication

AbbasChat supports Firebase Authentication and includes integrations for:

- Email authentication
- Google Sign-In
- Apple Sign-In
- Email verification
- Biometric authentication

The authentication layer is separated from the application's message encryption layer.

---

👆 Biometric Protection

The application can use the device's biometric authentication mechanisms.

Supported mechanisms depend on the operating system and device:

- Fingerprint
- Face authentication
- Device biometric authentication

Biometric authentication can be used as an additional application-level protection layer.

---

🔔 Notifications

AbbasChat integrates Firebase Cloud Messaging and local notifications.

Notifications can be used for:

- New messages
- Incoming communication
- Background events
- Application alerts

Privacy-sensitive notification content should be minimized so that sensitive plaintext is not unnecessarily exposed on a locked screen.

---

🏗️ Technology Stack

Technology| Purpose
Flutter| Cross-platform application framework
Dart| Application programming language
Firebase Auth| Authentication
Cloud Firestore| Real-time database
Firebase Storage| Media/file storage
Firebase Realtime Database| Real-time backend functionality
Firebase Cloud Messaging| Push notifications
Riverpod| State management
Hive| Local storage
Flutter Secure Storage| Secure key storage
AES-256-GCM| Symmetric encryption
RSA-2048| Asymmetric cryptography
SHA-256| Hashing/signatures
Flutter Animate| UI animations
Google Fonts| Typography

---

📦 Main Flutter Dependencies

The project currently uses a broad set of packages including:

firebase_core
firebase_auth
cloud_firestore
firebase_storage
firebase_database
firebase_messaging

google_sign_in
sign_in_with_apple

flutter_riverpod
riverpod_annotation

flutter_secure_storage
hive_flutter
crypto
encrypt
pointycastle

local_auth
screen_protector

image_picker
file_picker
open_filex
mime

record
audioplayers

connectivity_plus
permission_handler
path_provider

cached_network_image
flutter_image_compress

flutter_local_notifications

---

🧩 Project Architecture

The project follows a modular Flutter architecture designed to separate UI, state management, services, repositories, and security-related functionality.

A simplified structure:

lib/
├── core/
│   ├── security/
│   ├── services/
│   ├── utilities/
│   └── ...
│
├── features/
│   ├── authentication/
│   ├── chat/
│   ├── profile/
│   └── ...
│
├── models/
├── providers/
├── repositories/
├── screens/
├── widgets/
└── main.dart

The exact structure may evolve as development continues.

---

⚙️ Requirements

Before running the project, install:

- Flutter SDK
- Dart SDK
- Android Studio or VS Code
- Android SDK
- Xcode for iOS development
- Firebase project
- Git

Recommended:

flutter doctor

Make sure there are no critical environment errors.

---

🚀 Getting Started

1. Clone the repository

git clone https://github.com/abbas12df/abbaschat.git

cd abbaschat

2. Install dependencies

flutter pub get

3. Configure Firebase

Create a Firebase project and configure the required platforms.

Android configuration:

android/app/google-services.json

iOS configuration should be added through the appropriate Firebase/Xcode configuration.

«Never commit private credentials, service-account keys, private certificates, or other secrets to GitHub.»

4. Run the application

flutter run

For Android:

flutter run -d android

For iOS:

flutter run -d ios

---

🧪 Testing

Run Flutter tests with:

flutter test

Static analysis:

flutter analyze

Check outdated dependencies:

flutter pub outdated

---

🔍 Security Model

The security architecture currently includes:

Security Layer| Implementation
Message encryption| AES-256-GCM
Asymmetric cryptography| RSA-2048
Hashing| SHA-256
Key storage| Secure Storage
Local database| Encrypted storage
Authentication| Firebase Authentication
Biometric protection| Local Authentication
Screen protection| Screen Protector
Key rotation| Implemented
Ephemeral keys| Implemented
Digital signatures| Implemented

---

⚠️ Security Considerations

Security is an ongoing development process.

The repository contains a dedicated security assessment documenting the current security architecture and areas requiring further hardening.

Current areas of attention include:

- Avoiding sensitive information in application logs
- Making message signatures consistently enforced
- Backend rate limiting
- Abuse prevention
- Transport-layer hardening
- Secure error handling
- Security auditing
- Cryptographic protocol review
- Large-file encrypted transfer optimization

For a security-sensitive production deployment, an independent professional security audit is strongly recommended.

---

🚧 Roadmap

Messaging

- [x] Real-time messaging
- [x] Encrypted messages
- [x] Image sharing
- [x] File support
- [x] Voice messages
- [x] Push notifications

Security

- [x] AES-256-GCM
- [x] RSA-based key protection
- [x] Secure key storage
- [x] Encrypted local storage
- [x] Biometric protection
- [x] Key rotation
- [x] Digital signatures
- [ ] Complete independent security audit
- [ ] Stronger anti-abuse/rate-limiting infrastructure
- [ ] Further cryptographic protocol hardening

Media

- [x] Image selection
- [x] Image compression
- [x] File picker
- [x] Audio recording
- [x] Audio playback
- [ ] Optimized encrypted large-file transfer
- [ ] Resumable encrypted uploads/downloads
- [ ] Chunk-based file encryption and transfer

Platform

- [x] Android
- [x] iOS project configuration
- [ ] Production release hardening
- [ ] Additional platform testing

---

📊 Current Security Assessment

A security assessment is included in the repository.

Current documented assessment:

85 / 100 ⭐⭐⭐⭐

The assessment identifies strong cryptographic and local-security foundations while also identifying areas for improvement such as logging hygiene, mandatory signature enforcement, rate limiting, and additional transport security hardening.

See:

"SECURITY_ASSESSMENT.md"

---

🎯 Project Goals

The long-term goals of AbbasChat are:

1. Privacy-first communication
2. Strong client-side encryption
3. Minimal exposure of plaintext data
4. Secure local storage
5. Reliable real-time messaging
6. Efficient encrypted media transfer
7. Cross-platform support
8. Transparent security documentation
9. Maintainable and scalable architecture

---

🔬 Design Philosophy

AbbasChat follows several principles:

Privacy by Design

Security should be part of the architecture rather than added as an afterthought.

Client-Side Encryption

Sensitive message content should be encrypted before leaving the user's device whenever the communication flow supports it.

Zero Trust Transport

The communication infrastructure should not be assumed to be trusted merely because it is operated by the application.

Secure Key Handling

Cryptographic keys are more sensitive than encrypted messages themselves.

Defense in Depth

No single security mechanism is considered sufficient.

The application therefore combines:

Authentication
      +
Encryption
      +
Key Management
      +
Digital Signatures
      +
Secure Storage
      +
Biometric Protection
      +
Transport Security

---

📱 Screenshots

Screenshots will be added as the UI reaches a stable release.

Recommended structure:

docs/
└── screenshots/
    ├── login.png
    ├── conversations.png
    ├── chat.png
    ├── profile.png
    └── settings.png

---

🤝 Contributing

Contributions, security reviews, bug reports, and architectural suggestions are welcome.

Before submitting a change:

1. Fork the repository.
2. Create a feature branch.
3. Make your changes.
4. Run:

flutter analyze
flutter test

5. Commit your changes.
6. Push the branch.
7. Open a Pull Request.

For security vulnerabilities, please avoid publicly exposing sensitive vulnerability details before they can be responsibly reviewed.

---

🐛 Issues

If you find a bug or have a feature request, open an issue in the GitHub repository.

When reporting a bug, include:

- Device/platform
- Flutter version
- Android/iOS version
- Steps to reproduce
- Expected behavior
- Actual behavior
- Relevant logs without exposing secrets or private data

---

🔐 Responsible Disclosure

If you discover a security vulnerability:

Do not publish sensitive exploit details immediately.

Provide enough information to reproduce the issue safely and allow the maintainers to investigate and fix it.

Never include:

- Private keys
- Authentication tokens
- Passwords
- Personal conversations
- Private user information
- Production credentials

---

📄 License

The licensing terms for AbbasChat will be defined as the project approaches its public release.

Until a license is explicitly added to the repository, the source code should not be assumed to be freely reusable, modified, or redistributed.

---

👨‍💻 Author

Abbas

Computer Technology Engineering

GitHub:

https://github.com/abbas12df

---

⭐ Support the Project

If you find AbbasChat interesting or useful:

- ⭐ Star the repository
- 🐛 Report bugs
- 💡 Suggest improvements
- 🔐 Review the security architecture
- 🤝 Contribute code

---

📌 Disclaimer

AbbasChat is an independently developed software project.

The presence of cryptographic algorithms such as AES-256-GCM or RSA-2048 does not by itself guarantee complete security.

The application's security depends on the correctness of the implementation, key management, authentication, backend configuration, operating-system security, device security, and the overall protocol design.

AbbasChat has not been independently audited by a professional security firm at this time.

---

<div align="center">🔐 Nisaba

Private communication. Built with security in mind.

Made with ❤️ using Flutter & Firebase.

</div>
