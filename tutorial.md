# Couchbase Mobile Day Workshop iOS

In this workshop, you will learn how to use Couchbase Lite along with Sync Gateway using a ToDos app with offline-first capabilities and access control rules for sharing documents with other users.

This document will guide you through the steps to build the application using Couchbase Mobile.

### What is Included

This tutorial is based on a demo application, ToDo Lite, designed to show the
features of Couchbase Lite.  The full demo application is on the
master branch and is updated from time to time as new features are
added to Couchbase Lite.

You may be viewing this tutorial from a browser on github or on your
local system after cloning the repository or openining a zipfile.  in
Any case, you should find the following layout in the tutorial:

	CONTRIBUTING.md
	finished/
	tutorial.md
	README.md
	initial/

The CONTRIBUTING.md and README.md are a simple copy of the master
branch overview and contribution instructions.  The tutorial.md is the
file containing these instructions.  The initial/ directory contains
the basic scaffolding of ToDo Lite which you will edit to add
functionality to.  The finished/ directory contains a completed
version of the application.  You will use the completed version in a
later portion of the lab with Couchbase Sync Gateway and you may want
to refer to it if you get stuck when going through the lab steps.

### Getting started

If needed, clone the application from the ToDoLite-iOS repository:

	git clone https://github.com/couchbaselabs/ToDoLite-iOS
        git checkout workshop/CouchbaseDay

Once you have the files from either the repository or a zipfile open
the project.

	cd ToDoLite-iOS
        open initial/ToDoLite.xcodeproj

Download and unzip the latest zip file for the 1.1 release
[from the Couchbase website][1]. Drag the `CouchbaseLite.framework` file to the Frameworks folder.

![][image-1]

### Introduction

The topics below are the fundamental aspects of Couchbase Mobile. If
you understand all of them and their purposes, you’ll be in a very
good spot after walking through this tutorial.

- document: the primary entity stored in a database
- revision: with every change to a document, we get a new revision
- view: persistent index of documents in a database, which you then query to find data
- query: the action of looking up results from a view’s index
- attachment: stores data associated with a document, but are not part of the document’s JSON object

Throughout this tutorial, we will refer to the logs in the Xcode debugger to check that things are working as expected. You can open the Xcode debugger with the sliding panel button and `⌘ + ⇧ + Y`.

![][image-2]

### ToDoLite Data Model

In ToDoLite, there are 3 types of documents: a profile, a list and a task. The List document has an owner and a members array, the Task document holds a reference to the List it belongs to.

![][image-3]

### Working with Documents and Revisions

In Couchbase Lite a document’s body takes the form of a JSON object - a collection of key/value pairs where the values can be different types of data such as numbers, strings, arrays or even nested objects.

Documents can have different schemas and every change that is made to a document is saved as a new revision.

The document properties have to be valid JSON types. For other types, we can use Attachments, for example to save an image as we will see later.

Fortunately, the iOS SDK has a CBLModel convenience API that makes it really easy to work with a Document, it’s underlying Revisions and Attachments if they apply.

In the next section, we will learn how to use the CBLModel api to create the List model class.

### STEP 1: Create a database

Open `AppDelegate.h`, notice there is a property called database of type CBLDatabase. We will use this property throughout the application to get access to our database.

In `AppDelegate.m`, add a new method called `createDatabase` with the following code:

- use the `databaseNamed:error` method on the CBLManager sharedInstance to create a new database called `todosapp`
- initialise the `_database` to this database object

Call the createDatabase method in the `application:didFinishLaunchingWithOptions:` method.

The database doesn’t have any documents in it so far. Let’s add the Profile document:

- initialise `_currentUserId` to the name/user of your choice

As you can see in the Data Model diagram, the List document has an owner property which is the `_id` of the Profile document owning that List. You need to create the Profile document before creating Lists:

