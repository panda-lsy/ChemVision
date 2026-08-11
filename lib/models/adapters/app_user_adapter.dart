import 'package:hive/hive.dart';

import '../../models/app_user.dart';

/// AppUser 的 Hive 适配器(typeId=3,复用空缺 ID)
class AppUserAdapter extends TypeAdapter<AppUser> {
  @override
  final int typeId = 3;

  @override
  AppUser read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return AppUser(
      id: fields[0] as String,
      nickname: fields[1] as String,
      stage: fields[2] as String,
      avatarPath: fields[3] as String?,
      createdAt: fields[4] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, AppUser obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.nickname)
      ..writeByte(2)
      ..write(obj.stage)
      ..writeByte(3)
      ..write(obj.avatarPath)
      ..writeByte(4)
      ..write(obj.createdAt);
  }
}
