クラウドネイティブなアプリケーション
================================================================================

.. only:: html

 .. contents:: 目次
    :depth: 3
    :local:

クラウドネイティブなアプリケーションとは
--------------------------------------------------------------------------------
本ガイドラインにおけるクラウドネイティブなアプリケーションについて説明する。

クラウドネイティブなアプリケーションとは、クラウド基盤の伸縮性に対応し、必要なタイミングでリソースを増減可能な伸縮性を持ったアプリケーションである。
APサーバをステートレスな構造とし、クラウドベンダが提供する機能による動的なスケーリングを可能とする。
加えて、本ガイドラインでは動的なスケールが不可である領域の負荷分散を行う方式を提供する。

.. note::
   本ガイドラインでは、クラウド基盤の伸縮性に対応するための代表的なアプリケーション構造についてのみ説明を行う。
   基盤レイヤなどのアプリケーション以外の要素については説明しない。

本ガイドラインで説明する内容は以下のとおり。
アプリケーションの要件に応じて、必要な要素を実装すること。

.. figure:: ./imagesCloudNativeApplication/CloudNativeApplicationOverview.png
   :alt: Screen image of cloud native application.
   :width: 100%

.. tabularcolumns:: |p{0.10\linewidth}|p{0.30\linewidth}|p{0.30\linewidth}|p{0.30\linewidth}|
.. list-table::
  :header-rows: 1
  :widths: 10 30 30 30

  * - 項番
    - 項目
    - 概要
    - アプリケーションでの対応要否
  * - | ①
    - | :doc:`../ImplementationAtEachLayer/SessionManagement`
    - | セッション情報をクラウドベンダが提供するキャッシュサービス上で管理し、APサーバをステートレスな構造とする。
    - | セッションを利用するアプリケーションについては対応必須。RESTful Web Serviceなどの、セッションを利用しないアプリケーションでは対応不要。
  * - | ②
    - | :doc:`../ImplementationAtEachLayer/UploadFileManagement`
    - | アップロードファイルをクラウドベンダが提供するストレージサービス上で管理し、APサーバをステートレスな構造とする。
    - | 仮アップロードなどのアプリケーションが処理中の状態をファイルで保持するアプリケーションについては対応必須。
  * - | ③
    - | :doc:`../ImplementationAtEachLayer/PersistenceLayerScalability`
    - | データ永続層についてスケール可能なアプリケーション構造とする。
    - | データ永続層にRDBを利用し、将来的なスケール性を確保する要件がある場合に対応する。
  * - | ④
    - | :doc:`../ImplementationAtEachLayer/AsynchronousProcessing`
    - | 高負荷処理をメッセージサービスにより非同期実行し、レスポンスタイムを確保する。
    - | レスポンスタイムを優先し、高負荷処理を別サーバで非同期実行させる要件がある場合に対応する。
  * - | ⑤
    - | :doc:`../ImplementationAtEachLayer/EnvironmentValuesExternalManagement`
    - | 環境依存値をアプリケーション内部に保持せず、外部のコンフィグサーバで管理する。
    - | システム内の複数サーバ間での設定値の共有や、同一アプリケーションでの稼働環境(本番環境・ステージング環境・開発環境など)の切り替えを行う場合に対応する。
  * - | ⑥
    - | :doc:`../ImplementationAtEachLayer/HealthCheck`
    - | クラウドベンダが提供するヘルスチェックに加えて、アプリケーションからヘルスチェックを行う。
    - | クラウドベンダ機能の他に、アプリケーションからヘルスチェックを行う要件がある場合に対応する。
  * - | ⑦
    - | :doc:`../ImplementationAtEachLayer/LogManagement`
    - | クラウド基盤の伸縮性に対応したログ管理を行う。
    - | アプリケーションからログ出力を行う場合は対応必須。


AWSクラウドデザインパターンとの対応
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
本ガイドラインで説明する内容とAWSクラウドデザインパターンとの対応について説明する。

