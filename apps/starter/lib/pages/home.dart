import 'package:jaspr/jaspr.dart';

import '../components/counter.dart';

class Home extends StatelessComponent {
  @override
  Iterable<Component> build(BuildContext context) sync* {
    yield section([
      img(src: 'images/logo.png', width: 80),
      h1([text('Welcome')]),
      p([text('You successfully create a new Jaspr site.')]),
      div(styles: Styles.box(height: 100.px), []),
      Counter(),
    ]);
  }

  static get styles => [
        ...Counter.styles,
      ];
}
