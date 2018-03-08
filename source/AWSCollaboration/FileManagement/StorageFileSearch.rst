インターネットストレージ内ファイルの効率的な検索
================================================================================

.. only:: html

 .. contents:: 目次
    :depth: 3
    :local:

Overview
--------------------------------------------------------------------------------
| 本ガイドラインでは、AWSの提供するインターネットストレージ S3（Amazon Simple Storage Service）を利用する際に、高度な検索条件を指定してファイルの検索、取得を行うための方法を説明する。

| S3は登録ファイルにオブジェクトキー文字列を付与して保管し、同様にオブジェクトキー文字列を指定することで目的のファイルを取得する。
| こうしたオブジェクトキー文字列を指定して直接目的のファイルを取得するケースには対応しているが、ファイル名や作成日、作成者といった、取得条件を指定したファイル検索には対応していないため、ファイル検索を実現するためには登録ファイルを全て取得して1つずつ取得条件との一致を確認しなくてはならなくなる。
| しかしこの方法では登録ファイルの増加とともに検索処理の負荷も増加し、レスポンスの悪化も見込まれるため現実的ではない。

| これを解決するため、登録ファイルのオブジェクトキー文字列と取得条件となる情報を組み合わせて持つことができ、かつそれら情報を指定した検索も容易なKVSを検索処理に利用する。
| :ref:`storage-file-search-label` に則って検索性能の高いKVSを利用してファイルを特定し、特定されたファイルをS3から取得することで、高度な検索条件を指定したファイル検索、取得を実現する。

| KVSにはAWSの提供するDynamoDBを利用し、ファイルの検索情報としてオブジェクトキーおよびメタデータ（作成日、作成者、サイズなど）を登録する。
| また、S3へのファイル登録とDynamoDBへの検索情報登録を一連の処理として実行する必要があるため、S3の更新をトリガーとしてDynamoDBの登録処理を実行する仕組みが必要となる。
| この仕組みはS3の更新イベントを受信してDynamoDBへの検索情報登録を行うイベントリスナーを作成することで実現する。
| イベントの連携にはAWSの提供するSQS（Simple Queue Service）を利用する。


  .. figure:: ./imagesStorageFileSearch/StorageFileSearchOverview.png
    :alt: Screen image of storage file search overview.
    :width: 100%

  .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
  .. list-table::
    :header-rows: 1
    :widths: 10 90

    * - 項番
      - 説明
    * - | (1)
      - | クライアントはアップロードしたいファイルに対して任意のオブジェクトキーを設定し、S3のバケットへファイルをアップロードする。
        | （ファイルの削除をしたい場合は削除対象のファイルのオブジェクトキーを指定することにより、S3のバケットからファイルを削除する。）
    * - | (2)
      - | Createイベント（またはDeleteイベント）がイベントメッセージとしてSQSへ通知される。
    * - | (3)
      - | イベントリスナーがイベントメッセージを受信する。
    * - | (4)
      - | イベントメッセージから更新対象のファイル情報を取得する。
        | Createイベントを受信した場合はファイル情報をDynamoDBへ検索情報として登録する。
        | Deleteイベントを受信した場合はDynamoDBから検索情報を削除する。
    * - | (5)
      - | クライアントはDynamoDBを検索するアプリケーションを利用してダウンロード条件に一致するファイルを検索し、対象ファイルのオブジェクトキーを取得する。
    * - | (6)
      - | クライアントはDynamoDBから取得したオブジェクトキーを利用して、S3のバケットからファイルをダウンロードする。

|

.. _storage-file-search-overview-event-label:

Amazon S3のイベント通知機能
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
| S3にはイベント通知機能が備わっており、バケット内で特定のイベントが発生した際に通知メッセージを送出することができる。
| イベント通知の設定はバケット単位に行い、通知対象とするイベントとその通知先の組み合わせを指定することができる。

| 発生するイベントについては `イベント通知のタイプおよび送信先 <http://docs.aws.amazon.com/ja_jp/AmazonS3/latest/dev/NotificationHowTo.html#notification-how-to-event-types-and-destinations>`_ を参照されたい。

