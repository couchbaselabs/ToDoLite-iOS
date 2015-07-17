# Couchbase Mobile ワークショップ iOS

このワークショップでは、オフラインファーストに対応し、アクセス制御ルールを持って他のユーザとドキュメント共有が可能なTODOアプリを開発するために、Couchbase LiteをSync Gatewayと組み合わせ利用する方法を学びます。

このドキュメントはアプリケーション開発手順を解説し、Couchbase Mobileを利用して素晴らしいルックアンドフィールを持つアプリを開発する際のティップスや、つまずきやすい点についても解説していきます。

## Couchbase Liteの詳細なプレゼンテーション

プレゼンテーションスライドは[こちら](http://www.slideshare.net/Couchbase/mobile-workshop-couchbase-lite-indepth)にあります。

## 90分: Todo-Lite開発ハンズオン

### 環境設定

アプリケーションをToDoLite-iOSリポジトリからクローンします:

	git clone https://github.com/couchbaselabs/ToDoLite-iOS
	cd ToDoLite-iOS
	git checkout workshop/start

バージョン1.1のリリースを[こちら][1]からダウンロードし、zipファイルを展開します。`CouchbaseLite.framework`ファイルをFrameworksフォルダにドラッグします。

![][image-1]

### はじめに

Couchbase Mobileの基本となるトピックを以下に記載します。
これらのオブジェクトと利用用途を理解できたら、このチュートリアルを実施後に、非常に有用な知識が身に付いているでしょう。

- document: データベース内に保存されるプライマリなエンティティ
- revision: ドキュメントに変更を加えると、新規revisionが作成される
- view: データベース内のドキュメントに対する永続的なインデックス、これを利用してクエリを実行しデータを探す
- query: Viewインデックスから結果をルックアップするアクション
- attachment: ドキュメントのJSONオブジェクトの一部としてではなく、ドキュメントに関連するデータを保存する

このチュートリアルでは、物事が期待するように動作しているかを確認するために、Xcodeデバッガのログを参照します。スライディングパネルボタンと、`⌘ + ⇧ + Y`でXcodeデバッガを表示できます。

![][image-2]

### ToDoLite データモデル
ToDoLiteには、3種類のドキュメントがあります: Profile、List、そしてTaskです。
Listドキュメントはオーナとメンバの配列を保持しており、Taskドキュメントは属するListへの参照を保持しています。

![][image-3]

### ドキュメントとリビジョンを扱う

Couchbase LiteのドキュメントボディはJSONオブジェクト形式となります - key/valueペアの集合で、バリューには数値、文字列、配列、さらには入れ子構造のオブジェクトといった様々なデータ型を利用できます。

ドキュメントは異なるスキーマを持つことができ、ドキュメントを変更するたびに、新しいリビジョンとして保存されます。

ドキュメントのプロパティは有効なJSON型でなければなりません。その他の型には、アタッチメントを利用します、例えば、後ほど出てくる、画像を保存する場合などです。

幸運にも、iOS SDKにはCBLModelという便利なAPIがあり、ドキュメントとそのリビジョン、そしてアタッチメントを非常に簡単に扱うことができます。

次のセクションでは、Listモデルクラスを作成するための、CBLModel APIの利用方法を学びます。

### ステップ 1: データベースを作成する

`AppDelegate.h`を開き、CBLDatabase型のdatabaseというプロパティがあることを確認してください。このプロパティを利用してアプリケーションからデータベースへのアクセスを行います。

`AppDelegate.m`で、`createDatabase`という名前の新規メソッドを、以下のコードで追加します:

- CBLManager共有インスタンスの`databaseNamed:error`メソッドを使って、`todosapp`というデータベースを新規作成します
- 作成したデータベースオブジェクトで`_database`を初期化します

`application:didFinishLaunchingWithOptions:`メソッドから、createDatabaseメソッドを呼び出します。

まだデータベースには何もドキュメントが保存されていません。Profileドキュメントを追加してみましょう:

- `_currentUserId`をお好きなユーザIDで初期化します

データモデル図に示されるように、Listドキュメントはownerプロパティに、そのListを所有するProfileドキュメントの`_id`を保持しています。Listを作成する前に、Profileドキュメントを作成する必要があります:

- Profileの`profileInDatabase:forNewUserId:name`を実行し、databaseと現在のユーザIDとお好きな名前を渡します。すると、新しいProfileモデルのインスタンスが返されます
- Profileモデルのsaveを実行し、プロパティをコンソールに出力しましょう

アプリを起動すると、Profileドキュメントのプロパティがコンソールに表示されるはずです:

![][image-4]

### ステップ 2: CBLModelを利用する

ListとTaskドキュメントはどちらも、`title`プロパティを持っています。このため、両プロパティに設定する挙動を抽象化するために、`Titled`クラスを作成しています。

`Titled.h`で:

- `title`プロパティをNSStringで追加します
- `created_at`プロパティをNSDateで追加します

`Titled.m`で:

- `title`と`created_at`プロパティを@dynamicとしてマークします

CBLModelサブクラスのdynamicプロパティの詳細な利用方法は、[こちら][2]を参照してください。

次に、`awakeFromInitializer`メソッドを使って、iVarの設定を初期化処理にフックしましょう。

`awakeFromInitializer`で:

- `created_at`プロパティに現在時刻を設定します
- `type`プロパティに`docType`メソッドの戻り値を設定します (`[[self class] docType]`)

このメソッドが期待通り動作するかテストしましょう。`MasterViewController.m`を開き、`createListWithTitle`メソッドを実装します:

- `modelForNewDocumentInDatabase`クラスメソッドを利用して、新しいListモデルを生成します
- 引数で渡されたtitleをtitleプロパティに設定します
- `profileInDatabase:forExistingUserId:`メソッドにcurrentUserIdを渡してProfileオブジェクトを取得します
- Listのownerプロパティに、Profileモデルを設定します
- `save`メソッドを利用して、ListモデルをCouchbase Liteに保存します
- モデルが保存されたかチェックするために、モデルクラスのdocumentプロパティを利用して、コンソールにプロパティを出力しましょう (`[[list document] properties]`)
- listオブジェクトを返しましょう

アプリを実行してリストをいくつか作成しましょう。UIにはまだ何も表示されませんが、先に追加したログが表示されるはずです。次のセクションでは、これらのドキュメントのクエリ方法を学びます。

![][image-5]

### ステップ 3: Viewの作成

CouchbaseのViewはデータのインデクシング、クエリを可能とします。

Viewの主なコンポートは、**map関数**です。この関数はアプリの開発言語と同じ言語 - Objective-CまたはJavaなど - で記述でき、非常にフレキシブルです。ドキュメントのJSONを入力とし、任意の数のkey/valueペアをインデックス用にemit(出力)します。Viewはデータベース内のすべてのドキュメントに対しmap関数を実行し、emitされた各key/valueペアをインデックスに追加することで、keyでソートされた、完全なインデックスを生成します。

`List.m`にある`queryListsInDatabase`で、Listドキュメントをインデクシングするために不足しているコードを追加しましょう:

- dbの`viewNamed`メソッドを利用し、viewの変数を作成します (このviewは"lists"という名前にしましょう)
- `setMapBlock:version:`を利用し、map/reduce関数を設定します
- docのtypeが"list"であることをチェックします
- Listのtitleをkeyに、valueをnullとしてemitします
- このviewを初めてデータベースに登録するので、バージョン番号は1.0とします

Objective-Cでのmap/reduce viewシンタックスの例は、[こちら][3]を参照してください。

map関数の実装を疑似コードで示すと次のようになります:

	var type = doc.type;
	if doc.type == "list"
	    emit(doc.title, null)

### ステップ 4: Viewのクエリ

クエリはViewインデックスから結果をルックアップするアクションです。Couchbase Liteでは、クエリはQueryクラスのオブジェクトです。クエリを実行するには、これを生成し、プロパティを変更して(キーの範囲や最大行数など)、実行します。結果はQueryEnumeratorとなり、Viewインデックス結果の一行一行を表現する、QueryRowオブジェクトのリストを提供します。

ListドキュメントのViewを作成したので、クエリできるようになりました。`MasterViewController.m`で`setupTodoLists`に不足しているコードを追加しましょう:

- 先に作成したListクラスのメソッドを使用して、`query`という変数を`CBLQuery`型で作成します
- クエリを実行(run)し、`results`という変数を`CBLQueryEnumerator`型で作成します

CBLQueryEnumeratorはCBLQueryRowオブジェクトのenumeratorです。結果をイテレートし、各Listドキュメントのタイトルをログに出力しましょう。便利なenumerationショートカットを利用して、高速に各CBLQueryRowのタイトルをプリントしましょう。

![][image-6]

ステップ 2でListドキュメントを保存していれば、コンソールにタイトルが表示されるはずです:

![][image-7]

この時点で、画面にListを表示するためのTable View Data Sourceとして、結果のenumeratorを渡すことができます。しかしもう少し先に進んで、リアクティブなUIを実装するために、Live Queryを使ってみましょう。

### ステップ 5: Table View と Live Query

Couchbase LiteではLive Queryを利用できます。一度作成すると、Live Queryは継続して動作し、Viewインデックスの変更を監視し、クエリの結果が変わる際にObserverへ通知します。Live QueryはlistのようなUIコンポーネントを扱う際に非常に便利です。

クエリを利用してドキュメントを利用するTavle Viewを生成します。ドキュメントがインデクシングされた時に、自動的に更新されるUIを実装するため、Live Queryを利用します。

### ステップ 6: Tavle View Data Source と Live Query の記述

`MasterViewController.m`の`setupTodoLists`に戻り、単純なクエリの代わりにLive Queryを利用する変更を少し加える必要があります。MasterViewControllerクラスに、`setupTodoLists`から利用できる`liveQuery`プロパティがあります:

- `self.liveQuery`プロパティをステップ 4のqueryで初期化します (すべてのクエリはLive Queryへと変換できる`asLiveQuery`メソッドを持っています)
- liveQueryオブジェクトの`rows`プロパティに対して、selfをKVO observerとして追加します (optionsとcontextには0を指定します)
- `observeValueForKeyPath:ofObject:change:context:`メソッド内で、変更を処理します: `self.listsResults`に新しい結果をセットしましょう。`self.liveQuery`はrowsプロパティを持っています (CBLQueryEnumerator)。そして、rowsプロパティにはNSArrayの`allObjects`プロパティがあります。
- tableviewを`reloadData`メソッドでリロードします

最後に、UITableViewDataSourceで必要なメソッドを実装します、`tableView:numberOfRowsInSection:`と、 `tableView:cellForRowAtIndexPath:`です:

- `tableView:numberOfRowsInSection:`では、`listResult`配列内の要素の数を返します
- `tableView:cellForRowAtIndexPath:`メソッドでは、"List"型のtable viewのcellをdequeueします
- `CBLQueryRow`型の新規変数、rowを作成し、`listsResult`内の、indexPath.rowの位置にあるアイテムを設定します
- UITableViewsのデフォルトのcellにはText Label (textLabel)があり、このcellのtextプロパティにListのtitleプロパティを設定します。今回は単純なので、新しいListモデルを生成する代わりに、`[row.document propertyForKey:@"title"]`を使用しましょう。

シミュレータ上でアプリを動かし、ToDoリストを作成してみましょう、今度はTable Viewにリストが表示されるはずです。

![][image-8]

### ステップ 7: Task ドキュメントを保存する

Taskモデルを作成して保存するには、`List.m`を開いて、`addTaskWithTitle:withImage:withImageContentType:`メソッドの実装を完成させます:

- `modelForNewDocumentInDatabaseMethod:`メソッドを使用してTaskオブジェクトを作成します、databaseパラメータには、`self.database`を渡します
- titleには、引数で渡されたパラメータを指定します
- `list_id`にはselfを設定します、ここで二つのモデル間でリレーションを利用しているのを思い出してください。これはListのJSONドキュメント内の`_id`を設定していることになります。
- taskオブジェクトの`setAttachmentNamed:withContentType:content:`を使用します、アタッチメントの名前は`image`とし、contentTypeとcontentには引数のパラメータを指定します
- 最後に、taskオブジェクトを返します

`DetailViewController.m`を開き、`textFieldShouldReturn:`からこのメソッドを呼び出します:
- self.listの`addTaskWithTitle:withImage:withImageContentType:`を利用して、taskという変数を作成します、title、imageを渡し、contentTypeには"image/jpg"を指定します
- saveメソッドを使用してtaskオブジェクトを保存しましょう

![][image-9]

## Sync Gateway の詳細なプレゼンテーション

ゴールはこのアプリケーションに同期機能を追加することです。スピーカがSync Gatewayのインストール手順と、Couchbase Serverと連携して動作させる方法を説明します。

同一のSync Gatewayインスタンスに接続してみましょう。

プレゼンテーションスライドは[こちら](http://www.slideshare.net/Couchbase/mobile-workshop-sync-gateway-indepth-couchbase-connect-2015)にあります。

## 30分: ハンズオン、レプリケーション

### ステップ 8: 認証なしのレプリケーション

`AppDelegate.m`に、`startReplications`という新しいメソッドを作成し、push/pullレプリケーションを作成しましょう:

- 新規のNSURLオブジェクトを初期化します。このチュートリアルではurlストリングに`http://localhost:4984/todos`を利用します。
- databaseオブジェクトの`createPullReplication`メソッドを使用して、pullレプリケーションを作成します
- databaseオブジェクトの`createPushReplication`メソッドを使用して、pushレプリケーションを作成します
- 両レプリケーションで、continuousプロパティをtrueに設定します
- それぞれのレプリケーションで`start`メソッドを呼び出します

最後に、`application:didFinishLaunchingWithOptions`メソッドから`startReplications`メソッドを呼び出します。

**注意:** 上記のurlを、localhostからワークショップで利用可能なホスト名に変更してください。

アプリを実行しても、Sync Gatewayには何も保存されません。なぜなら、GUESTアカウントを設定ファイルで無効にしているからです。コンソールには401 HTTPエラーが表示されます:

アプリを起動して、HTTP 401 Unauthorisedエラーがコンソールに表示されることを確認しましょう:

![][image-10]

次のセクションでは、Sync Gatewayでのユーザ認証を追加します。このワークショップでは、Facebook Loginまたはベーシック認証を選択できます。

### ステップ 9: Sync Gateway ベーシック認証

現在、ToDoLite-iOS、ToDoLite-Androidでは、ユーザ名/パスワードを指定してユーザを作成する機能は実装されていません。

Sync Gatewayにユーザを登録するには、Admin REST APIの`_user`エンドポイントを利用します。Admin REST APIは`4985`ポートで利用可能で、Sync Gatewayが稼働している内部ネットワークからのみアクセスできます。アプリケーションサーバを利用してリクエストをSync Gatewayにプロキシするのは良い方法です。

このワークショップでは、`8080`ポートの`/signup`エンドポイントを利用し、nameにはステップ 1で決めたcurrentUserIdを指定します:

	curl -vX POST -H 'Content-Type: application/json' \
	    -d '{"name": "your username", "password": "your password"}' \
	    http://localhost:8080/signup

**注意:** 上記のurlを、localhostからワークショップで利用可能なホスト名に変更してください。


ユーザが正常に作成されると、200 OKが返却されるはずです。

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

iOSアプリに戻り、AppDelegate.mに、新しく`startReplicationsWithName:withPassword`メソッドを作成し、usernameとpasswordを指定できるようにします:

- 今回はCBLAuthenticatorクラスを利用して、ベーシック認証型のauthenticatorを作成しましょう、usernameとpasswordを指定します (ステップ 1で決めたcurrentUserIdを思い出してください)
- authenticatorをレプリケーションの`authenticator`メソッドを利用して設定します
- リファクタリングしたメソッドを`application:didFinishLaunchingWithOptions`から実行します

コンソールで、今度はSync Gatewayにドキュメントが同期されていることを確認しましょう。

![][image-11]

## Sync Gateway でのデータオーケストレーション プレゼンテーション

これまで、ReplicationやAuthenticatorクラスを利用して、Sync Gatewayでユーザ認証を行う方法を学んできました。最後に扱うコンポーネントはSyncファンクションです。Sync Gatewayの設定ファイルの一部であり、ユーザのアクセスルールを定義します。

プレゼンテーションスライドは[こちら](http://www.slideshare.net/Couchbase/mobile-workshop-data-orchestration)にあります。

## 30分: ハンズオン、データオーケストレーション

### ステップ 10: CBLUITableSourceを利用する

プレゼンテーションで紹介したように、各Listドキュメントは個別のチャネルにマッピングされ、そのチャネルにTaskも追加されます。ListモデルはNSArrayの`members`プロパティを持ち、Listを共有するユーザのIDを保持します。

すべてのProfileドキュメントは`profiles`チャネルにマッピングされ、すべてのユーザはこのチャネルへアクセスできます。

こうすることで、すべてのユーザProfileを表示でき、ユーザがListをシェアするユーザを選べるようにしています。先のセクションでは、Live Queryと、UITableView + UITableDataSourceを使ってQueryの結果を表示していました。今回は、より高度に抽象化されたCBLUITableSourceを呼び出します。

CBLUITableSourceクラスはTable ViewとDeta Source間で必要な連携をすべて実行してくれます。

今回は、`ShareViewController.m`内でコーディングをします。その前に、ヘッダファイルを開き、CBLUITableSource型のdataSourceプロパティを確認しましょう。

`viewDidLoad:`で:
- LiveQuery型の`liveQuery`という変数を新しく作成します。Profileの`queryProfilesInDatabase`クラスメソッドに利用中のdatabaseを渡します
- `dataSource`の`query`プロパティに、作成したLive Queryを設定します。
- `labelProperty`に`name`を設定します。labelPropertyはcellのTextLabelを生成するために利用する対象ドキュメントのプロパティです。

これで完了です! アプリを起動し、すべてのProfileドキュメントが表示されることを確認しましょう。

![][image-12]

### ステップ 11: Listをシェアする

次に、二つのメソッドを実装する必要があります:

1. Tableのrowをタッチした際に、選択したProfileの`_id`を現在のListのmembersに追加します
2. Table Viewで、Listに追加されたProfileにチェックマークを表示します

`ShareViewController.h`で、このクラスが`CBLUITableDelegate`プロトコルを実装していることを確認しましょう。何も新しいことはありませんが、`tableView:didSelectRowAtIndexPath:`メソッドを実装しましょう:
- 選択された行の`indexPath`を利用し、関連するドキュメントをdataSourceのrowAtIndexPathメソッドで取得します
- 新しい`members`という、配列の変数を作成し、Listのmembersを設定します (このクラスの`list`プロパティに現在のListオブジェクトがあります)
- create a new variable named `selectedUserId` that’s the documentID of the user that was selected
- `selectedUserId`という新しい変数を作成し、選択されたユーザのdocumentIDを格納します
- `selectedUserId`の値がmembers配列内にあるかチェックします (あるなら削除し、ないなら追加します)
- listの`members`プロパティを新しい値で更新します
- 更新されたlistオブジェクトを保存します
- save実行結果をログに出力します
- tell the Table View to redraw itself with `reloadData`
- Table Viewの`reloadData`で再描画します

アプリを実行して、cellをクリックすると、コンソールログに更新されたプロパティが出力されるはずです。

![][image-13]

次のセクションでは、CBLUITableSourceフックを適切に利用し、メンバにチェックマークを追加します。

### ステップ 12: メンバにチェックマークを追加する

`couchTableSouce:willUseCell:forRow:`メソッドを実装します。このメソッドは`CBLQueryRow`型のパラメータを持っています。これが、クリックされたcellのドキュメントになります:

- listドキュメントのmembers配列内にrowオブジェクトのdoc idが存在するかチェックします (存在すれば、cellのaccessoryTypeをcheckmarkに設定し、存在しなければ、cellのaccessoryTypeをNoneに設定します)

![][image-14]

### 最終結果をテストする

アプリを実行すると、`profiles`チャネルから異なるユーザを閲覧でき、Listを他の参加者の方と共有できるようになります。

![][image-15]

最終的な実装は`workshop/final`ブランチにあります。

## おわりに

おめでとうございます、これでToDoLiteのメイン機能が実装できました。Couchbase Liteと、Sync Gatewayのsync機能の利用方法への理解が深まったと思います、是非、アプリ開発にSDKをご利用ください。

[1]:	http://packages.couchbase.com/builds/mobile/ios/1.1.0/1.1.0-18/couchbase-lite-ios-community_1.1.0-18.zip
[2]:	http://developer.couchbase.com/mobile/develop/guides/couchbase-lite/native-api/model/index.html
[3]:	http://developer.couchbase.com/mobile/develop/guides/couchbase-lite/native-api/view/index.html#source_doc

[image-1]:	http://i.gyazo.com/71ba8ac8f36835f86ffc8d570708cec6.gif
[image-2]:	http://i.gyazo.com/7fa47e35c349c1936f2713acd18327e9.gif
[image-3]:	http://f.cl.ly/items/0r2I3p2C0I041G3P0C0C/Model.png
[image-4]:	http://i.gyazo.com/58f2f18f3a05651301a96792de7df373.gif
[image-5]:	http://i.gyazo.com/11fa6533027e17d316d64c059b8c42f5.gif
[image-6]:	http://i.gyazo.com/71f90e71e87e7ae9eccd545d41384b2a.gif
[image-7]:	http://i.gyazo.com/20e60cb13ba987f42970c5d04a495423.gif
[image-8]:	http://i.gyazo.com/359ac7a252f57f889649d74c2228e675.gif
[image-9]:	http://i.gyazo.com/bb951a6b846793c0bb38532c22d6f90b.gif
[image-10]:	http://i.gyazo.com/c874e2e1f48242eb93fb8ec1d843c30f.gif
[image-11]:	http://i.gyazo.com/3de9c203a9b37d57652e2aadef290069.gif
[image-12]:	http://i.gyazo.com/755327503b7f5c3e36dd2d816fedae62.gif
[image-13]:	http://i.gyazo.com/6ad24bd77513506a6869a1ce78c0a242.gif
[image-14]:	http://i.gyazo.com/22dd85add78a4283938fab9bb955161e.gif
[image-15]:	http://i.gyazo.com/80c7dda4371ecf2343d2fe36c59890e1.gif
