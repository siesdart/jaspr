import 'dart:html' as html;

import '../../../browser.dart';

abstract class Document implements Component {
  const factory Document.html({
    Map<String, String>? attributes,
    Key? key,
  }) = AttachDocument.html;

  const factory Document.head({
    String? title,
    Map<String, String>? meta,
    List<Component>? children,
    Key? key,
  }) = HeadDocument;

  const factory Document.body({
    Map<String, String>? attributes,
    Key? key,
  }) = AttachDocument.body;
}

class HeadDocument extends StatelessComponent implements Document {
  const HeadDocument({this.title, this.meta, this.children, super.key});

  final String? title;
  final Map<String, String>? meta;
  final List<Component>? children;

  @override
  Iterable<Component> build(BuildContext context) sync* {
    yield AttachDocument(
      target: AttachTarget.head,
      attributes: null,
      children: [
        if (title != null) DomComponent(tag: 'title', child: Text(title!)),
        if (meta != null)
          for (var e in meta!.entries) DomComponent(tag: 'meta', attributes: {'name': e.key, 'content': e.value}),
        ...?children,
      ],
    );
  }
}

enum AttachTarget {
  html(true, false),
  body(true, false),
  head(false, true);

  const AttachTarget(this.attachAttributes, this.attachChildren);
  final bool attachAttributes;
  final bool attachChildren;
}

class AttachDocument extends ProxyComponent implements Document {
  const AttachDocument.html({this.attributes, super.key}) : target = AttachTarget.html;
  const AttachDocument.body({this.attributes, super.key}) : target = AttachTarget.body;
  const AttachDocument({required this.target, this.attributes, super.children});

  final AttachTarget target;
  final Map<String, String>? attributes;

  @override
  ProxyElement createElement() => _AttachElement(this);
}

class _AttachElement extends ProxyRenderObjectElement {
  _AttachElement(AttachDocument super.component);

  @override
  RenderObject createRenderObject() {
    var AttachDocument(:target) = component as AttachDocument;
    return AttachRenderObject(target, depth);
  }

  @override
  void updateRenderObject() {
    var AttachDocument(:target, :attributes) = component as AttachDocument;
    (renderObject as AttachRenderObject)
      ..target = target
      ..attributes = attributes;
  }

  @override
  void activate() {
    super.activate();
    (renderObject as AttachRenderObject).depth = depth;
  }

  @override
  void detachRenderObject() {
    super.detachRenderObject();
    final renderObject = this.renderObject as AttachRenderObject;
    AttachAdapter.instanceFor(renderObject._target).unregister(renderObject);
  }
}

class AttachRenderObject extends DomRenderObject {
  AttachRenderObject(this._target, this._depth) {
    node = html.Text('');
    AttachAdapter.instanceFor(_target).register(this);
  }

  final List<html.Node> children = [];

  AttachTarget _target;
  set target(AttachTarget target) {
    if (_target == target) return;
    AttachAdapter.instanceFor(_target).unregister(this);
    _target = target;
    AttachAdapter.instanceFor(_target).register(this);
    AttachAdapter.instanceFor(_target).update();
  }

  Map<String, String>? _attributes;
  set attributes(Map<String, String>? attrs) {
    if (_attributes == attrs) return;
    _attributes = attrs;
    AttachAdapter.instanceFor(_target).update();
  }

  int _depth;
  int get depth => _depth;
  set depth(int depth) {
    if (_depth == depth) return;
    _depth = depth;
    AttachAdapter.instanceFor(_target).update(needsResorting: true);
  }

  @override
  void attach(DomRenderObject child, {DomRenderObject? after}) {
    try {
      var childNode = child.node;
      if (childNode == null) return;

      var afterNode = after?.node;
      if (afterNode == null && children.contains(childNode)) {
        // Keep child in current place.
        return;
      }

      if (afterNode != null && !children.contains(afterNode)) {
        afterNode = null;
      }

      children.remove(childNode);
      children.insert(afterNode != null ? children.indexOf(afterNode) + 1 : 0, childNode);
      AttachAdapter.instanceFor(_target).update();
    } finally {
      child.finalize();
    }
  }

  @override
  void remove(DomRenderObject child) {
    super.remove(child);
    children.remove(child.node);
    AttachAdapter.instanceFor(_target).update();
  }
}

