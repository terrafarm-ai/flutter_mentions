part of flutter_mentions;

/// A custom implementation of [TextEditingController] to support @ mention or other
/// trigger based mentions.
class AnnotationEditingController extends TextEditingController {
  Map<String, Annotation> _mapping;
  String? _pattern;
  List<String>? invalidList;

  // Generate the Regex pattern for matching all the suggestions in one.
  AnnotationEditingController(this._mapping)
      : _pattern = _mapping.keys.isNotEmpty
            ? "(${_mapping.keys.map((key) => RegExp.escape(key)).join('|')})"
            : null;

  /// Can be used to get the markup from the controller directly.
  String get markupText {
    final someVal = _mapping.isEmpty
        ? text
        : text.splitMapJoin(
            RegExp('$_pattern'),
            onMatch: (Match match) {
              final mention = _mapping[match[0]!] ??
                  _mapping[_mapping.keys.firstWhere((element) {
                    final reg = RegExp(element);

                    return reg.hasMatch(match[0]!);
                  })]!;

              // Default markup format for mentions
              if (!mention.disableMarkup) {
                return mention.markupBuilder != null
                    ? mention.markupBuilder!(
                        mention.trigger, mention.id!, mention.display!)
                    : '${mention.trigger}[__${mention.id}__](__${mention.display}__)';
              } else {
                return match[0]!;
              }
            },
            onNonMatch: (String text) {
              return text;
            },
          );

    return someVal;
  }

  Map<String, Annotation> get mapping {
    return _mapping;
  }

  set mapping(Map<String, Annotation> _mapping) {
    this._mapping = _mapping;

    var sortedKeys = _mapping.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length)); // 긴 것부터 정렬

    _pattern = "(${sortedKeys.map((key) => RegExp.escape(key)).join('|')})";
  }

  void setInvalidList(List<String> list) {
    invalidList = list;
  }

  @override
  TextSpan buildTextSpan({BuildContext? context, TextStyle? style, bool? withComposing}) {
    var children = <InlineSpan>[];

    final mentionPattern = RegExp(r'@([\uE000-\uF8FF])');

    text.splitMapJoin(
      mentionPattern,
      onMatch: (Match match) {
        final extractedId = match.group(1)!.codeUnitAt(0) - 0xE000;
        final mention = _mapping.values.firstWhere((element) => element.id == '${extractedId}');
        if (mention.displayBuilder != null) {
          return mention.displayBuilder!(children, style!, mention);
        }
        return '';
      },
      onNonMatch: (String text) {
        var remainingText = text;

        while (remainingText.isNotEmpty) {
          String? firstInvalid;
          var firstInvalidIndex = remainingText.length;

          for (var invalid in invalidList ?? []) {
            var index = remainingText.indexOf(invalid);
            if (index != -1 && index < firstInvalidIndex) {
              firstInvalid = invalid;
              firstInvalidIndex = index;
            }
          }

          if (firstInvalid == null) {
            children.add(TextSpan(text: remainingText, style: style));
            break;
          }

          if (firstInvalidIndex > 0) {
            children.add(TextSpan(text: remainingText.substring(0, firstInvalidIndex), style: style));
          }

          children.add(TextSpan(text: firstInvalid, style: style?.copyWith(color: Colors.red)));

          remainingText = remainingText.substring(firstInvalidIndex + firstInvalid.length);
        }

        return '';
      },

    );

    return TextSpan(style: style, children: children);
  }
}
