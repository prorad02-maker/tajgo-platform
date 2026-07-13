import 'tajgo_navigation_step.dart';

class TajGoRouteProgress {
  const TajGoRouteProgress({
    required this.remainingDistanceKm,
    required this.remainingEtaMinutes,
    required this.passedDistanceKm,
    required this.distanceToRouteMeters,
    required this.nextStep,
    required this.currentStepIndex,
    required this.isOffRoute,
    required this.routeCompletionPercent,
  });

  final double remainingDistanceKm;
  final int remainingEtaMinutes;
  final double passedDistanceKm;
  final double distanceToRouteMeters;
  final TajGoNavigationStep? nextStep;
  final int currentStepIndex;
  final bool isOffRoute;
  final double routeCompletionPercent;
}
