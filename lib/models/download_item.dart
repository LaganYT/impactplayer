class DownloadItem {
  final String title;
  final String source;
  final String? filePath;
  final double progress; // 0.0 to 1.0
  final bool isCompleted;
  final bool isError;
  final String? errorMessage;

  DownloadItem({
    required this.title,
    required this.source,
    this.filePath,
    this.progress = 0.0,
    this.isCompleted = false,
    this.isError = false,
    this.errorMessage,
  });

  DownloadItem copyWith({
    String? title,
    String? source,
    String? filePath,
    double? progress,
    bool? isCompleted,
    bool? isError,
    String? errorMessage,
  }) {
    return DownloadItem(
      title: title ?? this.title,
      source: source ?? this.source,
      filePath: filePath ?? this.filePath,
      progress: progress ?? this.progress,
      isCompleted: isCompleted ?? this.isCompleted,
      isError: isError ?? this.isError,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
} 