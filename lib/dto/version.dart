class Version {
  final int major;
  final int minor;

  const Version({
    required this.major,
    required this.minor,
  });

  factory Version.fromJson(Map<String, dynamic> json) {
    var major = json["major"];
    var minor = json["minor"];
    return Version(
      major: major,
      minor: minor,
    );
  }
}