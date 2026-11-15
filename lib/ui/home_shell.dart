import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../state/notes_store.dart';
import '../state/settings.dart';
import '../theme/vibes.dart';
import 'mindmap_view.dart';
import 'nav.dart';
import 'note_page.dart';
import 'overview_view.dart';
import 'widgets.dart';

/// The signed-in app: navigation plus the main area. The layout is the same
/// in every vibe; the navigation position is a setting. Phones get the side
/// pane as a drawer, tablets and desktops get it docked.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final _scaffold = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<NotesStore>().refresh());
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<NotesStore>();
    final settings = context.watch<AppSettings>();
    final v = VibeTheme.of(context);
    final p = v.p;
    final wide = MediaQuery.sizeOf(context).width >= 720;
    final pos = settings.navPosition;
    final side = pos == NavPosition.left || pos == NavPosition.right;
    final drawerMode = side && !wide;

    final menuButton = drawerMode
        ? IconButton(
            tooltip: 'Open navigation',
            icon: const Icon(Icons.menu),
            onPressed: () => pos == NavPosition.left
                ? _scaffold.currentState?.openDrawer()
                : _scaffold.currentState?.openEndDrawer(),
          )
        : null;

    final note = store.selectedNote;
    final Widget content = switch (store.view) {
      MainView.overview => OverviewView(key: const ValueKey('overview'), leading: menuButton),
      MainView.mindMap => MindMapView(key: const ValueKey('map'), leading: menuButton),
      MainView.note => note == null
          ? _Empty(key: const ValueKey('empty'), leading: menuButton, loading: store.loading)
          : NotePage(key: ValueKey('note-${note.id}'), noteId: note.id, leading: menuButton),
    };

    final main = Column(
      children: [
        if (store.error != null)
          Material(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      store.error!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer, fontSize: 13),
                    ),
                  ),
                  TextButton(onPressed: store.refresh, child: const Text('Retry')),
                ],
              ),
            ),
          ),
        Expanded(
          child: AnimatedSwitcher(
            duration: v.duration,
            switchInCurve: v.curve,
            child: content,
          ),
        ),
        if (v.spec.statusBar)
          Container(
            color: p.highlight,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
            child: DefaultTextStyle.merge(
              style: TextStyle(color: p.onHighlight, fontSize: 12),
              child: Row(
                children: [
                  const Text('main'),
                  const SizedBox(width: 16),
                  Text('${store.notes.length} notes'),
                  const SizedBox(width: 16),
                  Text('${store.folders.length} folders'),
                  const Spacer(),
                  Text(store.loading ? 'syncing…' : store.saving ? 'saving…' : 'synced'),
                ],
              ),
            ),
          ),
      ],
    );

    final divider = Container(
      width: v.spec.chromeless ? 0 : v.spec.borderWidth.clamp(1, 2).toDouble(),
      color: p.line,
    );

    final Widget body;
    if (side && wide) {
      const pane = SizedBox(width: 288, child: NavPane());
      body = Row(
        children: pos == NavPosition.left
            ? [pane, divider, Expanded(child: main)]
            : [Expanded(child: main), divider, pane],
      );
    } else if (!side) {
      body = Column(
        children: pos == NavPosition.top
            ? [const NavBar(atBottom: false), Expanded(child: main)]
            : [Expanded(child: main), const NavBar(atBottom: true)],
      );
    } else {
      body = main;
    }

    Widget? drawer() => Drawer(
          width: 300,
          shape: const RoundedRectangleBorder(),
          child: NavPane(onNavigate: () => Navigator.of(context).maybePop()),
        );

    return Scaffold(
      key: _scaffold,
      drawer: drawerMode && pos == NavPosition.left ? drawer() : null,
      endDrawer: drawerMode && pos == NavPosition.right ? drawer() : null,
      body: SafeArea(child: body),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({super.key, this.leading, required this.loading});
  final Widget? leading;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final store = context.read<NotesStore>();
    final v = VibeTheme.of(context);
    return Column(
      children: [
        if (leading != null) Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.all(8), child: leading)),
        Expanded(
          child: Center(
            child: loading
                ? const CircularProgressIndicator()
                : Appear(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const ZrLogo(size: 72),
                        const SizedBox(height: 18),
                        Text('Start your first note', style: v.heading(26)),
                        const SizedBox(height: 8),
                        Text('Notes hold sections you can place anywhere on the page.', style: TextStyle(color: v.p.muted)),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: () => store.addNote(title: 'My first note'),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('New note'),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
