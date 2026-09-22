import 'package:flutter_bloc/flutter_bloc.dart';

// Reference types
class Organisation {
  final int id;
  final String name;
  final String email;
  const Organisation({required this.id, required this.name, required this.email});
}

abstract class OrganisationsApi {
  Future<List<Organisation>> getOrganisations();
  Future<Organisation> createOrganisation({
    required String name,
    required String email,
  });
  Future<void> deleteOrganisation(int id);
}

// -------------------------------------------------------
// Code to analyse
// -------------------------------------------------------

class OrganisationsCubit extends Cubit<List<Organisation>> {
  OrganisationsCubit() : super([]);

  void setAll(List<Organisation> orgs) => emit(orgs);

  void addOne(Organisation org) => emit([...state, org]);

  void removeById(int id) => emit(state.where((o) => o.id != id).toList());
}

class OrganisationService {
  final OrganisationsApi _api;
  final OrganisationsCubit _cubit;

  OrganisationService(this._api, this._cubit);

  Future<List<Organisation>> getOrganisations() async {
    final orgs = await _api.getOrganisations();
    _cubit.setAll(orgs);
    return orgs;
  }

  Future<Organisation> createOrganisation(String name, String email) async {
    final org = await _api.createOrganisation(name: name, email: email);
    _cubit.addOne(org);
    return org;
  }

  Future<void> deleteOrganisation(int id) async {
    await _api.deleteOrganisation(id);
    _cubit.removeById(id);
  }
}
