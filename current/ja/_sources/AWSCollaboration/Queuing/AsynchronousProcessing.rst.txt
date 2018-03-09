非同期処理の実装（共通編）
================================================================================

.. only:: html

 .. contents:: 目次
    :depth: 3
    :local:

Overview
--------------------------------------------------------------------------------

| 本節では、Amazon Simple Queue Service（以下、Amazon SQS）を使用した非同期処理の実装方法について、:doc:`../../ImplementationAtEachLayer/Queuing/AsynchronousProcessing` に則って説明する。
| 非同期処理実装の全体イメージを以下に示す。

.. figure:: ./imagesAsynchronousProcessing/AsynchronousProcessingOverviewUsingAWS.png
   :alt: Screen image of asynchronous processing.
   :width: 100%

.. note::

   リクエストを受け付け、キューにメッセージを送信するフロントサーバと、キューからメッセージを受信し非同期に処理を行うバックサーバの2つのサーバが存在する前提で説明を進める。

   必要に応じて、バックサーバのプロジェクトを作成すること。プロジェクトの作成については、:doc:`../../ImplementationAtEachLayer/CreateWebApplicationProject` を参照されたい。

.. _AboutSQS:

Amazon SQSとは
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

| Amazon SQSは、Amazon Web Serviceが提供するメッセージキューサービスである。
| 非同期通信をサポートしており、クライアント間で疎結合にデータの移動を行える。
| Amazon SQSの詳細については、\ `Amazon Simple Queue Service (SQS) <https://aws.amazon.com/jp/sqs/>`_\を参照されたい。

.. _VarietyOfQueues:

Amazon SQSが提供するキューの種類
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

| Amazon SQSは、標準キューとFIFOキューという2タイプのキューを提供している。
| なお、本ガイドラインでは標準キューの利用法について紹介する。
| 2017/02時点での両者の主な違いは以下の通り。

.. list-table::
   :header-rows: 1
   :widths: 100 75 75

   * -
     - 標準キュー
     - FIFOキュー
   * - 1秒あたりのトランザクション数
     - 無制限
     - 300件
   * - メッセージの2重配信
     - 稀に発生する
     - 発生しない
   * - メッセージの到着順
     - 保証されない
     - 保証される

| キューの詳細については\ `Amazon SQS 製品の詳細 <https://aws.amazon.com/jp/sqs/details/>`_\を参照されたい。

* **標準キュー利用時の注意点**

 | Amazon SQSでは、冗長性と高可用性を確保する為、メッセージのコピーを複数台のサーバに保持している。
 | その為、メッセージの削除をサーバ間で同期できない事象が発生した場合、処理済みのメッセージを再度受信してしまうケースが存在する。
 | 対処法として、二重受信チェック処理を実装するなど、アプリケーション側でべき等性を担保する実装とする必要がある。
 | 本ガイドラインでは、メッセージ受信時にメッセージIDをDBに登録する事で2重受信チェックを実現している。詳細については\ :ref:`SQSHowToCheckDuplicateReceiving`\を参照されたい。

 .. warning::

    標準キューを利用する場合、稀にメッセージの2重配信が発生する為、べき等性を担保するようアプリケーションを実装すること。

    2重配信は標準キューの重要な特徴であるため、\ `少なくとも 1 回の配信 <http://docs.aws.amazon.com/ja_jp/AWSSimpleQueueService/latest/SQSDeveloperGuide/standard-queues.html#standard-queues-at-least-once-delivery>`_\ は必ず参照して頂きたい。

* **キューの採用基準**

 | 標準キューとFIFOキューはメリット・デメリットが一長一短な為、システムの性能目標や特性に合わせて採用を検討されたい。
 |
 | 例えば、連続したコマンドをメッセージに乗せて送信する場合など、厳密なメッセージ順序を求めるシステムには、性能面を考慮した上で、FIFOキューの採用を検討すると良い。
 | 一方、メッセージ到着順の変動を許容できるシステムの場合は、性能面で優位性のある標準キューの採用を検討する良い。
 | 本ガイドラインで紹介するモデルでは、チケット予約システムのように大量のリクエストが集中するシステムを想定しており、リクエストの順序は問わない為、標準キューを採用している。

.. _UsingSQSWithJava:

JavaアプリケーションからのAmazon SQSの利用
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Amazon Web Serviceでは、JavaアプリケーションからAmazon SQSを利用する為のAPIを提供している。

* **AmazonSQSインタフェース(AWS SDK for Java)**

 | \ ``com.amazonaws.services.sqs.AmazonSQS``\ をはじめとする、AWSが提供するSDKに含まれるAmazon SQS用のAPI。
 | \ ``AmazonSQS``\ インタフェースを利用する場合、アプリケーションはAWS依存となる。
 | 詳細については\ `AWS SDK for Java <https://aws.amazon.com/jp/documentation/sdk-for-java/>`_\および\ `スタンダード キュー <http://docs.aws.amazon.com/ja_jp/AWSSimpleQueueService/latest/SQSDeveloperGuide/standard-queues.html>`_\を参照されたい。


* **JMSインタフェース(Amazon SQS Java Messaging Library)**

 | Amazon SQSをJMSプロバイダとして使用する為のインタフェース。
 | **本ガイドラインでは、このJMSインタフェースと、後述するSpring JMSを組み合わせた実装例を紹介する。**
 | JMSインタフェースの詳細については\ `Amazon SQSでJMSを使用する <http://docs.aws.amazon.com/ja_jp/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-java-message-service-jms-client.html>`_\を参照されたい。

