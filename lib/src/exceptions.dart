class ClamAVException implements Exception {
  final String message;
  final Object? cause;

  ClamAVException(this.message, {this.cause});

  @override
  String toString() => 'ClamAVException: $message${cause != null ? ' ($cause)' : ''}';
}
