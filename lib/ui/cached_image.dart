import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:cached_network_image/cached_network_image.dart';

ImagesDatabase imagesDatabase = ImagesDatabase();


class ImagesDatabase {

  /*
  !!! Using the wrappers so i don't have to rewrite most of the code, because of migration to cached network image
  */

  void saveImage(String url) {
    CachedNetworkImageProvider(url);
  }

  Future<PaletteGenerator> getPaletteGenerator(String url) {
    return PaletteGenerator.fromImageProvider(CachedNetworkImageProvider(url));
  }

  Future<Color> getPrimaryColor(String url) async {
    PaletteGenerator paletteGenerator = await getPaletteGenerator(url);
    return paletteGenerator.colors.first;
  }

  Future<bool> isDark(String url) async {
    PaletteGenerator paletteGenerator = await getPaletteGenerator(url);
    return paletteGenerator.colors.first.computeLuminance() > 0.5 ? false : true;
  }

}

class CachedImage extends StatefulWidget {
  final String url;
  final double width;
  final double height;
  final bool circular;
  final bool fullThumb;
  final bool rounded;

  const CachedImage({Key key, this.url, this.height, this.width, this.circular = false, this.fullThumb = false, this.rounded = false}): super(key: key);

  @override
  _CachedImageState createState() => _CachedImageState();
}

class _CachedImageState extends State<CachedImage> {
  @override
  Widget build(BuildContext context) {

    if (widget.rounded) return ClipRRect(
      borderRadius: BorderRadius.circular(8.0),
      child: CachedImage(url: widget.url, height: widget.height, width: widget.width, circular: false, rounded: false, fullThumb: widget.fullThumb),
    );

    if (widget.circular) return ClipOval(
      child: CachedImage(url: widget.url, height: widget.height, width: widget.width, circular: false, rounded: false, fullThumb: widget.fullThumb,)
    );

    if (!widget.url.startsWith('http'))
      return Image.asset(
        widget.url,
        width: widget.width,
        height: widget.height,
      );

    return CachedNetworkImage(
      imageUrl: widget.url,
      width: widget.width,
      height: widget.height,
      placeholder: (context, url) {
        if (widget.fullThumb) return Image.asset('assets/cover.jpg', width: widget.width, height: widget.height,);
        return Image.asset('assets/cover_thumb.jpg', width: widget.width, height: widget.height);
      },
      errorWidget: (context, url, error) => Image.asset('assets/cover_thumb.jpg', width: widget.width, height: widget.height),
    );
  }
}