.. note::

 JMSインタフェースは、SQSのメッセージ送受信をJMSライクに行えるインタフェースであり、実態はJMSとは異なる為、注意が必要である。
 例えば、非同期受信時のトランザクション管理や、Pub-Subモデルとしての送受信はサポートされていない。

 Amazon SQS提供のJMSインタフェースがサポートしているJMS実装については、\ `サポートされている JMS 1.1 実装 <http://docs.aws.amazon.com/ja_jp/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-java-message-service-jms-client.html#supported-implementations>`_\を参照されたい。

.. note::

  本ガイドライン執筆時点では、JMSインタフェースはFIFOキューをサポートしていない。利用するキューを選定する際は、使用するAPIに対応しているかを確認されたい。

.. _UsingSQSWithSpringJms:

Spring JMSを使用したAmazon SQSの利用
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

| Spring Frameworkが提供するSpring JMSライブラリ経由でSQSを利用する方法について説明する。
| Spring JMSについては、|base_framework_name| のガイドライン\ `Spring Frameworkのコンポーネントを使用したJMSの利用 <https://macchinetta.github.io/server-guideline/1.5.1.RELEASE/ja/ArchitectureInDetail/MessagingDetail/JMS.html#spring-frameworkjms>`_\に詳しい利用法が記されている為、参照されたい。

.. note::

 Spring Cloudが提供する Spring Cloud for Amazon Web Services(以下、Spring Cloud AWS)を用いても、JavaアプリケーションからAmazon SQSを利用することができる。
 ただし、本ガイドライン執筆時点のバージョン(1.2.1.RELEASE)では、メッセージ受信を行う\ ``SimpleMessageListenerContainer``\ の仕様により、メッセージ受信後の処理がパラレルに実行できないという制約がある。
 詳細については、Spring Cloud AWSの\ `issues#166 <https://github.com/spring-cloud/spring-cloud-aws/issues/166>`_\を参照されたい。

 以上の理由から、本ガイドラインではSpring Cloud AWSを使用せず、Spring JMSを用いて説明する。

.. _SynchronousSendingOverview:

メッセージを同期送信する場合
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

メッセージを同期送信する処理の流れについて図を用いて説明する。

.. figure:: ./imagesAsynchronousProcessing/AsynchronousProcessingImageOfSynchronousSending.png
   :alt: Screen image of synchronous sending.
   :width: 70%

.. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
.. list-table::
   :header-rows: 1
   :widths: 10 90

   * - 項番
     - 説明
   * - | (1)
     - | Service内で、\ ``JmsMessagingTemplate``\ に対して「送信先のAmazon SQSキュー名」と「送信するメッセージのペイロード」を渡して処理を実行する。
       | \ ``JmsMessagingTemplate``\ は\ ``JmsTemplate``\ に処理を委譲する。
   * - | (2)
     - | \ ``JmsTemplate``\ はDIコンテナから取得した\ ``ConnectionFactory``\ から\ ``javax.jms.Connection``\ を取得する。
   * - | (3)
     - | \ ``JmsTemplate``\ は ``MessageProducer``\ に\ ``Destination``\ とメッセージを渡す。
       | \ ``MessageProducer``\ は\ ``javax.jms.Session``\ から生成される。(\ ``Session``\ は(2)で取得した\ ``Connection``\ から生成される。)
   * - | (4)
     - | \ ``SQSMessageProducer``\ は送信対象の\ ``Destination``\ へメッセージを送信する。

.. _AsynchronousReceivingOverview:

メッセージを非同期受信する場合
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

メッセージを非同期受信する処理の流れについて図を用いて説明する。

.. figure:: ./imagesAsynchronousProcessing/AsynchronousProcessingImageOfAsynchronousReceiving.png
   :alt: Screen image of asynchronous receiving.
   :width: 70%

.. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
.. list-table::
   :header-rows: 1
   :widths: 10 90

   * - 項番
     - 説明
   * - | (1)
     - | DIコンテナから取得した\ ``ConnectionFactory``\ から\ ``Connection``\ を取得する。
   * - | (2)
     - | \ ``DefaultMessageListenerContainer``\ は\ ``MessageConsumer``\ に\ ``Destination``\ を渡す。
       | \ ``MessageConsumer``\ は\ ``Session``\ から生成される。(\ ``Session``\ は(1)で取得した\ ``Connection``\ から生成される。)
       | また、\ ``Destination``\ は\ ``@JmsListener``\ アノテーションで指定された「受信対象のAmazon SQSキュー名」をもとに\ ``AmazonSQS``\経由で取得される。
   * - | (3)
     - | \ ``MessageConsumer``\ は\ ``Destination``\ からメッセージを受信する。
   * - | (4)
     - | 受信したメッセージを引数として、\ ``MessageListener``\ 内の\ ``@JmsListener``\ アノテーションが設定されたメソッド(リスナーメソッド)が呼び出される。リスナーメソッドは\ ``DefaultMessageListenerContainer``\ で管理される。

How to use
--------------------------------------------------------------------------------

.. _ConfigurationOfSQS:

Amazon SQSの設定
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Amazon SQSを使用する為に必要な設定について説明する。

.. _CreatingQueues:

キューの作成
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

Amazon Web Serviceのコンソール、またはクエリAPIから、アプリケーションで使用するキューを作成する。
キューの作成については、\ `チュートリアル: Amazon SQS キューの作成 <http://docs.aws.amazon.com/ja_jp/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-create-queue.html>`_\を参照されたい。