.. note::
   AWSクラウドデザインパターンとは、代表的なクラウドベンダであるAmazon Web Service（AWS）を利用したシステムアーキテクチャ設計を行う際のノウハウが整理されたドキュメントである。
   AWS利用者へ向けた内容であるが、クラウドネイティブなアプリケーションを開発するにあたって汎用的な考え方が網羅されている。

   詳細については、 `AWSクラウドデザインパターン <http://aws.clouddesignpattern.org/index.php>`_ を参照されたい。

本ガイドラインにおける :doc:`../ImplementationAtEachLayer/index` の各節とAWSクラウドデザインパターンの対応関係は以下のとおり。
なお、フレームワークの役割と関連性が薄い一部のデザインパターンは省略している。

.. tabularcolumns:: |p{0.20\linewidth}|p{0.40\linewidth}|p{0.20\linewidth}|p{0.20\linewidth}|
.. list-table::
  :header-rows: 1
  :widths: 20 40 20 20

  * - カテゴリ
    - AWSクラウドデザインパターン
    - 本ガイドラインでの対応(共通)
    - 本ガイドラインでの対応(AWS)
  * - | `基本のパターン <http://aws.clouddesignpattern.org/index.php/%E3%82%AB%E3%83%86%E3%82%B4%E3%83%AA:CDP:%E5%9F%BA%E6%9C%AC%E3%81%AE%E3%83%91%E3%82%BF%E3%83%BC%E3%83%B3>`_
    - | `Scale Outパターン（サーバ数の動的増減） <http://aws.clouddesignpattern.org/index.php/CDP:Scale_Out%E3%83%91%E3%82%BF%E3%83%BC%E3%83%B3>`_
    - | なし
    - | :doc:`../AWSCollaboration/AutoScale`
  * - | `可用性を向上するパターン <http://aws.clouddesignpattern.org/index.php/%E3%82%AB%E3%83%86%E3%82%B4%E3%83%AA:CDP:%E5%8F%AF%E7%94%A8%E6%80%A7%E3%82%92%E5%90%91%E4%B8%8A%E3%81%99%E3%82%8B%E3%83%91%E3%82%BF%E3%83%BC%E3%83%B3>`_
    - | `Multi-Serverパターン（サーバの冗長化） <http://aws.clouddesignpattern.org/index.php/CDP:Multi-Server%E3%83%91%E3%82%BF%E3%83%BC%E3%83%B3>`_
    - | :doc:`../ImplementationAtEachLayer/HealthCheck`
    - | 共通のみ
  * - |
    - | `Deep Health Checkパターン（システムのヘルスチェック） <http://aws.clouddesignpattern.org/index.php/CDP:Deep_Health_Check%E3%83%91%E3%82%BF%E3%83%BC%E3%83%B3>`_
    - | :doc:`../ImplementationAtEachLayer/HealthCheck`
    - | 共通のみ
  * - | `動的コンテンツを処理するパターン <http://aws.clouddesignpattern.org/index.php/%E3%82%AB%E3%83%86%E3%82%B4%E3%83%AA:CDP:%E5%8B%95%E7%9A%84%E3%82%B3%E3%83%B3%E3%83%86%E3%83%B3%E3%83%84%E3%82%92%E5%87%A6%E7%90%86%E3%81%99%E3%82%8B%E3%83%91%E3%82%BF%E3%83%BC%E3%83%B3>`_
    - | `State Sharingパターン（ステート情報の共有） <http://aws.clouddesignpattern.org/index.php/CDP:State_Sharing%E3%83%91%E3%82%BF%E3%83%BC%E3%83%B3>`_
    - | :doc:`../ImplementationAtEachLayer/SessionManagement`
      | :doc:`../ImplementationAtEachLayer/UploadFileManagement`
      | :doc:`../ImplementationAtEachLayer/LogManagement`
    - | :doc:`../AWSCollaboration/UploadFileManagement`
      | :doc:`../AWSCollaboration/LogManagement`
  * - |
    - | `URL Rewritingパターン（静的コンテンツの退避） <http://aws.clouddesignpattern.org/index.php/CDP:URL_Rewriting%E3%83%91%E3%82%BF%E3%83%BC%E3%83%B3>`_
    - | なし
    - | :doc:`../AWSCollaboration/StaticContents`
  * - | `静的コンテンツを処理するパターン <http://aws.clouddesignpattern.org/index.php/%E3%82%AB%E3%83%86%E3%82%B4%E3%83%AA:CDP:%E9%9D%99%E7%9A%84%E3%82%B3%E3%83%B3%E3%83%86%E3%83%B3%E3%83%84%E3%82%92%E5%87%A6%E7%90%86%E3%81%99%E3%82%8B%E3%83%91%E3%82%BF%E3%83%BC%E3%83%B3>`_
    - | `Web Storageパターン（可用性の高いインターネットストレージ活用） <http://aws.clouddesignpattern.org/index.php/CDP:Web_Storage%E3%83%91%E3%82%BF%E3%83%BC%E3%83%B3>`_
    - | :doc:`../ImplementationAtEachLayer/UploadFileManagement`
    - | :doc:`../AWSCollaboration/UploadFileManagement`
  * - |
    - | `Direct Hostingパターン（インターネットストレージで直接ホスティング） <http://aws.clouddesignpattern.org/index.php/CDP:Direct_Hosting%E3%83%91%E3%82%BF%E3%83%BC%E3%83%B3>`_
    - | なし
    - | なし
  * - |
    - | `Private Distributionパターン（特定ユーザへのデータ配布） <http://aws.clouddesignpattern.org/index.php/CDP:Private_Distribution%E3%83%91%E3%82%BF%E3%83%BC%E3%83%B3>`_
    - | なし
    - | なし
  * - |
    - | `Cache Distributionパターン（ユーザに物理的に近い位置へのデータ配置） <http://aws.clouddesignpattern.org/index.php/CDP:Cache_Distribution%E3%83%91%E3%82%BF%E3%83%BC%E3%83%B3>`_
    - | なし
    - | :doc:`../AWSCollaboration/StaticContents`
  * - |
    - | `Rename Distributionパターン（変更遅延のない配信） <http://aws.clouddesignpattern.org/index.php/CDP:Rename_Distribution%E3%83%91%E3%82%BF%E3%83%BC%E3%83%B3>`_
    - | なし
    - | なし
  * - |
    - | `Private Cache Distributionパターン（CDNを用いたプライベート配信） <http://aws.clouddesignpattern.org/index.php/CDP:Private_Cache_Distribution%E3%83%91%E3%82%BF%E3%83%BC%E3%83%B3>`_
    - | なし
    - | なし
  * - | `データをアップロードするパターン <http://aws.clouddesignpattern.org/index.php/%E3%82%AB%E3%83%86%E3%82%B4%E3%83%AA:CDP:%E3%83%87%E3%83%BC%E3%82%BF%E3%82%92%E3%82%A2%E3%83%83%E3%83%97%E3%83%AD%E3%83%BC%E3%83%89%E3%81%99%E3%82%8B%E3%83%91%E3%82%BF%E3%83%BC%E3%83%B3>`_
    - | `Write Proxyパターン（インターネットストレージへの高速アップロード） <http://aws.clouddesignpattern.org/index.php/CDP:Write_Proxy%E3%83%91%E3%82%BF%E3%83%BC%E3%83%B3>`_
    - | :doc:`../ImplementationAtEachLayer/UploadFileManagement`
    - | :doc:`../AWSCollaboration/UploadFileManagement`
  * - |
    - | `Storage Indexパターン（インターネットストレージの効率化） <http://aws.clouddesignpattern.org/index.php/CDP:Storage_Index%E3%83%91%E3%82%BF%E3%83%BC%E3%83%B3>`_
    - | なし
    - | なし
  * - |
    - | `Direct Object Uploadパターン（アップロード手順の簡略化） <http://aws.clouddesignpattern.org/index.php/CDP:Direct_Object_Upload%E3%83%91%E3%82%BF%E3%83%BC%E3%83%B3>`_
    - | なし
    - | なし
  * - |  `リレーショナルデータベースのパターン <http://aws.clouddesignpattern.org/index.php/%E3%82%AB%E3%83%86%E3%82%B4%E3%83%AA:CDP:%E3%83%AA%E3%83%AC%E3%83%BC%E3%82%B7%E3%83%A7%E3%83%8A%E3%83%AB%E3%83%87%E3%83%BC%E3%82%BF%E3%83%99%E3%83%BC%E3%82%B9%E3%81%AE%E3%83%91%E3%82%BF%E3%83%BC%E3%83%B3>`_
    - | `Read Replicaパターン（読込専用レプリカによる負荷分散） <http://aws.clouddesignpattern.org/index.php/CDP:Read_Replica%E3%83%91%E3%82%BF%E3%83%BC%E3%83%B3>`_
    - | :doc:`../ImplementationAtEachLayer/PersistenceLayerScalability`
    - | :doc:`../AWSCollaboration/DatabaseReadReplica`
  * - |
    - | `Inmemory DB Cacheパターン（頻度の高いデータのキャッシュ化） <http://aws.clouddesignpattern.org/index.php/CDP:Inmemory_DB_Cache%E3%83%91%E3%82%BF%E3%83%BC%E3%83%B3>`_
    - | :doc:`../ImplementationAtEachLayer/PersistenceLayerScalability`
      | :doc:`../ArchitectureInDetail/DataAccessDetail/CacheAbstraction`
    - | 共通のみ
  * - |
    - | `Sharding Writeパターン（書き込みの効率化） <http://aws.clouddesignpattern.org/index.php/CDP:Sharding_Write%E3%83%91%E3%82%BF%E3%83%BC%E3%83%B3>`_
    - | :doc:`../ImplementationAtEachLayer/PersistenceLayerScalability`
      | :doc:`../ArchitectureInDetail/DataAccessDetail/DataAccessMyBatis3`
    - | :doc:`../AWSCollaboration/DatabaseSharding`
  * - |  `非同期処理/バッチ処理のパターン <http://aws.clouddesignpattern.org/index.php/%E3%82%AB%E3%83%86%E3%82%B4%E3%83%AA:CDP:%E9%9D%9E%E5%90%8C%E6%9C%9F%E5%87%A6%E7%90%86/%E3%83%90%E3%83%83%E3%83%81%E5%87%A6%E7%90%86%E3%81%AE%E3%83%91%E3%82%BF%E3%83%BC%E3%83%B3>`_
    - | `Queuing Chainパターン（システムの疎結合化） <http://aws.clouddesignpattern.org/index.php/CDP:Queuing_Chain%E3%83%91%E3%82%BF%E3%83%BC%E3%83%B3>`_
    - | :doc:`../ImplementationAtEachLayer/AsynchronousProcessing`
    - | :doc:`../AWSCollaboration/AsynchronousProcessing`
  * - |
    - | `Priority Queueパターン（優先順位の変更） <http://aws.clouddesignpattern.org/index.php/CDP:Priority_Queue%E3%83%91%E3%82%BF%E3%83%BC%E3%83%B3>`_
    - | なし
    - | なし
  * - |
    - | `Fanoutパターン（複数種類の処理を非同期かつ並列に実行） <http://aws.clouddesignpattern.org/index.php/CDP:Fanout%E3%83%91%E3%82%BF%E3%83%BC%E3%83%B3>`_
    - | なし
    - | なし
  * - |  `運用保守のパターン <http://aws.clouddesignpattern.org/index.php/%E3%82%AB%E3%83%86%E3%82%B4%E3%83%AA:CDP:%E9%81%8B%E7%94%A8%E4%BF%9D%E5%AE%88%E3%81%AE%E3%83%91%E3%82%BF%E3%83%BC%E3%83%B3>`_
    - | `Bootstrapパターン（起動設定の自動取得） <http://aws.clouddesignpattern.org/index.php/CDP:Bootstrap%E3%83%91%E3%82%BF%E3%83%BC%E3%83%B3>`_
    - | :doc:`../ImplementationAtEachLayer/EnvironmentValuesExternalManagement`
    - | 共通のみ
  * - |
    - | `Cloud DIパターン（変更が多い部分の外出し） <http://aws.clouddesignpattern.org/index.php/CDP:Cloud_DI%E3%83%91%E3%82%BF%E3%83%BC%E3%83%B3>`_
    - | :doc:`../ImplementationAtEachLayer/EnvironmentValuesExternalManagement`
    - | 共通のみ
  * - |
    - | `Monitoring Integrationパターン（モニタリングツールの一元化） <http://aws.clouddesignpattern.org/index.php/CDP:Monitoring_Integration%E3%83%91%E3%82%BF%E3%83%BC%E3%83%B3>`_
    - | なし
    - | :doc:`../AWSCollaboration/AutoScale`
  * - |
    - | `Log Aggregation パターン(ログの集約) <http://aws.clouddesignpattern.org/index.php/CDP:Log_Aggregation_%E3%83%91%E3%82%BF%E3%83%BC%E3%83%B3>`_
    - | :doc:`../ImplementationAtEachLayer/LogManagement`
    - | :doc:`../AWSCollaboration/LogManagement`


