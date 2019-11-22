// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui' show Color;

import 'package:collection/collection.dart'
    show PriorityQueue, HeapPriorityQueue;
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';


class PaletteGenerator extends Diagnosticable {

  PaletteGenerator.fromColors(this.paletteColors, {this.targets})
      : assert(paletteColors != null),
        selectedSwatches = <PaletteTarget, PaletteColor>{} {
    _sortSwatches();
    _selectSwatches();
  }

  static Future<PaletteGenerator> fromImage(
      ui.Image image, {
        Rect region,
        int maximumColorCount,
        List<PaletteFilter> filters,
        List<PaletteTarget> targets,
      }) async {
    assert(image != null);
    assert(region == null || region != Rect.zero);
    assert(
    region == null ||
        (region.topLeft.dx >= 0.0 && region.topLeft.dy >= 0.0),
    'Region $region is outside the image ${image.width}x${image.height}');
    assert(
    region == null ||
        (region.bottomRight.dx <= image.width &&
            region.bottomRight.dy <= image.height),
    'Region $region is outside the image ${image.width}x${image.height}');

    filters ??= <PaletteFilter>[avoidRedBlackWhitePaletteFilter];
    maximumColorCount ??= _defaultCalculateNumberColors;
    final _ColorCutQuantizer quantizer = _ColorCutQuantizer(
      image,
      maxColors: maximumColorCount,
      filters: filters,
      region: region,
    );
    final List<PaletteColor> colors = await quantizer.quantizedColors;
    return PaletteGenerator.fromColors(
      colors,
      targets: targets,
    );
  }

  static Future<PaletteGenerator> fromImageProvider(
      ImageProvider imageProvider, {
        Size size,
        Rect region,
        int maximumColorCount,
        List<PaletteFilter> filters,
        List<PaletteTarget> targets,
        Duration timeout = const Duration(seconds: 15),
      }) async {
    assert(imageProvider != null);
    assert(timeout != null);
    assert(region == null || (region != null && size != null));
    assert(region == null || region != Rect.zero);
    assert(
    region == null ||
        (region.topLeft.dx >= 0.0 && region.topLeft.dy >= 0.0),
    'Region $region is outside the image ${size.width}x${size.height}');
    assert(region == null || size.contains(region.topLeft),
    'Region $region is outside the image $size');
    assert(
    region == null ||
        (region.bottomRight.dx <= size.width &&
            region.bottomRight.dy <= size.height),
    'Region $region is outside the image $size');
    final ImageStream stream = imageProvider.resolve(
      ImageConfiguration(size: size, devicePixelRatio: 1.0),
    );
    final Completer<ui.Image> imageCompleter = Completer<ui.Image>();
    Timer loadFailureTimeout;

    ImageStreamListener l;

    void imageListener(ImageInfo info, bool synchronousCall) {
      loadFailureTimeout?.cancel();
      stream.removeListener(l);
      imageCompleter.complete(info.image);
    }

    l = ImageStreamListener(imageListener);

    if (timeout != Duration.zero) {
      loadFailureTimeout = Timer(timeout, () {
        stream.removeListener(l);
        imageCompleter.completeError(
          TimeoutException(
              'Timeout occurred trying to load from $imageProvider'),
        );
      });
    }
    stream.addListener(l);
    return PaletteGenerator.fromImage(
      await imageCompleter.future,
      region: region,
      maximumColorCount: maximumColorCount,
      filters: filters,
      targets: targets,
    );
  }

  static const int _defaultCalculateNumberColors = 16;

  final Map<PaletteTarget, PaletteColor> selectedSwatches;

  final List<PaletteColor> paletteColors;

  final List<PaletteTarget> targets;

  Iterable<Color> get colors sync* {
    for (PaletteColor paletteColor in paletteColors) {
      yield paletteColor.color;
    }
  }

  PaletteColor get vibrantColor => selectedSwatches[PaletteTarget.vibrant];

  PaletteColor get lightVibrantColor =>
      selectedSwatches[PaletteTarget.lightVibrant];