特筆すべき設定項目について、以下に紹介する。
設定の詳細やその他の設定項目については\ `Amazon SQS キューの操作 <http://docs.aws.amazon.com/ja_jp/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-how-it-works.html>`_\を参照されたい。

 * **キューの種類**

   | 標準キュー、FIFOキューから選択する。
   | なお、本ガイドラインは標準キューを使用した場合について紹介している。

 * **キュー名**

   | キューの名称を決定する。
   | ここで決めた名称を、後述する\ ``@JmsListener``\ アノテーションに属性値として指定する。

 * **可視性タイムアウト**

   | キューの可視性タイムアウトを設定する。
   | 可視性タイムアウトとは、キューから受信されて処理中となっているメッセージが、他の受信コンポーネントから不可視となる時間の長さである。
   | 可視性タイムアウト時間を超えて処理が継続した場合、処理中に別の受信コンポーネント(別スレッドを含む)にて再度受信されてしまう。その為、可視性タイムアウトは処理時間を勘案した上で、充分な値を設定すること。
   | 詳細については、\ `可視性タイムアウト <http://docs.aws.amazon.com/ja_jp/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-visibility-timeout.html>`_\ および \ `全般的な推奨事項 メッセージの処理 <http://docs.aws.amazon.com/ja_jp/AWSSimpleQueueService/latest/SQSDeveloperGuide/general-recommendations.html>`_\ を参照されたい。

 * **メッセージ受信待機時間**

  | メッセージの受信待機時間を設定する。
  | 受信待機時間とは、受信コンポーネントが空のキューに対してReceiveMessageリクエストを行った際に、キューにメッセージが到着するまで待機する時間である。
  | 値は0-20秒の間で設定でき、0秒をショートポーリング、1秒以上をロングポーリングと呼ぶ。
  | ロングポーリングを使用することでAmazon SQSへのReceiveMessageリクエスト回数を削減できる為、20秒のロングポーリングを使用する事を推奨する。
  | ロングポーリングについては\ `Amazon SQS ロングポーリング <http://docs.aws.amazon.com/ja_jp/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-long-polling.html>`_\を参照されたい。

 * **デッドレターキュー設定**

  | 正常に処理できないメッセージの送達先として、デッドレターキューを設定できる。
  | デッドレターキューについては、\ `Amazon SQS デッドレターキューの使用 <http://docs.aws.amazon.com/ja_jp/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-dead-letter-queues.html>`_\を参照されたい。

.. note::
  メッセージ受信待機時間は、キュー側と受信コンポーネント側の両方に設定することができ、受信コンポーネント側の設定が優先される。

  AWS SDK(JMSインタフェースを含む)は、デフォルトで20秒のロングポーリング設定となっている為、本ガイドラインで紹介する構成の場合、キューのメッセージ受信待機時間設定に関わらず、20秒のロングポーリングとなる。

.. _SQSHowToUseEnviromentSetting:

メッセージの送受信に共通する設定
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

本節では、Amazon SQSを使用したメッセージの送受信に必要となる共通的な設定について説明する。

.. _SQSHowToUseDependentLibrary:

依存ライブラリの設定
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

フロントサーバ、バックサーバそれぞれのdomainプロジェクトのpom.xmlに、Amazon SQSを利用する為に必要となる依存ライブラリを追加する。

記述例を以下に示す。

- xxx-domain/pom.xml

 .. code-block:: xml

    <dependencies>

         <!-- (1) -->
         <dependency>
             <groupId>org.springframework</groupId>
             <artifactId>spring-jms</artifactId>
         </dependency>

         <!-- (2) -->
         <dependency>
             <groupId>com.amazonaws</groupId>
             <artifactId>amazon-sqs-java-messaging-lib</artifactId>
             <version>1.0.1</version>
         </dependency>

     </dependencies>

 .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
 .. list-table::
     :header-rows: 1
     :widths: 10 90

     * - 項番
       - 説明
     * - | (1)
       - | Spring Frameworkが提供する\ ``spring-jms``\ をdependenciesに追加する。
         | バージョンはSpring IO Platformによって定義されているため、pom.xmlで指定しなくてよい。
     * - | (2)
       - | JMSプロバイダとして、Amazon SQSのJMSインタフェース \ ``amazon-sqs-java-messaging-lib``\ をdependenciesに追加する。

.. _SQSHowToUseConnectionFactory:

ConnectionFactoryの設定
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

フロントサーバ、バックサーバそれぞれのdomainプロジェクトのinfra.xmlに\ ``ConnectionFactory``\ の定義を追加する。

記述例を以下に示す。

- xxx-infra.xml

 .. code-block:: xml

    <!-- (1) -->
    <bean id="connectionFactory" class="com.amazon.sqs.javamessaging.SQSConnectionFactory"
        factory-bean="connectionFactoryBuilder" factory-method="build" />

    <!-- (2) -->
    <bean id="connectionFactoryBuilder"
        class="com.amazon.sqs.javamessaging.SQSConnectionFactory$Builder">
        <property name="regionName" value="us-east-1" />
    </bean>

 .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
 .. list-table::
    :header-rows: 1
    :widths: 10 90

    * - 項番
      - 説明
    * - | (1)
      - | \ ``SQSConnectionFactory``\ をBean定義する。
        | \ ``SQSConnectionFactory``\ は\ ``SQSConnectionFactory$Builder``\ のファクトリメソッドにてインスタンス生成する為、
        | \ ``factory-method``\ 属性に \ ``build``\ を指定する。
    * - | (2)
      - | \ ``SQSConnectionFactory``\ のインスタンス生成に用いるビルダクラス \ ``SQSConnectionFactory$Builder``\ をBean定義する。
        | \ ``regionName``\ 属性に、接続先キューが存在するリージョンを指定する。

        .. note::

         ここではリージョンを固定文字列として記述しているが、実際の開発では外部管理とすることが望ましい。

         環境依存値の外部管理については、:doc:`../../ImplementationAtEachLayer/EnvironmentValuesExternalManagement` を参照されたい。

 .. note:: **ConnectionFactoryの定義方法について**

  |base_framework_name| のガイドライン\ `ConnectionFactoryの設定 <https://macchinetta.github.io/server-guideline/1.5.1.RELEASE/ja/ArchitectureInDetail/MessagingDetail/JMS.html#connectionfactory>`_\ では、
  Bean定義ファイルがアプリケーションサーバ提供のJMSプロバイダ依存となることを防ぐため、\ ``ConnectionFactory``\ をアプリケーションサーバ側にて定義することを推奨しているが、
  本ガイドラインで紹介しているケースにおいては、JMSプロバイダはクラウドベンダー提供のライブラリを使用する為、アプリケーションサーバ側に定義する必要性は低い。

  以上の理由から、本ガイドラインではBean定義ファイルで定義する方法を採っている。

