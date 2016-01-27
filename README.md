## ToDo Lite for iOS

This is a demo app showing how to use the [Couchbase Lite][CBL] framework to embed a nonrelational ("NoSQL") document-oriented database in an iOS app and sync it with [Couchbase Server][CBS] in "the cloud".

![screenshot](http://cl.ly/image/1K2X1W1W2V2E/ios_todolite.png)

The app is a simple shared to-do list manager. Users can create multiple lists, each with its own items that can be checked off when done. Lists are private by default but can be shared with other users (which is very useful if your housemate is halfway to the grocery store when you remember you're out of pasta.)

You can download a pre-buit version from the [iTunes App Store](https://itunes.apple.com/uy/app/todo-lite-sync/id697235451?mt=8).

TodoLite for the [PhoneGap](https://github.com/couchbaselabs/ToDoLite-Phonegap) and [Android](https://github.com/couchbaselabs/ToDoLite-Android) platforms are also available.

### Benefits of Couchbase Lite

What does Couchbase Lite bring to the table?

* **Transparent data sync.** By now, users practically _expect_ that data they enter on one device will be accessible from others, including their laptops. Couchbase Lite makes this easy. The app code operates on the local database, and bidirectional sync happens in the background.
* **Flexible, schemaless database.** Documents are stored as JSON, though they can be accessed as native Objective-C objects for convenience. There is no predefined schema. If you want to add new features like due dates or photo attachments, you won't have to deal with data migrations. The data will even interoperate with older versions of the app.
* **Multi-user capability.** With the Couchbase Sync Gateway, any number of users can securely sync with a single server database and share only the data they want to. The design of the gateway makes writing collaborative and social apps extremely easy.
* **Control over the back-end server.** You're not dependent on a big company to host everyone's data for you: you can run your own server, whether in a data center, on a host like EC2, or just on a spare PC in your office. It's even possible (though this app doesn't show how) to synchronize directly between two devices (P2P), with no server.
* **Cross-platform.** Couchbase Lite currently supports iOS, Android and Mac OS X, and its underlying data formats and protocols (as well as source code) are fully open.


## Building & Running The Demo App

Down to business: You should be familiar with how to build and run an iOS app. And you'll need a copy of Xcode version 6 or later.

If you have questions or get stuck or just want to say hi, please visit the [Mobile Couchbase group][LIST] on Google Groups.

1. Clone or download this repository.
2. Download [Couchbase Lite][CBL_DOWNLOAD] 1.1 or later, or [check out and build it yourself][CBL_BUILD].
3. Copy `CouchbaseLite.framework` into the `Frameworks` directory of this repo.
4. Open ToDoList.xcodeproj.
5. Select the "ToDoLite" scheme and the appropriate destination (simulator or attached iOS device) from the pop-up menu in the Xcode toolbar.
6. Click the Run button

That's it! Now that you're set up, you can just use the Run command again after making changes to the demo code.

## Quick modifications you might want to make.

In the AppDelegate.m file, there is a constant defined `kSyncGatewayUrl` -- by default when you log into the app via Facebook, it will sync with this test database hosted by Couchbase. If you deploy your own Sync Gateway, you will probably want to change this URL to point at your server.

If you run your own Sync Gateway, the sync function source code we use is available in the `sync-gateway-config.json` file in the root of this repository.

## To add the framework to your existing Xcode project

Please see the documentation for [Couchbase Lite][CBL].


## License

Released under the Apache license, 2.0.

Copyright 2011-2016, Couchbase, Inc.


[CBL]: https://github.com/couchbase/Couchbase-Lite-iOS/
[CBS]: http://www.couchbase.com/couchbase-server/overview
[TODO_PHONEGAP]: https://github.com/couchbaselabs/TodoLite-PhoneGap
[LIST]: https://groups.google.com/group/mobile-couchbase
[CBL_DOWNLOAD]: http://www.couchbase.com/download#cb-mobile
[CBL_BUILD]: https://github.com/couchbase/couchbase-lite-ios/wiki/Building-Couchbase-Lite
