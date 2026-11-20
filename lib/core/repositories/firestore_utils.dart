import 'dart:async';

/// Firestore queues writes while offline and only completes the Future once
/// the server confirms. The UI must not hang waiting for that, so writes are
/// awaited for a short time and otherwise left to sync in the background
/// (US-11.2: drafts upload when the connection returns).
Future<void> softWrite(Future<void> write,
    {Duration timeout = const Duration(seconds: 4)}) async {
  try {
    await write.timeout(timeout);
  } on TimeoutException {
    // Saved to the local cache; Firestore will sync it later.
  }
}
