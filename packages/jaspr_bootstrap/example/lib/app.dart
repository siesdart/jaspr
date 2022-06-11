import 'package:example/pages/container_page.dart';
import 'package:example/pages/grid_system_page.dart';
import 'package:jaspr/jaspr.dart';

class App extends StatelessComponent {
  @override
  Iterable<Component> build(BuildContext context) sync* {
    yield GridSystemPage();
  }
}