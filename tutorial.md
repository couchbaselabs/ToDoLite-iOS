# Couchbase Connect Mobile Workshop iOS

In this workshop, you will learn how to use Couchbase Lite along with Sync Gateway to build a ToDos app with a guest account mode, offline-first capabilities and syncing different ToDo lists to Sync Gateway.

This paper will guide you through the steps to build the application and know all the tips and tricks to building apps with a great look and feel using Couchbase Mobile.

## 30 minutes: Couchbase Mobile Presentation

## 120 minutes: Hands on building Todo-Lite

### Getting started

Download the starter project of ToDoLite [here](https://github.com/couchbaselabs/ToDoLite-iOS/archive/workshop/starter_project.zip). Open the app in Xcode and run it on the simulator.

In the next section, we’ll start building the data models for the application.

Every step of the tutorial are saved to a branch on the GitHub repository. If you find yourself in trouble and want to skip a step or catch up, you can just check out to the next branch. For example, to start at `step4`:

	git checkout refactor_prep

In the source code, you will find comments to help locate where the missing code is meant to go. For example:

	// WORKSHOP STEP 1: missing method to save a new List doc

### Introduction

The topics below are the fundamental aspects of Couchbase Mobile. If you understand all of them and their purposes, you’ll be in a very good spot after ready this tutorial.

- document: the primary entity stored in a database
- revision: with every change to a document, we get a new revision
- view: persistent index of documents in a database, which you then query to find data
- query: the action of looking up results from a view’s index
- attachment: stores data associated with a document, but are not part of the document’s JSON object

Throughout this tutorial, we will refer to the logs in the Xcode debugger to check that things are working as expected. You can open the Xcode debugger with the sliding panel button and `paste shortcut here`.

	Gif to show the opening/closing debug draw

### ToDoLite Data Model

In ToDoLite, there are 3 types of documents: a profile, a list and a task. The List document has an owner and a members array, the Task document holds a reference to the List it belongs to.

![](http://f.cl.ly/items/0r2I3p2C0I041G3P0C0C/Model.png)

### Working with Documents and Revisions

In Couchbase Lite a document’s body takes the form of a JSON object - a collection of key/value pairs where the values can be different types of data such as numbers, strings, arrays or even nested objects.

Documents can have different schemas and every change that is made to a document is saved as a new revision.

The document properties have to be valid JSON types. For other types, we can use Attachments, for example to save an image as we will see later.

Fortunately, the iOS SDK has a CBLModel convenience API that makes it really easy to work with a Document, it’s underlying Revisions and Attachments if they apply.

In the next section, we will learn how to use the CBLModel api to create the List model class.

### STEP 1: Working with CBLModel

Both the List and Task document have a `title` property. For that reason we created a `Titled` class to use the shared initializer. In the `Titled.m`, mark the `title` and `created_at` properties as dynamic. This will ensure there is a 1:1 mapping between the model properties and document properties (in JSON) persisted to Couchbase Lite.

With the newest 1.1 release of Couchbase Mobile, the iOS SDK removed the need to created initialisers for subclasses. We can use the`awakeFromInitializer` method to hook into the initialisation process to set our iVars.

In `awakeFromInitializer`:
- set the `created_at` property to the current time
- set the `type` property to the return value of the `docType` method

Now let’s test this method is working as expected. Open `MasterViewController.m` and complete the `createListWithTitle` method:

- instantiate a new List model with the `modelForNewDocumentInDatabase` method
- set the title property to the parameter that was passed in
- (if there is a `currentUserId` property, set the owner property on the list to the logged in user)

Finally, add a log statement to check that the document was saved.

Run the app and create a couple lists. Nothing will display in the UI just yet but you see the Log statement you added above. In the next section, you will learn how to query those documents.

	Gif to show the document was saved

The solution is on the `workshop/saving_list_document` branch.

### STEP 2: Creating Views

Couchbase views enable indexing and querying of data.

The main component of a view is its **map function**. This function is written in the same language as your app—most likely Objective-C or Java—so it’s very flexible. It takes a document's JSON as input, and emits (outputs) any number of key/value pairs to be indexed. The view generates a complete index by calling the map function on every document in the database, and adding each emitted key/value pair to the index, sorted by key.

You will find the `queryListsInDatabase` method in `List.m` and the objective is to add the missing code to index the List documents. The emit function will emit the List title as key and null as the value.

In sudo code, the map function will look like:

	var type = document.type;
	if document.type == "list"
	    emit(document.title, null)

The solution is on the `workshop/create_views` branch.

### STEP 3: Query Views

A query is the action of looking up results from a view's index. In Couchbase Lite, queries are objects of the Query class. To perform a query you create one of these, customise its properties (such as the key range or the maximum number of rows) and then run it. The result is a QueryEnumerator, which provides a list of QueryRow objects, each one describing one row from the view's index.

Now you have created the view to index List documents, you can query it. In `MasterViewController.m`, add the missing code to `setupTodoLists` method to run the query.

Iterate on the result and log the title of every List document. If you saved List documents in Step 1, you should now see the titles in the Console.

	Gif to show the logs

The solution is on the `workshop/query_views` branch.

At this point, we could pass the result enumerator to a Table View Data Source to display the lists on screen. However, we will jump slightly ahead of ourselves and use a Live Query to have Reactive UI capabilities. 

### STEP 4: A Table View meets a Live Query

Couchbase Lite provides live queries. Once created, a live query remains active and monitors changes to the view's index, notifying observers whenever the query results change. Live queries are very useful for driving UI components like lists.

We will use the query to populate a Table View with those documents. To have the UI automatically update when new documents are indexed, we will use a Live Query.

### STEP 5: Using the UITableDataSource

Back in `setupTodoLists` of `MasterViewController.m`, we will need to make slight changes to accommodate for a live query instead of a simple query. There is a `liveQuery` property on the Main Activity class that we can use in `setupTodoLists`:

- initialise the `self.liveQuery` with the query from Step 4 (all queries have a `toLiveQuery` method we can use to convert the query into a Live Query)
- add a KVO observer on the `rows` property of the liveQuery object
- in the `observeValueForKeyPath:ofObject:change:context:` handle the changes, set the `self.listsResults` to the new results. The rows result has a `allObjects` method to return an array
- reload the tableview with the `reloadData`

Finally, we need to implement the required methods of the `UITableViewDataSource`:
- return the number of elements in `listsResult` for the number rows in section
- in the `cellForRowAtIndexPath` method set the textLabel’s text property of the cell to the title property of the List

Run the app on the simulator and start creating ToDo lists, you can see they are persisted and displayed in the Table View.

![](http://i.gyazo.com/e7faa2e8a395a12bf4ce8315372f8a71.gif)

The solution is on the `workshop/persist_task_document` branch.

### STEP 6: Persist the Task document

To create a Task model and persist it, open `List.m` and complete the body of the method `addTaskWithTitle:withImage:withImageContentType:`:
- initialise a Task model with the `modelForNewDocumentInDatabaseMethod:`
- set the title to the parameter that was passed in
- set the `list_id` to self, notice here again that we are using a relationship between two models, the List and Task. This will translate to the id of the List in the underlying JSON document
- finally, return the task object

	need steps on where to call it

![](http://i.gyazo.com/68dfc680dc38813aa0c6ff144697ef4c.gif)

However, a Task document can have an image. In Couchbase Lite, all binary properties of documents are called attachments. The Document api doesn’t allow to save an attachment. To do so, we’ll have to go one step further and use the underlying Revision api.

### STEP 7: Working with Attachments and Revisions

- use `setImage:contentType:` on the task using the image (NSData) that was passed in

The solution is on the `workshop/attachments_and_revisions ` branch.

## 30 minutes: Sync Gateway in-depth

The goal is to add the sync feature to our application. The speaker will go through the steps to install Sync Gateway and get it running with Couchbase Server.

Then, we will all attempt to connect to the same instance of Sync Gateway running [here](#).

## 30 minutes: Hands-on, Replications

### STEP 8: Replications without authentication

In `AppDelegate.m`, create a new method called `startReplications` to create the push/pull replications:

- initialise a new NSURL object. The string url for this tutorial is `http://todolite-syncgateway.cluster.com`
- initialise the pull replication with the `createPullReplication` method
- initialise the push replication with the `createPushReplication` method
- set the continuous property to true on both replications
- call the `start` method on each replication
	 
Finally, call the `startReplications` method in the `application:didFinishLaunchingWithOptions` method.

If you run the app, nothing is saved to the Sync Gateway. That’s because we disabled the GUEST account in the configuration file.  You can see the 401 HTTP errors in the console:

	Gif TBA

The solution is on the `workshop/replication` branch.

In the next section, you will add user authentication with Sync Gateway. You can choose to use Facebook Login or Basic Authentication for this workshop.

### STEP 9: Sync Gateway Basic Authentication

Currently, the functionality to create a user with a username/password is not implemented in ToDoLite-iOS or ToDoLite-Android. But you can create one using the ToDoLite-Web app, the demo app is available at `http://todolite-web.herokuapp.com` and is connecting to the same Sync Gateway instance.

Create a new user account on the [signup page](#). 

Back in the iOS app in AppDelegate.m, refactor the `startReplications` method to provide a username and password:

- rename the `startReplications` method to take the login credentials as arguments `startReplicationsWithUsername:withPassword:`
- refactor the method to use those credentials to instantiate a new `authenticator` of type Authenticator
- wire up the authenticator to the replications using the `authenticator` method
- call the refactored method in `application:didFinishLaunchingWithOptions`.

Notice in the Console that the documents are now syncing to Sync Gateway.

	Gif TBA

The solution is on the `workshop/replication_basic_auth` branch.

### STEP 10: Sync Gateway Facebook Authentication

If you logged into the app with Facebook then the access token should be saved to the NSUserDefaults and we can retrieve it using the `` method.

- rename the `startReplications` method to take the Facebook access token as argument `startReplicationsWithFacebook(String accessToken)`
- refactor the method to use the access token to instantiate a new `authenticator` of type Authenticator
- wire up the authenticator to the replications using the `setAuthenticator` method
- call the refactored method in the `onCreate` method

Notice in LogCat that the documents are now syncing to Sync Gateway.

	Gif TBA

## 30 minutes: Data orchestration with Sync Gateway

So far, you’ve learned how to use the Replication and Authenticator classes to authenticate as a user with Sync Gateway. The last component we will discuss is the Sync Function. It’s part of Sync Gateway’s configuration file and defines the access rules for users.

## 30 minutes: Hands-on, Data orchestration

### STEP 11: The Share View

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

Next, we will have to implement two method:
1. Touching a table row should add the selected Profile `_id` to the members of that list
2. The Table View should show a checkmark for Profiles in that List

In `ShareViewController.h`, notice that the class implements the  `CBLUITableDelegate` protocol. Nothing new there, we can implement the `tableView:didSelectRowAtIndexPath:` method:
- using the `indexPath` of the selected row to fetch the corresponding document from the dataSource
- create a new variable called `memebers` storing the members of that List (remember `list` is a property on that class)
- check if doc id of the selected Profile is in the members array (if YES, remove it, if NO, add it)
- save the list
- add a log statement to print the response from the save operation
- tell the Table View to redraw itself with `reloadData`

Run the app and when clicking a particular cell, you should see the update properties logged to the Console.

	Gif to show the properties updating

The solution is on the `populating_list_items` branch.

In the next section, we will use the appropriate CBLUITableSource hook to add a checkmark to members.

### STEP 12: Adding a Checkmark for members

Implement the `couchTableSouce:willUseCell:forRow:` method. Notice here that this method returns passes a row of type `CBLQueryRow`. That’s the document for the cell that was clicked:
- check if the doc id of the row object in is the members array of the list document (if YES, set the cell’s accessoryType to checkmark, if NO, set the cell’s accessoryType to None)

	Gif to show the checkmark displaying

The solution is on the `workshop/final` branch.

## The End

Congratulations on building the main features of ToDoLite. Now you have a deeper understanding of Couchbase Lite and how to use the sync features with Sync Gateway you can start using the SDKs in your own apps.
