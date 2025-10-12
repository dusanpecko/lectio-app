# Firebase Push Notifications - Implementation Documentation

## Úspešne implementované komponenty ✅

### 1. Dependencies & Setup
- ✅ Pridané flutter_local_notifications ^17.2.2
- ✅ Kompatibilita timezone ^0.9.4
- ✅ Firebase Core & Messaging dependencies

### 2. Models & API Integration
- ✅ `NotificationTopic` model s multi-language support
- ✅ `NotificationPreference` model pre user settings
- ✅ `FCMTokenRequest` model pre API komunikáciu
- ✅ `NotificationAPI` service s backend integration
- ✅ API endpoints: `/api/user/fcm-tokens`, `/api/user/notification-preferences`

### 3. FCM Service (Rozšírený)
- ✅ Local notifications support
- ✅ Background/Foreground message handling
- ✅ Token management & refresh
- ✅ Topic subscription/unsubscription
- ✅ API integration pre backend sync
- ✅ Permission handling pre Android/iOS
- ✅ Notification channel setup

### 4. UI Components
- ✅ `NotificationSettingsScreen` - kompletná UI pre topic management
- ✅ Kategorization topics (Spiritual, Educational, News, etc.)
- ✅ Multi-language support (SK/EN)
- ✅ Loading states, error handling
- ✅ Batch updates pre preferences

### 5. Integration
- ✅ Integrácia do main.dart s proper lifecycle
- ✅ Profile screen link na notification settings
- ✅ Auth state handling (token deactivation on logout)
- ✅ Language change handling

### 6. Platform Configuration
- ✅ Android: POST_NOTIFICATIONS permission
- ✅ Android: FCM service configuration
- ✅ Android: Notification channel & color setup
- ✅ iOS: APS environment setup
- ✅ iOS: Background modes (remote-notification)
- ✅ iOS: Badge management

## Súborová štruktúra

```
lib/
├── models/
│   └── notification_models.dart          # NotificationTopic, NotificationPreference, FCMTokenRequest
├── services/
│   ├── fcm_service.dart                  # Rozšírený FCM service (MODIFIED)
│   └── notification_api.dart             # Backend API komunikácia (NOVA)
├── screens/
│   ├── notification_settings_screen.dart # UI pre notification settings (NOVA)
│   └── profile_screen.dart               # Pridaný link na notifications (MODIFIED)
└── main.dart                             # FCM initialization (MODIFIED)

assets/translations/
├── sk.json                               # Slovenské preklady (MODIFIED)
└── en.json                               # Anglické preklady (MODIFIED)

android/app/src/main/
├── AndroidManifest.xml                   # FCM permissions & service (MODIFIED)
└── res/values/colors.xml                 # Notification color (NOVA)

ios/Runner/
├── Info.plist                            # Background modes (OK)
├── Runner.entitlements                   # APS environment (OK)
└── AppDelegate.swift                     # Badge handling (OK)
```

## Backend API Endpoints

### 1. FCM Token Registration
```http
POST /api/user/fcm-tokens
Content-Type: application/json
Authorization: Bearer <token>

{
  "fcm_token": "string",
  "device_type": "android|ios",
  "app_version": "1.0.0+1", 
  "device_id": "optional",
  "locale_code": "sk|en|cs|es"
}
```

### 2. Get Notification Preferences
```http
GET /api/user/notification-preferences
Authorization: Bearer <token>

Response:
{
  "topics": [
    {
      "id": "uuid",
      "name_sk": "Duchovné zamyslenia",
      "name_en": "Spiritual Reflections",
      "name_cs": "Duchovní zamyšlení",
      "name_es": "Reflexiones Espirituales",
      "emoji": "🙏",
      "category": "spiritual",
      "sort_order": 1,
      "is_active": true
    }
  ],
  "preferences": [
    {
      "id": "uuid", 
      "user_id": "uuid",
      "topic_id": "uuid",
      "is_enabled": true
    }
  ]
}
```