  PaletteColor get darkVibrantColor =>
      selectedSwatches[PaletteTarget.darkVibrant];

  PaletteColor get mutedColor => selectedSwatches[PaletteTarget.muted];

  PaletteColor get lightMutedColor =>
      selectedSwatches[PaletteTarget.lightMuted];

  PaletteColor get darkMutedColor => selectedSwatches[PaletteTarget.darkMuted];

  PaletteColor get dominantColor => _dominantColor;
  PaletteColor _dominantColor;

  void _sortSwatches() {
    if (paletteColors.isEmpty) {
      _dominantColor = null;
      return;
    }
    paletteColors.sort((PaletteColor a, PaletteColor b) {
      return b.population.compareTo(a.population);
    });
    _dominantColor = paletteColors[0];
  }

  void _selectSwatches() {
    final Set<PaletteTarget> allTargets = Set<PaletteTarget>.from(
        (targets ?? <PaletteTarget>[]) + PaletteTarget.baseTargets);
    final Set<Color> usedColors = Set<Color>();
    for (PaletteTarget target in allTargets) {
      target._normalizeWeights();
      selectedSwatches[target] = _generateScoredTarget(target, usedColors);
    }
  }

  PaletteColor _generateScoredTarget(
      PaletteTarget target, Set<Color> usedColors) {
    final PaletteColor maxScoreSwatch =
    _getMaxScoredSwatchForTarget(target, usedColors);
    if (maxScoreSwatch != null && target.isExclusive) {
      // If we have a color, and the target is exclusive, add the color to the
      // used list.
      usedColors.add(maxScoreSwatch.color);
    }
    return maxScoreSwatch;
  }

  PaletteColor _getMaxScoredSwatchForTarget(
      PaletteTarget target, Set<Color> usedColors) {
    double maxScore = 0.0;
    PaletteColor maxScoreSwatch;
    for (PaletteColor paletteColor in paletteColors) {
      if (_shouldBeScoredForTarget(paletteColor, target, usedColors)) {
        final double score = _generateScore(paletteColor, target);
        if (maxScoreSwatch == null || score > maxScore) {
          maxScoreSwatch = paletteColor;
          maxScore = score;
        }
      }
    }
    return maxScoreSwatch;
  }

  bool _shouldBeScoredForTarget(
      PaletteColor paletteColor, PaletteTarget target, Set<Color> usedColors) {
    final HSLColor hslColor = HSLColor.fromColor(paletteColor.color);
    return hslColor.saturation >= target.minimumSaturation &&
        hslColor.saturation <= target.maximumSaturation &&
        hslColor.lightness >= target.minimumLightness &&
        hslColor.lightness <= target.maximumLightness &&
        !usedColors.contains(paletteColor.color);
  }

  double _generateScore(PaletteColor paletteColor, PaletteTarget target) {
    final HSLColor hslColor = HSLColor.fromColor(paletteColor.color);

    double saturationScore = 0.0;
    double valueScore = 0.0;
    double populationScore = 0.0;

    if (target.saturationWeight > 0.0) {
      saturationScore = target.saturationWeight *
          (1.0 - (hslColor.saturation - target.targetSaturation).abs());
    }
    if (target.lightnessWeight > 0.0) {
      valueScore = target.lightnessWeight *
          (1.0 - (hslColor.lightness - target.targetLightness).abs());
    }
    if (target.populationWeight > 0.0) {
      populationScore = target.populationWeight *
          (paletteColor.population / _dominantColor.population);
    }

    return saturationScore + valueScore + populationScore;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(IterableProperty<PaletteColor>(
        'paletteColors', paletteColors,
        defaultValue: <PaletteColor>[]));
    properties.add(IterableProperty<PaletteTarget>('targets', targets,
        defaultValue: PaletteTarget.baseTargets));
  }

}

