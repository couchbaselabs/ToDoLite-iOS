# Couchbase Connect Mobile Workshop iOS

In this workshop, you will learn how to use Couchbase Lite along with Sync Gateway to build a ToDos app with offline-first capabilities and access control rules for sharing documents with other users.

This document will guide you through the steps to build the application and know all the tips and tricks to building apps with a great look and feel using Couchbase Mobile.

## 30 minutes: Couchbase Mobile Presentation

## 30 minutes: Couchbase Lite in-depth Presentation

## 90 minutes: Hands on building Todo-Lite

### Getting started

Clone the application from the ToDoLite-iOS repository:

	git clone https://github.com/couchbaselabs/ToDoLite-iOS
	cd ToDoLite-iOS
	git checkout workshop/start

Download and unzip the zip file for the 1.1 release [here][1]. Drag the `CouchbaseLite.framework` file to the Frameworks folder.

![][image-1]

### Introduction

The topics below are the fundamental aspects of Couchbase Mobile. If you understand all of them and their purposes, you’ll be in a very good spot after reading this tutorial.

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

You can read more about the usage of dynamic properties in CBLModel subclasses and how to use them [here][2].

Next, we can use the `awakeFromInitializer` method to hook into the initialisation process to set our iVars.

In `awakeFromInitializer`:

- set the `created_at` property to the current time
- set the `type` property to the return value of the `docType` method (`[[self class] docType]`)

Now let’s test this method is working as expected. Open `MasterViewController.m` and complete the `createListWithTitle` method:

- instantiate a new List model with the `modelForNewDocumentInDatabase` class method
- set the title property to the parameter that was passed in
- get the Profile object using the `profileInDatabase:forExistingUserId:` method passing in the currentUserId
- set the owner property on the list to the Profile model
- use the `save` method to save the List model to Couchbase Lite
- to check that the model was saved, log the properties to the Console using the document property on the model class (`[[list document] properties]`)
- return the list object

Run the app and create a couple lists. Nothing will display in the UI just yet but you see the Log statement you added above. In the next section, you will learn how to query those documents.

![][image-5]

The solution is on the `workshop/saving_list_document` branch.

### STEP 3: Creating Views

Couchbase views enable indexing and querying of data.

The main component of a view is its **map function**. This function is written in the same language as your app—most likely Objective-C or Java—so it’s very flexible. It takes a document's JSON as input, and emits (outputs) any number of key/value pairs to be indexed. The view generates a complete index by calling the map function on every document in the database, and adding each emitted key/value pair to the index, sorted by key.

You will find the `queryListsInDatabase` method in `List.m` and the objective is to add the missing code to index the List documents. The emit function will emit the List title as key and null as the value.

In sudo code, the map function will look like:

	var type = document.type;
	if document.type == "list"
	    emit(document.title, null)

The solution is on the `workshop/create_views` branch.

### STEP 4: Query Views

A query is the action of looking up results from a view's index. In Couchbase Lite, queries are objects of the Query class. To perform a query you create one of these, customise its properties (such as the key range or the maximum number of rows) and then run it. The result is a QueryEnumerator, which provides a list of QueryRow objects, each one describing one row from the view's index.

Now you have created the view to index List documents, you can query it. In `MasterViewController.m`, add the missing code to `setupTodoLists`:
- create a `query` variable of type `CBLQuery` using the List class method you wrote above
- run the query and create a `results` variable of type `CBLQueryEnumerator`

Iterate on the result and log the title of every List document. If you saved List documents in Step 1, you should now see the titles in the Console:

![][image-6]

The solution is on the `workshop/query_views` branch.

At this point, we could pass the result enumerator to a Table View Data Source to display the lists on screen. However, we will jump slightly ahead of ourselves and use a Live Query to have Reactive UI capabilities. 

### STEP 5: A Table View meets a Live Query

Couchbase Lite provides live queries. Once created, a live query remains active and monitors changes to the view's index, notifying observers whenever the query results change. Live queries are very useful for driving UI components like lists.

We will use the query to populate a Table View with those documents. To have the UI automatically update when new documents are indexed, we will use a Live Query.

### STEP 6: Using the UITableDataSource

Back in `setupTodoLists` of `MasterViewController.m`, we will need to make small changes to accommodate for a live query instead of a simple query. There is a `liveQuery` property on the Main Activity class that we can use in `setupTodoLists`:

- initialise the `self.liveQuery` with the query from Step 4 (all queries have a `toLiveQuery` method we can use to convert the query into a Live Query)
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

The solution is on the `workshop/persist_task_document` branch.

### STEP 7: Persist the Task document

To create a Task model and persist it, open `List.m` and complete the body of the method `addTaskWithTitle:withImage:withImageContentType:`:
- initialise a Task model with the `modelForNewDocumentInDatabaseMethod:`
- set the title to the parameter that was passed in
- set the `list_id` to self, notice here again that we are using a relationship between two models, the List and Task. This will translate to the `_id` of the List in the underlying JSON document
- use the `setAttachmentNamed:withContentType:content:` method on the list object, the name of the attachment is `image`, the contentType and content are the params that were passed in
- finally, return the task object

Open `DetailViewController.m` and call this method on self.list passing in the title, image and "image/jpg" for the content type.

![][image-8]

The solution is on the `workshop/attachments_and_revisions ` branch.

## 30 minutes: Sync Gateway in-depth

The goal is to add the sync feature to our application. The speaker will go through the steps to install Sync Gateway and get it running with Couchbase Server.

Then, we will all attempt to connect to the same instance of Sync Gateway.

## 30 minutes: Hands-on, Replications

### STEP 9: Replications without authentication

In `AppDelegate.m`, create a new method called `startReplications` to create the push/pull replications:

