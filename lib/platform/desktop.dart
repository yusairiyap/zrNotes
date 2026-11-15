import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tray_manager/tray_manager.dart' as tray;
import 'package:window_manager/window_manager.dart';

import '../state/settings.dart';

/// Windows-only extras: the system tray icon, "close to tray" and the small
/// always-on-top compact window. On every other platform these calls do
/// nothing, so the rest of the app never has to check the platform.
class DesktopShell {
  static bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  static AppSettings? _settings;
  static tray.TrayIcon? _tray; // kept so the icon is not garbage collected

  static bool get hasTray => _tray != null;
  static bool _quitting = false;

  static Future<void> init(AppSettings settings) async {
    if (!supported) return;
    _settings = settings;
    try {
      final window = WindowManager.instance.getCurrent();
      if (window == null) return;
      window.title = 'zrNotes';
      window.minimumSize = const Size(340, 420).toNative();

      // Closing the window hides it to the tray instead of quitting.
      window.addListener((event) {
        if (event is WindowCloseRequestedEvent && !_quitting && (_settings?.closeToTray ?? false)) {
          event.request.cancel();
          window.hide();
        }
      });

      final icon = tray.TrayIcon.create();
      if (icon != null) {
        _tray = icon;
        icon.icon = tray.ImageAsset.fromAsset('assets/tray_icon.png');
        icon.setTooltip('zrNotes');

        final menu = tray.Menu.create()!;
        void add(String label, VoidCallback onClick) {
          final item = tray.MenuItem.createWithLabelAndType(label, tray.MenuItemType.normal)!;
          item.addListener((event) {
            if (event is tray.MenuItemClickedEvent) onClick();
          });
          menu.addItem(item);
        }

        add('Open zrNotes', show);
        add('Compact mode on/off', () {
          final on = !(_settings?.compactMode ?? false);
          _settings?.update((s) => s.compactMode = on);
          applyCompact(on);
          show();
        });
        menu.addSeparator();
        add('Quit', () {
          _quitting = true;
          window.close();
        });

        icon.setContextMenu(menu);
        icon.setContextMenuTrigger(tray.ContextMenuTrigger.rightClicked);
        icon.addListener((event) {
          if (event is tray.TrayIconClickedEvent || event is tray.TrayIconDoubleClickedEvent) show();
        });
        icon.setVisible(true);
      }

      if (settings.compactMode) applyCompact(true);
    } catch (e) {
      debugPrint('Desktop shell setup failed: $e');
    }
  }

  static void show() {
    if (!supported) return;
    try {
      final window = WindowManager.instance.getCurrent();
      window?.show();
      window?.focus();
    } catch (_) {}
  }

  /// Compact mode: a small window that stays above other apps.
  static void applyCompact(bool on) {
    if (!supported) return;
    try {
      final window = WindowManager.instance.getCurrent();
      if (window == null) return;
      window.isAlwaysOnTop = on;
      window.setSize((on ? const Size(400, 600) : const Size(1280, 800)).toNative(), false);
      if (!on) window.center();
    } catch (_) {}
  }
}
