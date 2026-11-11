import 'package:emoji_picker_flutter/emoji_picker_flutter.dart' as ep;
import 'package:flutter/material.dart';

/// ইমোজি বাছাইয়ের বটম শিট
Future<String?> pickEmoji(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      return SizedBox(
        height: MediaQuery.of(ctx).size.height * .55,
        child: ep.EmojiPicker(
          onEmojiSelected: (_, e) => Navigator.pop(ctx, e.emoji),
          config: ep.Config(
            height: null,
            checkPlatformCompatibility: true,
            emojiViewConfig: ep.EmojiViewConfig(
              backgroundColor: scheme.surface,
              columns: 8,
              emojiSizeMax: 30,
            ),
            categoryViewConfig: ep.CategoryViewConfig(
              backgroundColor: scheme.surface,
              indicatorColor: scheme.primary,
              iconColorSelected: scheme.primary,
            ),
            bottomActionBarConfig: const ep.BottomActionBarConfig(enabled: false),
            searchViewConfig: ep.SearchViewConfig(backgroundColor: scheme.surface),
          ),
        ),
      );
    },
  );
}
