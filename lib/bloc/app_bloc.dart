import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_authentication_demo/auth/auth_error.dart';
import 'package:firebase_authentication_demo/bloc/app_event.dart';
import 'package:firebase_authentication_demo/bloc/app_state.dart';
import 'package:firebase_authentication_demo/utils/upload_image.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AppBloc extends Bloc<AppEvent, AppState> {
  AppBloc()
      : super(
          const AppStateLoggedOut(
            isLoading: false,
            authError: null,
          ),
        ) {
    on<AppEventUploadImage>((event, emit) async {
      final user = state.user;
      if (user == null) {
        emit(const AppStateLoggedOut(isLoading: false));
        return;
      }

      emit(AppStateLoggedIn(
        isLoading: true,
        user: user,
        images: state.images ?? [],
      ));

      final file = File(event.filePathToUpload);
      await uploadImage(
        file,
        user.uid,
      );

      final images = await _getImages(user.uid);
      emit(
        AppStateLoggedIn(
          isLoading: false,
          user: user,
          images: images,
        ),
      );
    });

    //handle delete account
    on<AppEventDeleteAccount>((event, emit) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        emit(
          const AppStateLoggedOut(isLoading: false),
        );
        return;
      }
      //start loading
      emit(AppStateLoggedIn(
          user: user, images: state.images ?? [], isLoading: true));

      //delete account
      try {
        final folder = await FirebaseStorage.instance.ref(user.uid).listAll();
        for (final item in folder.items) {
          await item.delete().catchError((_) {});
        }
        await FirebaseStorage.instance
            .ref(user.uid)
            .delete()
            .catchError((_) {});
        await user.delete();
        await FirebaseAuth.instance.signOut();
        emit(const AppStateLoggedOut(isLoading: false));
      } on FirebaseAuthException catch (e) {
        emit(
          AppStateLoggedIn(
            user: user,
            images: state.images ?? [],
            isLoading: false,
            authError: AuthError.from(e),
          ),
        );
      } on FirebaseException catch (e) {
        //we might not be able to delete the folder
        emit(
          const AppStateLoggedOut(
            isLoading: false,
          ),
        );
      }
    });

    on<AppEventLogout>(
      (event, emit) async {
        // start loading
        const AppStateLoggedOut(isLoading: true);
        await FirebaseAuth.instance.signOut();
        emit(const AppStateLoggedOut(isLoading: false));
      },
    );

    on<AppEventInitialize>(
      (event, emit) async {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          emit(const AppStateLoggedOut(isLoading: false));
          return;
        } else {
          final images = await _getImages(user.uid);
          emit(
            AppStateLoggedIn(
              user: user,
              images: images,
              isLoading: false,
            ),
          );
        }
      },
    );

    on<AppEventLogin>(
      (event, emit) async {
        const AppStateLoggedOut(isLoading: true);
        final email = event.email;
        final password = event.password;
        try {
          final userCredential = await FirebaseAuth.instance
              .signInWithEmailAndPassword(email: email, password: password);
          final user = userCredential.user!;
          final images = await _getImages(user.uid);
          emit(
            AppStateLoggedIn(
              isLoading: false,
              user: user,
              images: images,
            ),
          );
        } on FirebaseAuthException catch (e) {
          emit(
            AppStateLoggedOut(
              isLoading: false,
              authError: AuthError.from(e),
            ),
          );
        }
      },
    );

    on<AppEventGoToLogin>(
      (event, emit) {
        emit(const AppStateLoggedOut(isLoading: false));
      },
    );

    on<AppEventGoToRegistration>(
      (event, emit) {
        emit(const AppStateIsInRegistrationView(isLoading: false));
      },
    );

    on<AppEventRegister>(
      (event, emit) async {
        //start loading
        emit(const AppStateIsInRegistrationView(isLoading: true));
        final email = event.email;
        final password = event.password;

        try {
          //create the user
          final credentials =
              await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );
          emit(AppStateLoggedIn(
            user: credentials.user!,
            images: const [],
            isLoading: false,
          ));
        } on FirebaseAuthException catch (e) {
          emit(
            AppStateIsInRegistrationView(
              isLoading: false,
              authError: AuthError.from(e),
            ),
          );
        }
      },
    );
  }

  Future<Iterable<Reference>> _getImages(String userId) =>
      FirebaseStorage.instance
          .ref(userId)
          .list()
          .then((listResult) => listResult.items);
}