Twelve-Factor Appとの対応
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
本ガイドラインで説明する内容とTwelve-Factor Appとの対応について説明する。

.. note::
   Twelve-Factor Appとは、モダンなクラウドアプリケーション開発のベストプラクティスの一つである。

   詳細については、 `The Twelve-Factor App <https://12factor.net/ja/>`_ を参照されたい。

本ガイドラインにおける :doc:`../ImplementationAtEachLayer/index` の各節とTwelve-Factor Appの各要素との対応関係は以下のとおり。

.. tabularcolumns:: |p{0.20\linewidth}|p{0.40\linewidth}|p{0.40\linewidth}|
.. list-table::
  :header-rows: 1
  :widths: 20 40 40

  * - Twelve-Factor App
    - 本ガイドラインでの対応(共通)
    - 本ガイドラインでの対応(AWS)
  * - | `I. コードベース <https://12factor.net/ja/codebase>`_
    - | フレームワークのスコープ外
    - | フレームワークのスコープ外
  * - | `II. 依存関係 <https://12factor.net/ja/dependencies>`_
    - | Maven等のツールで解決
    - | 共通のみ
  * - | `III. 設定 <https://12factor.net/ja/config>`_
    - | :doc:`../ImplementationAtEachLayer/EnvironmentValuesExternalManagement`
    - | 共通のみ
  * - | `IV. バックエンドサービス <https://12factor.net/ja/backing-services>`_
    - | :doc:`../ArchitectureInDetail/DataAccessDetail/CacheAbstraction`
    - | :doc:`../AWSCollaboration/UploadFileManagement`
      | :doc:`../AWSCollaboration/DatabaseSharding`
      | :doc:`../AWSCollaboration/AsynchronousProcessing`
      | :doc:`../AWSCollaboration/MailSending`
  * - | `V. ビルド、リリース、実行 <https://12factor.net/ja/build-release-run>`_
    - | フレームワークのスコープ外
    - | フレームワークのスコープ外
  * - | `VI. プロセス <https://12factor.net/ja/processes>`_
    - | :doc:`../ImplementationAtEachLayer/SessionManagement`
      | :doc:`../ImplementationAtEachLayer/UploadFileManagement`
    - | :doc:`../AWSCollaboration/UploadFileManagement`
  * - | `VII. ポートバインディング <https://12factor.net/ja/port-binding>`_
    - | なし
    - | なし
  * - | `VIII. 並行性 <https://12factor.net/ja/concurrency>`_
    - | :doc:`../ImplementationAtEachLayer/SessionManagement`
      | :doc:`../ImplementationAtEachLayer/UploadFileManagement`
      | :doc:`../ImplementationAtEachLayer/PersistenceLayerScalability`
      | :doc:`../ImplementationAtEachLayer/AsynchronousProcessing`
      | :doc:`../ArchitectureInDetail/DataAccessDetail/DataAccessMyBatis3`
      | :doc:`../ArchitectureInDetail/DataAccessDetail/CacheAbstraction`
    - | :doc:`../AWSCollaboration/DatabaseSharding`
      | :doc:`../AWSCollaboration/DatabaseReadReplica`
  * - | `IX. 廃棄容易性 <https://12factor.net/ja/disposability>`_
    - | :doc:`../ImplementationAtEachLayer/SessionManagement`
      | :doc:`../ImplementationAtEachLayer/UploadFileManagement`
      | :doc:`../ImplementationAtEachLayer/LogManagement`
    - | :doc:`../AWSCollaboration/LogManagement`
  * - | `X. 開発/本番一致 <https://12factor.net/ja/dev-prod-parity>`_
    - | フレームワークのスコープ外
    - | フレームワークのスコープ外
  * - | `XI. ログ <https://12factor.net/ja/logs>`_
    - | :doc:`../ImplementationAtEachLayer/LogManagement`
    - | なし
  * - | `XII. 管理プロセス <https://12factor.net/ja/admin-processes>`_
    - | なし
    - | なし


