/// A qualification certificate supported by Extra Efficient.
class CertificateOption {
  const CertificateOption({
    required this.code,
    required this.name,
    required this.sectionNoun,
  });

  factory CertificateOption.fromJson(Map<String, dynamic> json) {
    return CertificateOption(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      sectionNoun: json['sectionNoun'] as String? ?? 'Section',
    );
  }

  final String code;
  final String name;
  final String sectionNoun;
}

/// Active learner context returned by `GET /api/learner/context`.
class LearnerContext {
  const LearnerContext({
    required this.active,
    required this.certificates,
    required this.creditBalance,
    required this.examinedSkills,
    this.examDate,
  });

  factory LearnerContext.fromJson(Map<String, dynamic> json) {
    final activeMap = json['active'] as Map<String, dynamic>? ?? const {};
    final certList = json['certificates'] as List<dynamic>? ?? const [];
    final skillsList = json['examinedSkills'] as List<dynamic>? ?? const [];
    return LearnerContext(
      active: CertificateOption.fromJson(activeMap),
      certificates: certList
          .whereType<Map<String, dynamic>>()
          .map(CertificateOption.fromJson)
          .toList(),
      creditBalance: (json['creditBalance'] as num?)?.toInt() ?? 0,
      examinedSkills: skillsList.whereType<String>().toList(),
      examDate: json['examDate'] as String?,
    );
  }

  final CertificateOption active;
  final List<CertificateOption> certificates;
  final int creditBalance;
  final List<String> examinedSkills;
  final String? examDate;
}