- use the Profile’s `profileInDatabase:forNewUserId:name` passing in the database, current user id and a name of your choice. This will return a new Profile model instance
- call save on that profile model and log the properties to the console

Launch the app and you should see the properties of the Profile document in the Console:

![][image-4]

### STEP 2: Working with CBLModel

Both the List and Task documents have a `title` property. For that reason we created a `Titled` class to abstract the behaviour for setting both properties.

In `Titled.h`:

- add a property `title` of type NSString
- add a property `created_at` of type NSDate

In `Titled.m`:

- mark the `title` and `created_at` properties as @dynamic

You can read more about the usage of dynamic properties in CBLModel
subclasses and how to use them [in the model documentation][2] on the
Couchbase Developer website.

Next, we can use the `awakeFromInitializer` method to hook into the initialisation process to set our iVars.

In `awakeFromInitializer`:

- set the `created_at` property to the current time
- set the `type` property to the return value of the `docType` method (`[[self class] docType]`)

Now let’s test this method is working as expected. Open `MasterViewController.m` and complete the `createListWithTitle` method:

- instantiate a new List model with the `modelForNewDocumentInDatabase` method
- set the title property to the parameter that was passed in
- (if there is a `currentUserId` property, set the owner property on the list to the logged in user)

Finally, add a log statement to check that the document was saved.

Run the app and create a couple lists. Nothing will display in the UI just yet but you see the Log statement you added above. In the next section, you will learn how to query those documents.

![][image-5]

The solution is shown in the `Titled.h` and `Titled.m` files in the
finished directory.

### STEP 3: Creating Views

Couchbase views enable indexing and querying of data.

The main component of a view is its **map function**. This function is written in the same language as your app—most likely Objective-C or Java—so it’s very flexible. It takes a document's JSON as input, and emits (outputs) any number of key/value pairs to be indexed. The view generates a complete index by calling the map function on every document in the database, and adding each emitted key/value pair to the index, sorted by key.

You will find the `queryListsInDatabase` method in `List.m` and the objective is to add the missing code to index the List documents. The emit function will emit the List title as key and null as the value.

In pseudo code, the map function will look like:

	var type = document.type;
	if document.type == "list"
	    emit(document.title, null)

Note that you will need specify a version string.  This is used to
detect when the view code changes.  Use "1.0" for the version string.

The solution is also available in the `List.m` file in the finished directory.

### STEP 4: Query Views

A query is the action of looking up results from a view's index. In Couchbase Lite, queries are objects of the Query class. To perform a query you create one of these, customise its properties (such as the key range or the maximum number of rows) and then run it. The result is a QueryEnumerator, which provides a list of QueryRow objects, each one describing one row from the view's index.

Since in the previous step you created the view to index List documents, you can query it. In `MasterViewController.m`, add the missing code to `setupTodoLists`:
- create a `query` variable of type `CBLQuery` using the List class method you wrote above
- run the query and create a `results` variable of type `CBLQueryEnumerator`

Iterate on the result and log the title of every List document. If you
saved List documents in Step 1, you should now see the titles in the
Console whenever you launch the application:

![][image-6]

Note that simply saving a new list won't display your iteration
because the `setupTodoLists` is called when the view is loaded.

The code you would have added to the method is as follows:

    CBLQuery *query = [List queryListsInDatabase:self.database];
    CBLQueryEnumerator *result = [query run:nil];
    for (CBLQueryRow *row in result) {
        NSLog(@"The list title is %@", [[row document] propertyForKey:@"title"]);
    }

At this point, we could pass the result enumerator to a Table View Data Source to display the lists on screen. However, we will jump slightly ahead of ourselves and use a Live Query to have Reactive UI capabilities. 


### STEP 5: Adding Live Query to Table Views

Couchbase Lite provides a feature called live queries. Once created, a live query
remains active and monitors changes to the view's index, notifying
observers whenever the query results change. Live queries are very
useful for driving UI components like lists.

