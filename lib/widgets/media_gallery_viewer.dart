import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Um destaque com uma ou mais mídias (imagens ou vídeos).
class MediaStory {
  const MediaStory({
    required this.urls,
    this.description,
    this.title,
    this.onTitleTap,
  });

  final List<String> urls;
  final String? description;
  final String? title;
  final VoidCallback? onTitleTap;
}

/// Abre um único conjunto de mídias (ex.: imagem de oferta ou recompensa).
Future<void> showFullscreenMediaGallery(
  BuildContext context, {
  required List<String> urls,
  String? description,
  String? title,
  VoidCallback? onTitleTap,
}) {
  if (urls.isEmpty) return Future.value();
  return showFullscreenStoryViewer(
    context,
    stories: [
      MediaStory(
        urls: urls,
        description: description,
        title: title,
        onTitleTap: onTitleTap,
      ),
    ],
  );
}

/// Abre a sequência de destaques em tela cheia.
/// - Ao passar além da última mídia de um destaque, segue para o próximo destaque.
/// - Ao voltar na primeira mídia, abre a última mídia do destaque anterior.
/// - Arrastar para baixo fecha a tela.
Future<void> showFullscreenStoryViewer(
  BuildContext context, {
  required List<MediaStory> stories,
  int initialStoryIndex = 0,
  void Function(int storyIndex)? onStoryViewed,
}) {
  if (!stories.any((story) => story.urls.isNotEmpty)) return Future.value();
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: false,
      pageBuilder: (_, _, _) => _StoryViewerPage(
        stories: stories,
        initialStoryIndex: initialStoryIndex,
        onStoryViewed: onStoryViewed,
      ),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
      transitionDuration: const Duration(milliseconds: 180),
    ),
  );
}

bool _isVideo(String url) =>
    RegExp(r'\.(mp4|mov|m4v|webm)(\?|$)', caseSensitive: false).hasMatch(url);

/// Uma mídia dentro da sequência, com a referência ao destaque e à posição.
class _Entry {
  const _Entry({required this.story, required this.media, required this.url});

  final int story;
  final int media;
  final String url;
}

class _StoryViewerPage extends StatefulWidget {
  const _StoryViewerPage({
    required this.stories,
    required this.initialStoryIndex,
    this.onStoryViewed,
  });

  final List<MediaStory> stories;
  final int initialStoryIndex;
  final void Function(int storyIndex)? onStoryViewed;

  @override
  State<_StoryViewerPage> createState() => _StoryViewerPageState();
}

class _StoryViewerPageState extends State<_StoryViewerPage> {
  static const double _dismissDistance = 120;
  static const double _dismissVelocity = 800;

  late final List<_Entry> _entries;
  late final PageController _controller;
  int _page = 0;
  int _notifiedStory = -1;
  double _dragDy = 0;

  @override
  void initState() {
    super.initState();
    _entries = [
      for (var s = 0; s < widget.stories.length; s++)
        for (var m = 0; m < widget.stories[s].urls.length; m++)
          _Entry(story: s, media: m, url: widget.stories[s].urls[m]),
    ];

    final startStory = widget.initialStoryIndex
        .clamp(0, widget.stories.length - 1)
        .toInt();
    var start = _entries.indexWhere((entry) => entry.story >= startStory);
    if (start < 0) start = 0;

    _page = start;
    _controller = PageController(initialPage: start);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _notifyStory(_entries[_page].story),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _notifyStory(int story) {
    if (story == _notifiedStory) return;
    _notifiedStory = story;
    widget.onStoryViewed?.call(story);
  }

  void _onPageChanged(int page) {
    setState(() => _page = page);
    _notifyStory(_entries[page].story);
  }

  void _move(int delta) {
    final target = (_page + delta).clamp(0, _entries.length - 1).toInt();
    if (target == _page) return;
    _controller.animateToPage(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _close() => Navigator.of(context).pop();

  void _onTitleTap(MediaStory story) {
    final callback = story.onTitleTap;
    if (callback == null) return;
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) => callback());
  }

  Widget _titleWidget(MediaStory story, String title) {
    final isLink = story.onTitleTap != null;
    final label = Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: Colors.white,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        decoration: isLink ? TextDecoration.underline : null,
        decorationColor: Colors.white54,
      ),
    );

