import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

// Reference interfaces - not part of the problem
abstract class UserService {
  Future<List<User>> getUsers();
  Stream<List<User>> searchUsers(String term);
}

class User {
  final int id;
  final String name;
  const User({required this.id, required this.name});
}

// -------------------------------------------------------
// Code to analyse
// -------------------------------------------------------

sealed class UserListState {}

class UserListInitial extends UserListState {}

class UserListLoaded extends UserListState {
  final List<User> users;
  UserListLoaded(this.users);
}

class UserListCubit extends Cubit<UserListState> {
  final UserService _userService;

  UserListCubit(this._userService) : super(UserListInitial());

  void init() {
    _userService.getUsers().then((users) {
      emit(UserListLoaded([]));
    });
  }

  void onSearchChanged(String term) {
    _userService.searchUsers(term).listen((users) {
      emit(UserListLoaded(users));
    });
  }
}
