import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/content_models.dart';
import '../../services/firestore_service.dart';
import '../../widgets/common.dart';
import 'content_forms.dart';

/// How the gallery grid is ordered.
enum _GallerySort { newest, oldest, titleAsc, titleDesc, largest, smallest }

extension on _GallerySort {
  String get label => switch (this) {
        _GallerySort.newest => 'Newest first',
        _GallerySort.oldest => 'Oldest first',
        _GallerySort.titleAsc => 'Title A–Z',
        _GallerySort.titleDesc => 'Title Z–A',
        _GallerySort.largest => 'Largest file',
        _GallerySort.smallest => 'Smallest file',
      };
}

/// Rich management view for the shared media library: a thumbnail grid with
/// sorting, grid/thumbnail sizing, multi-select delete, and a full-screen
/// viewer (navigate, metadata, download, edit).
class GalleryAdmin extends StatefulWidget {
  final FirestoreService fs;
  const GalleryAdmin({super.key, required this.fs});

  @override
  State<GalleryAdmin> createState() => _GalleryAdminState();
}

class _GalleryAdminState extends State<GalleryAdmin> {
  _GallerySort _sort = _GallerySort.newest;
  double _thumb = 170; // base thumbnail extent in px
  int _columns = 0; // 0 = auto (fit to width); otherwise fixed column count
  final Set<String> _selected = {};

  List<GalleryImage> _sorted(List<GalleryImage> items) {
    final list = List<GalleryImage>.of(items);
    int cmpDate(GalleryImage a, GalleryImage b) =>
        (a.uploadedAt ?? DateTime(1970)).compareTo(b.uploadedAt ?? DateTime(1970));
    switch (_sort) {
      case _GallerySort.newest:
        list.sort((a, b) => cmpDate(b, a));
      case _GallerySort.oldest:
        list.sort(cmpDate);
      case _GallerySort.titleAsc:
        list.sort((a, b) =>
            a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      case _GallerySort.titleDesc:
        list.sort((a, b) =>
            b.title.toLowerCase().compareTo(a.title.toLowerCase()));
      case _GallerySort.largest:
        list.sort((a, b) => (b.sizeBytes ?? 0).compareTo(a.sizeBytes ?? 0));
      case _GallerySort.smallest:
        list.sort((a, b) => (a.sizeBytes ?? 0).compareTo(b.sizeBytes ?? 0));
    }
    return list;
  }

  Future<void> _addOrEdit(GalleryImage? existing) async {
    final result = await editGalleryImage(context, existing, widget.fs);
    if (result != null) await widget.fs.upsert('gallery', result);
  }

  Future<void> _deleteSelected() async {
    final count = _selected.length;
    if (count == 0) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $count image${count == 1 ? '' : 's'}?'),
        content: const Text('The selected images will be permanently removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    for (final id in _selected.toList()) {
      await widget.fs.delete('gallery', id);
    }
    if (mounted) setState(_selected.clear);
  }

  Future<void> _deleteOne(GalleryImage img) async {
    await widget.fs.delete('gallery', img.id);
    if (mounted) setState(() => _selected.remove(img.id));
  }

  void _openViewer(List<GalleryImage> images, int index) {
    showDialog(
      context: context,
      builder: (_) => _GalleryViewer(
        images: images,
        initialIndex: index,
        fs: widget.fs,
        onEdit: _addOrEdit,
        onDelete: _deleteOne,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<GalleryImage>>(
      stream: widget.fs.gallery(),
      builder: (context, snap) {
        if (snap.hasError) {
          return EmptyState(
              icon: Icons.error_outline,
              message: 'Something went wrong.\n${snap.error}');
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final images = _sorted(snap.data!);
        // Drop selections for images that no longer exist.
        _selected.removeWhere((id) => !images.any((g) => g.id == id));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _toolbar(context),
            Expanded(
              child: images.isEmpty
                  ? const EmptyState(
                      icon: Icons.photo_library_outlined,
                      message: 'No images yet — add one to get started.')
                  : _grid(images),
            ),
          ],
        );
      },
    );
  }

  Widget _toolbar(BuildContext context) {
    final hasSel = _selected.isNotEmpty;
    // Left: view controls that wrap within the available width. Right: the
    // selection/add actions. These two groups live in a Row (not a single
    // Wrap) so we never place a Flex-only widget like Spacer inside a Wrap —
    // doing so throws at layout time and renders a blank grey error box.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Sort
                _labeled(
                  'Sort',
                  DropdownButton<_GallerySort>(
                    value: _sort,
                    isDense: true,
                    underline: const SizedBox.shrink(),
                    onChanged: (v) => setState(() => _sort = v ?? _sort),
                    items: [
                      for (final s in _GallerySort.values)
                        DropdownMenuItem(value: s, child: Text(s.label)),
                    ],
                  ),
                ),
                // Grid columns
                _labeled(
                  'Grid',
                  DropdownButton<int>(
                    value: _columns,
                    isDense: true,
                    underline: const SizedBox.shrink(),
                    onChanged: (v) => setState(() => _columns = v ?? 0),
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('Auto')),
                      DropdownMenuItem(value: 2, child: Text('2')),
                      DropdownMenuItem(value: 3, child: Text('3')),
                      DropdownMenuItem(value: 4, child: Text('4')),
                      DropdownMenuItem(value: 5, child: Text('5')),
                      DropdownMenuItem(value: 6, child: Text('6')),
                    ],
                  ),
                ),
                // Thumbnail size
                _labeled(
                  'Thumbnail',
                  SegmentedButton<double>(
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: 120, label: Text('S')),
                      ButtonSegment(value: 170, label: Text('M')),
                      ButtonSegment(value: 240, label: Text('L')),
                    ],
                    selected: {_thumb},
                    onSelectionChanged: (s) => setState(() => _thumb = s.first),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (hasSel) ...[
                Text('${_selected.length} selected'),
                TextButton.icon(
                  onPressed: () => setState(_selected.clear),
                  icon: const Icon(Icons.clear, size: 18),
                  label: const Text('Clear'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: _deleteSelected,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: Text('Delete (${_selected.length})'),
                ),
              ],
              FilledButton.icon(
                onPressed: () => _addOrEdit(null),
                icon: const Icon(Icons.add),
                label: const Text('Add new'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _labeled(String label, Widget child) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label:',
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(width: 6),
          child,
        ],
      );

  Widget _grid(List<GalleryImage> images) {
    final delegate = _columns == 0
        ? SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: _thumb,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1,
          )
        : SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _columns,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1,
          );
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      gridDelegate: delegate,
      itemCount: images.length,
      itemBuilder: (context, i) {
        final img = images[i];
        return _GalleryTile(
          image: img,
          selected: _selected.contains(img.id),
          onToggleSelect: () => setState(() {
            if (!_selected.add(img.id)) _selected.remove(img.id);
          }),
          onOpen: () => _openViewer(images, i),
        );
      },
    );
  }
}

