class ClinicSettings {
  const ClinicSettings(this.name, this.phone, this.address, this.version);
  final String name, phone, address;
  final int version;
}

abstract interface class ClinicSettingsRepository {
  Future<ClinicSettings> load();
  Future<int> save(ClinicSettings draft);
}
