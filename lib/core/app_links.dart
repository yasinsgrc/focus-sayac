/// Uygulamanın dışarıya verdiği sabit adresler.
library;

/// Başarı kartı paylaşılırken metne eklenen mağaza adresi (Ekran 05).
///
/// Sondaki paket adı `android/app/build.gradle.kts` içindeki `applicationId`
/// ile aynı olmak zorunda — biri değişirse diğeri de değişmeli.
///
/// Uygulama yayımlanana kadar bu adres 404 döner; paylaşımın kendisi yine
/// çalışır, yalnızca link henüz bir sayfaya gitmez.
const String kPlayStoreUrl =
    'https://play.google.com/store/apps/details?id=com.focussayac.focussayac';
