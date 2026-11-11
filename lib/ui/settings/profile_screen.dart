import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../providers.dart';
import '../widgets/common.dart';

/// প্রোফাইলের ঘর — সেটিংস টেবিলে `profile_*` কী হিসেবে থাকে
class ProfileFields {
  static const name = 'profile_name';
  static const phone = 'profile_phone';
  static const email = 'profile_email';
  static const address = 'profile_address';
  static const occupation = 'profile_occupation';
  static const photo = 'profile_photo';
}

/// গোল প্রোফাইল ছবি; ছবি না থাকলে নামের প্রথম অক্ষর
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.photo, required this.name, this.radius = 28});
  final String? photo;
  final String? name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final file = photo == null ? null : File(photo!);
    final has = file != null && file.existsSync();
    final initial = (name ?? '').trim().isEmpty
        ? null
        : name!.trim().characters.first.toUpperCase();
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.brand.withValues(alpha: .12),
      backgroundImage: has ? FileImage(file) : null,
      child: has
          ? null
          : (initial == null
                ? Icon(Icons.person, size: radius, color: AppColors.brand)
                : Text(
                    initial,
                    style: TextStyle(
                      fontSize: radius * .8,
                      fontWeight: FontWeight.w800,
                      color: AppColors.brand,
                    ),
                  )),
    );
  }
}

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late final Map<String, TextEditingController> _c;
  String? _photo;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    final raw = ref.read(appSettingsProvider).raw;
    _c = {
      for (final k in [
        ProfileFields.name,
        ProfileFields.phone,
        ProfileFields.email,
        ProfileFields.address,
        ProfileFields.occupation,
      ])
        k: TextEditingController(text: raw[k] ?? '')..addListener(() => _dirty = true),
    };
    _photo = raw[ProfileFields.photo];
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pick(ImageSource src) async {
    try {
      final x = await ImagePicker().pickImage(source: src, maxWidth: 800, imageQuality: 85);
      if (x == null) return;
      final dir = Directory(p.join((await getApplicationDocumentsDirectory()).path, 'profile'));
      await dir.create(recursive: true);
      // নতুন নাম দিলে পুরনো ছবি ক্যাশে আটকে থাকে না
      final dest = p.join(dir.path, 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await File(x.path).copy(dest);
      setState(() {
        _photo = dest;
        _dirty = true;
      });
    } catch (_) {
      if (mounted) toast(context, tr('ছবি নেওয়া যায়নি', 'Could not get the photo'));
    }
  }

  Future<void> _photoMenu() async {
    final v = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(tr('ক্যামেরা দিয়ে তুলুন', 'Take a photo')),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(tr('গ্যালারি থেকে বাছুন', 'Choose from gallery')),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            if (_photo != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.expense),
                title: Text(tr('ছবি সরান', 'Remove photo')),
                onTap: () => Navigator.pop(ctx, 'remove'),
              ),
          ],
        ),
      ),
    );
    if (v == 'camera') await _pick(ImageSource.camera);
    if (v == 'gallery') await _pick(ImageSource.gallery);
    if (v == 'remove') {
      setState(() {
        _photo = null;
        _dirty = true;
      });
    }
  }

  Future<void> _save() async {
    final email = _c[ProfileFields.email]!.text.trim();
    if (email.isNotEmpty && !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      toast(context, tr('ইমেইল ঠিক নেই', 'Email looks invalid'));
      return;
    }
    final repo = ref.read(repoProvider);
    for (final e in _c.entries) {
      final v = e.value.text.trim();
      v.isEmpty ? await repo.removeSetting(e.key) : await repo.setSetting(e.key, v);
    }
    _photo == null
        ? await repo.removeSetting(ProfileFields.photo)
        : await repo.setSetting(ProfileFields.photo, _photo!);
    _dirty = false;
    if (!mounted) return;
    toast(context, tr('প্রোফাইল সেভ হয়েছে ✓', 'Profile saved ✓'));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    Widget field(String key, IconData icon, String label, {TextInputType? type, int lines = 1}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            controller: _c[key],
            keyboardType: type,
            maxLines: lines,
            textCapitalization: type == null ? TextCapitalization.words : TextCapitalization.none,
            decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
          ),
        );

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await confirm(
          context,
          tr('সেভ না করে বের হবেন?', 'Leave without saving?'),
          ok: tr('বের হন', 'Leave'),
        );
        if (leave && context.mounted) {
          _dirty = false;
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text(tr('প্রোফাইল', 'Profile'))),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Center(
              child: GestureDetector(
                onTap: _photoMenu,
                child: Stack(
                  children: [
                    ValueListenableBuilder(
                      valueListenable: _c[ProfileFields.name]!,
                      builder: (context, v, _) =>
                          ProfileAvatar(photo: _photo, name: v.text, radius: 56),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        child: Icon(
                          Icons.photo_camera,
                          size: 18,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: _photoMenu,
                child: Text(
                  _photo == null
                      ? tr('ছবি যোগ করুন', 'Add photo')
                      : tr('ছবি বদলান', 'Change photo'),
                ),
              ),
            ),
            const SizedBox(height: 12),
            field(ProfileFields.name, Icons.person_outline, tr('নাম', 'Name')),
            field(
              ProfileFields.phone,
              Icons.phone_outlined,
              tr('মোবাইল নম্বর', 'Mobile number'),
              type: TextInputType.phone,
            ),
            field(
              ProfileFields.email,
              Icons.email_outlined,
              tr('ইমেইল', 'Email'),
              type: TextInputType.emailAddress,
            ),
            field(
              ProfileFields.occupation,
              Icons.work_outline,
              tr('পেশা / প্রতিষ্ঠান', 'Occupation / organisation'),
            ),
            field(ProfileFields.address, Icons.home_outlined, tr('ঠিকানা', 'Address'), lines: 2),
            const SizedBox(height: 4),
            Text(
              tr(
                'এই তথ্য শুধু আপনার ফোনেই থাকে — কোথাও পাঠানো হয় না।',
                'This information stays on your phone only — it is never sent anywhere.',
              ),
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: Text(tr('সেভ', 'Save')),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            ),
          ],
        ),
      ),
    );
  }
}
