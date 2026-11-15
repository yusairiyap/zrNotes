import 'dart:async';
import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/repository.dart';

enum NavPosition { left, right, top, bottom }

/// Where the formatting tools sit: fixed under the title, floating over the
/// note while you type, or hidden.
enum ToolbarMode { docked, floating, hidden }

enum CanvasBackground { vibe, blank, dots, grid, ruled }

/// How much of the app is shown. Simple hides the advanced tools.
enum UserLevel { simple, balanced, power }

/// Every user preference. Saved on the device straight away and, when signed
/// in, copied to the `user_settings` table so other devices pick it up.
class AppSettings extends ChangeNotifier {
  AppSettings(this._prefs, this._repo);
  final SharedPreferences _prefs;
  final Repository _repo;
  Timer? _syncTimer;

  static const _key = 'zrnotes.settings';

  String vibe = 'default';
  ThemeMode themeMode = ThemeMode.system;
  int? accent; // null = the vibe's own accent
  NavPosition navPosition = NavPosition.left;
  CanvasBackground canvasBackground = CanvasBackground.vibe;
  UserLevel level = UserLevel.balanced;
  double textScale = 1.0;
  double cornerScale = 1.0;
  bool reduceMotion = false;
  bool highContrast = false;
  bool largeTargets = false;
  bool boldText = false;
  bool showMarkdownToggle = true;
  ToolbarMode toolbar = ToolbarMode.floating;
  bool showToolbarLabels = true;
  bool showNavIcons = true;
  bool showNavSections = true;
  bool showNoteCounts = true;
  bool showChecklistProgress = true;
  bool zoomOutSummary = true;
  bool sectionShadows = true;
  bool closeToTray = true;
  bool compactMode = false;
  bool wizardDone = false;

  static Future<AppSettings> load(Repository repo) async {
    final prefs = await SharedPreferences.getInstance();
    final s = AppSettings(prefs, repo);
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        s._apply(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }
    return s;
  }

  Map<String, dynamic> toJson() => {
        'vibe': vibe,
        'themeMode': themeMode.name,
        'accent': accent,
        'navPosition': navPosition.name,
        'canvasBackground': canvasBackground.name,
        'level': level.name,
        'textScale': textScale,
        'cornerScale': cornerScale,
        'reduceMotion': reduceMotion,
        'highContrast': highContrast,
        'largeTargets': largeTargets,
        'boldText': boldText,
        'showMarkdownToggle': showMarkdownToggle,
        'toolbar': toolbar.name,
        'showToolbarLabels': showToolbarLabels,
        'showNavIcons': showNavIcons,
        'showNavSections': showNavSections,
        'showNoteCounts': showNoteCounts,
        'showChecklistProgress': showChecklistProgress,
        'zoomOutSummary': zoomOutSummary,
        'sectionShadows': sectionShadows,
        'closeToTray': closeToTray,
        'compactMode': compactMode,
        'wizardDone': wizardDone,
      };

  T _enum<T extends Enum>(List<T> values, Object? name, T fallback) =>
      values.where((v) => v.name == name).firstOrNull ?? fallback;

  void _apply(Map<String, dynamic> j) {
    vibe = (j['vibe'] as String?) ?? vibe;
    themeMode = _enum(ThemeMode.values, j['themeMode'], themeMode);
    accent = (j['accent'] as num?)?.toInt();
    navPosition = _enum(NavPosition.values, j['navPosition'], navPosition);
    canvasBackground = _enum(CanvasBackground.values, j['canvasBackground'], canvasBackground);
    level = _enum(UserLevel.values, j['level'], level);
    textScale = (j['textScale'] as num?)?.toDouble() ?? textScale;
    cornerScale = (j['cornerScale'] as num?)?.toDouble() ?? cornerScale;
    reduceMotion = (j['reduceMotion'] as bool?) ?? reduceMotion;
    highContrast = (j['highContrast'] as bool?) ?? highContrast;
    largeTargets = (j['largeTargets'] as bool?) ?? largeTargets;
    boldText = (j['boldText'] as bool?) ?? boldText;
    showMarkdownToggle = (j['showMarkdownToggle'] as bool?) ?? showMarkdownToggle;
    toolbar = _enum(ToolbarMode.values, j['toolbar'], toolbar);
    showToolbarLabels = (j['showToolbarLabels'] as bool?) ?? showToolbarLabels;
    showNavIcons = (j['showNavIcons'] as bool?) ?? showNavIcons;
    showNavSections = (j['showNavSections'] as bool?) ?? showNavSections;
    showNoteCounts = (j['showNoteCounts'] as bool?) ?? showNoteCounts;
    showChecklistProgress = (j['showChecklistProgress'] as bool?) ?? showChecklistProgress;
    zoomOutSummary = (j['zoomOutSummary'] as bool?) ?? zoomOutSummary;
    sectionShadows = (j['sectionShadows'] as bool?) ?? sectionShadows;
    closeToTray = (j['closeToTray'] as bool?) ?? closeToTray;
    compactMode = (j['compactMode'] as bool?) ?? compactMode;
    wizardDone = (j['wizardDone'] as bool?) ?? wizardDone;
  }

