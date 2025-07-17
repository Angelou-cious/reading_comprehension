class Story {
  final String title;
  final String body;

  Story({required this.title, required this.body});

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'body': body,
    };
  }

  factory Story.fromMap(Map<String, dynamic> map) {
    return Story(
      title: map['title'],
      body: map['body'],
    );
  }
}