class PaletteTarget extends Diagnosticable {
  PaletteTarget({
    this.minimumSaturation = 0.0,
    this.targetSaturation = 0.5,
    this.maximumSaturation = 1.0,
    this.minimumLightness = 0.0,
    this.targetLightness = 0.5,
    this.maximumLightness = 1.0,
    this.isExclusive = true,
  })  : assert(minimumSaturation != null),
        assert(targetSaturation != null),
        assert(maximumSaturation != null),
        assert(minimumLightness != null),
        assert(targetLightness != null),
        assert(maximumLightness != null),
        assert(isExclusive != null);

  final double minimumSaturation;

  final double targetSaturation;

  final double maximumSaturation;

  final double minimumLightness;

  final double targetLightness;

  final double maximumLightness;

  final bool isExclusive;

  double saturationWeight = _weightSaturation;

  double lightnessWeight = _weightLightness;

  double populationWeight = _weightPopulation;

  static const double _targetDarkLightness = 0.26;
  static const double _maxDarkLightness = 0.45;

  static const double _minLightLightness = 0.55;
  static const double _targetLightLightness = 0.74;

  static const double _minNormalLightness = 0.3;
  static const double _targetNormalLightness = 0.5;
  static const double _maxNormalLightness = 0.7;

  static const double _targetMutedSaturation = 0.3;
  static const double _maxMutedSaturation = 0.4;

  static const double _targetVibrantSaturation = 1.0;
  static const double _minVibrantSaturation = 0.35;

  static const double _weightSaturation = 0.24;
  static const double _weightLightness = 0.52;
  static const double _weightPopulation = 0.24;

  static final PaletteTarget lightVibrant = PaletteTarget(
    targetLightness: _targetLightLightness,
    minimumLightness: _minLightLightness,
    minimumSaturation: _minVibrantSaturation,
    targetSaturation: _targetVibrantSaturation,
  );

  static final PaletteTarget vibrant = PaletteTarget(
    minimumLightness: _minNormalLightness,
    targetLightness: _targetNormalLightness,
    maximumLightness: _maxNormalLightness,
    minimumSaturation: _minVibrantSaturation,
    targetSaturation: _targetVibrantSaturation,
  );

  static final PaletteTarget darkVibrant = PaletteTarget(
    targetLightness: _targetDarkLightness,
    maximumLightness: _maxDarkLightness,
    minimumSaturation: _minVibrantSaturation,
    targetSaturation: _targetVibrantSaturation,
  );

  static final PaletteTarget lightMuted = PaletteTarget(
    targetLightness: _targetLightLightness,
    minimumLightness: _minLightLightness,
    targetSaturation: _targetMutedSaturation,
    maximumSaturation: _maxMutedSaturation,
  );

  static final PaletteTarget muted = PaletteTarget(
    minimumLightness: _minNormalLightness,
    targetLightness: _targetNormalLightness,
    maximumLightness: _maxNormalLightness,
    targetSaturation: _targetMutedSaturation,
    maximumSaturation: _maxMutedSaturation,
  );

  static final PaletteTarget darkMuted = PaletteTarget(
    targetLightness: _targetDarkLightness,
    maximumLightness: _maxDarkLightness,
    targetSaturation: _targetMutedSaturation,
    maximumSaturation: _maxMutedSaturation,
  );

  static final List<PaletteTarget> baseTargets = <PaletteTarget>[
    lightVibrant,
    vibrant,
    darkVibrant,
    lightMuted,
    muted,
    darkMuted,
  ];

  void _normalizeWeights() {
    final double sum = saturationWeight + lightnessWeight + populationWeight;
    if (sum != 0.0) {
      saturationWeight /= sum;
      lightnessWeight /= sum;
      populationWeight /= sum;
    }
  }

  @override
  bool operator ==(dynamic other) {
    return minimumSaturation == other.minimumSaturation &&
        targetSaturation == other.targetSaturation &&
        maximumSaturation == other.maximumSaturation &&
        minimumLightness == other.minimumLightness &&
        targetLightness == other.targetLightness &&
        maximumLightness == other.maximumLightness &&
        saturationWeight == other.saturationWeight &&
        lightnessWeight == other.lightnessWeight &&
        populationWeight == other.populationWeight;
  }