クラウドネイティブ成熟度モデルとの対応
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
Springを開発、提供しているPivotal社が提示している
\ `クラウドネイティブ成熟度モデル（Cloud Native Maturity Model） <http://www.slideshare.net/Pivotal/the-cloud-native-journey-58445711>`_\
と本フレームワークの対応関係を示す。

.. tabularcolumns:: |p{0.10\linewidth}|p{0.30\linewidth}|p{0.30\linewidth}|p{0.30\linewidth}|
.. list-table::
  :header-rows: 1
  :widths: 10 30 30 30

  * - 成熟度
    - Pivotal社が提示する要件
    - 本ガイドラインでの対応(共通)
    - 本ガイドラインでの対応(AWS)
  * - | Cloud Native
    - | Microservices architecture
      | API-first design
    - | なし
    - | なし
  * - | Cloud Resilient
    - | Fault-tolerant and resilient design
      | Cloud-agnostic runtime implementation
      | Bundled metrics and monitoring
      | Proactive failure testing
    - |  :doc:`../ImplementationAtEachLayer/HealthCheck`
    - | :doc:`../AWSCollaboration/AutoScale`
  * - | Cloud Friendly
    - | 12 factor App methodology
      | Horizontally scalable
      | Leverages platform for high availability
    - | :doc:`../ImplementationAtEachLayer/SessionManagement`
      | :doc:`../ImplementationAtEachLayer/PersistenceLayerScalability`
      | :doc:`../ArchitectureInDetail/DataAccessDetail/DataAccessMyBatis3`
      | :doc:`../ArchitectureInDetail/DataAccessDetail/CacheAbstraction`
      | :doc:`../ImplementationAtEachLayer/AsynchronousProcessing`
    - | :doc:`../AWSCollaboration/DatabaseSharding`
      | :doc:`../AWSCollaboration/AsynchronousProcessing`
      | :doc:`../AWSCollaboration/DatabaseReadReplica`
  * - | Cloud Ready
    - | No permanent disk access
      | Self-contained application
      | Platform-managed ports and networking
      | Consumes platform-managed backing services
    - | :doc:`../ImplementationAtEachLayer/UploadFileManagement`
      | :doc:`../ImplementationAtEachLayer/EnvironmentValuesExternalManagement`
      | :doc:`../ImplementationAtEachLayer/LogManagement`
    - | :doc:`../AWSCollaboration/UploadFileManagement`
      | :doc:`../AWSCollaboration/StaticContents`
      | :doc:`../AWSCollaboration/MailSending`
      | :doc:`../AWSCollaboration/LogManagement`


