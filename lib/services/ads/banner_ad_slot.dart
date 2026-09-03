import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../domain/settings/settings_providers.dart';
import 'ad_service.dart';

/// Boyut sorgusu cevap vermeden önce (ve hiç cevap vermezse) ayrılan yükseklik
/// — prototipin `BANNER 320×50` kutusuyla aynı.
const double kBannerSlotFallbackHeight = 50;

/// SPEC.md §7.1'in banner yuvası. **Yalnızca Ekran 02 ve Ekran 06** kullanır;
/// Ekran 03'te (odak) bu widget hiç ağaca girmez — "gizlenmez, hiç istenmez".
///
/// Yükseklik reklam gelmeden **önce** ayrılıyor ve yükleme başarısız olsa da
/// korunuyor (SPEC: "Yüklenemezse aynı yükseklikte `SizedBox` → layout
/// zıplamaz"). Tek istisna reklamın hiç istenmediği hâl (premium ya da onay
/// yok): orada yuva tamamen kapanır, çünkü asla dolmayacak bir boşluğu
/// ayırmak kullanıcıya reklamsız sürümün alanını geri vermemek olurdu.
class BannerAdSlot extends ConsumerStatefulWidget {
  const BannerAdSlot({super.key, this.bottomMargin = 0});

  /// Alt gezinme çubuğunun üstünde kalması için bırakılan boşluk. Yuva
  /// kapandığında bu boşluk da kalkar (aksi hâlde premium kullanıcıda ekranın
  /// altında sebepsiz bir aralık kalırdı).
  final double bottomMargin;

  @override
  ConsumerState<BannerAdSlot> createState() => _BannerAdSlotState();
}

class _BannerAdSlotState extends ConsumerState<BannerAdSlot> {
  bool _startedLoading = false;
  bool _closed = false;
  bool _loaded = false;
  AdSize? _size;
  BannerAd? _ad;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // `initState` değil: adaptive boyut için ekran genişliği gerekiyor ve
    // `MediaQuery` ancak burada okunabiliyor. Bayrak, bağımlılık her
    // değiştiğinde ikinci bir istek atılmasını engelliyor.
    if (_startedLoading) return;
    _startedLoading = true;
    unawaited(_load(MediaQuery.sizeOf(context).width.truncate()));
  }

  Future<void> _load(int widthDp) async {
    final AdService adService = ref.read(adServiceProvider);
    if (!await adService.canRequestAds()) {
      if (mounted) setState(() => _closed = true);
      return;
    }
    // Boyut çözülemezse prototipin 320×50'si: adaptive boyut alınamadı diye
    // banner'dan tümüyle vazgeçmek gereksiz.
    final AdSize size = await adService.resolveBannerSize(widthDp) ?? AdSize.banner;
    if (!mounted) return;
    setState(() => _size = size);
    final BannerAd? ad = await adService.loadBanner(
      size: size,
      onLoaded: () {
        if (mounted) setState(() => _loaded = true);
      },
      onFailed: () {
        if (mounted) setState(() => _loaded = false);
      },
    );
    if (!mounted) {
      unawaited(ad?.dispose());
      return;
    }
    setState(() => _ad = ad);
  }

  @override
  void dispose() {
    unawaited(_ad?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Kapı `AdService`te; buradaki izleme yalnızca satın alma anında ekranda
    // duran bir banner'ı kaldırmak için (v1'de UI pasif olduğu için pratikte
    // tetiklenmez, bkz. SPEC §7.3).
    final bool isPremium = ref.watch(appSettingsProvider).value?.isPremium ?? false;
    if (_closed || isPremium) return const SizedBox.shrink();
    final BannerAd? ad = _ad;
    return Container(
      margin: EdgeInsets.only(bottom: widget.bottomMargin),
      width: double.infinity,
      height: (_size?.height ?? kBannerSlotFallbackHeight).toDouble(),
      child: ad != null && _loaded ? AdWidget(ad: ad) : null,
    );
  }
}
