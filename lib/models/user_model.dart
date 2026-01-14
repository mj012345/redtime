/// 사용자 정보 모델 (Firestore 저장용)
class UserModel {
  final String uid;
  final String email;
  final String? displayName;
  final String? photoURL;
  final String? birthDate; // yyyy-MM-dd 형식
  final String? gender; // 'male', 'female', 'other', null
  final String? phoneNumber;
  final String? termsVersion; // 이용약관 동의 버전
  final String? privacyVersion; // 개인정보처리방침 동의 버전
  final DateTime createdAt;
  final DateTime updatedAt;

  UserModel({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoURL,
    this.birthDate,
    this.gender,
    this.phoneNumber,
    this.termsVersion,
    this.privacyVersion,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Firestore Map으로 변환
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoURL': photoURL,
      'birthDate': birthDate,
      'gender': gender,
      'phoneNumber': phoneNumber,
      'termsVersion': termsVersion,
      'privacyVersion': privacyVersion,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Firestore Map에서 생성
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] as String,
      email: map['email'] as String,
      displayName: map['displayName'] as String?,
      photoURL: map['photoURL'] as String?,
      birthDate: map['birthDate'] as String?,
      gender: map['gender'] as String?,
      phoneNumber: map['phoneNumber'] as String?,
      termsVersion: map['termsVersion'] as String?,
      privacyVersion: map['privacyVersion'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  /// 일부 필드만 업데이트한 새 인스턴스 생성
  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoURL,
    String? birthDate,
    String? gender,
    String? phoneNumber,
    String? termsVersion,
    String? privacyVersion,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoURL: photoURL ?? this.photoURL,
      birthDate: birthDate ?? this.birthDate,
      gender: gender ?? this.gender,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      termsVersion: termsVersion ?? this.termsVersion,
      privacyVersion: privacyVersion ?? this.privacyVersion,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
