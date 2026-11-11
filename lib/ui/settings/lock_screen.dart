import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/money.dart';
import '../widgets/logo.dart';

String hashPin(String pin) => sha256.convert(utf8.encode('takar-khata:$pin')).toString();

Future<bool> biometricAvailable() async {
  try {
    final auth = LocalAuthentication();
    return await auth.canCheckBiometrics || await auth.isDeviceSupported();
  } catch (_) {
    return false;
  }
}

Future<bool> authenticateBiometric() async {
  try {
    return await LocalAuthentication().authenticate(
      localizedReason: 'টাকার খাতা খুলতে আঙুলের ছাপ দিন',
      biometricOnly: false,
      persistAcrossBackgrounding: true,
    );
  } catch (_) {
    return false;
  }
}

/// PIN বা ফিঙ্গারপ্রিন্ট দিয়ে লক
class LockScreen extends StatefulWidget {
  const LockScreen({super.key, required this.pinHash, required this.biometric, required this.onUnlock});
  final String pinHash;
  final bool biometric;
  final VoidCallback onUnlock;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String _pin = '';
  bool _error = false;

  @override
  void initState() {
    super.initState();
    if (widget.biometric) WidgetsBinding.instance.addPostFrameCallback((_) => _bio());
  }

  Future<void> _bio() async {
    if (await authenticateBiometric()) widget.onUnlock();
  }

  void _key(String k) {
    HapticFeedback.selectionClick();
    setState(() {
      _error = false;
      if (k == '⌫') {
        if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
      } else if (_pin.length < 6) {
        _pin += k;
      }
    });
    if (_pin.length >= 4 && hashPin(_pin) == widget.pinHash) {
      widget.onUnlock();
    } else if (_pin.length == 6) {
      HapticFeedback.heavyImpact();
      setState(() {
        _error = true;
        _pin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: PinPad(
          title: 'PIN দিন',
          pin: _pin,
          error: _error ? 'ভুল PIN' : null,
          onKey: _key,
          extra: widget.biometric
              ? IconButton(iconSize: 32, onPressed: _bio, icon: const Icon(Icons.fingerprint))
              : null,
        ),
      ),
    );
  }
}

class PinPad extends StatelessWidget {
  const PinPad({super.key, required this.title, required this.pin, required this.onKey, this.error, this.extra});
  final String title;
  final String pin;
  final ValueChanged<String> onKey;
  final String? error;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget key(String k) => Expanded(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: AspectRatio(
          aspectRatio: 1.6,
          child: k.isEmpty
              ? (k == '' && extra != null ? Center(child: extra) : const SizedBox())
              : Material(
                  color: scheme.surfaceContainerHighest.withValues(alpha: .6),
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => onKey(k),
                    child: Center(
                      child: k == '⌫'
                          ? const Icon(Icons.backspace_outlined)
                          : Text(dg(k), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
        ),
      ),
    );
    return Column(
      children: [
        const Spacer(),
        const AppLogo(size: 72),
        const SizedBox(height: 16),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < 6; i++)
              Container(
                margin: const EdgeInsets.all(6),
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < pin.length ? scheme.primary : Colors.transparent,
                  border: Border.all(color: i < 4 || i < pin.length ? scheme.primary : scheme.outlineVariant),
                ),
              ),
          ],
        ),
        SizedBox(
          height: 24,
          child: error == null ? null : Text(error!, style: TextStyle(color: scheme.error)),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              Row(children: [key('1'), key('2'), key('3')]),
              Row(children: [key('4'), key('5'), key('6')]),
              Row(children: [key('7'), key('8'), key('9')]),
              Row(children: [key(''), key('0'), key('⌫')]),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

/// নতুন PIN সেট (দুবার লিখে নিশ্চিত)
class SetPinScreen extends StatefulWidget {
  const SetPinScreen({super.key});
  @override
  State<SetPinScreen> createState() => _SetPinScreenState();
}

class _SetPinScreenState extends State<SetPinScreen> {
  String _pin = '';
  String? _first;
  String? _error;

  void _key(String k) {
    setState(() {
      _error = null;
      if (k == '⌫') {
        if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
        return;
      }
      if (_pin.length < 6) _pin += k;
    });
  }

  void _next() {
    if (_pin.length < 4) {
      setState(() => _error = 'অন্তত ৪ সংখ্যা');
      return;
    }
    if (_first == null) {
      setState(() {
        _first = _pin;
        _pin = '';
      });
    } else if (_first == _pin) {
      Navigator.pop(context, hashPin(_pin));
    } else {
      setState(() {
        _first = null;
        _pin = '';
        _error = 'মেলেনি — আবার লিখুন';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('অ্যাপ লক')),
      body: Column(
        children: [
          Expanded(
            child: PinPad(
              title: _first == null ? 'নতুন PIN লিখুন (৪–৬ সংখ্যা)' : 'আবার লিখে নিশ্চিত করুন',
              pin: _pin,
              error: _error,
              onKey: _key,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: FilledButton(
              onPressed: _next,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              child: Text(_first == null ? 'পরের ধাপ' : 'সেট করুন'),
            ),
          ),
        ],
      ),
    );
  }
}