  /// Change any settings inside [change], then save and repaint.
  void update(void Function(AppSettings s) change) {
    change(this);
    notifyListeners();
    _prefs.setString(_key, jsonEncode(toJson()));
    _syncTimer?.cancel();
    _syncTimer = Timer(const Duration(seconds: 2), () {
      _repo.saveSettings(toJson()).catchError((_) {});
    });
  }

  /// Pulls the copy saved in the cloud after sign-in. The device keeps its own
  /// window-only choices.
  Future<void> pullFromCloud() async {
    try {
      final data = await _repo.fetchSettings();
      if (data == null) return;
      final compact = compactMode;
      _apply(data);
      compactMode = compact;
      notifyListeners();
      _prefs.setString(_key, jsonEncode(toJson()));
    } catch (_) {}
  }

  // ---- presets -----------------------------------------------------------
  //
  // A preset decides how much is on screen and how comfortable it is to read.
  // It never touches the look (vibe, colours, navigation position): that is
  // what vibes are for. Each preset is a full snapshot of the fields below,
  // so the app can tell which one is active, or that the user has gone custom.

  static const presets = <String, String>{
    'simple': 'Simple. Just notes, with fewer buttons.',
    'balanced': 'Balanced. The everyday set of tools.',
    'power': 'Power. Every tool and view on show.',
    'comfort': 'Comfort. Larger text and buttons, strong contrast, calm motion.',
    'focus': 'Focus. Fewer things on screen. Pairs well with the Zen vibe.',
  };

  static const presetIcons = <String, IconData>{
    'simple': Icons.spa_outlined,
    'balanced': Icons.balance_outlined,
    'power': Icons.bolt_outlined,
    'comfort': Icons.accessibility_new_outlined,
    'focus': Icons.center_focus_strong_outlined,
  };

  static const _balanced = <String, Object>{
    'level': UserLevel.balanced,
    'showMarkdownToggle': true,
    'showNoteCounts': true,
    'showChecklistProgress': true,
    'showNavIcons': true,
    'zoomOutSummary': true,
    'toolbar': ToolbarMode.floating,
    'showToolbarLabels': true,
    'textScale': 1.0,
    'largeTargets': false,
    'highContrast': false,
    'reduceMotion': false,
    'boldText': false,
  };

  static final _presetValues = <String, Map<String, Object>>{
    'simple': {
      ..._balanced,
      'level': UserLevel.simple,
      'showMarkdownToggle': false,
      'showNoteCounts': false,
      'showChecklistProgress': false,
    },
    'balanced': _balanced,
    'power': {..._balanced, 'level': UserLevel.power, 'toolbar': ToolbarMode.docked},
    'comfort': {
      ..._balanced,
      'level': UserLevel.simple,
      'showMarkdownToggle': false,
      'textScale': 1.3,
      'largeTargets': true,
      'highContrast': true,
      'reduceMotion': true,
      'boldText': true,
    },
    'focus': {
      ..._balanced,
      'showMarkdownToggle': false,
      'showNoteCounts': false,
      'showChecklistProgress': false,
      'showNavIcons': false,
      'showToolbarLabels': false,
    },
  };

  Map<String, Object> get _presetFields => {
        'level': level,
        'showMarkdownToggle': showMarkdownToggle,
        'showNoteCounts': showNoteCounts,
        'showChecklistProgress': showChecklistProgress,
        'showNavIcons': showNavIcons,
        'zoomOutSummary': zoomOutSummary,
        'toolbar': toolbar,
        'showToolbarLabels': showToolbarLabels,
        'textScale': textScale,
        'largeTargets': largeTargets,
        'highContrast': highContrast,
        'reduceMotion': reduceMotion,
        'boldText': boldText,
      };

  /// The preset the current options match, or null when the user has changed
  /// something by hand ("Custom").
  String? get currentPreset {
    final now = _presetFields;
    for (final e in _presetValues.entries) {
      if (e.value.entries.every((f) => now[f.key] == f.value)) return e.key;
    }
    return null;
  }

  void applyPreset(String id) {
    final values = _presetValues[id];
    if (values == null) return;
    update((s) {
      s.level = values['level']! as UserLevel;
      s.showMarkdownToggle = values['showMarkdownToggle']! as bool;
      s.showNoteCounts = values['showNoteCounts']! as bool;
      s.showChecklistProgress = values['showChecklistProgress']! as bool;
      s.showNavIcons = values['showNavIcons']! as bool;
      s.zoomOutSummary = values['zoomOutSummary']! as bool;
      s.toolbar = values['toolbar']! as ToolbarMode;
      s.showToolbarLabels = values['showToolbarLabels']! as bool;
      s.textScale = values['textScale']! as double;
      s.largeTargets = values['largeTargets']! as bool;
      s.highContrast = values['highContrast']! as bool;
      s.reduceMotion = values['reduceMotion']! as bool;
      s.boldText = values['boldText']! as bool;
    });
  }
}
