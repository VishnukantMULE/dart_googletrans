import 'dart:math';
import 'package:http/http.dart' as http;

class GoogleTranslateToken {
  String tkk = '0';
  final String host;
  static const Map<String, String> headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.5',
  };

  GoogleTranslateToken({this.host = 'translate.google.com'});

  int applyTransform(int a, String b) {
    int sizeB;
    sizeB = b.length;

    int c;
    c = 0;

    while (c < sizeB - 2) {
      String d;
      d = b[c + 2];

      int dVal;
      dVal = d.codeUnitAt(0);

      if (dVal >= 'a'.codeUnitAt(0)) {
        dVal = dVal - 87;
      } else {
        dVal = int.parse(d);
      }

      if (b[c + 1] == '+') {
        dVal = (a >> dVal) & 0xFFFFFFFF;
      } else {
        dVal = (a << dVal) & 0xFFFFFFFF;
      }

      if (b[c] == '+') {
        a = (a + dVal) & 0xFFFFFFFF;
      } else {
        a = a ^ dVal;
      }

      c = c + 3;
    }

    return a;
  }

  List<int> convertToUtf16(String text) {
    List<int> a = [];
    for (int i = 0; i < text.length; i++) {
      int val = text.codeUnitAt(i);
      if (val < 0x10000) {
        a.add(val);
      } else {
        a.add(((val - 0x10000) ~/ 0x400 + 0xD800));
        a.add(((val - 0x10000) % 0x400 + 0xDC00));
      }
    }
    return a;
  }

  String generateTokenInternal(String text) {
    List<int> a = convertToUtf16(text);
    String b = tkk != '0' ? tkk : '';
    List<String> d = b.split('.');
    int bVal = d.length > 1 ? int.parse(d[0]) : 0;

    List<int> e = [];
    int g = 0;

    while (g < a.length) {
      int l = a[g];

      if (l < 128) {
        e.add(l);
      } else {
        if (l < 2048) {
          if ((l >> 6) != 0) {
            e.add((l >> 6) | 192);
          } else {
            e.add((l >> 6) | 192);
          }
        } else {
          if ((l & 64512) == 55296) {
            if (g + 1 < a.length) {
              if ((a[g + 1] & 64512) == 56320) {
                g++;
                l = 65536 + ((l & 1023) << 10) + (a[g] & 1023);
                if ((l >> 18) != 0) {
                  e.add((l >> 18) | 240);
                } else {
                  e.add((l >> 18) | 240);
                }
                if (((l >> 12) & 63) != 0) {
                  e.add(((l >> 12) & 63) | 128);
                } else {
                  e.add(((l >> 12) & 63) | 128);
                }
              } else {
                e.add((l >> 12) | 224);
                e.add(((l >> 6) & 63) | 128);
              }
            } else {
              e.add((l >> 12) | 224);
              e.add(((l >> 6) & 63) | 128);
            }
          } else {
            if ((l & 63) != 0) {
              e.add((l >> 12) | 224);
            } else {
              e.add((l >> 12) | 224);
            }
            if (((l >> 6) & 63) != 0) {
              e.add(((l >> 6) & 63) | 128);
            } else {
              e.add(((l >> 6) & 63) | 128);
            }
            if ((l & 63) != 0) {
              e.add((l & 63) | 128);
            } else {
              e.add((l & 63) | 128);
            }
          }
        }
      }
      g++;
    }

    int aVal = bVal;
    for (int value in e) {
      aVal = (aVal + value) & 0xFFFFFFFF;
      aVal = applyTransform(aVal, "+-a^+6");
    }

    aVal = applyTransform(aVal, "+-3^+b+-f");

    if (d.length > 1) {
      aVal ^= int.parse(d[1]);
    }

    if (aVal < 0) {
      aVal = (aVal & 2147483647) + 2147483648;
    }
    aVal %= 1000000;

    return "$aVal.${aVal ^ bVal}";
  }

  Future<void> fetchTkk() async {
    try {
      final url = 'https://${host.replaceAll(RegExp(r'^https?://'), '')}';

      final client = http.Client();
      final request = http.Request('GET', Uri.parse(url))..headers.addAll(headers);

      final streamedResponse = await client.send(request);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final patterns = [
          RegExp(r"tkk:\s*'(.+?)'"),
          RegExp(r"tkk=\s*'(.+?)'"),
          RegExp(r'"tkk":"(.+?)"'),
          RegExp(r"tkk=\s*'(\d+\.\d+)'"),
        ];

        String? extractedTkk;
        for (var pattern in patterns) {
          final match = pattern.firstMatch(response.body);
          if (match != null) {
            extractedTkk = match.group(1);
            break;
          }
        }

        if (extractedTkk != null) {
          tkk = extractedTkk;
        } else {
          final now = (DateTime.now().millisecondsSinceEpoch ~/ 3600000).toString();
          tkk = '$now.${Random().nextInt(999999)}';
        }
      } else {
        throw Exception('Failed to load page: ${response.statusCode}');
      }

      client.close();
    } catch (e) {
      final now = (DateTime.now().millisecondsSinceEpoch ~/ 3600000).toString();
      tkk = '$now.${Random().nextInt(999999)}';
    }
  }

  Future<String> getTranslationToken(String text) async {
    if (tkk == '0') {
      await fetchTkk();
    }
    return generateTokenInternal(text);
  }
}