We need a query to populate a Table View with those
documents. To have the UI automatically update when new documents are
indexed, we will use a Live Query using UITableDataSource.

Back in `setupTodoLists` of `MasterViewController.m`, we will need to make small changes to accommodate for a live query instead of a simple query. There is a `liveQuery` property on the Main Activity class that we can use in `setupTodoLists`:

- Remove the code for iterating over the list from earlier
- Initialize the already defined `self.liveQuery` with the query from Step 4 (all queries have an `asLiveQuery` method we can use to convert the query into a Live Query)
- add a KVO observer on the `rows` property of the liveQuery object
- in the `observeValueForKeyPath:ofObject:change:context:` handle the changes, set the `self.listsResults` to the new results. The rows result has a `allObjects` method to return an array
- reload the tableview with the `reloadData` method

Finally, we need to implement the required methods of the `UITableViewDataSource`, that’s `tableView:numberOfRowsInSection:` and `tableView:cellForRowAtIndexPath:`:
- return the number of elements in the `listsResult` array for the `tableView:numberOfRowsInSection:`
- for the `tableView:cellForRowAtIndexPath:` method, dequeue a table view cell of type "List"
- create a new variable row of type `CBLQueryRow` that’s the item in `listsResult` at the indexPath.row position
- default cells in UITableViews have a Text Label (textLabel), set the text property of the cell to the title property of the List. For this simple case, we don’t need to create a new List model, use `[row.document propertyForKey:@"title"]`

Run the app on the simulator and start creating ToDo lists, you can see the lists are now displayed in the Table View.

![][image-7]

The solution is also available in the `MasterViewController.m` file in the finished directory.

### STEP 6: Persist the Task document

To create a Task model and persist it, open `List.m` and complete the body of the method `addTaskWithTitle:withImage:withImageContentType:`:
- initialise a Task model with the `modelForNewDocumentInDatabaseMethod:`
- set the title to the parameter that was passed in
- set the `list_id` to self, notice here again that we are using a relationship between two models, the List and Task. This will translate to the `_id` of the List in the underlying JSON document
- use the `setAttachmentNamed:withContentType:content:` method on the list object, the name of the attachment is `image`, the contentType and content are the params that were passed in
- finally, return the task object

Open `DetailViewController.m` and call this method on self.list passing in the title, image and "image/jpg" for the content type.

![][image-8]

The solution is in the `List.m` and `DetailViewController.m` files in
the finished directory.

## Hands On Sync Gateway

In this section, our goal is to pick up a completed version of the
ToDo Lite demonstration code and configure a Sync Gateway backed by
Couchbase Server to store the documents.  Optionally, you can run
multiple instances of ToDo Lite to see your demo application
synchronize between multipled devices.

Note: this section of the workshop is separated by letters instead of
numbers.

### STEP A: Install Sync Gateway and Couchbase Server

(Side note: if you are constrained in resources, it is possible to use
Sync Gateway alone with memory backed storage.  This is known as
"wallace" and the Sync Gateway documentation covers the details.)


#### Install from Vagrant

If you are attending a workshop in person, you may obtain a software
distribution of a Vagrant configuration and an associated `.box`
file.  With Vagrant and VirtualBox installed locally, set up Sync
Gateway by running `vagrant up` from a shell prompt in the directory
with the `Vagrantfile` and the `Couchbase-Sync_Gateway.box` files.