| 通知メッセージの構造については `イベントメッセージの構造 <http://docs.aws.amazon.com/ja_jp/AmazonS3/latest/dev/notification-content-structure.html>`_ を参照されたい。

|

.. _storage-file-search-overview-metadata-label:

メタデータの格納先
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
| アップロードしたファイルを高度な検索によって取得できるようにするため、検索用の情報としてファイルのメタデータ（作成日、作成者、サイズなど）をKVSに登録しておく。
| ファイルのメタデータはイベントメッセージより取得する。

.. note::
  DynamoDBに登録する検索情報は、情報量が多くなることにより検索性能にも影響が出るため、実現したい「高度な検索」の要件に応じた登録情報を検討し、不必要な情報は登録しないようにすることが望ましい。

.. note::
  本ガイドラインではメタデータの登録先にDynamoDBを使用しているが、登録先は検索要件に応じて選択することができる。
  詳細は :ref:`storage-file-search-extend-metadata2-label` を参照されたい。

.. note::
  本ガイドラインでは検索用情報としてイベントメッセージから取得できる情報のみを登録しているが、検索要件に応じてイベントメッセージに含まれない情報も別途取得して登録することができる。
  詳細は :ref:`storage-file-search-extend-metadata1-label` を参照されたい。

|

How to use
--------------------------------------------------------------------------------
ライブラリの使い分け
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

| DynamoDBへのアクセスはspring-data-dynamodbまたはAmazon SDK for Javaを使用することで実装可能であるが、両者の使い分けについて説明する。
| spring-data-dynamodbによる実装では、Spring Framework が提供する\ ``CrudRepository``\ インターフェースにより、Spring Data と親和性のあるリソースアクセスの抽象化が可能である。
| 一方で Spring Data 仕様に寄せられていることにより、DynamoDBアクセス固有の機能についてはいくつか制限がある。
| spring-data-dynamodbの詳細については、 `Spring Data DynamoDB# <https://github.com/michaellavelle/spring-data-dynamodb>`_ を参照されたい。
| 対してAmazon SDK for JavaではDynamoDB用の高レベルプログラミングインターフェイス\ ``DynamoDBMapper``\ を利用することにより、参照・更新の都度\ ``DynamoDBMapperConfig.ConsistentReads``\、\ ``DynamoDBMapperConfig.SaveBehavior``\によるきめ細かいオプションを指定することができる。

| 本項ではS3のオンデマンドな更新に対し整合性を保ったメタデータの登録を実現させるために、上記機能が利用できるAmazon SDK for Javaを利用する。

|

.. _storage-file-search-s3-label:

Amazon S3の設定
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. _storage-file-search-s3-event-label:

SQSへのS3イベントの通知
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
| 本ガイドラインではS3の特定バケットへのファイルの登録、更新、削除のイベントを受信したいため、以下のイベントをSQSに通知するよう設定する。
| 設定方法は `S3 バケットのイベント通知を有効化および設定する方法 <http://docs.aws.amazon.com/ja_jp/AmazonS3/latest/user-guide/enable-event-notifications.html>`_ を参照されたい。
| なお、ファイルの更新は登録イベントとして通知されるため、\ ``ObjectCreate (All)``\ のイベント設定によって登録、更新のイベント通知がまとめて設定される。
| 登録、更新の判別は後述する :ref:`storage-file-search-metadata-label` にてDynamoDBにメタデータが登録済であるか否かで行う。
|

.. tabularcolumns:: |p{0.20\linewidth}|p{0.20\linewidth}|p{0.10\linewidth}|p{0.10\linewidth}|p{0.10\linewidth}|p{0.30\linewidth}|
.. list-table::
  :header-rows: 1
  :widths: 20 20 10 10 10 30

  * - 名前
    - イベント
    - プレフィックス
    - サフィックス
    - 送信先
    - SQS
  * - Create ※任意
    - ObjectCreate (All)
    - －
    - －
    - SQSキュー
    - イベント通知先として作成したSQSキュー
  * - Delete ※任意
    - ObjectDelete (All)
    - －
    - －
    - SQSキュー
    - イベント通知先として作成したSQSキュー

