/// TajGo design tokens — единая точка импорта дизайн-системы.
///
/// `import 'package:tajgo/core/design/tajgo_design.dart';` даёт доступ к
/// цветам, типографике, отступам, радиусам, длительностям, теням и размерам
/// иконок. Токены — единственный источник значений стиля; хардкодить пиксели,
/// цвета и длительности в экранах не следует.
library;

export '../constants/tajgo_colors.dart';
export 'tajgo_durations.dart';
export 'tajgo_icon_sizes.dart';
export 'tajgo_radius.dart';
export 'tajgo_shadows.dart';
export 'tajgo_spacing.dart';
export 'tajgo_typography.dart';
