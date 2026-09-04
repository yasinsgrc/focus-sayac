# FocusSayaç — Gizlilik Politikası

**Son güncelleme:** 3 Eylül 2026 · **Uygulama sürümü:** 1.0.0

Bu belge `focussayac.app/gizlilik` adresinde yayımlanan metnin kaynağıdır.
Play Console'un **Gizlilik politikası URL'si** alanına o adres girilir; Play
alanın herkese açık, giriş istemeyen bir sayfaya çözülmesini şart koşuyor.
Uygulama içindeki özet ayarlardaki "Gizlilik politikası" satırında
(`settingsPrivacyBody`, `lib/l10n/app_tr.arb`) — **iki metin de aynı olguları
anlatmalı**, biri değişince diğeri de değişir.

---

## 1. Kim topluyor

FocusSayaç'ı geliştiren bağımsız yayıncı. İletişim: `destek@focussayac.app`

## 2. Cihazında kalan veriler

Uygulamanın kendisi hesap açmanı istemez; senden ad, e-posta, telefon
numarası ya da konum istemez. Şunlar yalnızca cihazının kendi depolamasında,
uygulamanın veritabanında tutulur ve **hiçbir sunucuya gönderilmez**:

| Veri | Ne için |
| --- | --- |
| Seçtiğin ve eklediğin sınavlar (ad, tarih) | Geri sayım |
| Tamamlanan/iptal edilen odak ve mola seansları (başlangıç anı, planlanan süre) | İstatistik, seri, rozetler |
| Kazanılan rozetler | Rozet ekranı |
| Ayarlar (süreler, bildirim tercihleri, kart şablonu) | Uygulamanın davranışı |

Bu verileri uygulamayı kaldırarak ya da **Ayarlar → Verileri sıfırla** ile
silebilirsin. Sıfırlama odak geçmişini ve rozetleri siler; sınavların ve
ayarların korunur.

## 3. Reklamlar (Google AdMob)

Ücretsiz sürümde Google AdMob reklamları gösterilir. AdMob; reklamı sunmak,
ölçmek ve sahtekârlığı önlemek için cihazının **reklam kimliği (AAID)**,
IP tabanlı yaklaşık konum, cihaz ve uygulama bilgisi gibi verileri işler. Bu
işleme Google'ın kendi politikasına tabidir:
<https://business.safety.google/privacy/>

- İlk açılışta Google'ın **UMP** onay ekranı gösterilir. Kişiselleştirilmiş
  reklamı reddedersen yalnızca kişiselleştirilmemiş reklam istenir.
- Onay vermezsen ya da reklamsız sürüme geçersen **hiçbir reklam isteği
  atılmaz** — bu kural kodda tek bir kapıdan geçer
  (`lib/services/ads/ad_service.dart`).
- Odak seansı ekranında hiçbir reklam gösterilmez.
- 2. bölümdeki verilerin (sınavların, seansların, rozetlerin) hiçbiri reklam
  ağına gönderilmez.

## 4. Satın alma

Reklamsız sürüm satın alındığında ödeme tamamen Google Play üzerinden yürür;
kart bilgilerini görmeyiz ve saklamayız. Play'den yalnızca satın almanın
geçerli olup olmadığı bilgisi okunur.

## 5. Bildirimler ve izinler

- **Bildirim izni** — seans/mola bitişini ve seri hatırlatmasını göndermek
  için. Reddedersen uygulama tam çalışır, yalnızca bildirim gelmez.
- **Tam zamanlı alarm izni** — bildirimin dakikası şaşmasın diye.
- **Galeriye kaydetme** — yalnızca başarı kartını "Kaydet" dediğinde ve
  yalnızca o dosya için (Android 10 ve öncesinde gerekiyor).

Bildirimlerin içeriği cihazdan çıkmaz.

## 6. Çocuklar

Uygulama 13 yaşın altındaki çocuklara yönelik değildir ve bilerek onlardan
veri toplamaz.

## 7. Haklarının kullanımı

Kişisel veriler cihazından çıkmadığı için silme/erişim talebini doğrudan
uygulama içinden karşılayabilirsin (2. bölüm). Reklam kimliğiyle ilgili
talepler için Android **Ayarlar → Gizlilik → Reklamlar** ekranından reklam
kimliğini sıfırlayabilir ya da silebilirsin.

## 8. Değişiklikler

Bu metin değişirse üstteki tarih güncellenir ve yeni sürüm aynı adreste
yayımlanır. Önemli bir değişiklikte uygulama içinden de bilgilendirilirsin.