After running `vagrant up`, you should be able to `vagrant ssh` to
connect to the VM.  Also, you should be able to reach your
[Couchbase Web UI][couchbase-web-ui] via the browser 
at [http://10.111.72.101:8091/index.html][couchbase-web-ui].  The
username is "Administrator" and the password is "password".

#### Install from Download

To set up Couchbase Sync Gateway on your own system, get Couchbase
Server and Sync Gateway binaries from the
[Couchbase download page](http://www.couchbase.com/nosql-databases/downloads).
Follow the setup wizard from Couchbase Server to set it up and install
the Sync Gateway binary for your platform per the
[installation instructions](http://developer.couchbase.com/documentation/mobile/1.1.0/develop/guides/sync-gateway/running-sync-gateway/installing-sync-gateway/index.html).

#### STEP B: Configure Sync Gateway

In this step, we will start with a minimal Sync Gateway configuration
for our environment and run the "finished" ToDo LIte application
against it.  It will not yet actually be syncing files.

As before, there is both an 'initial' and 'finished' configuration.
You will find a file named `sync-gateway-config.json` in both the VM
and in this repository.

First, copy the initial `sync-gateway-config.json` into your local
working directory.  Then, start Sync Gateway with either the provided shell
script (VM environment) or by running the `sync_gateway` executable
with the `sync-gateway-config.json` file as an argument.

When Sync Gateway starts, you should see some basic logging output.

```
2015-11-17T07:58:01.571Z Enabling logging: [CRUD REST+ Access]
2015-11-17T07:58:01.571Z ==== Couchbase Sync Gateway/1.1.1(10;2fff9eb) ====
2015-11-17T07:58:01.571Z Configured process to allow 4096 open file descriptors
2015-11-17T07:58:01.572Z Opening db /todos as bucket "todos", pool "default", server <walrus:>
2015-11-17T07:58:01.573Z Opening Walrus database todos on <walrus:>
2015-11-17T07:58:01.573Z Using default sync function 'channel(doc.channels)' for database "todos"
2015-11-17T07:58:01.646Z WARNING: No users have been defined in the 'todos' database, which means that you will not be able to get useful data out of the sync gateway over the standard port.  FIX: define users in the configuration json or via the REST API on the admin port, and grant users to channels via the admin_channels parameter. -- rest.emitAccessRelatedWarnings() at server_context.go:576
2015-11-17T07:58:01.646Z Starting admin server on 127.0.0.1:4985
2015-11-17T07:58:01.650Z Starting server on :4984 ...
```

You will notice that it may not be listening on the IP address we want
it to.  Also, you may notice that it is currently using the "walrus:"
memory backend, but it is otherwise configured for our ToDo Lite
application.  Next, we'll want to set up the Sync Gatway REST API to
listen on all IPs on the host.

Entering `ctrl-c` will stop the process.

Then edit the JSON file.  Add a new value for _interface_ set up to
listen on `0.0.0.0`, which indicates all IPs on the system.  You will
add  `"interface": "0.0.0.0:4984",` to the JSON.

Start Sync Gateway again and you should see:
```2015-11-17T08:06:49.206Z Starting server on 0.0.0.0:4984 ...```

### STEP C: Run the Completed ToDo Lite

From XCode, close any projects you may currently have open.  Then,
open the project in the `finished/` directory.

Open `AppDelegate.m` and verify that the IP address
is correct for the Sync Gateway you will connect to (_note_: the one on the
preconfigured VM is 10.111.72.101).  

When ToDo Lite runs, you will see some logged traffic on the Sync
Gateway node:
```
2015-11-17T14:17:13.177Z HTTP auth failed for username="oliver"
2015-11-17T14:17:13.177Z HTTP:  #001: GET /todos/_session
2015-11-17T14:17:13.177Z HTTP: #001:     --> 401 Invalid login  (0.1 ms)
2015-11-17T14:17:13.178Z HTTP auth failed for username="oliver"
2015-11-17T14:17:13.178Z HTTP:  #002: GET /todos/_session
2015-11-17T14:17:13.178Z HTTP: #002:     --> 401 Invalid login  (0.1 ms)
```

Since ToDo LIte is configured for authentication but Sync Gateway
does not have the "oliver" user built in to the app, it cannot
authenticate.  Add that user using the
[Sync Gateway REST API][sg-rest-useradd].  You will have to use the
admin port to access this REST API.  For security reasons, Sync
Gateway listens on two ports.  One is intended for administrative
access and should *only* be open to trusted networks.  By default, it
will be localhost only.

Adding the user should generate these log messages:
```
2015-11-17T14:23:11.474Z HTTP:  #003: POST /todos/_user/  (ADMIN)
> POST /todos/_user/ HTTP/1.1
> User-Agent: curl/7.19.7 (x86_64-redhat-linux-gnu) libcurl/7.19.7 NSS/3.16.2.3 Basic ECC zlib/1.2.3 libidn/1.18 libssh2/1.4.2
> Host: localhost:4985
> Accept: */*
> Content-Type: application/json
> Content-Length: 41
```

Once the user is added, if you run the application again, you will
note that "oliver" authenticates successfully.

However, we are not done yet.  We still need to configure Sync Gateway
to connect to the Couchbase Server bucket and store and retrieve
documents based on the user with a sync function.

The solution to adding the user is in a shell script in the
`finished/` directory.  

### STEP D: Complete the Sync Gateway Configuration

Verify your [Couchbase Web UI][couchbase-web-ui]] has a bucket named
"todos".  If does not exist, create it.  

Now, referring to the [documentation on config.json][sg-config-json]
edit the `sync-gateway-config.json` to change the server to
"http://localhost:8091" or wherever your Couchbase Server is.  Also
change it so user 'GUEST' access is disabled.  Finally, add a sync
function:
```
function(doc, oldDoc) {
  // NOTE this function is the same across the iOS, Android, and PhoneGap versions.
  if (doc.type == "task") {
    if (!doc.list_id) {
      throw({forbidden : "items must have a list_id"})
    }
    channel("list-"+doc.list_id);
  } else if (doc.type == "list") {
    channel("list-"+doc._id);
    if (!doc.owner) {
      throw({forbidden : "list must have an owner"})
    }
    if (oldDoc) {
      var oldOwnerName = oldDoc.owner.substring(oldDoc.owner.indexOf(":")+1);
      requireUser(oldOwnerName)
    }
    var ownerName = doc.owner.substring(doc.owner.indexOf(":")+1);
    access(ownerName, "list-"+doc._id);
    if (Array.isArray(doc.members)) {
      var memberNames = [];
      for (var i = doc.members.length - 1; i >= 0; i--) {
        memberNames.push(doc.members[i].substring(doc.members[i].indexOf(":")+1))
      };
      access(memberNames, "list-"+doc._id);
    }
  } else if (doc.type == "profile") {
    channel("profiles");
    var user = doc._id.substring(doc._id.indexOf(":")+1);
    if (user !== doc.user_id) {
      throw({forbidden : "profile user_id must match docid"})
    }
    requireUser(user);
    access(user, "profiles"); // TODO this should use roles
  }
}
```

Read through that sync function.  You'll notice that it handles
documents differently based on the type.  For instance "task"
documents must have an owner and a list_id and the "profile" user\_id
is required to match the docid.  

Start Sync Gateway with this new configuration file.

Before we can synchronize, the user "oliver" with the password
"letmein" needs to be added as you did earlier via the Admin REST
API:
```
2015-11-17T14:56:22.145Z Access: Computed channels for "oliver": !:1
2015-11-17T14:56:22.161Z Access: Computed roles for "oliver": 
< HTTP/1.1 201 Created
< Server: Couchbase Sync Gateway/1.1.1
< Date: Tue, 17 Nov 2015 14:56:22 GMT
< Content-Length: 0
< Content-Type: text/plain; charset=utf-8
< 
* Connection #0 to host localhost left intact
* Closing connection #0
```

You will also note in the [Couchbase Server Web UI][couchbase-web-ui]
that the "todos" bucket now has some documents in it related to Sync
Gateway's own management of data.

The completed configuration is in the `finished/` directory.

### STEP E:  Run the Completed ToDo Lite Against the Server

Once again, go back to the completed ToDo Lite Application and start
it.  This time, as you interact with the app, you should see data
being automatically synchronized to and from the server:
```
2015-11-17T15:00:06.884Z HTTP:  #002: GET /todos/_session  (as oliver)
2015-11-17T15:00:06.900Z HTTP:  #003: GET /todos/_session  (as oliver)
2015-11-17T15:00:06.925Z HTTP:  #004: GET /todos/_local/417e79ad1e103bb533eb9083f975c0f8523f7c83  (as oliver)
2015-11-17T15:00:06.925Z HTTP: #004:     --> 404 missing  (1.5 ms)
2015-11-17T15:00:06.959Z HTTP:  #005: GET /todos/_local/2d306925261478d9482423011c6dbfd168fc74d1  (as oliver)
2015-11-17T15:00:06.959Z HTTP: #005:     --> 404 missing  (0.5 ms)
2015-11-17T15:00:06.990Z HTTP:  #006: POST /todos/_changes  (as oliver)
2015-11-17T15:00:07.016Z HTTP:  #007: POST /todos/_changes  (as oliver)
2015-11-17T15:00:07.462Z HTTP:  #008: POST /todos/_revs_diff  (as oliver)
2015-11-17T15:00:07.504Z HTTP:  #009: PUT /todos/56a4997f-2b85-419e-a10d-1c3712748415?new_edits=false  (as oliver)
2015-11-17T15:00:07.539Z HTTP:  #010: POST /todos/_bulk_docs  (as oliver)
2015-11-17T15:00:07.633Z CRUD: 	Doc "p:oliver" in channels "{profiles}"
```

Congratulations on building the main features of ToDoLite. Now you have a deeper understanding of Couchbase Lite and how to use the sync features with Sync Gateway you can start using the SDKs in your own apps.

[1]:   http://www.couchbase.com/nosql-databases/downloads
[2]:	http://developer.couchbase.com/mobile/develop/guides/couchbase-lite/native-api/model/index.html

[image-1]:	http://i.gyazo.com/71ba8ac8f36835f86ffc8d570708cec6.gif
[image-2]:	http://i.gyazo.com/7fa47e35c349c1936f2713acd18327e9.gif
[image-3]:	http://f.cl.ly/items/0r2I3p2C0I041G3P0C0C/Model.png
[image-4]:	http://i.gyazo.com/58f2f18f3a05651301a96792de7df373.gif
[image-5]:	http://i.gyazo.com/11fa6533027e17d316d64c059b8c42f5.gif
[image-6]:	http://i.gyazo.com/20e60cb13ba987f42970c5d04a495423.gif
[image-7]:	http://i.gyazo.com/359ac7a252f57f889649d74c2228e675.gif
[image-8]:	http://i.gyazo.com/bb951a6b846793c0bb38532c22d6f90b.gif
[image-9]:	http://i.gyazo.com/c874e2e1f48242eb93fb8ec1d843c30f.gif
[image-10]:	http://i.gyazo.com/3de9c203a9b37d57652e2aadef290069.gif
[image-11]:	http://i.gyazo.com/755327503b7f5c3e36dd2d816fedae62.gif
[image-12]:	http://i.gyazo.com/6ad24bd77513506a6869a1ce78c0a242.gif
[image-13]:	http://i.gyazo.com/22dd85add78a4283938fab9bb955161e.gif
[image-14]:	http://i.gyazo.com/80c7dda4371ecf2343d2fe36c59890e1.gif
[couchbase-web-ui]: http://10.111.72.101:8091/index.html
[couchbase-sg]: http://10.111.72.101:4984/index.html
[sg-rest-useradd]: http://developer.couchbase.com/documentation/mobile/current/develop/references/sync-gateway/admin-rest-api/user/post-user/index.html
[sg-config-json]: http://developer.couchbase.com/documentation/mobile/1.1.0/develop/guides/sync-gateway/configuring-sync-gateway/config-properties/index.html
