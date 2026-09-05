import 'package:flutter/material.dart';

import '../../../core/theme/app_typography.dart';
import '../../../domain/story_card/story_card_text.dart';
import '../../../l10n/gen/app_localizations.dart';

/// Kartın **mantıksal** boyutu. Prototipin önizlemesi 248×441; buradaki
/// 270×480 onunla aynı orana sahip (9:16) ama `pixelRatio`yu tam sayı
/// yapıyor: `1080 / 270 = 4` ve `480 × 4 = 1920`. Prototipin ölçüleriyle
/// (248×441) çarpan 4.3548 olur, yükseklik 1920.5'e düşer ve
/// `RenderRepaintBoundary.toImage` bunu 1921'e yuvarlardı — SPEC.md Ekran 05
/// "1080 × 1920 png" tam sayı istiyor.
const double kStoryCardWidth = 270;
const double kStoryCardHeight = 480;

/// `pixelRatio = 1080 / kartMantıksalGenişlik` (SPEC.md Ekran 05).
const double kStoryCardExportPixelRatio = 1080 / kStoryCardWidth;

/// Prototipin 248px'lik önizleme genişliği — ekranda kart bu boyda görünür,
/// dışa aktarım yine 270×480 katmanından alınır.
const double kStoryCardPreviewWidth = 248;

/// Prototipin kart ölçüleri 248 genişliğe göre yazılmış; 270'lik mantıksal
/// tuvale taşınırken hepsi bu katsayıyla ölçeklendi.
const double _s = kStoryCardWidth / 248;

/// Bir şablonun görsel kimliği. Renkler `AppColors` tokenlarına **bağlı
/// değil**, şablona özel sabitler: kart bir görsel olarak dışa aktarılıyor ve
/// şablonun kimliği paletin ileriki değişikliklerinden bağımsız kalmalı.
///
/// Faz 17'de tek istisna eklendi: her şablonun bir de açık varyantı var,
/// hangisinin çizileceğine uygulamanın o anki teması karar veriyor
/// (DECISIONS.md'deki "kart her zaman koyu" kararı bilerek geri alındı).
/// Varyant **uygulama içi** temayı izler, sistemi değil — kullanıcı kartı
/// ekranda gördüğüyle aynı tonda paylaşsın diye.
class StoryCardStyle {
  const StoryCardStyle({
    required this.background,
    required this.accent,
    required this.bigColor,
    required this.bigFontSize,
    required this.textPrimary,
    required this.textMuted,
    this.glowColor,
    this.glowCenter = Alignment.center,
    this.glowStop = 0.62,
  });

  final Color background;
  final Color accent;
  final Color bigColor;
  final double bigFontSize;

  /// Kartın gövde metinleri. Üç şablonun üçünde de aynı ikili, ama varyanta
  /// göre yön değiştiriyor — bu yüzden şablonun kendi tanımında duruyor.
  final Color textPrimary;
  final Color textMuted;
  final Color? glowColor;
  final Alignment glowCenter;
  final double glowStop;
}

/// Şablonun yürürlükteki varyantı. Tek çözüm noktası: hem ekrandaki önizleme
/// hem dışa aktarılan PNG buradan geçiyor, ikisi ayrışamaz.
StoryCardStyle storyCardStyle(StoryCardTemplate template, Brightness brightness) {
  final Map<StoryCardTemplate, StoryCardStyle> set =
      brightness == Brightness.dark ? kStoryCardStyles : kStoryCardLightStyles;
  return set[template]!;
}

/// Prototip v2 satır 506-510'daki üç kart tanımı birebir.
const Map<StoryCardTemplate, StoryCardStyle> kStoryCardStyles = <StoryCardTemplate, StoryCardStyle>{
  StoryCardTemplate.nightTorch: StoryCardStyle(
    background: Color(0xFF0B0C14),
    accent: Color(0xFFFFB03A),
    bigColor: Color(0xFFFFD79A),
    bigFontSize: 66 * _s,
    textPrimary: Color(0xFFF6F7FF),
    textMuted: Color(0xFFCFD3E5),
    glowColor: Color(0x6BFFB03A),
    glowCenter: Alignment(0, 0.68), // CSS `circle at 50% 84%`
  ),
  StoryCardTemplate.minimal: StoryCardStyle(
    background: Color(0xFF12131C),
    accent: Color(0xFFB5ABFC),
    bigColor: Color(0xFFF6F7FF),
    bigFontSize: 108 * _s,
    textPrimary: Color(0xFFF6F7FF),
    textMuted: Color(0xFFCFD3E5),
  ),
  StoryCardTemplate.streak: StoryCardStyle(
    background: Color(0xFF151A3C),
    accent: Color(0xFF4FE0B4),
    bigColor: Color(0xFF9DF3D9),
    bigFontSize: 108 * _s,
    textPrimary: Color(0xFFF6F7FF),
    textMuted: Color(0xFFCFD3E5),
    glowColor: Color(0x6663B4FF),
    glowCenter: Alignment(-0.64, -0.68), // CSS `circle at 18% 16%`
    glowStop: 0.6,
  ),
};

