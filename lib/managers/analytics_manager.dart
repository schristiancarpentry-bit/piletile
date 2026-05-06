class AnalyticsManager {
  static final AnalyticsManager _instance = AnalyticsManager._();
  factory AnalyticsManager() => _instance;
  AnalyticsManager._();

  void logEvent(String name, [Map<String, dynamic>? params]) {
    // TODO: wire up Firebase Analytics or similar
  }

  void reviveOffered(int journeyId, int level, int round) =>
      logEvent('revive_offered', {'journey': journeyId, 'level': level, 'round': round});

  void reviveAccepted(int journeyId, int level, int round) =>
      logEvent('revive_accepted', {'journey': journeyId, 'level': level, 'round': round});

  void reviveDeclined(int journeyId, int level, int round, {required bool timeout}) =>
      logEvent('revive_declined', {
        'journey': journeyId, 'level': level, 'round': round, 'timeout': timeout
      });

  void reviveSuccess(int journeyId, int level, int round) =>
      logEvent('revive_success', {'journey': journeyId, 'level': level, 'round': round});

  void reviveFail(int journeyId, int level, int round) =>
      logEvent('revive_fail', {'journey': journeyId, 'level': level, 'round': round});
}
