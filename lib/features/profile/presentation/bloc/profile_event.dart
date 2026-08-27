import 'package:equatable/equatable.dart';
import 'package:image_picker/image_picker.dart';

abstract class ProfileEvent extends Equatable {
  const ProfileEvent();

  @override
  List<Object?> get props => const [];
}

class ProfileStarted extends ProfileEvent {
  const ProfileStarted();
}

class ProfileUpdateUser extends ProfileEvent {
  final String? name;
  final String? phone;
  final String? city;
  final String? address;
  final String? avatarUrl;

  const ProfileUpdateUser({
    this.name,
    this.phone,
    this.city,
    this.address,
    this.avatarUrl,
  });

  @override
  List<Object?> get props => [name, phone, city, address, avatarUrl];
}

class ProfileUploadAvatar extends ProfileEvent {
  final XFile imageFile;

  const ProfileUploadAvatar(this.imageFile);

  @override
  List<Object?> get props => [imageFile.path];
}

class ProfileUpdatePassword extends ProfileEvent {
  final String newPassword;

  const ProfileUpdatePassword(this.newPassword);

  @override
  List<Object?> get props => [newPassword];
}

class ProfileSignOut extends ProfileEvent {
  const ProfileSignOut();
}