.. _SQSHowToUseDestinationResolver:

DestinationResolverの設定
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

Amazon SQSキューの名前解決は、AWS SDK for Javaが提供するJMSプロバイダによって行われる。
Spring JMSは、JMSプロバイダによる解決を行う \ ``DynamicDestinationResolver``\ をデフォルトで使用する為、
\ ``DestinationResolver``\ についての設定は不要である。

.. note::

  Spring BootのAuto-configurationの仕組みを採用し、デフォルトのまま使用した場合、
  \ ``JmsAutoConfiguration``\ の設定により、JNDIによる名前解決を行う\ ``JndiDestinationResolver``\ がBean定義され、宛先キューの解決に使用される。
  ただし、Amazon SQSのキューはJNDIでルックアップできない為、最終的には\ ``DynamicDestinationResolver``\ での解決が行われる。

.. _SQSHowToUseSyncSendMessage:

メッセージを同期送信する方法
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

| クライアントからAmazon SQSキューへメッセージを同期送信する方法を説明する。

本ガイドラインでは、|base_framework_name| のガイドライン \ `メッセージを同期送信する方法 <https://macchinetta.github.io/server-guideline/1.5.1.RELEASE/ja/ArchitectureInDetail/MessagingDetail/JMS.html#jmshowtousesyncsendmessage>`_\ との差分について重点的に紹介している為、
本ガイドラインと併せて、|base_framework_name| のガイドラインも参照されたい。

.. _SQSHowToUseSettingForSyncSend:

基本的な同期送信
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

| \ ``JmsMessagingTemplate``\ を利用して、Amazon SQSへの同期送信処理を実現する。
| ここでは、\ ``Reservation``\ クラスのオブジェクトをメッセージ同期送信する場合の実装例を紹介する。

- 同期送信に必要となるBean定義

  | メッセージの送信側アプリケーションに必要となるBean定義例を以下に示す。

  - xxx-infra.xml

    .. code-block:: xml

      <bean id="cachingConnectionFactory"
         class="org.springframework.jms.connection.CachingConnectionFactory" primary="true"> <!-- (1) -->
         <property name="targetConnectionFactory" ref="connectionFactory" /> <!-- (2) -->
         <property name="sessionCacheSize" value="10" />  <!-- (3) -->
      </bean>

    .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
    .. list-table::
       :header-rows: 1
       :widths: 10 90

       * - 項番
         - 説明
       * - | (1)
         - | \ ``Session``\ 、\ ``MessageProducer``\ のキャッシュを行う\ ``org.springframework.jms.connection.CachingConnectionFactory``\ をBean定義する。
           | \ ``SQSConnectionFactory``\ をそのまま使うのではなく、
             \ ``CachingConnectionFactory``\ にラップして使用することで、キャッシュ機能を使用することができる。
           | DIコンテナに\ ``ConnectionFactory``\ 実装クラスが複数登録されることになる為、\ ``primary``\属性に\ ``true``\ を指定する。
       * - | (2)
         - | Bean定義された\ ``SQSConnectionFactory``\ を指定する。
       * - | (3)
         - | \ ``Session``\ のキャッシュ数を設定する。（デフォルト値は1）
           | この例では10を指定しているが、性能要件に応じて適宜キャッシュ数を変更すること。
           | このキャッシュ数を超えてセッションが必要になるとキャッシュを使用せず、新しいセッションの作成と破棄を繰り返すことになる。
           | すると処理効率が下がり、性能劣化の原因になるので注意すること。

.. note::

  本ガイドラインでは、Spring BootのAuto-configurationの使用を前提としており、
  メッセージ送信に使用する\ ``JmsTemplate``\、\ ``JmsMessagingTemplate``\ は \ ``JmsAutoConfiguration``\ にてBean定義される為、
  デフォルト設定のまま使用する場合は、Bean定義は不要である。


なお、\ ``JmsTemplate``\ の設定については、|base_framework_name| のガイドライン\ `メッセージを同期送信する方法 <https://macchinetta.github.io/server-guideline/1.5.1.RELEASE/ja/ArchitectureInDetail/MessagingDetail/JMS.html#jmshowtousesyncsendmessage>`_\に詳しく紹介されている為、必要に応じて参照されたい。

