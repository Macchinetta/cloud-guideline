セッション外部管理
================================================================================

.. only:: html

 .. contents:: 目次
    :depth: 3
    :local:

Overview
--------------------------------------------------------------------------------

AWS環境でオートスケーリングを利用した場合に、スケールイン発生時にセッションなどのEC2インスタンス固有の情報は失われてしまう。
その為、ELBによるロードバランシングにおいてスティッキーセッションはOFF（デフォルト）とし、アプリケーションの構造としてどのEC2インスタンスに
リクエストが割り振られた場合でも業務継続可能とする為の方式を示す。

|

AWS上での構成
""""""""""""""""""""""""
:ref:`session-management-label` に則って、AWS上では以下の構成とする。

 .. figure:: ./imagesSessionManagement/SessionManagementConstitution.png
   :alt: Screen image of Session management.
   :width: 100%

 .. note::
  上記は、\ `クラスター化された Redis <https://docs.aws.amazon.com/ja_jp/AmazonElastiCache/latest/UserGuide/Replication.Redis.Groups.html#Replication.Redis.Groups.Cluster>`_\
  を使用した構成のサンプルを示している。Redis構成の比較については、\ `従来の Redis と クラスター化された Redis <https://docs.aws.amazon.com/ja_jp/AmazonElastiCache/latest/UserGuide/Replication.Redis-RedisCluster.html>`_\
  を参照されたい。

|



How to use
--------------------------------------------------------------------------------

本ガイドラインでは、AWS環境固有の使用方法を示す。

|

エンドポイントの検索
""""""""""""""""""""""""""""""""""""""""""""""""

\ `クラスター化された Redis <https://docs.aws.amazon.com/ja_jp/AmazonElastiCache/latest/UserGuide/Replication.Redis.Groups.html#Replication.Redis.Groups.Cluster>`_\
を使用した場合のエンドポイントは、\ `クラスター化された Redis クラスターのエンドポイントの検索 <https://docs.aws.amazon.com/ja_jp/AmazonElastiCache/latest/UserGuide/Endpoints.html#Endpoints.Find.RedisCluster>`_\
を参照されたい。

| 設定方法については、:ref:`session-management-endpoint-label` を参照されたい。


|

AWS環境での固有設定
""""""""""""""""""""""""""""""""""""""""""""""""

\ `Spring Session with Redis <http://docs.spring.io/spring-session/docs/1.3.1.RELEASE/reference/html5/#httpsession-redis>`_\
は、Redisのconfigコマンドを使用して初期化時に自動で設定を実施するが、ElastiCacheのようなマネージドサービスでは
configコマンドが無効化されていてエラーになってしまうため、以下の設定が必要となる。
詳細については、\ `SessionDeletedEvent and SessionExpiredEvent <http://docs.spring.io/spring-session/docs/1.3.1.RELEASE/reference/html5/#api-redisoperationssessionrepository-sessiondestroyedevent>`_\ を参照されたい。


- :file:`application-context.xml`

 .. code-block:: xml

   <!-- (1) -->
   <util:constant
      static-field="org.springframework.session.data.redis.config.ConfigureRedisAction.NO_OP"/>


 .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
 .. list-table::
   :header-rows: 1
   :widths: 10 90

   * - 項番
     - 説明
   * - | (1)
     - | \ `Spring Session with Redis <http://docs.spring.io/spring-session/docs/1.3.1.RELEASE/reference/html5/#httpsession-redis>`_\の自動設定を無効化する設定を定義。



.. raw:: latex

   \newpage