class AttachAdapter {
  AttachAdapter(this.target);

  static AttachAdapter instanceFor(AttachTarget target) {
    return _instances[target] ??= AttachAdapter(target);
  }

  static final Map<AttachTarget, AttachAdapter> _instances = {};

  final AttachTarget target;

  late final html.Element element = html.querySelector(target.name)!;

  late final Map<String, String> initialAttributes = {...element.attributes};

  late final (html.Node, html.Node) attachWindow = () {
    var iterator = html.NodeIterator(element, html.NodeFilter.SHOW_COMMENT);

    html.Node? start, end;

    html.Comment? currNode;
    while ((currNode = iterator.nextNode() as html.Comment?) != null) {
      var value = currNode!.nodeValue ?? '';
      if (value == r'$') {
        start = currNode;
      } else if (value == '/') {
        end = currNode;
      }
    }

    if (start == null) {
      start = html.Comment(r'$');
      element.insertBefore(start, end);
    }
    if (end == null) {
      end = html.Comment('/');
      element.insertBefore(end, start.nextNode);
    }
    return (start, end);
  }();

  Iterable<html.Node> get liveNodes sync* {
    html.Node? curr = attachWindow.$1.nextNode;
    while (curr != null && curr != attachWindow.$2) {
      yield curr;
      curr = curr.nextNode;
    }
  }

  late final Map<String, html.Node> initialKeyedNodes = {
    for (var node in liveNodes)
      if (keyFor(node) case String key) key: node,
  };

  String? keyFor(html.Node node) {
    return switch (node) {
      html.Element(id: String id) when id.isNotEmpty => id,
      html.Element(tagName: "TITLE" || "BASE") => '__${node.tagName}',
      html.Element(tagName: "META", attributes: {'name': String name}) => '__meta:$name',
      _ => null,
    };
  }

  final List<AttachRenderObject> _renderObjects = [];
  List<AttachRenderObject> get renderObjects => _renderObjects;
  bool _needsResorting = true;

  void update({bool needsResorting = false}) {
    if (needsResorting || _needsResorting) {
      _renderObjects.sort((a, b) => a.depth - b.depth);
      _needsResorting = false;
    }

    if (target.attachAttributes) {
      Map<String, String> attributes = initialAttributes;

      for (var renderObject in renderObjects) {
        assert(renderObject._target == target);
        if (renderObject._attributes case final attrs?) {
          attributes.addAll(attrs);
        }
      }

      var attributesToRemove = element.attributes.keys.toSet();
      if (attributes.isNotEmpty) {
        for (var attr in attributes.entries) {
          element.clearOrSetAttribute(attr.key, attr.value);
          attributesToRemove.remove(attr.key);
        }
      }

      if (attributesToRemove.isNotEmpty) {
        for (final name in attributesToRemove) {
          element.removeAttribute(name);
        }
      }
    }

    if (target.attachChildren) {
      Map<String, html.Node> keyedNodes = Map.of(initialKeyedNodes);
      List<html.Node> children = List.of(initialKeyedNodes.values);

      for (var renderObject in renderObjects) {
        for (var node in renderObject.children) {
          var key = keyFor(node);
          if (key != null) {
            var shadowedNode = keyedNodes[key];
            keyedNodes[key] = node;
            if (shadowedNode != null) {
              children[children.indexOf(shadowedNode)] = node;
              continue;
            }
          }
          children.add(node);
        }
      }

      html.Node? current = attachWindow.$1.nextNode;

      for (var node in children) {
        if (current == null || current == attachWindow.$2) {
          element.insertBefore(node, current);
        } else if (current == node) {
          current = current.nextNode;
        } else if (keyFor(node) != null && keyFor(node) == keyFor(current)) {
          current.replaceWith(node);
          current = node.nextNode;
        } else {
          element.insertBefore(node, current);
        }
      }

      while (current != null && current != attachWindow.$2) {
        var next = current.nextNode;
        current.remove();
        current = next;
      }
    }
  }

  void register(AttachRenderObject renderObject) {
    _renderObjects.add(renderObject);
    _needsResorting = true;
  }

  void unregister(AttachRenderObject renderObject) {
    _renderObjects.remove(renderObject);
    update();
  }
}
