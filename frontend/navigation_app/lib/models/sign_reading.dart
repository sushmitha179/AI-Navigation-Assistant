class SignReading {
  const SignReading({
    required this.text,
    required this.confidence,
    required this.wordCount,
  });

  final String text;
  final double confidence;
  final int wordCount;

  factory SignReading.fromJson(Map<String, dynamic> json) {
    final confidenceValue = json['confidence'];
    final wordCountValue = json['word_count'];
    if (json['text'] is! String ||
        confidenceValue is! num ||
        !confidenceValue.isFinite ||
        confidenceValue < 0 ||
        confidenceValue > 1 ||
        wordCountValue is! int ||
        wordCountValue < 0) {
      throw const FormatException('Invalid sign-reading response');
    }
    return SignReading(
      text: json['text'] as String,
      confidence: confidenceValue.toDouble(),
      wordCount: wordCountValue,
    );
  }
}