.. _cloud_native_application_framework_relation:

|base_framework_name| との関係
--------------------------------------------------------------------------------
|framework_name| は |base_framework_name| を拡張し、クラウドネイティブなアプリケーションを開発するためのベストプラクティスを提供するものである。
|base_framework_name| が提供するライブラリやノウハウについては原則として踏襲するものとし、必要に応じて拡張を行う。

バージョンの対応関係
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
|framework_name| と |base_framework_name| のバージョンの対応関係を以下に示す。

.. tabularcolumns:: |p{0.50\linewidth}|p{0.50\linewidth}|
.. list-table::
  :header-rows: 1
  :widths: 50 50

  * - |framework_name|
    - |base_framework_name|
  * - | |framework_version|
    - | |base_framework_version|

機能の対応状況
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
本ガイドラインにおける |base_framework_name| が提供する機能の対応状況について説明する。

共通ライブラリ
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
|base_framework_name| が提供する\ `共通ライブラリ <http://macchinetta.github.io/server-guideline/1.4.0.RELEASE/ja/Overview/FrameworkStack.html#frameworkstack-common-library>`_\ の対応状況は以下の通り。

.. tabularcolumns:: |p{0.15\linewidth}|p{0.25\linewidth}|p{0.40\linewidth}|p{0.25\linewidth}|
.. list-table::
  :header-rows: 1
  :widths: 15 25 40 25

  * - | プロジェクト名
    - | 分類
    - | 部品名
    - | 対応状況(AWS)
  * - | terasoluna-gfw-common
    - | 例外ハンドリング
    - | 例外クラス
    - | 検証済み
  * - |
    - |
    - | 例外クラス
    - | 検証済み
  * - |
    - |
    - | 例外コード
    - | 検証済み
  * - |
    - |
    - | 例外ログ出力インターセプタ
    - | 検証済み
  * - |
    - | システム時刻
    - | システム時刻ファクトリ
    - | 検証済み
  * - |
    - | コードリスト
    - | コードリスト
    - | 検証済み
  * - |
    - | データベースアクセス（共通編）
    - | クエリエスケープ
    - | 未検証
  * - |
    - |
    - | シーケンサ
    - | 未検証
  * - | terasoluna-gfw-string
    - | 文字列処理
    - | 半角全角変換
    - | 未検証
  * - | terasoluna-gfw-codepoints
    - | 文字列処理
    - | コードポイントチェック
    - | 未検証
  * - |
    - | 入力チェック
    - | コードポイントチェック用Bean Validation制約アノテーション
    - | 未検証
  * - | terasoluna-gfw-validator
    - | 入力チェック
    - | バイト長チェック用Bean Validation制約アノテーション
    - | 未検証
  * - |
    - |
    - | フィールド値比較相関チェック用Bean Validation制約アノテーション
    - | 未検証
  * - | terasoluna-gfw-jodatime
    - | システム時刻
    - | Joda Time用システム時刻ファクトリ
    - | 検証済み
  * - | terasoluna-gfw-web
    - | 二重送信防止
    - | トランザクショントークンチェック
    - | 検証済み（制約有り） \*1
  * - |
    - | 例外ハンドリング
    - | 例外ハンドラ
    - | 検証済み
  * - |
    - |
    - | 例外ログ出力インターセプタ
    - | 検証済み
  * - |
    - | コードリスト
    - | コードリスト埋込インターセプタ
    - | 検証済み
  * - |
    - | ファイルダウンロード
    - | 汎用ダウンロードView
    - | 未検証
  * - |
    - | ロギング
    - | トラッキングID格納用サーブレットフィルタ
    - | 検証済み
  * - |
    - |
    - | 汎用MDC格納用サーブレットフィルタ
    - | 検証済み
  * - |
    - |
    - | MDCクリア用サーブレットフィルタ
    - | 検証済み
  * - | terasoluna-gfw-web-jsp
    - | 二重送信防止
    - | トランザクショントークン出力用のJSPタグ
    - | 検証済み
  * - |
    - | ページネーション
    - | ページネーションリンク表示用のJSPタグ
    - | 検証済み
  * - |
    - | メッセージ管理
    - | 結果メッセージ表示用のJSPタグ
    - | 検証済み
  * - |
    - | EL Functions
    - | XSS対策用EL関数
    - | 検証済み
  * - |
    - |
    - | URL用EL関数
    - | 未検証
  * - |
    - |
    - | DOM変換用EL関数
    - | 未検証
  * - |
    - |
    - | ユーティリティEL関数
    - | 未検証
  * - | terasoluna-gfw-security-web
    - | ロギング
    - | 認証ユーザ名格納用サーブレットフィルタ
    - | 検証済み

