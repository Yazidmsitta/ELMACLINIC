class StaffMember {
  const StaffMember(this.id, this.name, this.role, this.active, this.version);
  final String id, name, role;
  final bool active;
  final int version;
}

class StaffPage {
  const StaffPage(this.items, this.hasMore);
  final List<StaffMember> items;
  final bool hasMore;
}

abstract interface class StaffRepository {
  Future<StaffPage> list({int page = 1});
  Future<void> update(
    StaffMember original,
    String name,
    String role,
    bool active,
  );
}
