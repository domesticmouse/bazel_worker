// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'dart:async';

import '../constants.dart';
import '../worker_protocol.pb.dart';
import 'worker_connection.dart';
import 'worker_loop.dart';

/// Persistent Bazel worker loop.
///
/// Extend this class and implement the `performRequest` method.
abstract class SyncWorkerLoop implements WorkerLoop {
  final SyncWorkerConnection connection;

  SyncWorkerLoop({SyncWorkerConnection connection})
      : this.connection = connection ?? StdSyncWorkerConnection();

  /// Perform a single [WorkRequest], and return a [WorkResponse].
  WorkResponse performRequest(WorkRequest request);

  /// Run the worker loop. Blocks until [connection#readRequest] returns `null`.
  void run() {
    while (true) {
      WorkResponse response;
      try {
        var request = connection.readRequest();
        if (request == null) break;
        var printMessages = StringBuffer();
        response = runZoned(() => performRequest(request), zoneSpecification:
            ZoneSpecification(print: (self, parent, zone, message) {
          printMessages.writeln();
          printMessages.write(message);
        }));
        if (printMessages.isNotEmpty) {
          response.output = '${response.output}$printMessages';
        }
        // In case they forget to set this.
        response.exitCode ??= EXIT_CODE_OK;
      } catch (e, s) {
        response = WorkResponse()
          ..exitCode = EXIT_CODE_ERROR
          ..output = '$e\n$s';
      }

      connection.writeResponse(response);
    }
  }
}
