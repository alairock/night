import 'dart:async';
import 'package:flutter/material.dart';

Future<bool> renderBackButtonModal(BuildContext context) async {
  final bool? shouldPop = await showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Confirm'),
      content: const Text('Do you really want to leave the lobby?'),
      backgroundColor: const Color(0XFFDE6E46),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('No'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Yes'),
        ),
      ],
    ),
  );

  // TODO: Remove user from lobby

  return shouldPop ?? false;
}
