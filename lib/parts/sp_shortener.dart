import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;

class ComponentShortener {
  Map<String, String> dictionary = {};
  final String path = "assets/statuspage";
  final String url = "https://raw.githubusercontent.com/Puzzaks/PTK/main";

  Future<void> setup({Future<void> Function(String, String, String)? log}) async {
    final box = Hive.box('app_storage');
    
    // 1. Load Cache or Fallback Asset
    String? cachedDict = box.get("cached_sp_dictionary");
    if (cachedDict != null) {
      try {
        Map<String, dynamic> decoded = jsonDecode(cachedDict);
        dictionary = decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
      } catch (e) {
        if (kDebugMode) print("Failed to parse cached component dictionary: $e");
      }
    } else {
      try {
        String assetDict = await rootBundle.loadString('$path/component_dictionary.json');
        Map<String, dynamic> decoded = jsonDecode(assetDict);
        dictionary = decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
      } catch (e) {
        if (kDebugMode) print("Failed to load local component dictionary: $e");
      }
    }
    
    // 2. Network Check & Cache Refresh
    if (!kDebugMode && url != "") {
      try {
        if (log != null) await log("sp_shortener", "info", "Fetching component dictionary from GitHub");
        final response = await http.get(Uri.parse("$url/$path/component_dictionary.json"));
        if (response.statusCode == 200) {
          if (log != null) await log("sp_shortener", "info", "Component dictionary fetched successfully");
          Map<String, dynamic> decoded = jsonDecode(response.body);
          dictionary = decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
          box.put("cached_sp_dictionary", response.body); // Update persistent cache
        } else {
          if (log != null) await log("sp_shortener", "warning", "Failed to download component dictionary: ${response.statusCode}");
        }
      } catch (e) {
        if (kDebugMode) print("Falling back to strictly offline Component Dictionary! Error: $e");
        if (log != null) await log("sp_shortener", "error", "Network error during sp_shortener setup: $e");
      }
    }
  }

  String format(String text) {
    if (text.isEmpty) return text;
    
    String formatted = text;
    // Iterate over dictionary and replace (case-insensitive)
    dictionary.forEach((key, value) {
      formatted = formatted.replaceAll(RegExp(key, caseSensitive: false), value);
    });

    return truncate(formatted);
  }

  String truncate(String text) {
    if (text.length > 18) {
      return '${text.substring(0, 15)}...';
    }
    return text;
  }
}
