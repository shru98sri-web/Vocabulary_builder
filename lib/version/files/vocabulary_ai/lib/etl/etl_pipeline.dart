import 'dart:async';

/// E: read raw data from a source.
abstract class Extractor<I> {
  Future<I> extract();
}

/// T: clean / validate / reshape the raw data.
abstract class Transformer<I, O> {
  O transform(I input);
}

/// L: write the result to its destination.
abstract class Loader<O, R> {
  Future<R> load(O data);
}

class EtlException implements Exception {
  final String pipeline;
  final String stage;
  final Object cause;
  EtlException(this.pipeline, this.stage, this.cause);

  @override
  String toString() => 'ETL "$pipeline" failed at $stage: $cause';
}

/// Runs Extract -> Transform -> Load and tags failures with the stage.
class EtlPipeline<I, O, R> {
  final String name;
  final Extractor<I> extractor;
  final Transformer<I, O> transformer;
  final Loader<O, R> loader;

  const EtlPipeline({
    required this.name,
    required this.extractor,
    required this.transformer,
    required this.loader,
  });

  Future<T> _stage<T>(String stage, FutureOr<T> Function() fn) async {
    try {
      return await fn();
    } catch (e) {
      throw EtlException(name, stage, e);
    }
  }

  Future<R> run() async {
    final raw = await _stage<I>('extract', () => extractor.extract());
    final clean = await _stage<O>('transform', () => transformer.transform(raw));
    return _stage<R>('load', () => loader.load(clean));
  }
}