|

.. _storage-file-search-dynamodb-label:

Amazon DynamoDBの設定
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
| DynamoDBについては :ref:`aws-dynamodb` を参照されたい。

.. _storage-file-search-dynamodb-index-label:

テーブルおよびセカンダリインデックスの作成
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
| ファイルの情報の中から検索用情報として使用したい属性を選択し、DynamoDBのテーブルに格納すべき属性（列）を選定する。

| 選定した属性（列）の中から、項目（行）を一意にできる属性（列）をパーティションキーに設定する。
| 本ガイドラインではS3のオブジェクトキーをパーティションキーとする。

| 上記を踏まえ、\ ``FileMetaData``\ テーブルを以下の構成で作成する。
|

.. tabularcolumns:: |p{0.10\linewidth}|p{0.10\linewidth}|p{0.10\linewidth}|p{0.20\linewidth}|p{0.50\linewidth}|
.. list-table::
  :header-rows: 1
  :widths: 10 10 10 20 50

  * - PK
    - 属性名（論理）
    - 属性名（物理）
    - 登録値サンプル
    - 属性説明
  * - パーティションキー
    - オブジェクトキー
    - \ ``objectKey``\
    - USER001_FILE001.txt
    - ファイルを一意に特定するためのキー。ユーザIDとファイル名の連結値を登録する。
  * - －
    - バケット名
    - \ ``bucketName``\
    - fileupload.a
    - ファイルアップロード先のバケット名
  * - －
    - ファイルID
    - \ ``fileId``\
    - FILE001.txt
    - ファイルID
  * - －
    - サイズ
    - \ ``size``\
    - 12
    - ファイルサイズ
  * - －
    - 登録ユーザ
    - \ ``uploadUser``\
    - USER001
    - ファイルアップロードを行ったユーザ名
  * - －
    - 登録日付
    - \ ``uploadDate``\
    - 2017-08-20
    - ファイルアップロードを行った日付
  * - －
    - シーケンサ
    - \ ``sequencer``\
    - 00599E9964323435D9
    - 同一ファイルをアップロードした際の順序性検証のために使用する。
      詳細は :ref:`storage-file-search-metadata-label` を参照されたい。

|
| また、検索条件に使用したい属性（列）の組み合わせに応じたセカンダリインデックスを作成する。
| 本ガイドラインでは、以下の検索条件を想定してセカンダリインデックスを作成する。
|

.. tabularcolumns:: |p{0.20\linewidth}|p{0.20\linewidth}|p{0.20\linewidth}|p{0.20\linewidth}|p{0.20\linewidth}|
.. list-table::
  :header-rows: 1
  :widths: 20 20 20 20 20

  * - 検索条件
    - セカンダリインデックス名
    - パーティションキー
    - ソートキー
    - 種類
  * - 特定ユーザのファイルを更新日時順に取得する。
    - \ ``uploadUser-uploadDate-index``\
    - 登録ユーザ
    - 登録日付
    - グローバルセカンダリインデックス
  * - 特定バケットのファイルサイズ順に取得する。
    - \ ``bucketName-size-index``\
    - バケット名
    - サイズ
    - グローバルセカンダリインデックス

|

.. _storage-file-search-message-label:

メッセージの非同期受信
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. _storage-file-search-message-receive-label:

S3イベントメッセージの受信
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
SQSキューに通知されるS3のイベントメッセージを受信する。
:doc:`../Queuing/AsynchronousProcessing`
に従って、SQSキューからイベントメッセージを受信するリスナークラスを作成する。

リスナークラスではイベントメッセージの受信と同時に後述するメタデータの登録も行うため、実装例は :ref:`storage-file-search-metadata-label` を参照されたい。


.. _storage-file-search-metadata-label:

