import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

Widget footer() {
  return Container(
    width: double.infinity,
    color: const Color(0xFF2D2D2D), // Dark gray color
    child: SizedBox(
      height: 180, // Set the height as per your requirement
      child: InkWell(
        onTap: () async {
          const url = 'https://www.buymeacoffee.com/alairock';
          final Uri uri = Uri.parse(url);
          if (!await launchUrl(uri)) {
            throw Exception('Could not launch $uri');
          }
        },
        child: Center(
          child: Column(children: [
            ClipRect(
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor:
                    0.7, // This will clip the bottom half of the image
                child: SizedBox(
                  width: 300, // Set the image width
                  height: 160, // Set the image height
                  child: Image.network(
                    'https://media2.giphy.com/media/513lZvPf6khjIQFibF/giphy.gif',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            const SizedBox(
                height: 40,
                width: 700,
                child: Center(
                    child: Text(
                        "You like this FREE app? Consider buying me a coffee!",
                        style: TextStyle(
                            color: Color.fromARGB(255, 177, 177, 177))))),
          ]),
        ),
      ),
    ),
  );
}