### 3. Update Topic Preference
```http
POST /api/user/notification-preferences
Content-Type: application/json
Authorization: Bearer <token>

{
  "topic_id": "uuid",
  "is_enabled": true
}
```

### 4. Deactivate FCM Token
```http
DELETE /api/user/fcm-tokens
Content-Type: application/json
Authorization: Bearer <token>

{
  "fcm_token": "string"
}
```

## Použitie v aplikácii

### Inicializácia
```dart
// V main.dart sa automaticky inicializuje pri štarte
FcmService.instance.init(languageCode);
```

### Navigácia na notification settings
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const NotificationSettingsScreen(),
  ),
);
```

### Programatické topic management
```dart
// Získaj preferences
final preferences = await FcmService.instance.getNotificationPreferences();

// Aktualizuj topic
final success = await FcmService.instance.updateTopicPreference(
  'topic-id',
  true,
);

// Batch update
final success = await FcmService.instance.updateMultipleTopicPreferences({
  'topic-1': true,
  'topic-2': false,
});
```

## Testing & Validation

### 1. Token Registration Test
- [ ] Nová inštalácia aplikácie registruje token
- [ ] Token refresh sa správne spracuje
- [ ] Multi-device support (user má viacero zariadení)

### 2. Notification Delivery Test  
- [ ] Foreground notifications (lokálne zobrazenie)
- [ ] Background notifications 
- [ ] App terminated notifications
- [ ] Notification tap handling

### 3. Topic Management Test
- [ ] Topic subscription/unsubscription
- [ ] Language change updates topics
- [ ] User preferences sync s backend

### 4. Permission Handling Test
- [ ] Android notification permission request
- [ ] iOS notification permission request  
- [ ] Permission denied scenario
- [ ] App reinstall scenario

### 5. Platform Specific Test
- [ ] Android notification channels
- [ ] iOS badge management
- [ ] iOS APNS token handling
- [ ] Android notification icon & color

## Vývojárske poznámky

### Debugging FCM
```dart
// Enable Firebase debug logging
Logger.level = Level.debug;

// Check current FCM token
final token = await FcmService.instance.getCurrentToken();
print('FCM Token: $token');

// Test API connection
final isConnected = await NotificationAPI.instance.testConnection();
print('API Connection: $isConnected');
```

### Testing lokálnych notifikácií
```dart
// Test local notification bez FCM
await flutterLocalNotificationsPlugin.show(
  999,
  'Test Title',
  'Test Body',
  NotificationDetails(/* ... */),
);
```

### Resetovanie notification preferencií
```dart
// Clear cached preferences
await NotificationPreferencesCache.clearCache();

// Reset all topics to disabled
await FcmService.instance.updateMultipleTopicPreferences(
  Map.fromEntries(topics.map((t) => MapEntry(t.id, false))),
);
```

## Production Checklist

### Firebase Console Setup
- [ ] Production Firebase project
- [ ] Android SHA fingerprints
- [ ] iOS Bundle ID & certificates
- [ ] Cloud Messaging enabled

### App Store / Play Store
- [ ] Notification permission justification
- [ ] Background modes explanation (iOS)
- [ ] GDPR compliance pre EU users

### Backend Configuration
- [ ] Firebase Admin SDK setup
- [ ] Database migrations pre topics/preferences
- [ ] API rate limiting
- [ ] Error monitoring

### Monitoring & Analytics
- [ ] FCM delivery reports
- [ ] Token registration success rate
- [ ] User engagement metrics
- [ ] Error logging & alerts

---

## Záver

Firebase Push Notifications sú úspešne implementované s kompletnou integráciou na backend API. Systém podporuje:

- ✅ Multi-language notification topics
- ✅ User preference management  
- ✅ Platform-specific handling (Android/iOS)
- ✅ Local notifications for better UX
- ✅ Proper lifecycle management
- ✅ Error handling & retry logic
- ✅ Offline caching support

Aplikácia je pripravená na receiving a handling push notifikácií cez admin panel backend systému.