import 'dart:math';

String generateRandomCode(int length) {
  const String chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  Random rnd = Random();
  return String.fromCharCodes(Iterable.generate(
    length,
    (_) => chars.codeUnitAt(rnd.nextInt(chars.length)),
  ));
}
