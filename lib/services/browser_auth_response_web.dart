import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

bool submitForm(String uri, Map<String, String> fields) {
  final form = web.HTMLFormElement()
    ..method = 'post'
    ..action = uri;
  for (final entry in fields.entries) {
    form.append(
      web.HTMLInputElement()
        ..type = 'hidden'
        ..name = entry.key
        ..value = entry.value,
    );
  }
  web.window.document.body?.append(form);
  form.submit();
  return true;
}

bool replaceDocument(String html) {
  final document = web.window.document;
  document.callMethod<JSAny?>('open'.toJS);
  document.callMethod<JSAny?>('write'.toJS, html.toJS);
  document.callMethod<JSAny?>('close'.toJS);
  return true;
}
