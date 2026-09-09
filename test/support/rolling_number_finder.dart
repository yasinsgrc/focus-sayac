import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focussayac/core/widgets/rolling_number.dart';

/// `RollingNumber` her karakteri ayrı bir `Text`e koyuyor (yalnızca değişen
/// hane kaysın diye), bu yüzden `find.text('3 SAAT')` artık tutmuyor: ağaçta
/// o dizeyi taşıyan tek bir `Text` yok. Aranan şey widget'ın kendi etiketi —
/// ekran okuyucunun okuduğu ve `Semantics.label`a verilen dize.
Finder findRollingNumber(String label) {
  return find.byWidgetPredicate(
    (Widget widget) => widget is RollingNumber && widget.label == label,
    description: 'RollingNumber("$label")',
  );
}
