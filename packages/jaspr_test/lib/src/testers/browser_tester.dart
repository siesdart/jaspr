import 'dart:async';
import 'dart:html' as html;

import 'package:jaspr/browser.dart';
import 'package:meta/meta.dart';
import 'package:test/test.dart';

import '../binding.dart';
import '../finders.dart';

@isTest
void testBrowser(
  String description,
  FutureOr<void> Function(BrowserTester tester) callback, {
  String location = '/',
  bool? skip,
  Timeout? timeout,
  dynamic tags,
}) {
  test(
    description,
    () async {
      if (html.window.location.pathname != location) {
        html.window.history.replaceState(null, 'Test', location);
      }

      var binding = BrowserAppBinding();
      var tester = BrowserTester._(binding);

      return binding.runTest(() async {
        await callback(tester);
      });
    },
    skip: skip,
    timeout: timeout,
    tags: tags,
  );
}

/// Tests any jaspr app in a headless browser environment.
class BrowserTester {
  BrowserTester._(this.binding);

  final BrowserAppBinding binding;

  Future<void> pumpComponent(Component component, {String attachTo = 'body'}) {
    return binding.attachRootComponent(component, attachTo: attachTo);
  }

  Future<void> click(Finder finder, {bool pump = true}) async {
    dispatchEvent(finder, 'click', null);
    if (pump) {
      await pumpEventQueue();
    }
  }

  void dispatchEvent(Finder finder, String event, dynamic data) {
    var element = _findDomElement(finder);

    var source = (element.renderObject as DomRenderObject).node;
    if (source is html.Element) {
      source.dispatchEvent(html.MouseEvent('click'));
    }
  }

  DomElement _findDomElement(Finder finder) {
    var elements = finder.evaluate();

    if (elements.isEmpty) {
      throw 'The finder "$finder" could not find any matching components.';
    }
    if (elements.length > 1) {
      throw 'The finder "$finder" ambiguously found multiple matching components.';
    }

    var element = elements.single;

    if (element is DomElement) {
      return element;
    }

    DomElement? foundElement;

    void findFirstDomElement(Element e) {
      if (e is DomElement) {
        foundElement = e;
        return;
      }
      e.visitChildren(findFirstDomElement);
    }

    findFirstDomElement(element);

    if (foundElement == null) {
      throw 'The finder "$finder" could not find a dom element.';
    }

    return foundElement!;
  }
}
