import 'interaction_performance_test.dart' as interactions;
import 'performance_test.dart' as scrolling;

/// One physical profile launch, two independent scenarios and report sections.
/// Each scenario owns and disposes its AppEnvironment; the driver retains both
/// raw timelines. The individual entrypoints remain usable for diagnosis.
void main() {
  scrolling.main();
  interactions.main();
}
