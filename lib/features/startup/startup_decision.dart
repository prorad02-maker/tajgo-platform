import '../../core/models/app_user.dart';

enum StartupDestination { intent, profileCompletion, customerHome, courierHome }

StartupDestination resolveStartupDestination({
  required bool authenticated,
  AppUser? profile,
}) {
  if (!authenticated) return StartupDestination.intent;
  if (profile == null || !profile.profileComplete) {
    return StartupDestination.profileCompletion;
  }
  if (profile.lastMode == AppUserRole.courier && profile.courierApproved) {
    return StartupDestination.courierHome;
  }
  return StartupDestination.customerHome;
}