メタデータの登録
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
| イベントメッセージに含まれるアップロードファイルのメタデータをDynamoDBに登録する。
| 登録前に既存データの有無を確認し、既存データが登録済の場合は更新、未登録の場合は登録を行う。

| 既存データの検索の際は、読み込み整合性に「強力な整合性のある読み込み」を設定して最新の登録情報を確実に取得する。
| 読み込み整合性については `読み込み整合性 <http://docs.aws.amazon.com/ja_jp/amazondynamodb/latest/developerguide/HowItWorks.ReadConsistency.html>`_ を参照されたい。

| 既存データの更新前には、既存データの登録契機となったイベントメッセージと今回のイベントメッセージの発生順序を確認し、既存データよりも発生順序が古いイベントメッセージの情報で更新しないよう順序性を検証する。
| 順序性の検証はイベントメッセージに含まれる\ ``sequencer``\ の値を比較することで行う。
| \ ``sequencer``\ を利用したイベントの順序性の検証についての詳細は `イベントメッセージの構造 <http://docs.aws.amazon.com/ja_jp/AmazonS3/latest/dev/notification-content-structure.html>`_ を参照されたい。

| 既存データの更新時には、既存データが検索時点から更新されていないことを確認するため、バージョン番号を使用したオプティミスティックロックを利用する。
| バージョン番号を使用したオプティミスティックロックの詳細は `バージョン番号を使用したオプティミスティックロック <http://docs.aws.amazon.com/ja_jp/amazondynamodb/latest/developerguide/DynamoDBMapper.OptimisticLocking.html>`_ を参照されたい。

| 登録処理の実装例を以下に示す。
|

- \ ``pom.xml``\

  .. code-block:: xml


    ...
    <!-- (1) -->
    <dependency>
        <groupId>com.amazonaws</groupId>
        <artifactId>aws-java-sdk-dynamodb</artifactId>
    </dependency>
    ...

  .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
  .. list-table::
    :header-rows: 1
    :widths: 10 90

    * - 項番
      - 説明
    * - | (1)
      - | AWS SDK for Java を利用するための\ ``aws-java-sdk-dynamodb``\ を定義する。

|

- \ ``xxx-env.xml``\

  .. code-block:: xml


    <!-- Spring Data DynamoDB -->
    <!-- (1) -->
    <bean id="amazonDynamoDB" class="com.example.xxx.app.fileupload.DynamoDBClientFactory" factory-method="create">
      <constructor-arg index="0" value="${cloud.aws.region.static}" />
    </bean>
    <!-- (2) -->
    <bean id="dynamoDBMapper" class="com.amazonaws.services.dynamodbv2.datamodeling.DynamoDBMapper">
        <constructor-arg index="0" ref="amazonDynamoDB" />
    </bean>

  .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
  .. list-table::
    :header-rows: 1
    :widths: 10 90

    * - 項番
      - 説明
    * - | (1)
      - | DynamoDBへアクセスするための\ ``AmazonDynamoDBClient``\ を定義する。
        | \ ``DynamoDBClientFactory``\ を使用してインスタンスを生成する。
    * - | (2)
      - | AWS SDK for Java を利用するための\ ``DynamoDBMapper``\ を定義する。

|

- \ ``DynamoDBClientFactory.java``\

  .. code-block:: java


    public class DynamoDBClientFactory {
      	public static AmazonDynamoDB create(String region) {
            // (1)
            return AmazonDynamoDBClientBuilder.standard().withRegion(region).build();
        }
    }

  .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
  .. list-table::
    :header-rows: 1
    :widths: 10 90

    * - 項番
      - 説明
    * - | (1)
      - | \ ``AmazonDynamoDBClientBuilder``\ を使用してインスタンスを生成する。

|

