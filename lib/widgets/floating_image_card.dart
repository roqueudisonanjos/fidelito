import 'package:flutter/material.dart';

/// Bloco de conteúdo: texto ou widget.
/// - Texto com [fullWidth] = true fica em largura total, acima da imagem.
/// - Texto sem [fullWidth] contorna a imagem.
/// - Widget ocupa a largura total, com altura fixa [height].
class FloatBlock {
  const FloatBlock.text(
    this.text,
    this.style, {
    this.spacing = 0,
    this.maxLines,
    this.fullWidth = false,
  })  : widget = null,
        height = 0,
        topGap = 0;

  const FloatBlock.widget(
    this.widget, {
    this.height = 0,
    this.spacing = 0,
    this.topGap = 0,
  })  : text = null,
        style = null,
        maxLines = null,
        fullWidth = true;

  final String? text;
  final TextStyle? style;
  final Widget? widget;
  final double height;
  final double spacing;
  final int? maxLines;
  final bool fullWidth;

  /// Espaço extra entre a base da imagem e o widget, quando o widget desce para baixo dela.
  final double topGap;
}

class _Layout {
  const _Layout(this.children, this.imageTop, this.height);

  final List<Widget> children;
  final double? imageTop;
  final double height;
}

class FloatingImageCard extends StatelessWidget {
  const FloatingImageCard({
    super.key,
    required this.blocks,
    this.imageUrl,
    this.imageSize = 140,
    this.gap = 12,
    this.padding = EdgeInsets.zero,
    this.onImageTap,
    this.mediaCount = 1,
  });
  
  final VoidCallback? onImageTap;
  final int mediaCount;

  final List<FloatBlock> blocks;
  final String? imageUrl;
  final double imageSize;
  final double gap;

  /// Espaço interno do conteúdo. A imagem fica encostada na borda direita.
  final EdgeInsets padding;

