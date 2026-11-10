import 'package:flutter/material.dart';

class NovagramLogo extends StatelessWidget {
  const NovagramLogo({this.size = 42, this.showWordmark = false, super.key});
  final double size;
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    final mark = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF050505),
        borderRadius: BorderRadius.circular(size * .29),
        border: Border.all(color: Colors.white.withValues(alpha: .13)),
        boxShadow: [BoxShadow(color: const Color(0xFF8B7CFF).withValues(alpha: .20), blurRadius: size * .35)],
      ),
      child: Text('Н', style: TextStyle(color: Colors.white, fontSize: size * .59, height: 1, fontWeight: FontWeight.w900, letterSpacing: -2)),
    );
    if (!showWordmark) return mark;
    return Row(mainAxisSize: MainAxisSize.min, children: [mark, const SizedBox(width: 11), const Text('Novagram', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, letterSpacing: -.6))]);
  }
}