- initialise a new NSURL object. The string url for this tutorial is `http://localhost:4984/todos`
- initialise the pull replication with the `createPullReplication` method
- initialise the push replication with the `createPushReplication` method
- set the continuous property to true on both replications
- call the `start` method on each replication
Finally, call the `startReplications` method in the `application:didFinishLaunchingWithOptions` method.

If you run the app, nothing is saved to the Sync Gateway. That’s because we disabled the GUEST account in the configuration file.  You can see the 401 HTTP errors in the console:

Run the app, you should see HTTP 401 Unauthorised errors in the Console:

![][image-9]

In the next section, you will add user authentication with Sync Gateway. You can choose to use Facebook Login or Basic Authentication for this workshop.

### STEP 10: Sync Gateway Basic Authentication

Currently, the functionality to create a user with a username/password is not implemented in ToDoLite-iOS or ToDoLite-Android. 

To register users on Sync Gateway, we can use the Admin REST API `_user` endpoint. The Admin REST API is available on post `4985` and can only be accessed on the internal network that Sync Gateway is running on. That’s a good use case for using an app server to proxy the request to Sync Gateway.

For this workshop, the endpoint is `/signup` on port `8080`:

	curl -vX POST -H 'Content-Type: application/json' \
	    -d '{"name": "your username", "password": "your password"}' \
	    http://localhost:8080/signup

You should get a 200 OK if the user was created successfully.

	* Hostname was NOT found in DNS cache
	*   Trying ::1...
	* Connected to localhost (::1) port 8080 (#0)
	> POST /signup HTTP/1.1
	> User-Agent: curl/7.37.1
	> Host: localhost:8080
	> Accept: */*
	> Content-Type: application/json
	> Content-Length: 49
	>
	* upload completely sent off: 49 out of 49 bytes
	< HTTP/1.1 200 OK
	< Content-Type: application/json
	< Date: Mon, 01 Jun 2015 21:57:32 GMT
	< Content-Length: 0
	<
	* Connection #0 to host localhost left intact

Back in the iOS app in AppDelegate.m, create a new method `startReplicationsWithName:withPassword` method to provide a username and password:

- this time use the CBLAuthenticator class to create an authenticator of type basic auth passing in the name and password
- wire up the authenticator to the replications using the `authenticator` method
- call the refactored method in `application:didFinishLaunchingWithOptions`

Notice in the Console that the documents are now syncing to Sync Gateway.

![][image-10]

The solution is on the `workshop/replication_basic_auth` branch.

## 30 minutes: Data orchestration with Sync Gateway Presentation

So far, you’ve learned how to use the Replication and Authenticator classes to authenticate as a user with Sync Gateway. The last component we will discuss is the Sync Function. It’s part of Sync Gateway’s configuration file and defines the access rules for users.

## 30 minutes: Hands-on, Data orchestration

### STEP 11: Using the CBLUITableSource

As we saw in the presentation, a List document is mapped to a channel to which the Tasks are also added. The List model has a `members` property of type NSArray holding the ids of the users to share the list with.

All Profile documents are mapped to the `profiles` channel and all users have access to it.

That way, we can display all the user Profiles and let the user pick who to share the List with. Remember earlier we used a Live Query and a UITableView+UITableDataSource to display a Query result. This time, we will use a higher level abstraction called CBLUITableSource.

The CBLUITableSource class does all the plumbing between the Table View and Data Source for us.

This time, we will work in `ShareViewController.m`. Before that, open the header file and notice the dataSource property is of type CBLUITableSource.

In `viewDidLoad:`:
- create a new variable called `liveQuery` of type LiveQuery. Use the `queryProfilesInDatabase` passing in the current database
- set the `query` property on the `dataSource` to the live query you created above
- set it’s `labelProperty` to `name`
- set the `deletionAllowed` boolean property to `NO`

At this point, you’re done! Try running the app and notice the list all the Profiles documents is there.

![][image-11]

### STEP 12: Sharing a List

Next, we will have to implement two method:
1. Touching a table row should add the selected Profile `_id` to the members of that list
2. The Table View should show a checkmark for Profiles in that List

In `ShareViewController.h`, notice that the class implements the  `CBLUITableDelegate` protocol. Nothing new there, we can implement the `tableView:didSelectRowAtIndexPath:` method:
- using the `indexPath` of the selected row to fetch the corresponding document from the dataSource
- create a new variable called `members` storing the members of that List (remember `list` is a property on that class)
- check if doc id of the selected Profile is in the members array (if YES, remove it, if NO, add it)
- save the list
- add a log statement to print the response from the save operation
- tell the Table View to redraw itself with `reloadData`

Run the app and when clicking a particular cell, you should see the update properties logged to the Console.

![][image-12]

The solution is on the `populating_list_items` branch.

In the next section, we will use the appropriate CBLUITableSource hook to add a checkmark to members.

### STEP 12: Adding a Checkmark for members

Implement the `couchTableSouce:willUseCell:forRow:` method. Notice here that this method has a row parameter of type `CBLQueryRow`. That’s the document for the cell that was clicked:
- check if the doc id of the row object is in the members array of the list document (if YES, set the cell’s accessoryType to checkmark, if NO, set the cell’s accessoryType to None)

![][image-13]

The solution is on the `workshop/final` branch.

### Testing the final result

Run the app, you can now see the different users from the `profiles` channel and share lists with other attendees.

![][image-14]

The result is on the `workshop/final` branch.

## The End

Congratulations on building the main features of ToDoLite. Now you have a deeper understanding of Couchbase Lite and how to use the sync features with Sync Gateway you can start using the SDKs in your own apps.

[1]:	http://packages.couchbase.com/builds/mobile/ios/1.1.0/1.1.0-18/couchbase-lite-ios-community_1.1.0-18.zip
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