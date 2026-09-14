import 'dart:io';

bool get supportsSecureCredentials => Platform.isAndroid || Platform.isIOS;
