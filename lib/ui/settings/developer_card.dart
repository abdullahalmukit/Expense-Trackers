import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/developer.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../widgets/common.dart';

/// সেটিংসের নিচে ডেভেলপারের পরিচয় ও যোগাযোগ
class DeveloperCard extends StatelessWidget {
  const DeveloperCard({super.key});

  Future<void> _open(BuildContext context, String url) async {
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    ).catchError((_) => false);
    if (!ok && context.mounted) {
      // খোলা না গেলে অন্তত লিংক কপি
      await Clipboard.setData(
        ClipboardData(text: url.replaceFirst('mailto:', '').split('?').first),
      );
      if (context.mounted) toast(context, tr('লিংক কপি করা হয়েছে', 'Link copied'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget link(IconData icon, Color color, String title, String sub, String url) => ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: color.withValues(alpha: .14),
        child: Icon(icon, size: 19, color: color),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Icon(Icons.open_in_new, size: 18, color: scheme.outline),
      onTap: () => _open(context, url),
      onLongPress: () async {
        await Clipboard.setData(ClipboardData(text: sub));
        if (context.mounted) toast(context, tr('কপি করা হয়েছে', 'Copied'));
      },
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [AppColors.brand, AppColors.brandAccent]),
                ),
                child: const CircleAvatar(radius: 48, backgroundImage: AssetImage(Developer.photo)),
              ),
              const SizedBox(height: 10),
              const Text(
                Developer.name,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              Text(
                tr('ডেভেলপার · টাকার খাতা', 'Developer · Takar Khata'),
                style: TextStyle(color: scheme.outline),
              ),
              const SizedBox(height: 8),
              link(
                Icons.email_outlined,
                AppColors.expense,
                tr('ইমেইল — যেকোনো প্রশ্ন বা যোগাযোগে', 'Email — for any query or contact'),
                Developer.email,
                'mailto:${Developer.email}?subject=${Uri.encodeComponent('টাকার খাতা / Takar Khata')}',
              ),
              link(
                Icons.language,
                AppColors.income,
                tr('ওয়েবসাইট', 'Website'),
                'mukit.swe.bd',
                Developer.website,
              ),
              link(
                Icons.code,
                const Color(0xFF24292F),
                'GitHub',
                'github.com/abdullahalmukit',
                Developer.github,
              ),
              link(
                Icons.work_outline,
                const Color(0xFF0A66C2),
                'LinkedIn',
                'linkedin.com/in/abdullah-al-mukit-12-12-2003-',
                Developer.linkedin,
              ),
              link(
                Icons.facebook,
                const Color(0xFF1877F2),
                'Facebook',
                'facebook.com/abdulla.almukit.79',
                Developer.facebook,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