  @override
  int get hashCode {
    return hashValues(
      minimumSaturation,
      targetSaturation,
      maximumSaturation,
      minimumLightness,
      targetLightness,
      maximumLightness,
      saturationWeight,
      lightnessWeight,
      populationWeight,
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    final PaletteTarget defaultTarget = PaletteTarget();
    properties.add(DoubleProperty('minimumSaturation', minimumSaturation,
        defaultValue: defaultTarget.minimumSaturation));
    properties.add(DoubleProperty('targetSaturation', targetSaturation,
        defaultValue: defaultTarget.targetSaturation));
    properties.add(DoubleProperty('maximumSaturation', maximumSaturation,
        defaultValue: defaultTarget.maximumSaturation));
    properties.add(DoubleProperty('minimumLightness', minimumLightness,
        defaultValue: defaultTarget.minimumLightness));
    properties.add(DoubleProperty('targetLightness', targetLightness,
        defaultValue: defaultTarget.targetLightness));
    properties.add(DoubleProperty('maximumLightness', maximumLightness,
        defaultValue: defaultTarget.maximumLightness));
    properties.add(DoubleProperty('saturationWeight', saturationWeight,
        defaultValue: defaultTarget.saturationWeight));
    properties.add(DoubleProperty('lightnessWeight', lightnessWeight,
        defaultValue: defaultTarget.lightnessWeight));
    properties.add(DoubleProperty('populationWeight', populationWeight,
        defaultValue: defaultTarget.populationWeight));
  }
}

typedef _ContrastCalculator = double Function(Color a, Color b, int alpha);

class PaletteColor extends Diagnosticable {
  PaletteColor(this.color, this.population)
      : assert(color != null),
        assert(population != null);
  static const double _minContrastTitleText = 3.0;
  static const double _minContrastBodyText = 4.5;

  /// The color that this palette color represents.
  final Color color;

  /// The number of pixels in the source image that this palette color
  /// represents.
  final int population;

  /// The color of title text for use with this palette color.
  Color get titleTextColor {
    if (_titleTextColor == null) {
      _ensureTextColorsGenerated();
    }
    return _titleTextColor;
  }

  Color _titleTextColor;

  /// The color of body text for use with this palette color.
  Color get bodyTextColor {
    if (_bodyTextColor == null) {
      _ensureTextColorsGenerated();
    }
    return _bodyTextColor;
  }

  Color _bodyTextColor;

  void _ensureTextColorsGenerated() {
    if (_titleTextColor == null || _bodyTextColor == null) {
      const Color white = Color(0xffffffff);
      const Color black = Color(0xff000000);
      final int lightBodyAlpha =
      _calculateMinimumAlpha(white, color, _minContrastBodyText);
      final int lightTitleAlpha =
      _calculateMinimumAlpha(white, color, _minContrastTitleText);

      if (lightBodyAlpha != null && lightTitleAlpha != null) {
        _bodyTextColor = white.withAlpha(lightBodyAlpha);
        _titleTextColor = white.withAlpha(lightTitleAlpha);
        return;
      }

      final int darkBodyAlpha =
      _calculateMinimumAlpha(black, color, _minContrastBodyText);
      final int darkTitleAlpha =
      _calculateMinimumAlpha(black, color, _minContrastTitleText);

      if (darkBodyAlpha != null && darkBodyAlpha != null) {
        _bodyTextColor = black.withAlpha(darkBodyAlpha);
        _titleTextColor = black.withAlpha(darkTitleAlpha);
        return;
      }

      _bodyTextColor = lightBodyAlpha != null //
          ? white.withAlpha(lightBodyAlpha)
          : black.withAlpha(darkBodyAlpha);
      _titleTextColor = lightTitleAlpha != null //
          ? white.withAlpha(lightTitleAlpha)
          : black.withAlpha(darkTitleAlpha);
    }
  }

