# BepulTV

APTV o'rniga o'zingiz uchun bepul IPTV pleyer. Oylik to'lov yo'q, reklama yo'q, kuzatuv yo'q.

## Nima qila oladi

- M3U / M3U8 pleylistni **havola** yoki **fayl** orqali qo'shish, bitta kanalni qo'lda qo'shish
- Kanal logotiplari, guruhlar, qidiruv, sevimlilar
- Video ko'rish, Picture-in-Picture (kichik oyna)
- **Ekran bloklansa ham ovoz davom etadi** — qulf ekranidan pauza / keyingi / oldingi kanal
- Pleylistni bir tugma bilan yangilash
- CarPlay qismi (kanallar ro'yxati + "Hozir ijroda") kodda tayyor

## Rostini aytganda: nima qilmaydi

- **CarPlay'da chiqmaydi.** iOS ilovani mashina ekraniga faqat Apple bergan ruxsatnoma bilan chiqaradi.
  Bepul Apple ID bilan bu ruxsatnomani olib bo'lmaydi. Kod tayyor turadi — Apple ruxsat bersa,
  `project.yml` dagi `CODE_SIGN_ENTITLEMENTS` qatorini yoqasiz, xolos. Mashinada ovoz uchun
  telefonni Bluetooth yoki CarPlay orqali ulab, ovozni shu ilovadan eshitasiz.
- **YouTube ichida yo'q.** YouTube qoidalari videoni boshqa ilova orqali tortib olishni taqiqlaydi.
  Bepul maslahat: YouTube'ni **Safari**da oching, videoni qo'ying, ekranni bloklang, so'ng qulf
  ekranidagi ▶️ tugmasini bosing — ovoz fonda davom etadi.
- Kanallarni o'zi bermaydi. Siz foydalanish huquqiga ega bo'lgan pleylistni qo'shasiz.

## Xavfsizlik

Kod to'liq ochiq, hammasi `Sources/` papkada, ~600 qator. Ilova faqat siz qo'shgan pleylist va
kanal havolalariga ulanadi. Hech qanday analitika, reklama, begona kutubxona yo'q.
Ma'lumotlar faqat telefonda saqlanadi.

## O'rnatish

Bepul Apple ID bilan o'rnatilgan ilova **7 kun** ishlaydi, keyin qayta o'rnatasiz (ma'lumotlar saqlanib qoladi).
Yillik Apple Developer akkaunti ($99) bo'lsa — 1 yil.

### A yo'l — Mac bor bo'lsa

1. App Store'dan **Xcode** o'rnating.
2. Terminalda: `brew install xcodegen`, so'ng shu papkada `xcodegen generate`.
3. `BepulTV.xcodeproj` ni oching → **Signing & Capabilities** → Team: o'z Apple ID'ingiz.
4. iPhone'ni kabel bilan ulang, yuqorida uni tanlang, ▶️ bosing.
5. iPhone'da: **Sozlamalar → Umumiy → VPN va qurilma boshqaruvi** → o'z Apple ID'ingizga ishonch bildiring.
6. iOS 16+ da **Sozlamalar → Maxfiylik va xavfsizlik → Developer Mode** ni yoqing.

### B yo'l — Mac yo'q, faqat Windows

1. github.com da bepul akkaunt oching, yangi **private** repozitoriy yarating, shu papkadagi hamma
   fayllarni yuklang (`.github` papkasi ham).
2. **Actions → Build IPA → Run workflow**. 5–10 daqiqada tugaydi.
3. Tugagan ishga kirib, **Artifacts** bo'limidan `BepulTV-ipa` ni yuklab oling, ichidagi `BepulTV.ipa`.
4. Kompyuterga **Sideloadly** (sideloadly.io) va iTunes (Apple saytidan) o'rnating.
5. iPhone'ni ulang, Sideloadly'ga `BepulTV.ipa` ni tashlang, Apple ID kiriting, **Start**.
6. A yo'ldagi 5–6-qadamlarni bajaring.

## Foydalanish

1. **+** → Havola / Fayl / Bitta kanal.
2. Kanalni bosing — video ochiladi.
3. Ekranni bloklang — ovoz davom etadi.
4. Kanalni chapga surib — sevimlilarga qo'shasiz.
