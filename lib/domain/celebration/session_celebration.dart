import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../flame/flame_tier.dart';

/// Seans tamamlanışında kutlanacak şey. Tek bir tip olarak modelleniyor çünkü
/// kutlama **tek**: rozet açılışı, kademe atlaması ve seri eşiği aynı anda
/// düşebilir ve üç dialogu üst üste açmak kutlamayı kesintiye çevirirdi.
/// Hangisinin öne geçtiğine çağıran (`PomodoroController`) karar veriyor.
sealed class SessionCelebration {
  const SessionCelebration();
}

/// Bu tamamlanışta açılan rozetler. Liste **sırasız** geliyor (kaynağı bir
/// `Set`); gösteren ekran onu `kBadgeCatalog` sırasına sokuyor, çünkü sıra bir
/// sunum kararı ve kataloğun merdiveni zaten orada biliniyor. Aynı anda birden
/// fazla rozet açılabiliyor (ör. "İlk Kıvılcım" + "Sabah Yıldızı").
class BadgeCelebration extends SessionCelebration {
  const BadgeCelebration(this.badgeKeys);

  final List<String> badgeKeys;
}

/// Serinin kutlanmaya değer bir eşiğe ulaşması (`kStreakMilestones`).
/// [days] eşiğin kendisi değil **güncel** seri: ikisi aynı olmayabilir (30
/// günlük seriyle güncelleyen kullanıcıda eşik 30, seri 34).
class StreakCelebration extends SessionCelebration {
  const StreakCelebration({required this.days});

  final int days;
}

/// Meşale kademesinin atlaması (`kFlameTierLadder`). [tier] **yeni** kademedir;
/// dialog alevi tam o kademede çiziyor, yani kutlamanın görseli ödülün kendisi.
///
/// Eşik sayısı değil kademenin kendisi taşınıyor: çizim `scale`, `emberBase`,
/// `sparkCount` ve `haloOpacity`yi de istiyor ve merdiven `const`, yani aynı
/// kademe her zaman aynı nesne (`FlameTierStatus`in `==` gerekçesiyle aynı).
class FlameTierCelebration extends SessionCelebration {
  const FlameTierCelebration({required this.tier});

  final FlameTier tier;
}

/// Kutlanmış en yüksek seri eşiğinin `SharedPreferences` anahtarı. Eşik günü
/// boyunca seri aynı sayıda kaldığı için o gün tamamlanan her seans aynı
/// kutlamayı yeniden açardı; kalıcı bir "en son kutlanan" değeri bunu tek
/// seferliğe indiriyor. "Verileri sıfırla" bunu da temizliyor
/// (`AppDataResetService`), yoksa geçmişi silinmiş kullanıcı eşikleri bir daha
/// hiç kutlayamazdı.
const String kCelebratedStreakMilestonePrefsKey = 'celebrated_streak_milestone_v1';

/// Kutlanmış en yüksek kademenin `SharedPreferences` anahtarı — seri eşiğinin
/// yanındaki kalıbın ikizi. Kademe kalıcı (asla düşmez), yani işaret olmadan o
/// kademedeki **her** seans aynı kutlamayı yeniden açardı.
///
/// Varsayılanı 0 değil **1**: K1 kullanıcının başlangıç hâli, atlanan bir
/// kademe değil. Yoksa ilk tamamlanan pomodoro "Kıvılcım'a yükseldin" derdi.
/// Buna karşılık K1'in üstündeki bir kullanıcının ilk seansında güncel kademesi
/// bir kez kutlanıyor — `streakMilestoneToCelebrate`in "geriye dönük üç dialog
/// açma, en yükseği bir kez kutla" kuralıyla aynı.
///
/// "Verileri sıfırla" bunu da temizliyor (`AppDataResetService`): geçmişi
/// silinen kullanıcının kademesi K1'e düşüyor, işaret kalsaydı merdiveni bir
/// daha hiç kutlayamazdı.
const String kCelebratedFlameTierPrefsKey = 'celebrated_flame_tier_v1';

/// Kutlanacak kademe: [tierIndex] daha önce kutlanmış [lastCelebrated]'dan
/// büyükse odur, değilse `null`. `streakMilestoneToCelebrate`in kademe
/// karşılığı — merdiven sırayla çıkıldığı için "en yüksek yeni eşik" araması
/// gerekmiyor, güncel kademe zaten en yükseği.
int? flameTierToCelebrate({required int tierIndex, required int lastCelebrated}) =>
    tierIndex > lastCelebrated ? tierIndex : null;

final NotifierProvider<SessionCelebrationQueue, SessionCelebration?> sessionCelebrationProvider =
    NotifierProvider<SessionCelebrationQueue, SessionCelebration?>(SessionCelebrationQueue.new);

/// Kutlama anı ile onu gösteren ekran arasındaki tek yuva.
///
/// Neden bir provider: kutlamayı **üreten** yer `PomodoroController`
/// (`_completeFocus`; `BuildContext`i yok), **gösteren** yer Ekran 03/09.
/// Controller'ın doğrudan dialog açması `domain`i `features`a bağlardı.
///
/// Bilinçli olarak **kalıcı değil**: uygulama kutlama gösterilmeden öldürülürse
/// kutlama da gider. Rozet zaten Ekran 04'te ve bildirimi düşmüş durumda;
/// günler sonra açılışta "tebrikler" demek, anını kaçırmış bir kutlama olurdu.
class SessionCelebrationQueue extends Notifier<SessionCelebration?> {
  @override
  SessionCelebration? build() => null;

  void offer(SessionCelebration celebration) {
    state = celebration;
  }

  /// Gösterildi — yuvayı boşaltır. Ekran yeniden çizildiğinde (ör. saniye
  /// tiki) aynı kutlamanın ikinci kez açılmaması buna bağlı.
  void consume() {
    state = null;
  }
}