  static double _calculateContrast(Color foreground, Color background) {
    assert(background.alpha == 0xff,
    'background can not be translucent: $background.');
    if (foreground.alpha < 0xff) {
      // If the foreground is translucent, composite the foreground over the
      // background
      foreground = Color.alphaBlend(foreground, background);
    }
    final double lightness1 = HSLColor.fromColor(foreground).lightness + 0.05;
    final double lightness2 = HSLColor.fromColor(background).lightness + 0.05;
    return math.max(lightness1, lightness2) / math.min(lightness1, lightness2);
  }

  static int _calculateMinimumAlpha(
      Color foreground, Color background, double minContrastRatio) {
    assert(foreground != null);
    assert(background != null);
    assert(background.alpha == 0xff,
    'The background cannot be translucent: $background.');
    double contrastCalculator(Color fg, Color bg, int alpha) {
      final Color testForeground = fg.withAlpha(alpha);
      return _calculateContrast(testForeground, bg);
    }

    // First lets check that a fully opaque foreground has sufficient contrast
    final double testRatio = contrastCalculator(foreground, background, 0xff);
    if (testRatio < minContrastRatio) {
      // Fully opaque foreground does not have sufficient contrast, return error
      return null;
    }
    foreground = foreground.withAlpha(0xff);
    return _binaryAlphaSearch(
        foreground, background, minContrastRatio, contrastCalculator);
  }

  static int _binaryAlphaSearch(
      Color foreground,
      Color background,
      double minContrastRatio,
      _ContrastCalculator calculator,
      ) {
    assert(foreground != null);
    assert(background != null);
    assert(background.alpha == 0xff,
    'The background cannot be translucent: $background.');
    const int minAlphaSearchMaxIterations = 10;
    const int minAlphaSearchPrecision = 1;

    int numIterations = 0;
    int minAlpha = 0;
    int maxAlpha = 0xff;
    while (numIterations <= minAlphaSearchMaxIterations &&
        (maxAlpha - minAlpha) > minAlphaSearchPrecision) {
      final int testAlpha = (minAlpha + maxAlpha) ~/ 2;
      final double testRatio = calculator(foreground, background, testAlpha);
      if (testRatio < minContrastRatio) {
        minAlpha = testAlpha;
      } else {
        maxAlpha = testAlpha;
      }
      numIterations++;
    }
    // Conservatively return the max of the range of possible alphas, which is
    // known to pass.
    return maxAlpha;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Color>('color', color));
    properties
        .add(DiagnosticsProperty<Color>('titleTextColor', titleTextColor));
    properties.add(DiagnosticsProperty<Color>('bodyTextColor', bodyTextColor));
    properties.add(IntProperty('population', population, defaultValue: 0));
  }

  @override
  int get hashCode {
    return hashValues(color, population);
  }

  @override
  bool operator ==(dynamic other) {
    return color == other.color && population == other.population;
  }
}

/// Hook to allow clients to be able filter colors from selected in a
/// [PaletteGenerator]. Returns true if the [color] is allowed.
///
/// See also:
///
///   * [PaletteGenerator.fromImage], which takes a list of these for its
///    `filters` parameter.
///   * [avoidRedBlackWhitePaletteFilter], the default filter for
///     [PaletteGenerator].
typedef PaletteFilter = bool Function(HSLColor color);

/// A basic [PaletteFilter], which rejects colors near black, white and low
/// saturation red.
///
/// Use this as an element in the `filters` list given to [PaletteGenerator.fromImage].
///
/// See also:
///  * [PaletteGenerator], a class for selecting color palettes from images.
bool avoidRedBlackWhitePaletteFilter(HSLColor color) {
  bool _isBlack(HSLColor hslColor) {
    const double _blackMaxLightness = 0.05;
    return hslColor.lightness <= _blackMaxLightness;
  }

  bool _isWhite(HSLColor hslColor) {
    const double _whiteMinLightness = 0.95;
    return hslColor.lightness >= _whiteMinLightness;
  }

  // Returns true if the color is close to the red side of the I line.
  bool _isNearRedILine(HSLColor hslColor) {
    const double redLineMinHue = 10.0;
    const double redLineMaxHue = 37.0;
    const double redLineMaxSaturation = 0.82;
    return hslColor.hue >= redLineMinHue &&
        hslColor.hue <= redLineMaxHue &&
        hslColor.saturation <= redLineMaxSaturation;
  }

  return !_isWhite(color) && !_isBlack(color) && !_isNearRedILine(color);
}

