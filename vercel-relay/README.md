# خادم الإشعارات المجاني على Vercel

ينقل إرسال إشعارات Push خارج التطبيق — حساب الخدمة يُخزن كسرٍ في Vercel فقط.
مجاني بالكامل (خطة Hobby — لا تطلب بطاقة دفع).

## خطوات الإعداد (مرة واحدة)

### 1. إنشاء حساب Vercel
- ادخل https://vercel.com وسجل بحساب GitHub نفسه (مجاني).

### 2. تثبيت الأداة والنشر
```bash
npm install -g vercel
cd vercel-relay
vercel login
vercel --prod
```
بعد النشر ستحصل على رابط مثل:
`https://abbaschat-relay.vercel.app`
والدالة تعمل على: `https://abbaschat-relay.vercel.app/api/send-push`

### 3. إضافة الأسرار (Environment Variables)
من لوحة Vercel: **Project → Settings → Environment Variables** أضف:

| الاسم | القيمة |
|---|---|
| `FIREBASE_SERVICE_ACCOUNT` | محتوى ملف JSON لحساب الخدمة كاملاً (من Firebase Console ← Project Settings ← Service Accounts ← Generate new private key) |
| `RELAY_SECRET` | أي نص سري طويل تختاره (مثلاً 40 حرفاً عشوائياً) |

ثم أعد النشر: `vercel --prod`

### 4. ربط التطبيق
افتح `lib/core/services/push_notification_service.dart` وعدّل الثابتين أعلى الكلاس:

```dart
static const String _relayUrl = 'https://YOUR-PROJECT.vercel.app/api/send-push';
static const String _relayKey = 'نفس-قيمة-RELAY_SECRET';
```

ثم شغّل التطبيق — سيرسل الإشعارات عبر Vercel تلقائياً.

## بعد أن تتأكد أن الإشعارات تعمل

1. احذف `lib/core/security/secure_service_account.dart` والمسار الاحتياطي (LEGACY FALLBACK) من الخدمة.
2. **أبطل مفتاح حساب الخدمة القديم** المدمج سابقاً:
   Google Cloud Console ← IAM & Admin ← Service Accounts ← Keys ← حذف.

## ملاحظات
- الخطة المجانية تعطي 100GB نقل شهرياً — أكثر من كافية للإشعارات.
- أول طلب بعد فترة خمول قد يتأخر ثانية (cold start) — طبيعي.
- لا تحفظ الأسرار في الكود أو Git — فقط في Environment Variables.