- \ ``S3NoticeMessageListener.java``\

  .. code-block:: java


    @Component
    public class S3NoticeMessageListener {

        @Inject
        DynamoDBMapper dbMapper;  // (1)

        private static final String EV_CREATED = "ObjectCreated";
        private static final String EV_REMOVED = "ObjectRemoved";

        @JmsListener(destination = "S3_UPDATE_NOTICE", concurrency = "1")  // (2)
        public void receive(SQSTextMessage recvMsg) {
            try {
                // (3)  JSON -> Java
                S3EventNotification event = S3EventNotification.parseJson(recvMsg.getText());
                S3EventNotificationRecord eventMsg = event.getRecords().get(0);

                // Consistent Read
                FileMetaData currentData = dbMapper.load(FileMetaData.class,
                        eventMsg.getS3().getObject().getKey(),
                        ConsistentReads.CONSISTENT.config());  // (4)

                // Create
                if (currentData == null) {
                    createRecord(eventMsg);  // (5)

                // Update
                } else {
                    updateRecord(currentData, eventMsg); // (8)
                }

            } catch (JMSException e) {
                // omitted
            }
        }

        private void createRecord(S3EventNotificationRecord eventMsg) {
            String objectKey = eventMsg.getS3().getObject().getKey();
            // omitted

            // objectKey -> {userId, fileName}
            String[] objectKeyArr = dataSplit(objectKey);  // (6)

            // create
            if (eventMsg.getEventName().contains(EV_CREATED)) {
                FileMetaData newData = new FileMetaData();
                newData.setObjectKey(objectKey);
                // omitted
                dbMapper.save(newData, SaveBehavior.CLOBBER.config());  // (7)
            }
        }

        private void updateRecord(FileMetaData currentData, S3EventNotificationRecord eventMsg) {
            // event sequence check
            String sequencer = eventMsg.getS3().getObject().getSequencer();
            if (!isNewEntry(currentData.getSequencer(), sequencer)) {  // (9)
                return;
            }

            String objectKey = eventMsg.getS3().getObject().getKey();
            // omitted

            // objectKey -> {userId, fileName}
            String[] objectKeyArr = dataSplit(objectKey);

            try {
                // update
                if (eventMsg.getEventName().contains(EV_CREATED)) {
                    currentData.setBucketName(bucketName);
                    // omitted
                    dbMapper.save(currentData, SaveBehavior.UPDATE.config());  // (10)

                // delete
                } else if (eventMsg.getEventName().contains(EV_REMOVED)) {
                    dbMapper.delete(currentData, SaveBehavior.UPDATE.config());  // (11)
                }

            } catch (ConditionalCheckFailedException e) {  // (12)
                // get current data
                currentData = dbMapper.load(FileMetaData.class,
                        eventMsg.getS3().getObject().getKey(),
                        ConsistentReads.CONSISTENT.config());
                // update retry
                updateRecord(currentData, eventMsg);
            }
        }

        private boolean isNewEntry(String curSequencer, String newSequencer) {
            int len = Math.abs(curSequencer.length() - newSequencer.length());

            if (len > 0) {
                String paddingStr = String.format("%0"+ len +"d", 0);
                if (curSequencer.length() < newSequencer.length()) {
                    curSequencer += paddingStr;
                } else if (newSequencer.length() < curSequencer.length()) {
                    newSequencer += paddingStr;
                }
            }
            return newSequencer.compareTo(curSequencer) > 0;
        }

        private String[] dataSplit(String objectKey) {
            // input string is "[UserID]-[FileName]"
            // omitted
            return new String[]{userId, fileName};
        }
    }


.. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
.. list-table::
  :header-rows: 1
  :widths: 10 90

  * - 項番
    - 説明
  * - | (1)
    - | AWS SDK for Java を利用するための\ ``DynamoDBMapper``\ を設定する。
  * - | (2)
    - | 非同期受信用のメソッドに対し\ ``@JmsListener``\ アノテーションを設定する。
      | \ ``destination``\ 属性には、受信先のキュー名を指定する。
      | \ ``concurrency``\ 属性には、リスナーメソッドの並列数の上限を指定する。
      | DynamoDBに登録済の既存データを検索する処理とそのデータの更新処理までの一連を排他的に実行したいため、並列数の上限を\ ``1``\ に設定する。
  * - | (3)
    - | \ ``S3EventNotification#parseJson``\ を利用したJSON->Java変換を実行する。
  * - | (4)
    - | プライマリキーを指定して既存データを検索する。
      | 読み込み整合性に「強力な整合性のある読み込み（\ ``ConsistentReads.CONSISTENT``\ ）」を指定し、最新状態の既存データを確実に取得する。
  * - | (5)
    - | 既存データが未登録の場合は、新規登録を行う。
  * - | (6)
    - | オブジェクトキーを分解して「ユーザID」、「ファイル名」を取得する。

        .. note::
    	      オブジェクトキーのレイアウトにイベントメッセージからは取得できない属性（ユーザメタデータの値など）を持つことで、
    	      別途S3を参照する必要なくユーザメタデータを使用した検索を実現できる。
    	      またこのような属性値を取り出してDynamoDBに登録することで、セカンダリインデックスを使用した検索にも使用できる。
  * - | (7)
    - | DynamoDBへの登録を実行する。新規登録のため、\ ``SaveBehavior.CLOBBER``\ を指定する。
      | （既存データが未登録であることを確認しているため効果はないが、\ ``SaveBehavior.CLOBBER``\ を指定することで既存データの全ての属性をクリアした後に登録データの値で置換される。）
  * - | (8)
    - | 既存データが登録済の場合は、更新または削除を行う。
  * - | (9)
    - | イベントメッセージの順序性を保障するため、既存データが登録データよりも過去に発生したイベントによって登録されたものであることを確認する。
  * - | (10)
    - | DynamoDBへの更新を実行する。既存データの更新のため、\ ``SaveBehavior.UPDATE``\ を指定する。
      | \ ``SaveBehavior.UPDATE``\ を指定することで、登録データにフィールドとして存在する属性のみが更新される。（フィールドがnull値の場合も更新対象となる）
      | また、後述する「バージョン番号を使用したオプティミスティックロック」も利用可能となる。
  * - | (11)
    - | DynamoDBからの削除を実行する。
      | 更新時と同様、後述する「バージョン番号を使用したオプティミスティックロック」を利用するため\ ``SaveBehavior.UPDATE``\ を指定する。
  * - | (12)
    - | バージョンチェックエラーが発生した場合（既存データに別の更新がされていた場合）は既存データを再取得して更新処理を再実行する。
      | 再実行の結果、(9)の処理にて既存データよりも今回の登録データの方が新しい情報である場合は更新処理を実行し、そうでない場合は更新不要と判定する。

|

|
| \ ``FileMetaData``\ テーブルの項目のマッピングクラスの実装例を以下に示す。

- \ ``FileMetaData.java``\

  .. code-block:: java


    @DynamoDBTable(tableName = "FileMetaData")  // (1)
    public class FileMetaData {

        private String objectKey;
        private String bucketName;
        private String fileName;
        private int size;
        private String uploadUser;
        private String uploadDate;
        private String sequencer;
        private Long version;

        @DynamoDBHashKey  // (2)
        public String getObjectKey() {
            return objectKey;
        }
        // omitted

        @DynamoDBIndexHashKey(globalSecondaryIndexName = "bucketName-size-index")  // (3)
        public String getBucketName() {
            return bucketName;
        }
        // omitted

        @DynamoDBAttribute  // (8)
        public String getFileName() {
            return fileName;
        }
        // omitted

        @DynamoDBIndexRangeKey(globalSecondaryIndexName = "bucketName-size-index")  // (4)
        public int getSize() {
            return size;
        }
        // omitted

        @DynamoDBIndexHashKey(globalSecondaryIndexName = "uploadUser-uploadDate-index")  // (5)
        public String getUploadUser() {
            return uploadUser;
        }
        // omitted

        @DynamoDBIndexRangeKey(globalSecondaryIndexName = "uploadUser-uploadDate-index")  // (6)
        public String getUploadDate() {
            return uploadDate;
        }
        // omitted

        @DynamoDBAttribute
        public String getSequencer() {
            return sequencer;
        }
        // omitted

        @DynamoDBVersionAttribute  // (7)
        public Long getVersion() {
            return version;
        }
        // omitted
    }


.. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
.. list-table::
  :header-rows: 1
  :widths: 10 90

  * - 項番
    - 説明
  * - | (1)
    - | クラスに対して\ ``@DynamoDBTable``\ アノテーションを付与し、\ ``tableName``\ にマッピング対象となる\ ``FileMetaData``\ テーブルを指定する。
  * - | (2)
    - | \ ``FileMetaData``\ テーブルのハッシュキーである\ ``objectKey``\ のGetterに対して\ ``@DynamoDBHashKey``\ アノテーションを付与する。
  * - | (3)
    - | グローバルセカンダリインデックス「\ ``bucketName-size-index``\ 」のハッシュキーである\ ``bucketName``\ のGetterに対して\ ``@DynamoDBIndexHashKey``\ アノテーションを付与する。
      | \ ``globalSecondaryIndexName``\ には\ ``bucketName-size-index``\ を指定する。
  * - | (4)
    - | グローバルセカンダリインデックス「\ ``bucketName-size-index``\ 」のソートキーである\ ``size``\ のGetterに対して\ ``@DynamoDBIndexRangeKey``\ アノテーションを付与する。
      | \ ``globalSecondaryIndexName``\ には\ ``bucketName-size-index``\ を指定する。
  * - | (5)
    - | グローバルセカンダリインデックス「\ ``uploadUser-uploadDate-index``\ 」のハッシュキーである\ ``uploadUser``\ のGetterに対して\ ``@DynamoDBIndexHashKey``\ アノテーションを付与する。
      | \ ``globalSecondaryIndexName``\ には\ ``uploadUser-uploadDate-index``\ を指定する。
  * - | (6)
    - | グローバルセカンダリインデックス「\ ``uploadUser-uploadDate-index``\ 」のソートキーである\ ``uploadDate``\ のGetterに対して\ ``@DynamoDBIndexRangeKey``\ アノテーションを付与する。
      | \ ``globalSecondaryIndexName``\ には\ ``uploadUser-uploadDate-index``\ を指定する。
  * - | (7)
    - | バージョン番号を使用したオプティミスティックロックを行うため、\ ``version``\ のGetterに対して\ ``@DynamoDBVersionAttribute``\ アノテーションを付与する。
  * - | (8)
    - | プライマリキーまたはセカンダリインデックスに使用しない属性については、\ ``@DynamoDBAttribute``\ アノテーションを付与する。

|

.. _storage-file-search-search-label:

オブジェクトの検索
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
プライマリキーまたはセカンダリインデックスを使用してDynamoDBからアップロードファイルのメタデータを検索する。

以下の条件指定による検索を行う。

* ハッシュキー（オブジェクトキー）を指定して単一のアップロード情報を取得する。
* グローバルセカンダリインデックス（登録ユーザ、登録日時）を指定して、特定ユーザの特定日のアップロードファイル情報をリスト取得する。
* グローバルセカンダリインデックスのハッシュキーのみ（登録ユーザ）を指定して、特定ユーザのアップロードファイル情報を登録日順（昇順）にリスト取得する。
* グローバルセカンダリインデックスのハッシュキーのみ（バケット名）を指定して、特定バケットのアップロードファイル情報をサイズ順（降順）にリスト取得する。

検索処理の実装例を以下に示す。