enum _ColorComponent {
  red,
  green,
  blue,
}

/// A box that represents a volume in the RGB color space.
class _ColorVolumeBox {
  _ColorVolumeBox(int lowerIndex, int upperIndex, this.histogram, this.colors)
      : assert(histogram != null),
        assert(colors != null),
        _lowerIndex = lowerIndex,
        _upperIndex = upperIndex {
    _fitMinimumBox();
  }

  final Map<Color, int> histogram;
  final List<Color> colors;

  // The lower and upper index are inclusive.
  int _lowerIndex;
  int _upperIndex;

  // The population of colors within this box.
  int _population;

  // Bounds in each of the dimensions.
  int _minRed;
  int _maxRed;
  int _minGreen;
  int _maxGreen;
  int _minBlue;
  int _maxBlue;

  int getVolume() {
    return (_maxRed - _minRed + 1) *
        (_maxGreen - _minGreen + 1) *
        (_maxBlue - _minBlue + 1);
  }

  bool canSplit() {
    return getColorCount() > 1;
  }

  int getColorCount() {
    return 1 + _upperIndex - _lowerIndex;
  }

  /// Recomputes the boundaries of this box to tightly fit the colors within the
  /// box.
  void _fitMinimumBox() {
    // Reset the min and max to opposite values
    int minRed = 256;
    int minGreen = 256;
    int minBlue = 256;
    int maxRed = -1;
    int maxGreen = -1;
    int maxBlue = -1;
    int count = 0;
    for (int i = _lowerIndex; i <= _upperIndex; i++) {
      final Color color = colors[i];
      count += histogram[color];
      if (color.red > maxRed) {
        maxRed = color.red;
      }
      if (color.red < minRed) {
        minRed = color.red;
      }
      if (color.green > maxGreen) {
        maxGreen = color.green;
      }
      if (color.green < minGreen) {
        minGreen = color.green;
      }
      if (color.blue > maxBlue) {
        maxBlue = color.blue;
      }
      if (color.blue < minBlue) {
        minBlue = color.blue;
      }
    }
    _minRed = minRed;
    _maxRed = maxRed;
    _minGreen = minGreen;
    _maxGreen = maxGreen;
    _minBlue = minBlue;
    _maxBlue = maxBlue;
    _population = count;
  }

  /// Split this color box at the mid-point along it's longest dimension
  ///
  /// Returns the new ColorBox
  _ColorVolumeBox splitBox() {
    assert(canSplit(), "Can't split a box with only 1 color");
    // find median along the longest dimension
    final int splitPoint = _findSplitPoint();
    final _ColorVolumeBox newBox =
    _ColorVolumeBox(splitPoint + 1, _upperIndex, histogram, colors);
    // Now change this box's upperIndex and recompute the color boundaries
    _upperIndex = splitPoint;
    _fitMinimumBox();
    return newBox;
  }

  /// Returns the largest dimension of this color box.
  _ColorComponent _getLongestColorDimension() {
    final int redLength = _maxRed - _minRed;
    final int greenLength = _maxGreen - _minGreen;
    final int blueLength = _maxBlue - _minBlue;
    if (redLength >= greenLength && redLength >= blueLength) {
      return _ColorComponent.red;
    } else if (greenLength >= redLength && greenLength >= blueLength) {
      return _ColorComponent.green;
    } else {
      return _ColorComponent.blue;
    }
  }