    if (!isLink) return label;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _onTitleTap(story),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: label),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: Colors.white70, size: 18),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entry = _entries[_page];
    final story = widget.stories[entry.story];
    final total = story.urls.length;
    final title = story.title?.trim() ?? '';
    final description = story.description?.trim() ?? '';
    final opacity = (1 - _dragDy / 400).clamp(0.3, 1.0).toDouble();

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: opacity),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onVerticalDragUpdate: (details) => setState(() {
          _dragDy = (_dragDy + details.delta.dy).clamp(0.0, 600.0).toDouble();
        }),
        onVerticalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          if (_dragDy > _dismissDistance || velocity > _dismissVelocity) {
            _close();
          } else {
            setState(() => _dragDy = 0);
          }
        },
        onVerticalDragCancel: () => setState(() => _dragDy = 0),
        child: Transform.translate(
          offset: Offset(0, _dragDy),
          child: SafeArea(
            child: Column(
              children: [
                SizedBox(
                  height: 54,
                  child: Row(
                    children: [
                      if (title.isNotEmpty)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 10),
                            child: _titleWidget(story, title),
                          ),
                        )
                      else
                        const Spacer(),
                      if (total > 1)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(
                            '${entry.media + 1}/$total',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                      IconButton(
                        tooltip: 'Fechar',
                        onPressed: _close,
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      PageView.builder(
                        controller: _controller,
                        itemCount: _entries.length,
                        onPageChanged: _onPageChanged,
                        itemBuilder: (_, index) => Center(
                          child: _MediaItem(
                            key: ValueKey(_entries[index].url),
                            url: _entries[index].url,
                          ),
                        ),
                      ),
                      if (_entries.length > 1) ...[
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          width: 64,
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: () => _move(-1),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          bottom: 0,
                          width: 64,
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: () => _move(1),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    child: SizedBox(
                      width: double.infinity,
                      child: Text(
                        description,
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MediaItem extends StatefulWidget {
  const _MediaItem({super.key, required this.url});

  final String url;

  @override
  State<_MediaItem> createState() => _MediaItemState();
}

class _MediaItemState extends State<_MediaItem> {
  VideoPlayerController? _video;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    if (_isVideo(widget.url)) {
      _video = VideoPlayerController.networkUrl(Uri.parse(widget.url))
        ..initialize().then((_) {
          if (mounted) setState(() {});
        }).catchError((_) {
          if (mounted) setState(() => _failed = true);
        });
    }
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final video = _video;
    if (_isVideo(widget.url)) {
      if (_failed) {
        return const Icon(Icons.broken_image, color: Colors.white54, size: 54);
      }
      if (video == null || !video.value.isInitialized) {
        return const CircularProgressIndicator(color: Colors.white);
      }
      return GestureDetector(
        onTap: () => setState(
          () => video.value.isPlaying ? video.pause() : video.play(),
        ),
        child: AspectRatio(
          aspectRatio: video.value.aspectRatio,
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(video),
              if (!video.value.isPlaying)
                const Icon(Icons.play_circle_fill, color: Colors.white, size: 64),
            ],
          ),
        ),
      );
    }
    return InteractiveViewer(
      minScale: 1,
      maxScale: 4,
      child: Image.network(
        widget.url,
        fit: BoxFit.contain,
        loadingBuilder: (_, child, progress) => progress == null
            ? child
            : const CircularProgressIndicator(color: Colors.white),
        errorBuilder: (_, _, _) =>
            const Icon(Icons.broken_image, color: Colors.white54, size: 54),
      ),
    );
  }
}