- 送信対象のJavaBeanの実装

  | フロントサーバ、バックサーバの両アプリケーションで共用するオブジェクトの為、modelプロジェクトに作成する。
  | modelの共有についての詳細は、|base_framework_name| のガイドライン \ `プロジェクト構成について <https://macchinetta.github.io/server-guideline/1.5.1.RELEASE/ja/ArchitectureInDetail/MessagingDetail/JMS.html#jmsoverviewaboutprojectconfiguration>`_\を参照されたい。

  実装例を以下に示す。

  - Reservation.java

   .. code-block:: java

     package com.example.domain.model;

     import java.io.Serializable;

     public class Reservation implements Serializable { // (1)

         private static final long serialVersionUID = -1L;

         private String reserveNo;

         // omitted

         public String getReserveNo() {
             return reserveNo;
         }

         public void setReserveNo(String reserveNo) {
             this.reserveNo = reserveNo;
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
         - | シリアライズして送信するため、\ ``java.io.Serializable``\ インタフェース を実装する必要がある。


- 同期送信を行うサービスクラスの実装

  予約情報を持つ\ ``Reservation``\ オブジェクトをAmazon SQSキューに同期送信する。

  実装例を以下に示す。

  - ReservationServiceImpl.java

   .. code-block:: java

      package com.example.domain.service.reservation;

      import javax.inject.Inject;
      import org.springframework.jms.core.JmsMessagingTemplate;
      import org.springframework.stereotype.Service;
      import com.example.domain.model.Reservation;

      @Service
      public class ReservationServiceImpl implements ReservationService {

          @Inject
          JmsMessagingTemplate jmsMessagingTemplate;    // (1)

          @Override
          public void sendMessage(Reservation reservation) {

             // omitted

             jmsMessagingTemplate.convertAndSend("reservation-queue", reservation);  // (2)

          }
      }


   .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
   .. list-table::
      :header-rows: 1
      :widths: 10 90

      * - 項番
        - 説明
      * - | (1)
        - | \ ``JmsMessagingTemplate``\ をインジェクションする。
      * - | (2)
        - | \ ``JmsMessagingTemplate``\ の\ ``convertAndSend``\ メソッドを使用して、引数のJavaBeanを\ ``org.springframework.messaging.Message``\ インタフェースの実装クラスに変換し、指定したDestinationに対しメッセージを同期送信する。
          | 本実装例では、Amazon SQSキューに送信する為、\ ``com.amazon.sqs.javamessaging.message.SQSObjectMessage``\ に変換され、送信される。

.. _SQSHowToUseAsyncReceiveMessage:

メッセージを非同期受信する方法
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
| Amazon SQSキューからメッセージを非同期受信する方法を説明する。

本ガイドラインでは、|base_framework_name| のガイドライン \ `メッセージを非同期受信する方法 <https://macchinetta.github.io/server-guideline/1.5.1.RELEASE/ja/ArchitectureInDetail/MessagingDetail/JMS.html#jmshowtouseasyncreceivemessage>`_\ との差分について重点的に紹介している為、
本ガイドラインと併せて、|base_framework_name| のガイドラインも参照されたい。

.. warning::

   Amazon SQSはトランザクションをサポートしていない為、|base_framework_name| のガイドライン \ `トランザクション管理 <https://macchinetta.github.io/server-guideline/1.5.1.RELEASE/ja/ArchitectureInDetail/MessagingDetail/JMS.html#jmshowtousetransactionmanagementforasyncreceive>`_\ で紹介されているような、
   メッセージングとDBのトランザクションを組み合わせる設計は行えない為、注意が必要である。

.. _SQSHowToUseSettingForAsyncReceive:

基本的な非同期受信
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
| \ ``@JmsListener``\ アノテーションを利用した非同期受信の方法について説明する。

- Bean定義ファイルの設定

  非同期受信の実装には下記の設定が必要となる。

  * JMS Namespaceを定義する。
  * \ ``@JmsListener``\ アノテーションを有効化する。
  * DIコンテナで管理しているコンポーネントのメソッドに\ ``@JmsListener``\ アノテーションを指定する。

  記述例を以下に示す。

  - applicationContext.xml

   .. code-block:: xml

      <!-- (1) -->
      <beans xmlns="http://www.springframework.org/schema/beans"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xmlns:jms="http://www.springframework.org/schema/jms"
          xsi:schemaLocation="http://www.springframework.org/schema/beans http://www.springframework.org/schema/beans/spring-beans.xsd
              http://www.springframework.org/schema/jms http://www.springframework.org/schema/jms/spring-jms.xsd">

          <!-- (2) -->
          <jms:annotation-driven />

          <!-- (3) -->
          <jms:listener-container
              factory-id="jmsListenerContainerFactory"
              acknowledge="client" />

   .. tabularcolumns:: |p{0.26\linewidth}|p{0.26\linewidth}|p{0.74\linewidth}|
   .. list-table::
      :header-rows: 1
      :widths: 10 26 64

      * - 項番
        - 属性名
        - 内容
      * - | (1)
        - xmlns:jms
        - | JMS Namespaceを定義する。
          | 値として\ ``http://www.springframework.org/schema/jms``\ を指定する。
          | JMS Namespaceの詳細については、\ `JMS Namespace Support <http://docs.spring.io/autorepo/docs/spring-framework/4.3.14.RELEASE/spring-framework-reference/html/jms.html#jms-namespace>`_\ を参照されたい。
      * -
        - xsi:schemaLocation
        - | スキーマのURLを指定する。
          | 値に\ ``http://www.springframework.org/schema/jms``\ と\ ``http://www.springframework.org/schema/jms/spring-jms.xsd``\ を追加する。
      * - | (2)
        - \-
        - | \ ``<jms:annotation-driven />``\ を利用して、\ ``@JmsListener``\ アノテーションや\ ``@SendTo``\ アノテーション等のJMS関連のアノテーション機能を有効化する。
      * - | (3)
        - \-
        - | \ ``<jms:listener-container/>``\ を利用して\ ``DefaultMessageListenerContainer``\ を生成するファクトリへパラメータを与えることで、\ ``DefaultMessageListenerContainer``\ の設定を行う。
          | \ ``<jms:listener-container/>``\ の属性には、利用したい\ ``ConnectionFactory``\ のBeanを指定できる\ ``connection-factory``\ 属性が存在する。\ ``connection-factory``\ 属性のデフォルト値は\ ``connectionFactory``\ である。
          | この例では、\ :ref:`SQSHowToUseConnectionFactory`\ で示した\ ``ConnectionFactory``\ のBean(Bean名は\ ``connectionFactory``\ )を利用するため、\ ``connection-factory``\ 属性を省略している。
          | \ ``<jms:listener-container/>``\ には、ここで紹介した以外の属性も存在する。
          | 詳細については、\ `Attributes of the JMS <listener-container> element <http://docs.spring.io/spring/docs/4.3.14.RELEASE/spring-framework-reference/html/jms.html#jms-namespace-listener-container-tbl>`_\ を参照されたい。

          .. warning::

             非同期受信の場合、\ ``DefaultMessageListenerContainer``\ の内部に独自のキャッシュ機能が備わっているため、\ ``CachingConnectionFactory``\ は使用してはいけない。
             詳細については、\ `DefaultMessageListenerContainerのJavadoc <http://docs.spring.io/autorepo/docs/spring-framework/4.3.14.RELEASE/javadoc-api/org/springframework/jms/listener/DefaultMessageListenerContainer.html>`_\ を参照されたい。
      * -
        - \ ``factory-id``\
        - | Bean定義を行う\ ``DefaultJmsListenerContainerFactory``\ の名前を設定する。
          | \ ``@JmsListener``\ アノテーションがデフォルトでBean名\ ``jmsListenerContainerFactory``\ を参照するため、\ ``<jms:listener-container/>``\ が一つの場合はBean名を\ ``jmsListenerContainerFactory``\ とすることを推奨する。
      * -
        - \ ``acknowledge``\
        - | メッセージ受信時の、Amazon SQSへの確認応答の返し方を設定する。Amazon SQSキューは、確認応答を受け取った際にキュー内のメッセージを削除する。
          | \ ``acknowledge``\ 属性のデフォルトは\ ``auto``\である。ここでは、\ ``client``\を設定している。
          | \ ``client``\を設定した場合は、リスナーメソッドが正常終了した際に確認応答を返し、例外発生時にはメッセージがキューに戻される。

          .. note::

             acknowledgeモードはAmazon SQS、Spring JMS で意味合いが異なる為、注意が必要である。
             ここでは、\ ``DefaultMessageListenerContainer``\を使用する為、Spring JMSのacknowledgeモードに従って設定している。

   .. note::

      Amazon SQSはトランザクションをサポートしていない為、\ ``transaction-manager``\属性は設定できない。

- リスナークラスの実装

 | DIコンテナで管理しているコンポーネントのメソッドに\ ``@JmsListener``\ アノテーションを指定することで、指定したDestinationより非同期でメッセージを受信する。
 | また、\ :ref:`UsingSQSWithJava`\にて紹介した、標準キューの2重受信の検出についてもここで行う。

 実装例を以下に示す。

 - ReservationMessageListener.java

  .. code-block:: java

     package com.example.listener.reservation;

     import javax.inject.Inject;
     import org.springframework.jms.annotation.JmsListener;
     import org.springframework.jms.support.JmsHeaders;
     import org.springframework.stereotype.Component;
     import com.example.domain.common.exception.DuplicateReceivingException;
     import com.example.domain.model.Reservation;
     import com.example.domain.service.reservation.ReservationInspectionService;

     @Component
     public class ReservationMessageListener {

        @Inject
        ReservationInspectionService reservationInspectionService;

        @JmsListener(destination = "reservation-queue", concurrency = "5-10")   // (1)
        public void receive(Reservation reservation,
                @Header(JmsHeaders.MESSAGE_ID) String messageId) { // (2)

            try{
                reservationInspectionService.inspectAndNotify(reservation, messageId); // (3)
            }catch(DuplicateReceivingException e){ // (4)
                return;
            }
           // omitted
        }

     }

  .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
  .. list-table::
     :header-rows: 1
     :widths: 10 90

     * - 項番
       - 説明
     * - | (1)
       - | 非同期受信用のメソッドに対し\ ``@JmsListener``\ アノテーションを設定する。
         | \ ``destination``\ 属性には、受信先のキュー名を指定する。
         | \ ``concurrency``\ 属性には、リスナーメソッドの並列数の上限を指定する。記述例のように、下限と上限を設定することも可能である。

         .. note::

            \ ``concurrency``\ 属性は、\ ``<jms:listener-container/>``\ にて設定することも可能だが、
            記述例ではリスナーメソッドごとに並列数を設定する設計を想定している為、\ ``@JmsListener``\ アノテーションに設定している。

     * - | (2)
       - | 後述する2重受信チェックに使用するJMSMessageIDを、\ ``Header``\ アノテーションを使用してメソッド引数として受け取る。
     * - | (3)
       - | メッセージ受信後に実行するサービスクラスのメソッドを呼び出す。
         | サービスクラス内にて2重受信チェックを行うため、受信メッセージのJMSMessageIDを引数として渡す。
     * - | (4)
       - | 2重受信チェックの結果、受信したメッセージが処理済であった場合は、\ ``return``\ してリスナーメソッドを正常終了させる。

.. _SQSHowToCheckDuplicateReceiving:

2重受信チェック
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
| Amazon SQSの標準キューを利用する際に必要となる、2重受信チェックについて説明する。
|
| Amazon SQSのドキュメント\ `少なくとも 1 回の配信 <http://docs.aws.amazon.com/ja_jp/AWSSimpleQueueService/latest/SQSDeveloperGuide/standard-queues.html#standard-queues-at-least-once-delivery>`_\ で示されている通り、標準キューを使用する場合は、アプリケーションがべき等性を持つように設計する必要がある。
| べき等性を持たせる方法はいくつか存在するが、本ガイドラインではRDBの一意性制約を利用して実現する方法を紹介する。
|
| 処理済のメッセージを再度受信した場合のイメージを以下に示す。

 .. figure:: ./imagesAsynchronousProcessing/AsynchronousProcessingDuplicateReceiving.png
   :alt: Screen image of unique message check.
   :width: 100%

 .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
 .. list-table::
    :header-rows: 1
    :widths: 10 90

    * - 項番
      - 説明
    * - | (1)
      - | バックサーバのアプリケーションは、SQSメッセージ(ID:AAAAAAAAAAAZ)を受信する。
    * - | (2)
      - | バックサーバのアプリケーションは、2重受信チェック部品を使用してメッセージID:AAAAAAAAAAAZをRDBのメッセージID管理テーブルに登録した後、業務処理を実行する。
        | メッセージID管理テーブルは、メッセージIDカラムがユニークキーに設定されている前提。

        .. note::

           2重受信チェック部品は、\ ``@Transactional``\ が付与されたサービスクラスのメソッド内にて呼び出され、サービスクラスのトランザクションに参加する。その為、メッセージID挿入は、サービスクラスのメソッドが正常終了した時点でコミットされる。

    * - | (3)
      - | バックサーバのアプリケーションは、何らかの原因により、(2)で受信したSQSメッセージ(ID:AAAAAAAAAAAZ)を再度受信する。
    * - | (4)
      - | 2重受信チェック部品は、メッセージID:AAAAAAAAAAAZをRDBのメッセージID管理テーブルに登録しようとするが、既に同じIDが登録されている為に挿入できず、2重受信と判断する。
    * - | (5)
      - | バックサーバのアプリケーションは、以降の業務処理を行わずにリスナーメソッドを正常終了させる。

        .. note::

           リスナーメソッドを例外終了させた場合、Spring JMSのacknowledgeモード\ ``client``\の仕様により、メッセージが削除されずキューに戻されてしまう。
           2重受信した処理済メッセージをキューから削除する為、ここではリスナーメソッドを正常終了させている。

| 2重受信チェックの実装例を以下に示す。

- DuplicateMessageChecker.java

 .. code-block:: java

    package com.example.domain.messaging;

    import javax.inject.Inject;
    import org.springframework.dao.DuplicateKeyException;
    import org.springframework.transaction.annotation.Transactional;
    import com.example.domain.repository.messaging.MessageIdRepository;
    import com.example.domain.common.exception.DuplicateReceivingException;

    public class DuplicateMessageChecker {

        @Inject
        MessageIdRepository repository; // (1)

        @Transactional  // (2)
        public void checkDuplicateMessage(String messageId) {

            try {

                repository.register(messageId); // (3)

            } catch (DuplicateKeyException e) { // (4)

                throw new DuplicateReceivingException(messageId);
            }
        }
    }


 .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
 .. list-table::
    :header-rows: 1
    :widths: 10 90

    * - 項番
      - 説明
    * - | (1)
      - | メッセージIDをINSERTするリポジトリ \ ``MessageIdRepository``\ をインジェクションする。

        .. note::

           \ ``MessageIdRepository``\ は単項目のINSERTを行うリポジトリの為、マッピングファイル等の記述例は割愛する。

    * - | (2)
      - | メッセージIDをINSERTするトランザクションを業務処理のトランザクションに含める為、\ ``@Transactional``\を付与する。
        | \ ``propagation``\属性には、デフォルト値の\ ``REQUIRED``\が使用される。
        | 業務処理にて例外が発生した場合は、メッセージIDのINSERTもロールバックされる。
    * - | (3)
      - | \ ``MessageIdRepository``\の\ ``register``\メソッドを実行し、メッセージIDをメッセージID管理テーブルにINSERTする。
    * - | (4)
      - | 一意性制約違反によって発生する\ ``DuplicateKeyException``\ をcatchする。
        | 2重受信発生を示す例外をthrowする。

- ReservationInspectionServiceImpl.java

 .. code-block:: java

    package com.example.domain.service.reservation;

    import javax.inject.Inject;
    import org.springframework.stereotype.Service;
    import org.springframework.transaction.annotation.Transactional;
    import com.example.domain.common.messaging.DuplicateMessageChecker;
    import com.example.domain.model.Reservation;

    @Service
    public class ReservationInspectionServiceImpl implements
                                                 ReservationInspectionService {

        @Inject
        DuplicateMessageChecker duplicateMessageChecker; // (1)

        @Transactional
        public void inspectAndNotify(Reservation reservation, String messageId) {

            duplicateMessageChecker.checkDuplicateMessage(messageId); // (2)

            // omitted

        }
    }


 .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
 .. list-table::
    :header-rows: 1
    :widths: 10 90

    * - 項番
      - 説明
    * - | (1)
      - | 2重受信チェックユーティリティ\ ``DuplicateMessageChecker``\ をインジェクションする。
    * - | (2)
      - | \ ``DuplicateMessageChecker``\ を使用して、2重受信チェックを行う。
        | 2重受信が発生していた場合には例外がthrowされる。

.. _SQSHowToLoggingTraceID:

メッセージのトレース
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
| メッセージのトレーサビリティ向上の為、各ログにメッセージIDを出力させる方法を説明する。
|
| メッセージIDを含めたログの例を、以下に示す。

.. code-block:: console

   date:2017-02-08 09:38:42	messageId:cad212f8-4e35-4d03-924f-5d5fe339a282	message:[START SERVICE] (omitted)
   date:2017-02-08 09:38:43	messageId:cad212f8-4e35-4d03-924f-5d5fe339a282	message:[END SERVICE  ] (omitted)
   date:2017-02-08 09:38:44	messageId:32b00a02-a851-4900-b5b8-72a44d42bedb	message:[START SERVICE] (omitted)
   date:2017-02-08 09:38:45	messageId:92c76511-3564-4332-892b-6dadae2bc090	message:[START SERVICE] (omitted)
   date:2017-02-08 09:38:45	messageId:92c76511-3564-4332-892b-6dadae2bc090	message:[END SERVICE  ] (omitted)
   date:2017-02-08 09:38:45	messageId:32b00a02-a851-4900-b5b8-72a44d42bedb	message:[END SERVICE  ] (omitted)

| メッセージIDを出力させることで、不規則に出力された場合でも、ログを結びつけることができる。
| 上記の例だと、3行目と6行目は4,5行目を跨いでいるが、同じリクエストに関するログであることがわかる。
|
| このような横断的なログ出力は、MDCを利用することで可能となる。MDCについては、|base_framework_name| のガイドライン\ `MDCの使用 <https://macchinetta.github.io/server-guideline/1.5.1.RELEASE/ja/ArchitectureInDetail/GeneralFuncDetail/Logging.html#mdc>`_\に詳しい利用法が記されている為、参照されたい。

MDCを用いてメッセージIDをログに埋め込む例を以下に示す。

- MessageIdLoggingInterceptor.java

 .. code-block:: java

    package com.example.app.common.logging;

    import org.aopalliance.intercept.MethodInterceptor;
    import org.aopalliance.intercept.MethodInvocation;
    import org.slf4j.MDC;
    import com.example.domain.model.Reservation

    public class MessageIdLoggingInterceptor implements MethodInterceptor {  // (1)

         @Override
         public Object invoke(MethodInvocation invocation) throws Throwable {

             String key = "messageId";

             Object[] arguments = invocation.getArguments();
             Parameter[] parameters = invocation.getMethod().getParameters();

             for (int i = 0; i < parameters.length; i++) {
                 Header header = parameters[i].getAnnotation(Header.class);

                 if (header != null && JmsHeaders.MESSAGE_ID.equals(header.value()) // (2)
                         && arguments[i] instanceof String) {
                     MDC.put(key, ((String) arguments[i])); // (3)
                     break;
                 }
             }

             Object ret = invocation.proceed();

             MDC.remove(key); // (4)

             return ret;
         }

    }

 .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
 .. list-table::
    :header-rows: 1
    :widths: 10 90

    * - 項番
      - 説明
    * - | (1)
      - | Spring AOPにてメッセージ埋め込み処理を差し込む為、\ ``MethodInterceptor``\ インタフェースを実装する。
    * - | (2)
      - | \ ``MethodInvocation``\ の\ ``getArguments``\ メソッドを呼び出し、リスナーメソッドの引数リストを取得する。
        | リスナーメソッドの引数のうち、\ ``Header``\ アノテーションにJMSMessageIDが指定されているものを取得する。
    * - | (3)
      - | \ ``MDC``\ の\ ``put``\ メソッドを使用して、メッセージIDを\ ``messageId``\というキーで登録する。
    * - | (4)
      - | \ ``MDC``\ の\ ``remove``\ メソッドを使用して、登録したメッセージIDを削除する。

 .. note:: **removeメソッドをfinally句で呼び出さない理由について**

    finally句でMDCのremoveメソッドを呼び出す作りにすると、例外発生時にMDCからメッセージIDがremoveされてしまい、
    Spring提供の例外ハンドラErrorHandler内でのログにメッセージIDが出力されなくなる。例外の起因となったメッセージが特定し辛くなる為、
    例外時にMDCの情報を削除する処理は、ErrorHandlerにて行うのが望ましい。

| 作成した\ ``MessageIdLoggingInterceptor``\ クラスを、Bean定義ファイルに設定する。

記述例を以下に示す。

- applicationContext.xml

 .. code-block:: xml

    <!-- (1) -->
    <beans xmlns="http://www.springframework.org/schema/beans"
       xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:context="http://www.springframework.org/schema/context"
       xmlns:aop="http://www.springframework.org/schema/aop"
       xsi:schemaLocation="http://www.springframework.org/schema/aop http://www.springframework.org/schema/aop/spring-aop.xsd
           http://www.springframework.org/schema/beans http://www.springframework.org/schema/beans/spring-beans.xsd
           http://www.springframework.org/schema/context http://www.springframework.org/schema/context/spring-context.xsd">

    <!-- (2) -->
    <bean id="messageIdLoggingInterceptor" class="com.example.app.common.logging.MessageIdLoggingInterceptor" />

    <!-- (3) -->
    <aop:config>
        <aop:advisor advice-ref="messageIdLoggingInterceptor"
            pointcut="@annotation(org.springframework.jms.annotation.JmsListener)" />
    </aop:config>

 .. tabularcolumns:: |p{0.26\linewidth}|p{0.26\linewidth}|p{0.74\linewidth}|
 .. list-table::
    :header-rows: 1
    :widths: 10 26 64

    * - 項番
      - 属性名
      - 内容
    * - | (1)
      - xmlns:aop
      - | AOP Namespaceを定義する。
        | 値として\ ``http://www.springframework.org/schema/aop``\ を指定する。
        | AOP Namespaceの詳細については、\ `Schema-based AOP support <http://docs.spring.io/autorepo/docs/spring-framework/4.3.14.RELEASE/spring-framework-reference/html/aop.html#aop-schema>`_\ を参照されたい。
    * -
      - xsi:schemaLocation
      - | スキーマのURLを指定する。
        | 値に\ ``http://www.springframework.org/schema/aop``\ と\ ``http://www.springframework.org/schema/aop/spring-aop.xsd``\ を追加する。
    * - | (2)
      - \-
      - | \ ``MessageIdLoggingInterceptor``\ をBean定義する。
    * - | (3)
      - \-
      - | (2)でBean定義した \ ``MessageIdLoggingInterceptor``\をアドバイスとして登録する。
        | ポイントカットには\ ``@annotation``\指示子を使用し、\ ``@JmsListener``\アノテーションが付与されたメソッドを指定する。

.. raw:: latex

   \newpage