/// Koyu setin açık karşılıkları. Her şablonun **kendi rengi** (ember / mor /
/// nane) korunuyor, değişen yalnız zeminin yönü: koyu zeminde açık yazı yerine
/// açık zeminde koyu yazı. Geometri, yazı boyutu ve hâle konumları koyu setle
/// birebir aynı — böylece şablon değiştirmeden tema değiştiren biri aynı kartı
/// tanıyor.
const Map<StoryCardTemplate, StoryCardStyle> kStoryCardLightStyles = <StoryCardTemplate, StoryCardStyle>{
  StoryCardTemplate.nightTorch: StoryCardStyle(
    background: Color(0xFFFFF7EC),
    accent: Color(0xFFA35D00),
    bigColor: Color(0xFF7A4400),
    bigFontSize: 66 * _s,
    textPrimary: Color(0xFF14161F),
    textMuted: Color(0xFF4E5264),
    glowColor: Color(0x4DFFB03A),
    glowCenter: Alignment(0, 0.68),
  ),
  StoryCardTemplate.minimal: StoryCardStyle(
    background: Color(0xFFF7F8FC),
    accent: Color(0xFF5A4BD0),
    bigColor: Color(0xFF14161F),
    bigFontSize: 108 * _s,
    textPrimary: Color(0xFF14161F),
    textMuted: Color(0xFF4E5264),
  ),
  StoryCardTemplate.streak: StoryCardStyle(
    background: Color(0xFFEDF3FC),
    accent: Color(0xFF0B7A5E),
    bigColor: Color(0xFF07553F),
    bigFontSize: 108 * _s,
    textPrimary: Color(0xFF14161F),
    textMuted: Color(0xFF4E5264),
    glowColor: Color(0x3D63B4FF),
    glowCenter: Alignment(-0.64, -0.68),
    glowStop: 0.6,
  ),
};

/// Ekran 05'in başarı kartı (prototip v2 satır 221-231). Hem ekrandaki
/// önizleme hem dışa aktarılan PNG bu tek widget'tan çiziliyor — ikisi
/// ayrılsaydı paylaşılan görsel önizlemeden sapabilirdi.
///
/// [boundaryKey] dışa aktarımın tutamağı; `StoryCardExporter` bu anahtardan
/// `RenderRepaintBoundary`ye ulaşıp `toImage` çağırıyor.
class StoryCardView extends StatelessWidget {
  const StoryCardView({
    required this.template,
    required this.text,
    super.key,
    this.boundaryKey,
  });

  final StoryCardTemplate template;
  final StoryCardText text;
  final GlobalKey? boundaryKey;

  @override
  Widget build(BuildContext context) {
    final StoryCardStyle style = storyCardStyle(template, Theme.of(context).brightness);

    return RepaintBoundary(
      key: boundaryKey,
      child: SizedBox(
        width: kStoryCardWidth,
        height: kStoryCardHeight,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28 * _s),
          child: ColoredBox(
            color: style.background,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                if (style.glowColor != null)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: style.glowCenter,
                        colors: <Color>[style.glowColor!, style.glowColor!.withValues(alpha: 0)],
                        stops: <double>[0, style.glowStop],
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24 * _s, vertical: 28 * _s),
                  child: _CardBody(style: style, text: text),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CardBody extends StatelessWidget {
  const _CardBody({required this.style, required this.text});

  final StoryCardStyle style;
  final StoryCardText text;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(width: 14 * _s, height: 1 * _s, color: style.accent),
            const SizedBox(width: 7 * _s),
            Expanded(
              child: Text(
                text.tag.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.kicker(fontSize: 8 * _s, color: style.textMuted),
              ),
            ),
          ],
        ),
        const Spacer(),
        // Üç haneli gün sayısı ve uzun rumuz taştığında kırpmak yerine
        // küçültülüyor (SPEC.md §9 taşma testi) — `Flexible` sayesinde
        // `FittedBox` hem genişliğe hem kalan yüksekliğe uyuyor.
        Flexible(
          child: SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                text.big,
                maxLines: 1,
                style: AppTypography.counter(
                  fontSize: style.bigFontSize,
                  color: style.bigColor,
                  height: 0.88,
                  letterSpacingEm: -0.07,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12 * _s),
        Text(
          text.line1,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.display(
            fontSize: 16 * _s,
            weight: FontWeight.w600,
            color: style.textPrimary,
            height: 1.28,
          ).copyWith(letterSpacing: 16 * _s * -0.02),
        ),
        if (text.line2.isNotEmpty) ...<Widget>[
          const SizedBox(height: 7 * _s),
          Text(
            text.line2,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.body(
              fontSize: 12.5 * _s,
              color: style.textMuted,
              height: 1.45,
            ),
          ),
        ],
        const SizedBox(height: 18 * _s),
        // Alt imza (SPEC.md Ekran 05). Instagram gibi uygulamalar paylaşım
        // metnini yok sayıp yalnızca görseli aldığı için kartın kendisi de
        // nereden geldiğini söylemek zorunda. Rengi şablonun vurgusundan
        // türüyor — üç kart için ayrı ayar gerekmiyor.
        Text(
          AppLocalizations.of(context).storyCardBrandFooter,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.kicker(
            fontSize: 7.5 * _s,
            color: style.accent.withValues(alpha: 0.7),
            letterSpacingEm: 0.18,
          ),
        ),
      ],
    );
  }
}
