更新履歴
================================================================================

.. tabularcolumns:: |p{0.15\linewidth}|p{0.25\linewidth}|p{0.60\linewidth}|
.. list-table::
    :header-rows: 1
    :widths: 15 25 60

    * - 更新日付
      - 更新箇所
      - 更新内容

    * - 2020-6-29
      - \-
      - 1.2.0 RELEASE版公開

    * -
      - :doc:`../Overview/FrameworkStack`
      - Spring Boot Actuatorのリンクを変更

    * -
      - :doc:`../ImplementationAtEachLayer/CreateWebApplicationProject`
      - `Provide a mechanism to easily register a custom RequestDataValueProcessor <https://github.com/spring-projects/spring-boot/issues/4676>`_\ の改善に伴い
        制約事項「トランザクショントークンチェックを使用するための設定方法が異なる」を削除(管理ID#B18)

    * -
      - :doc:`../ImplementationAtEachLayer/SessionManagement`
      - Spring BootのRedisSessionConfigurationのアクセス修飾子変更に伴い、制約事項を1項目追加(管理ID#B15)

    * -
      - :doc:`../AWSCollaboration/SessionManagement`
      - Spring BootのRedisSessionConfigurationのアクセス修飾子変更に伴い、Redis自動設定の無効化手順の変更(管理ID#B16)

    * -
      - :doc:`../ImplementationAtEachLayer/HealthCheck`
      - ヘルスチェックのResponse内容の例を更新(管理ID#B14)

    * -
      - :doc:`../ArchitectureInDetail/DataAccessDetail/CacheAbstraction`
      - Cacheアノテーションのインターフェース利用を削除(管理ID#B19)

    * -
      - :doc:`../AWSCollaboration/DatabaseSharding`
      - Cacheアノテーションのインターフェース利用を削除(管理ID#B20)

        AmazonDynamoDBの直接利用に伴う記述の修正(管理ID#B29)

    * -
      - :doc:`../AWSCollaboration/Queuing/AsynchronousProcessing`
      - 個別に導入するライブラリを更新

        * amazon-sqs-java-messaging-lib 1.0.8
        * spring-jms 4.3.25

    * -
      - :doc:`../AWSCollaboration/DatabaseReadReplica`
      - log4jdbc-remixライブラリの除外に伴う修正(管理ID#B30)

    * -
      - :doc:`../Overview/FrameworkStack`
      - Macchinetta Framework for Javaのバージョンを1.7.0.RELEASEに更新

        * spring-cloud-dependenciesのバージョンをHoxton.SR3に更新
        * spring-cloud-dependenciesのバージョン更新に伴い利用するOSSのバージョンを更新

        個別に導入するライブラリを更新

        * amazon-sqs-java-messaging-lib 1.0.8
        * spring-data-dynamodb ライブラリ削除

        利用するOSS一覧の見直しに伴う修正

    * -
      - :doc:`../Introduction/Introduction`
      - 動作検証環境を更新

        * CentOS 7.6
        * RDS(PostgreSQL 11)
        
    * - 2019-3-25
      - \-
      - 1.1.1 RELEASE版公開

    * -
      - 全般
      - ガイドラインの誤記(タイプミスや単純な記述ミスなど)の修正

        記載内容の改善

        Macchinetta Framework for Java (1.x)への対応リンクを1.6.1.RELEASE版に更新

        利用するOSSのバージョン更新に伴うリンク修正

    * -
      - :doc:`../Introduction/Introduction`
      - 動作検証環境を更新

        * CentOS 7.4
        * Apache Tomcat 9.0
        * RDS(PostgreSQL 10)

    * -
      - :doc:`../Overview/FrameworkStack`
      - Macchinetta Framework for Javaのバージョンを1.6.1.RELEASEに更新

        * spring-cloud-dependenciesのバージョンをGreenwich.RELEASEに更新
        * spring-cloud-dependenciesのバージョン更新に伴い利用するOSSのバージョンを更新
        * Spring IO platform廃止に伴い説明を修正

        個別に導入するライブラリを更新

        * amazon-sqs-java-messaging-lib 1.0.4
        * aws-java-sdk-dynamodb 1.11.415
        * spring-data-dynamodb 5.0.4

        利用するOSS一覧の見直しに伴う修正

    * -
      - :doc:`../ImplementationAtEachLayer/CreateWebApplicationProject`
      - Macchinetta Framework for Javaのバージョン更新に伴う修正

        * WebMvcAutoConfiguration、SpringBootServletInitializerのライブラリパス修正(管理ID#A227)
        * allow-bean-definition-overridingプロパティ追加に伴うyml定義例の追加(管理ID#A303)
        * Auto-configurationクラスの除外対象クラス追加(管理ID#A227, #A304)

    * -
      - :doc:`../ImplementationAtEachLayer/SessionManagement`
      - spring-cloud-dependenciesのバージョン更新に伴う修正

        * \ `CookieHttpSessionStrategy should look at all cookies not just the first <https://github.com/spring-projects/spring-session/issues/275>`_\ の改善に伴うwarrning削除(管理ID#A223)
        * spring-boot-starter-data-redisの仕様変更に伴いspring-session-data-redis + jedisを利用するよう修正(管理ID#A254)

        記載内容の修正

        * Apache TilesとTomcatの組み合わせでレスポンスにCookieが設定されない問題の説明削除(管理ID#A165)

    * -
      - :doc:`../AWSCollaboration/CreateAWSApplicationProject`
      - Macchinetta Framework for Javaのバージョン更新に伴う修正

        * ContextStackAutoConfigurationの仕様変更に伴い説明を修正(管理ID#A308)

    * -
      - :doc:`../ImplementationAtEachLayer/HealthCheck`
      - spring-cloud-dependenciesのバージョン更新に伴う修正

        * ActuatorのProduction-ready化に伴う内容修正(管理ID#A257)

    * -
      - :doc:`../ArchitectureInDetail/DataAccessDetail/DataAccessMyBatis3`
      - spring-cloud-dependenciesのバージョン更新に伴う修正

        * CrudRepositoryクラスのメソッド変更に伴う修正(管理ID#A252)

    * -
      - :doc:`../ArchitectureInDetail/DataAccessDetail/CacheAbstraction`
      - spring-cloud-dependenciesのバージョン更新に伴う修正

        * CrudRepositoryクラスのメソッド変更に伴う修正(管理ID#A252)
        * spring-boot-starter-data-redisの仕様変更に伴いspring-data-redis + jedisを利用するよう修正(管理ID#A254)

        spring-data-redisのバージョン更新に伴う修正

        * Bean定義方法の変更に伴う修正(管理ID#A254)
        * cacheNames属性で指定した値がキープレフィックスとして付与される旨を追記(管理ID#A254)

    * -
      - :doc:`../AWSCollaboration/AutoScale`
      - spring-cloud-dependenciesのバージョン更新に伴う修正

        * CloudWatchMetricPropertiesの仕様変更に伴いYAMLからプロパティを取得するよう修正(管理ID#A251)

    * -
      - :doc:`../AWSCollaboration/FileManagement/UploadFileManagement`
      - spring-cloud-dependenciesのバージョン更新に伴う修正

        * ResourcePatternResolverの実装方法変更に伴う修正(管理ID#A258)

    * -
      - :doc:`../AWSCollaboration/StaticContents`
      - Macchinetta Framework for Javaのバージョン更新に伴う修正

        * \ `CookieClearingLogoutHandler doesn't work correctly <https://jira.spring.io/browse/SEC-2091>`_\ の改善に伴うnote削除(管理ID#A226)

    * -
      - :doc:`../AWSCollaboration/Queuing/AsynchronousProcessing`
      - spring-cloud-dependenciesのバージョン更新に伴う修正

        * Amazon SQSがJMS1.1までサポートするため、spring-jmsバージョンを見直し(管理ID#A253)

    * -
      - :doc:`../AWSCollaboration/DatabaseSharding`
      - spring-cloud-dependenciesのバージョン更新に伴う修正

        * CrudRepositoryクラスのメソッド変更に伴う修正(管理ID#A252)

        spring-data-dynamodbのバージョン更新に伴う修正

        * スニペットに記載されているバージョンの修正(管理ID#A256)

    * -
      - :doc:`../AWSCollaboration/DatabaseReadReplica`
      - リードレプリカの機能追加に伴う修正

        * マルチAZ構成でのフェイルオーバーによる可用性確保について追記(管理ID#A219)

    * - 2018-2-28
      - \-
      - CVE-2018-1199への対応のため、利用するOSSをのバージョンを更新

        * Macchinetta Framework for Javaのバージョンを5.4.1.RELEASEに更新
        * Spring Frameworkのバージョンを4.3.14.RELEASEに更新
        * Spring Securityのバージョンを4.2.4.RELEASEに更新

    * - 2017-12-18
      - 日本語版
      - 初版

.. raw:: latex

   \newpage