class _GalleryTile extends StatelessWidget {
  final GalleryImage image;
  final bool selected;
  final VoidCallback onToggleSelect;
  final VoidCallback onOpen;
  const _GalleryTile({
    required this.image,
    required this.selected,
    required this.onToggleSelect,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onTap: onOpen,
            child: MediaImage(image.imageUrl, fit: BoxFit.cover),
          ),
          // Title strip along the bottom.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black.withValues(alpha: 0.65), Colors.transparent],
                  ),
                ),
                child: Text(
                  image.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          ),
          // "Hidden from public" badge for non-public images.
          if (!image.public)
            Positioned(
              top: 6,
              right: 6,
              child: IgnorePointer(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.visibility_off, color: Colors.white, size: 13),
                      SizedBox(width: 3),
                      Text('Hidden',
                          style: TextStyle(color: Colors.white, fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ),
          // Selection checkbox. An opaque GestureDetector on top absorbs the
          // tap so toggling selection never also opens the viewer.
          Positioned(
            top: 4,
            left: 4,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onToggleSelect,
              child: Container(
                decoration: const BoxDecoration(
                    color: Colors.black45, shape: BoxShape.circle),
                padding: const EdgeInsets.all(2),
                child: Icon(
                  selected ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: selected ? scheme.primary : Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
          if (selected)
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: scheme.primary, width: 3),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Full-screen image viewer with prev/next navigation, metadata, download and
/// edit.
class _GalleryViewer extends StatefulWidget {
  final List<GalleryImage> images;
  final int initialIndex;
  final FirestoreService fs;
  final Future<void> Function(GalleryImage) onEdit;
  final Future<void> Function(GalleryImage) onDelete;
  const _GalleryViewer({
    required this.images,
    required this.initialIndex,
    required this.fs,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_GalleryViewer> createState() => _GalleryViewerState();
}

class _GalleryViewerState extends State<_GalleryViewer> {
  late final PageController _controller;
  late List<GalleryImage> _images;
  late int _index;
  bool _showInfo = true;

  @override
  void initState() {
    super.initState();
    _images = List.of(widget.images);
    _index = widget.initialIndex;
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  GalleryImage get _current => _images[_index];

  void _go(int delta) {
    final next = _index + delta;
    if (next < 0 || next >= _images.length) return;
    _controller.animateToPage(next,
        duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  Future<void> _download() async {
    final uri = Uri.tryParse(_current.imageUrl);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _edit() async {
    await widget.onEdit(_current);
    // Reflect any edit in place by re-reading the latest for this id. The image
    // count doesn't change (editing never deletes), so the pager stays valid.
    final latest = await widget.fs.gallery().first;
    final match = latest.where((g) => g.id == _current.id);
    if (!mounted || match.isEmpty) return;
    setState(() => _images[_index] = match.first);
  }

  Future<void> _delete() async {
    // Deleting while inside the pager and mutating the list resyncs awkwardly,
    // so just remove and close — the grid updates from the stream.
    await widget.onDelete(_current);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          // Image pager with pinch-zoom.
          PageView.builder(
            controller: _controller,
            itemCount: _images.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) => InteractiveViewer(
              maxScale: 5,
              child: Center(
                child: MediaImage(_images[i].imageUrl, fit: BoxFit.contain),
              ),
            ),
          ),
          // Top action bar.
          _topBar(context),
          // Prev / next buttons.
          if (_index > 0)
            _navButton(Alignment.centerLeft, Icons.chevron_left, () => _go(-1)),
          if (_index < _images.length - 1)
            _navButton(
                Alignment.centerRight, Icons.chevron_right, () => _go(1)),
          // Metadata panel.
          if (_showInfo)
            Align(alignment: Alignment.bottomCenter, child: _infoPanel(context)),
        ],
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withValues(alpha: 0.6), Colors.transparent],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Row(
            children: [
              IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              Expanded(
                child: Text(
                  '${_index + 1} / ${_images.length}',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              IconButton(
                tooltip: _showInfo ? 'Hide details' : 'Show details',
                icon: Icon(_showInfo ? Icons.info : Icons.info_outline,
                    color: Colors.white),
                onPressed: () => setState(() => _showInfo = !_showInfo),
              ),
              IconButton(
                tooltip: 'Download',
                icon: const Icon(Icons.download, color: Colors.white),
                onPressed: _download,
              ),
              IconButton(
                tooltip: 'Edit',
                icon: const Icon(Icons.edit, color: Colors.white),
                onPressed: _edit,
              ),
              IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline, color: Colors.white),
                onPressed: _confirmDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete image?'),
        content: Text('“${_current.title}” will be permanently removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) await _delete();
  }

  Widget _navButton(Alignment align, IconData icon, VoidCallback onTap) {
    return Align(
      alignment: align,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: CircleAvatar(
          backgroundColor: Colors.black.withValues(alpha: 0.4),
          child: IconButton(
            icon: Icon(icon, color: Colors.white),
            onPressed: onTap,
          ),
        ),
      ),
    );
  }

  Widget _infoPanel(BuildContext context) {
    final img = _current;
    final created = img.uploadedAt != null
        ? DateFormat('MMM d, y · h:mm a').format(img.uploadedAt!)
        : null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (img.title.isNotEmpty)
              Text(img.title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600)),
            if (img.caption.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(img.caption,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85))),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                if (img.fileName.isNotEmpty)
                  _meta(Icons.insert_drive_file_outlined, img.fileName),
                if (img.dimensionsLabel != null)
                  _meta(Icons.straighten, '${img.dimensionsLabel} px'),
                if (img.sizeLabel != null) _meta(Icons.sd_storage, img.sizeLabel!),
                if (created != null) _meta(Icons.event, created),
                _meta(img.public ? Icons.public : Icons.visibility_off,
                    img.public ? 'Public' : 'Hidden from public'),
              ],
            ),
            if (img.tags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final t in img.tags)
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(t,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12)),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _meta(IconData icon, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.8)),
          const SizedBox(width: 5),
          Text(text,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85), fontSize: 12)),
        ],
      );
}