- \ ``SearchSharedServiceImpl.java``\

  .. code-block:: java


    @Service
    public class SearchSharedServiceImpl implements SearchSharedService {

        @Inject
        DynamoDBMapper dbMapper;  // (1)

        public FileMetaData doPkSearch(String objectKey) {
            // (2)
            FileMetaData result = dbMapper.load(FileMetaData.class, objectKey);
            return result;
        }

        public List<FileMetaData> doUserIdIndexSearch(String uploadUser, String uploadDate) {
            HashMap<String, AttributeValue> eav = new HashMap<>();
            eav.put(":v1", new AttributeValue().withS(uploadUser));
            String keyConditionExpression = "uploadUser = :v1";

            if (uploadDate.length() > 0) {
                eav.put(":v2", new AttributeValue().withS(uploadDate));
                keyConditionExpression += " and uploadDate = :v2";
            }
            // (3)
            DynamoDBQueryExpression<FileMetaData> queryExpression = new DynamoDBQueryExpression<FileMetaData>()
                .withIndexName("uploadUser-uploadDate-index")
                .withConsistentRead(false)
                .withKeyConditionExpression(keyConditionExpression)
                .withExpressionAttributeValues(eav);
            List<FileMetaData> indexResult = dbMapper.query(FileMetaData.class, queryExpression);
            return indexResult;
        }

        public List<FileMetaData> doBucketNameIndexSearch(String bucketName) {
            HashMap<String, AttributeValue> eav = new HashMap<>();
            eav.put(":v1", new AttributeValue().withS(bucketName));
            // (4)
            DynamoDBQueryExpression<FileMetaData> queryExpression = new DynamoDBQueryExpression<FileMetaData>()
                .withIndexName("bucketName-size-index")
                .withConsistentRead(false)
                .withKeyConditionExpression("bucketName = :v1")
                .withScanIndexForward(false)
                .withExpressionAttributeValues(eav);
            List<FileMetaData> indexResult = dbMapper.query(FileMetaData.class, queryExpression);
            return indexResult;
        }
    }


.. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
.. list-table::
  :header-rows: 1
  :widths: 10 90

  * - 項番
    - 説明
  * - | (1)
    - | AWS SDK for Java を利用するための\ ``DynamoDBMapper``\ を設定する。
  * - | (2)
    - | \ ``FileMetaData``\ テーブルのハッシュキーである\ ``objectKey``\ を指定した検索を実行する。
      | プライマリキーを指定した検索となるため、1項目のみ取得される。
  * - | (3)
    - | グローバルセカンダリインデックス「\ ``uploadUser-uploadDate-index``\ 」を指定した検索を実行する。
      | ハッシュキーが\ ``uploadUser``\ 、ソートキーが\ ``uploadDate``\ となる。
      | \ ``uploadUser``\ のみが指定された場合は、\ ``uploadUser``\ が一致する項目が\ ``uploadDate``\ 順（昇順）にリスト取得される。
      | \ ``uploadUser``\ と\ ``uploadDate``\ の両方が指定された場合は、\ ``uploadUser``\ と\ ``uploadDate``\ が一致する項目がリスト取得される。
  * - | (4)
    - | グローバルセカンダリインデックス「\ ``bucketName-size-index``\ 」を指定した検索を実行する。
      | ハッシュキーが\ ``bucketName``\ 、ソートキーが\ ``size``\ となる。
      | \ ``bucketName``\ が一致する項目が\ ``size``\ 順（降順）にリスト取得される。


How to extend
--------------------------------------------------------------------------------

.. _storage-file-search-extend-metadata1-label:

メタデータの登録項目について
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
| 検索要件によって、イベントメッセージから取得できる情報（ファイルのシステムメタデータ）だけでは検索情報として足りない場合、必要な情報を別途取得する処理を実装する必要がある。
| 例えばファイルのユーザメタデータの情報を利用したい場合には、イベントメッセージの受信処理にてS3を参照し、ユーザメタデータの情報を取得してDynamoDBへ登録することで、ユーザメタデータの情報を指定した検索を行うことができる。

.. _storage-file-search-extend-metadata2-label:

メタデータの登録先について
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
| DynamoDBでは対応できない複雑な検索条件が必要な要件がある場合（例えば複数テーブルを結合しての検索など）、Amazon Relational Database Service (RDS) の利用も検討できる。
| KVSではないためDynamoDBと比べて検索速度は劣るものの、リレーショナルデータベースの特性を利用してデータを柔軟に取り扱うことができる。