  /// Calcula a altura que o card terá com estes blocos e esta largura.
  static double measureHeight(
    BuildContext context, {
    required List<FloatBlock> blocks,
    required double width,
    String? imageUrl,
    double imageSize = 140,
    double gap = 12,
    EdgeInsets padding = EdgeInsets.zero,
  }) {
    return _layout(
      blocks: blocks,
      maxW: width,
      hasImage: imageUrl != null && imageUrl.isNotEmpty,
      imageSize: imageSize,
      gap: gap,
      padding: padding,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    ).height;
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    final textDirection = Directionality.of(context);
    final textScaler = MediaQuery.textScalerOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final layout = _layout(
          blocks: blocks,
          maxW: maxW,
          hasImage: hasImage,
          imageSize: imageSize,
          gap: gap,
          padding: padding,
          textDirection: textDirection,
          textScaler: textScaler,
        );
        final top = layout.imageTop ?? padding.top;

        return SizedBox(
          width: maxW,
          height: layout.height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Padding(
                padding: padding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: layout.children,
                ),
              ),
              if (hasImage)
                Positioned(
                  top: top,
                  right: 0,
                  child: GestureDetector(
                    onTap: onImageTap,
                    child: Stack(children: [
                      _FadedSquareImage(url: imageUrl!, size: imageSize),
                      if (mediaCount > 1) Positioned(right: 6, top: 6, child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                        decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(14)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.collections, color: Colors.white, size: 13), const SizedBox(width: 4), Text('$mediaCount', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))]),
                      )),
                    ]),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  static _Layout _layout({
    required List<FloatBlock> blocks,
    required double maxW,
    required bool hasImage,
    required double imageSize,
    required double gap,
    required EdgeInsets padding,
    required TextDirection textDirection,
    required TextScaler textScaler,
  }) {
    final floatW = hasImage ? imageSize + gap : 0.0;
    final innerW = maxW - padding.horizontal;
    final floatAvail = maxW - padding.left - floatW;

    final children = <Widget>[];
    var y = padding.top;
    var contentBottom = padding.top;
    double? imageTop;
    var pendingSpacing = 0.0;

    for (final block in blocks) {
      // Espaçamento do bloco anterior só é aplicado se houver outro bloco depois.
      if (pendingSpacing > 0) {
        children.add(SizedBox(height: pendingSpacing));
        y += pendingSpacing;
        pendingSpacing = 0;
      }

      // Widget: fica em largura total e, se ainda estiver na faixa da imagem,
      // desce para baixo dela.
      if (block.widget != null) {
        final imageEnd = imageTop == null ? null : imageTop + imageSize;
        if (imageEnd != null && y < imageEnd) {
          children.add(SizedBox(height: imageEnd - y));
          y = imageEnd;
          if (block.topGap > 0) {
            children.add(SizedBox(height: block.topGap));
            y += block.topGap;
          }
        }
        children.add(
          SizedBox(
            width: innerW,
            height: block.height,
            child: block.widget,
          ),
        );
        y += block.height;
        contentBottom = y;
        pendingSpacing = block.spacing;
        continue;
      }

      // Texto: quebra em linhas. Enquanto a linha estiver na faixa da imagem,
      // a largura é reduzida.
      final needsFloat = hasImage && !block.fullWidth;
      if (needsFloat) imageTop ??= y;

      var rest = block.text ?? '';
      var lineCount = 0;
      int? lastIndex;
      var lastText = '';
      var lastAvail = innerW;

      while (rest.trim().isNotEmpty) {
        final inFloat = needsFloat && y < imageTop! + imageSize;
        final avail = inFloat ? floatAvail : innerW;

        if (block.maxLines != null && lineCount >= block.maxLines!) {
          if (lastIndex != null) {
            children[lastIndex] = _line(
              _ellipsize(lastText, block.style, lastAvail, textDirection, textScaler),
              block.style,
              innerW - lastAvail,
            );
          }
          break;
        }

        final tp = TextPainter(
          text: TextSpan(text: rest, style: block.style),
          textDirection: textDirection,
          textScaler: textScaler,
        )..layout(maxWidth: avail);

        var end = tp.getLineBoundary(const TextPosition(offset: 0)).end;
        if (end <= 0) end = rest.length;

        final line = rest.substring(0, end).trimRight();
        final lineHeight = tp.computeLineMetrics().first.height;

        lastIndex = children.length;
        lastText = line;
        lastAvail = avail;
        children.add(_line(line, block.style, innerW - avail));
        lineCount++;

        y += lineHeight;
        contentBottom = y;
        rest = rest.substring(end).trimLeft();
      }

      if (lineCount > 0) pendingSpacing = block.spacing;
    }

    final top = imageTop ?? padding.top;
    final imageBottom = hasImage ? top + imageSize : 0.0;
    final contentH = contentBottom > imageBottom ? contentBottom : imageBottom;

    return _Layout(children, imageTop, contentH + padding.bottom);
  }

  static Widget _line(String text, TextStyle? style, double rightPad) {
    return Padding(
      padding: EdgeInsets.only(right: rightPad < 0 ? 0 : rightPad),
      child: Text(text, style: style),
    );
  }

  static String _ellipsize(
    String text,
    TextStyle? style,
    double maxWidth,
    TextDirection dir,
    TextScaler scaler,
  ) {
    var t = text.trimRight();
    while (t.isNotEmpty) {
      final candidate = '$t…';
      final tp = TextPainter(
        text: TextSpan(text: candidate, style: style),
        textDirection: dir,
        textScaler: scaler,
      )..layout();
      if (tp.width <= maxWidth) return candidate;
      t = t.substring(0, t.length - 1).trimRight();
    }
    return '…';
  }
}

class _FadedSquareImage extends StatelessWidget {
  const _FadedSquareImage({required this.url, required this.size});

  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(12),
          bottomLeft: Radius.circular(16),
        ),
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Colors.transparent, Colors.white],
            stops: [0.0, 0.4],
          ).createShader(bounds),
          child: Image.network(
            url,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}