#. 二重送信防止に関する制約の内容については、:doc:`../ImplementationAtEachLayer/CreateWebApplicationProject` を参照されたい。

提供機能
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
|base_framework_name| \ `Development Guideline <http://macchinetta.github.io/server-guideline/1.4.0.RELEASE/ja/index.html>`_\ が提供する機能の対応状況は以下の通り。

.. tabularcolumns:: |p{0.33\linewidth}|p{0.33\linewidth}|p{0.33\linewidth}|
.. list-table::
  :header-rows: 1
  :widths: 33 33 33

  * - | 分類
    - | 機能名
    - | 対応状況(AWS)
  * - | Webアプリ開発機能
    - | 入力チェック
    - | 検証済み
  * - |
    - | 例外ハンドリング
    - | 検証済み
  * - |
    - | セッション管理
    - | 未検証
  * - |
    - | ページネーション
    - | 検証済み
  * - |
    - | 二重送信防止
    - | 検証済み（制約有り） \*1
  * - |
    - | メッセージ管理
    - | 検証済み
  * - |
    - | 国際化
    - | 未検証
  * - |
    - | コードリスト
    - | 検証済み
  * - |
    - | ファイルアップロード
    - | 検証済み（拡張有り）
  * - |
    - | ファイルダウンロード
    - | 未検証
  * - |
    - | Tilesによる画面レイアウト
    - | 検証済み（制約有り） \*2
  * - |
    - | 共通ライブラリが提供するJSP Tag Library と EL Functions
    - | 検証済み
  * - |
    - | Ajax
    - | 未検証
  * - |
    - | ヘルスチェック
    - | 検証済み(拡張有り)
  * - | Web Service
    - | RESTful Web Service
    - | 未検証
  * - |
    - | RESTクライアント（HTTPクライアント）
    - | 未検証
  * - |
    - | SOAP Web Service（サーバ/クライアント）
    - | 未検証
  * - | データアクセス
    - | データベースアクセス（共通編）
    - | 検証済み
  * - |
    - | データベースアクセス（MyBatis3編）
    - | 検証済み（拡張有り）
  * - |
    - | データベースアクセス（JPA編）
    - | 未検証
  * - |
    - | 排他制御
    - | 検証済み
  * - | アプリケーション形態に依存しない汎用機能
    - | ロギング
    - | 検証済み
  * - |
    - | プロパティ管理
    - | 検証済み（拡張有り）
  * - |
    - | 日付操作(JSR-310 Date and Time API)
    - | 未検証
  * - |
    - | 日付操作(Joda Time)
    - | 検証済み
  * - |
    - | システム時刻
    - | 検証済み
  * - |
    - | 文字列処理
    - | 未検証
  * - |
    - | Beanマッピング(Dozer)
    - | 検証済み
  * - | メッセージ連携
    - | E-mail送信(SMTP)
    - | 検証済み
  * - |
    - | JMS(Java Message Service)
    - | 検証済み（拡張有り）
  * - | セキュリティ対策
    - | Spring Security概要
    - | 検証済み
  * - |
    - | 認証
    - | 検証済み
  * - |
    - | 認可
    - | 検証済み
  * - |
    - | セッション管理
    - | 未検証
  * - |
    - | CSRF対策
    - | 検証済み
  * - |
    - | ブラウザのセキュリティ対策機能との連携
    - | 未検証
  * - |
    - | XSS対策
    - | 検証済み
  * - |
    - | 暗号化
    - | 未検証

#. 二重送信防止に関する制約の内容については、:doc:`../ImplementationAtEachLayer/CreateWebApplicationProject` を参照されたい。
#. Tilesによる画面レイアウトに関する制約の内容については、:doc:`../ImplementationAtEachLayer/SessionManagement` を参照されたい。

.. raw:: latex

   \newpage