  // Finds where to split this box between _lowerIndex and _upperIndex.
  //
  // The split point is calculated by finding the longest color dimension, and
  // then sorting the sub-array based on that dimension value in each color.
  // The colors are then iterated over until a color is found with the
  // midpoint closest to the whole box's dimension midpoint.
  //
  // Returns the index of the split point in the colors array.
  int _findSplitPoint() {
    final _ColorComponent longestDimension = _getLongestColorDimension();
    int compareColors(Color a, Color b) {
      int makeValue(int first, int second, int third) {
        return first << 16 | second << 8 | third;
      }

      switch (longestDimension) {
        case _ColorComponent.red:
          final int aValue = makeValue(a.red, a.green, a.blue);
          final int bValue = makeValue(b.red, b.green, b.blue);
          return aValue.compareTo(bValue);
        case _ColorComponent.green:
          final int aValue = makeValue(a.green, a.red, a.blue);
          final int bValue = makeValue(b.green, b.red, b.blue);
          return aValue.compareTo(bValue);
        case _ColorComponent.blue:
          final int aValue = makeValue(a.blue, a.green, a.red);
          final int bValue = makeValue(b.blue, b.green, b.red);
          return aValue.compareTo(bValue);
      }
      return 0;
    }

    // We need to sort the colors in this box based on the longest color
    // dimension.
    final List<Color> colorSubset =
    colors.sublist(_lowerIndex, _upperIndex + 1);
    colorSubset.sort(compareColors);
    colors.replaceRange(_lowerIndex, _upperIndex + 1, colorSubset);
    final int median = (_population / 2).round();
    for (int i = 0, count = 0; i <= colorSubset.length; i++) {
      count += histogram[colorSubset[i]];
      if (count >= median) {
        // We never want to split on the upperIndex, as this will result in the
        // same box.
        return math.min(_upperIndex - 1, i + _lowerIndex);
      }
    }
    return _lowerIndex;
  }

  PaletteColor getAverageColor() {
    int redSum = 0;
    int greenSum = 0;
    int blueSum = 0;
    int totalPopulation = 0;
    for (int i = _lowerIndex; i <= _upperIndex; i++) {
      final Color color = colors[i];
      final int colorPopulation = histogram[color];
      totalPopulation += colorPopulation;
      redSum += colorPopulation * color.red;
      greenSum += colorPopulation * color.green;
      blueSum += colorPopulation * color.blue;
    }
    final int redMean = (redSum / totalPopulation).round();
    final int greenMean = (greenSum / totalPopulation).round();
    final int blueMean = (blueSum / totalPopulation).round();
    return PaletteColor(
      Color.fromARGB(0xff, redMean, greenMean, blueMean),
      totalPopulation,
    );
  }
}

class _ColorCutQuantizer {
  _ColorCutQuantizer(
      this.image, {
        this.maxColors = PaletteGenerator._defaultCalculateNumberColors,
        this.region,
        this.filters,
      })  : assert(image != null),
        assert(maxColors != null),
        assert(region == null || region != Rect.zero),
        _paletteColors = <PaletteColor>[];

  FutureOr<List<PaletteColor>> get quantizedColors async {
    if (_paletteColors.isNotEmpty) {
      return _paletteColors;
    } else {
      return _quantizeColors(image);
    }
  }

  final ui.Image image;
  final List<PaletteColor> _paletteColors;

  final int maxColors;
  final Rect region;
  final List<PaletteFilter> filters;

  Iterable<Color> _getImagePixels(ByteData pixels, int width, int height,
      {Rect region}) sync* {
    final int rowStride = width * 4;
    int rowStart;
    int rowEnd;
    int colStart;
    int colEnd;
    if (region != null) {
      rowStart = region.top.floor();
      rowEnd = region.bottom.floor();
      colStart = region.left.floor();
      colEnd = region.right.floor();
      assert(rowStart >= 0);
      assert(rowEnd <= height);
      assert(colStart >= 0);
      assert(colEnd <= width);
    } else {
      rowStart = 0;
      rowEnd = height;
      colStart = 0;
      colEnd = width;
    }
    int byteCount = 0;
    for (int row = rowStart; row < rowEnd; ++row) {
      for (int col = colStart; col < colEnd; ++col) {
        final int position = row * rowStride + col * 4;
        // Convert from RGBA to ARGB.
        final int pixel = pixels.getUint32(position);
        final Color result = Color((pixel << 24) | (pixel >> 8));
        byteCount += 4;
        yield result;
      }
    }
    assert(byteCount == ((rowEnd - rowStart) * (colEnd - colStart) * 4));
  }

