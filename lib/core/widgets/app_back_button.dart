import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../l10n/gen/app_localizations.dart';
import '../theme/app_colors.dart';

/// Ekran 04/07 gibi alt gezinme çubuğu olmayan ekranların geri dönüş yolu.
/// Görünüm Ekran 05'in geri oku ile birebir aynı.
///
/// Yığında geri gidilecek bir sayfa yoksa (ekran doğrudan açılmış olabilir)
/// ok çizilmez; pop o durumda hata verirdi.
///
/// `go_router`ın `context.pop()`u yerine `Navigator` kullanılıyor: rota
/// yığınını ikisi de aynı şekilde açıyor ama `Navigator` sürümü ekranı tek
/// başına pump eden widget testlerinde de çalışıyor.
class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = Theme.of(context).extension<AppColors>()!;
    final NavigatorState? navigator = Navigator.maybeOf(context);
    if (navigator == null || !navigator.canPop()) return const SizedBox.shrink();

    // Görsel olarak yalnızca bir ok var; ekran okuyucu için ada ihtiyacı olduğu
    // (ve `Icon`un `semanticLabel`i `InkWell`in düğme rolüyle birleşmediği)
    // için etiket dışarıdan veriliyor.
    return Semantics(
      button: true,
      label: AppLocalizations.of(context).commonBack,
      child: InkWell(
        onTap: () => Navigator.of(context).maybePop(),
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0x1FFFFFFF)),
          ),
          child: Icon(PhosphorIconsRegular.arrowLeft, size: 17, color: colors.neutral400),
        ),
      ),
    );
  }
}
