enum MediaType { movie, series }

enum WatchStatus { none, plan, watching, completed, paused, dropped, favorite }

extension WatchStatusLabel on WatchStatus {
  String get label => switch (this) {
    WatchStatus.none => 'بدون وضعیت',
    WatchStatus.plan => 'بعداً می‌بینم',
    WatchStatus.watching => 'در حال تماشا',
    WatchStatus.completed => 'تماشا شده',
    WatchStatus.paused => 'متوقف شده',
    WatchStatus.dropped => 'رها شده',
    WatchStatus.favorite => 'مورد علاقه',
  };
}

class Episode {
  const Episode({
    required this.season,
    required this.number,
    required this.title,
    required this.runtime,
    required this.overview,
  });
  final int season;
  final int number;
  final String title;
  final int runtime;
  final String overview;

  String get id => '$season-$number';
}

class MediaItem {
  const MediaItem({
    required this.id,
    required this.title,
    required this.originalTitle,
    required this.type,
    required this.posterUrl,
    required this.backdropUrl,
    required this.overview,
    required this.year,
    required this.genres,
    required this.rating,
    required this.runtime,
    required this.country,
    required this.director,
    required this.cast,
    this.endYear,
    this.status = 'منتشر شده',
    this.episodes = const [],
    this.featured = false,
  });

  final String id;
  final String title;
  final String originalTitle;
  final MediaType type;
  final String posterUrl;
  final String backdropUrl;
  final String overview;
  final int year;
  final int? endYear;
  final List<String> genres;
  final double rating;
  final int runtime;
  final String country;
  final String director;
  final List<String> cast;
  final String status;
  final List<Episode> episodes;
  final bool featured;

  bool get isSeries => type == MediaType.series;
  int get seasonCount => episodes.isEmpty
      ? 0
      : episodes.map((e) => e.season).reduce((a, b) => a > b ? a : b);
}

class Review {
  const Review({
    required this.user,
    required this.text,
    required this.date,
    required this.spoiler,
  });
  final String user;
  final String text;
  final String date;
  final bool spoiler;

  Map<String, dynamic> toJson() => {
    'user': user,
    'text': text,
    'date': date,
    'spoiler': spoiler,
  };
  factory Review.fromJson(Map<String, dynamic> json) => Review(
    user: json['user'] as String,
    text: json['text'] as String,
    date: json['date'] as String,
    spoiler: json['spoiler'] as bool? ?? false,
  );
}