  bool _shouldIgnoreColor(Color color) {
    final HSLColor hslColor = HSLColor.fromColor(color);
    if (filters != null && filters.isNotEmpty) {
      for (PaletteFilter filter in filters) {
        if (!filter(hslColor)) {
          return true;
        }
      }
    }
    return false;
  }

  Future<List<PaletteColor>> _quantizeColors(ui.Image image) async {
    const int quantizeWordWidth = 5;
    const int quantizeChannelWidth = 8;
    const int quantizeShift = quantizeChannelWidth - quantizeWordWidth;
    const int quantizeWordMask =
        ((1 << quantizeWordWidth) - 1) << quantizeShift;

    Color quantizeColor(Color color) {
      return Color.fromARGB(
        color.alpha,
        color.red & quantizeWordMask,
        color.green & quantizeWordMask,
        color.blue & quantizeWordMask,
      );
    }

    final ByteData imageData =
    await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final Iterable<Color> pixels =
    _getImagePixels(imageData, image.width, image.height, region: region);
    final Map<Color, int> hist = <Color, int>{};
    for (Color pixel in pixels) {
      final Color quantizedColor = quantizeColor(pixel);
      final Color colorKey = quantizedColor.withAlpha(0xff);
      if (quantizedColor.alpha != 0x0) {
        hist[colorKey] = (hist[colorKey] ?? 0) + 1;
      }
    }
    hist.removeWhere((Color color, int _) {
      return _shouldIgnoreColor(color);
    });
    if (hist.length <= maxColors) {
      _paletteColors.clear();
      for (Color color in hist.keys) {
        _paletteColors.add(PaletteColor(color, hist[color]));
      }
    } else {
      _paletteColors.clear();
      _paletteColors.addAll(_quantizePixels(maxColors, hist));
    }
    return _paletteColors;
  }

  List<PaletteColor> _quantizePixels(
      int maxColors,
      Map<Color, int> histogram,
      ) {
    int volumeComparator(_ColorVolumeBox a, _ColorVolumeBox b) {
      return b.getVolume().compareTo(a.getVolume());
    }

    final PriorityQueue<_ColorVolumeBox> priorityQueue =
    HeapPriorityQueue<_ColorVolumeBox>(volumeComparator);
    priorityQueue.add(_ColorVolumeBox(
        0, histogram.length - 1, histogram, histogram.keys.toList()));
    _splitBoxes(priorityQueue, maxColors);
    return _generateAverageColors(priorityQueue);
  }

  void _splitBoxes(PriorityQueue<_ColorVolumeBox> queue, final int maxSize) {
    while (queue.length < maxSize) {
      final _ColorVolumeBox colorVolumeBox = queue.removeFirst();
      if (colorVolumeBox != null && colorVolumeBox.canSplit()) {
        // First split the box, and offer the result
        queue.add(colorVolumeBox.splitBox());
        queue.add(colorVolumeBox);
      } else {
        return;
      }
    }
  }

  List<PaletteColor> _generateAverageColors(
      PriorityQueue<_ColorVolumeBox> colorVolumeBoxes) {
    final List<PaletteColor> colors = <PaletteColor>[];
    for (_ColorVolumeBox colorVolumeBox in colorVolumeBoxes.toList()) {
      final PaletteColor paletteColor = colorVolumeBox.getAverageColor();
      if (!_shouldIgnoreColor(paletteColor.color)) {
        colors.add(paletteColor);
      }
    }
    return colors;
  }
}
