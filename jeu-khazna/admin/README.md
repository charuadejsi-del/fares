# لوحة المدير — الخزنة

موقع ثابت بلا خطوة بناء (ES Modules)، منشور على Vercel (`khazna-admin`).

```
admin/
├── index.html            نقطة الدخول + الخطوط + Chart.js
├── manifest.webmanifest  تثبيت كتطبيق على الهاتف (PWA)
├── css/
│   ├── tokens.css        الألوان والمسافات (مصدر وحيد)
│   ├── base.css          أساسيات
│   ├── layout.css        الشريط الجانبي / العلوي / شريط الهاتف
│   ├── components.css    أزرار، حقول، بطاقات، نوافذ، جداول…
│   └── views.css         تنسيقات كل صفحة
└── js/
    ├── main.js           التحقّق من المدير، الموجّه، التحديث الدوري
    ├── core/             api (Supabase) · store · router · ui · charts · format · icons · fx · config
    └── views/            login · shell · dashboard · players · payments · activity · settings · rooms
```

- الصلاحيات تُفرض في قاعدة البيانات (RLS + دوالّ `admin_*` تتحقّق من `is_admin()`).
- اختصارات: `Ctrl K` بحث سريع، `Alt 1..6` التنقّل.
