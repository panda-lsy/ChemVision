import 'dart:convert';

import 'package:flutter/widgets.dart';

import 'avatar_image_provider_stub.dart'
    if (dart.library.io) 'avatar_image_provider_io.dart'
    as platform;

/// Resolves avatar data URLs, remote URLs, and legacy local file paths.
ImageProvider<Object>? avatarImageProvider(String? source) {
  final value = source?.trim();
  if (value == null || value.isEmpty) return null;

  if (value.startsWith('data:image/')) {
    final separator = value.indexOf(',');
    if (separator < 0) return null;
    try {
      return MemoryImage(base64Decode(value.substring(separator + 1)));
    } on FormatException {
      return null;
    }
  }

  final uri = Uri.tryParse(value);
  if (uri != null &&
      (uri.scheme == 'http' || uri.scheme == 'https' || uri.scheme == 'blob')) {
    return NetworkImage(value);
  }

  return platform.localAvatarImageProvider(value);
}
