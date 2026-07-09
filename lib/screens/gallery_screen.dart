import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/content_models.dart';
import '../services/firestore_service.dart';
import '../widgets/common.dart';

/// Public view of the shared media library. Contributors manage these images in
/// the Admin dashboard; they can be reused across the site.
class GalleryScreen extends StatelessWidget {
  const GalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fs = context.read<FirestoreService>();
    return PageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Gallery',
            icon: Icons.photo_library,
            subtitle: 'Photos and images from around the Booster Club.',
          ),
          StreamListView<GalleryImage>(
            stream: fs.gallery(),
            emptyIcon: Icons.photo_library_outlined,
            emptyMessage: 'No images yet. Check back soon!',
            builder: (context, images) {
              // Only images marked public are shown here; contributors can hide
              // images from this page in the Admin dashboard.
              final visible = images.where((i) => i.public).toList();
              if (visible.isEmpty) {
                return const EmptyState(
                  icon: Icons.photo_library_outlined,
                  message: 'No images yet. Check back soon!',
                );
              }
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final img in visible)
                    _GalleryTile(
                      image: img,
                      onTap: () => _showImage(context, img),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  void _showImage(BuildContext context, GalleryImage img) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: InteractiveViewer(
                child: MediaImage(img.imageUrl, fit: BoxFit.contain),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(img.title,
                      style: Theme.of(context).textTheme.titleMedium),
                  if (img.caption.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(img.caption,
                        style: Theme.of(context).textTheme.bodyMedium),
                  ],
                  if (img.tags.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final t in img.tags) Pill(t, icon: Icons.sell),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GalleryTile extends StatelessWidget {
  final GalleryImage image;
  final VoidCallback onTap;
  const _GalleryTile({required this.image, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 4 / 3,
                child: MediaImage(image.imageUrl, fit: BoxFit.cover),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(image.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall),
                    if (image.caption.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(image.caption,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              )),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
