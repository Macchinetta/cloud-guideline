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
  上記は、\ `クラスタ化された Redis <https://docs.aws.amazon.com/ja_jp/AmazonElastiCache/latest/UserGuide/Replication.Redis.Groups.html#Replication.Redis.Groups.Cluster>`_\
  を使用した構成のサンプルを示している。Redis構成の比較については、\ `従来の Redis と クラスタ化された Redis <https://docs.aws.amazon.com/ja_jp/AmazonElastiCache/latest/UserGuide/Replication.Redis-RedisCluster.html>`_\
  を参照されたい。

|



How to use
--------------------------------------------------------------------------------

本ガイドラインでは、AWS環境固有の使用方法を示す。

|

エンドポイントの検索
""""""""""""""""""""""""""""""""""""""""""""""""

\ `クラスタ化された Redis <https://docs.aws.amazon.com/ja_jp/AmazonElastiCache/latest/UserGuide/Replication.Redis.Groups.html#Replication.Redis.Groups.Cluster>`_\
を使用した場合のエンドポイントは、\ `クラスタ化された Redis クラスタのエンドポイントの検索 <https://docs.aws.amazon.com/ja_jp/AmazonElastiCache/latest/UserGuide/Endpoints.html#Endpoints.Find.RedisCluster>`_\
を参照されたい。

| 設定方法については、:ref:`session-management-endpoint-label` を参照されたい。


|

AWS環境での固有設定
""""""""""""""""""""""""""""""""""""""""""""""""

\ `Spring Session with Redis <https://docs.spring.io/spring-session/docs/2.2.0.RELEASE/reference/html5/#httpsession-redis>`_\
は、Redisのconfigコマンドを使用して初期化時に自動で設定を実施するが、ElastiCacheのようなマネージドサービスでは
configコマンドが無効化されていてエラーになってしまうため、以下の設定が必要となる。
詳細については、\ `Spring boot Reference - Security properties <https://docs.spring.io/spring-boot/docs/2.2.4.RELEASE/reference/html/appendix-application-properties.html#security-properties>`_\ を参照されたい。



- :file:`application.yml`
 .. code-block:: yaml

   spring:
     session:
       redis:
         # (1)
         configure-action: NONE

 .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
 .. list-table::
   :header-rows: 1
   :widths: 10 90

   * - 項番
     - 説明
   * - | (1)
     - | \ `Spring boot - Security properties <https://docs.spring.io/spring-boot/docs/2.2.4.RELEASE/reference/html/appendix-application-properties.html#security-properties>`_\ BootのRedis自動設定を無効化する設定を定義。

.. raw:: latex

   \newpage
