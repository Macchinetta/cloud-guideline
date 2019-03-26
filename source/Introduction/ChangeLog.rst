更新履歴
================================================================================

.. tabularcolumns:: |p{0.15\linewidth}|p{0.25\linewidth}|p{0.60\linewidth}|
.. list-table::
    :header-rows: 1
    :widths: 15 25 60

    * - 更新日付
      - 更新箇所
      - 更新内容

    * - 2019-3-26
      - \-
      - 1.1.1 RELEASE版公開

    * -
      - 全般
      - ガイドラインの誤記(タイプミスや単純な記述ミスなど)の修正

        記載内容の改善

        Macchinetta Server Framework for Java (1.x)への対応リンクを1.6.1 RELEASE版に更新

        利用するOSSのバージョン更新に伴うリンク修正

    * -
      - :doc:`../Introduction/Introduction`
      - 動作検証環境を更新

        * CentOS 7.4
        * Apache Tomcat 9.0
        * RDS(PostgreSQL 10)

    * -
      - :doc:`../Overview/FrameworkStack`
      - TERASOLUNA Server Framework for Javaのバージョンを5.5.1.RELEASEに更新

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
      - TERASOLUNA Server Framework for Javaのバージョン更新に伴う修正

        * WebMvcAutoConfiguration、SpringBootServletInitializerのライブラリパス修正(管理ID#227)
        * allow-bean-definition-overridingプロパティ追加に伴うyml定義例の追加(管理ID#303)
        * Auto-configurationクラスの除外対象クラス追加(管理ID#227, #304)

    * -
      - :doc:`../ImplementationAtEachLayer/SessionManagement`
      - spring-cloud-dependenciesのバージョン更新に伴う修正

        * \ `CookieHttpSessionStrategy should look at all cookies not just the first <https://github.com/spring-projects/spring-session/issues/275>`_\ の改善に伴うwarrning削除(管理ID#223)
        * spring-boot-starter-data-redisの仕様変更に伴いspring-session-data-redis + jedisを利用するよう修正(管理ID#254)

        記載内容の修正

        * Apache TilesとTomcatの組み合わせでレスポンスにCookieが設定されない問題の説明削除(管理ID#165)

    * -
      - :doc:`../AWSCollaboration/CreateAWSApplicationProject`
      - TERASOLUNA Server Framework for Javaのバージョン更新に伴う修正

        * ContextStackAutoConfigurationの仕様変更に伴い説明を修正(管理ID#308)

    * -
      - :doc:`../ImplementationAtEachLayer/HealthCheck`
      - spring-cloud-dependenciesのバージョン更新に伴う修正

        * ActuatorのProduction-ready化に伴う内容修正(管理ID#257)

    * -
      - :doc:`../ArchitectureInDetail/DataAccessDetail/DataAccessMyBatis3`
      - spring-cloud-dependenciesのバージョン更新に伴う修正

        * CrudRepositoryクラスのメソッド変更に伴う修正(管理ID#252)

    * -
      - :doc:`../ArchitectureInDetail/DataAccessDetail/CacheAbstraction`
      - spring-cloud-dependenciesのバージョン更新に伴う修正

        * CrudRepositoryクラスのメソッド変更に伴う修正(管理ID#252)
        * spring-boot-starter-data-redisの仕様変更に伴いspring-data-redis + jedisを利用するよう修正(管理ID#254)

        spring-data-redisのバージョン更新に伴う修正

        * Bean定義方法の変更に伴う修正(管理ID#254)
        * cacheNames属性で指定した値がキープレフィックスとして付与される旨を追記(管理ID#254)

    * -
      - :doc:`../AWSCollaboration/AutoScale`
      - spring-cloud-dependenciesのバージョン更新に伴う修正

        * CloudWatchMetricPropertiesの仕様変更に伴いYAMLからプロパティを取得するよう修正(管理ID#251)

    * -
      - :doc:`../AWSCollaboration/FileManagement/UploadFileManagement`
      - spring-cloud-dependenciesのバージョン更新に伴う修正

        * ResourcePatternResolverの実装方法変更に伴う修正(管理ID#258)

    * -
      - :doc:`../AWSCollaboration/StaticContents`
      - TERASOLUNA Server Framework for Javaのバージョン更新に伴う修正

        * \ `CookieClearingLogoutHandler doesn't work correctly <https://jira.spring.io/browse/SEC-2091>`_\ の改善に伴うnote削除(管理ID#226)

    * -
      - :doc:`../AWSCollaboration/Queuing/AsynchronousProcessing`
      - spring-cloud-dependenciesのバージョン更新に伴う修正

        * Amazon SQSがJMS1.1までサポートするため、spring-jmsバージョンを見直し(管理ID#253)

    * -
      - :doc:`../AWSCollaboration/DatabaseSharding`
      - spring-cloud-dependenciesのバージョン更新に伴う修正

        * CrudRepositoryクラスのメソッド変更に伴う修正(管理ID#252)

        spring-data-dynamodbのバージョン更新に伴う修正

        * スニペットに記載されているバージョンの修正(管理ID#256)

    * -
      - :doc:`../AWSCollaboration/DatabaseReadReplica`
      - リードレプリカの機能追加に伴う修正

        * マルチAZ構成でのフェイルオーバーによる可用性確保について追記(管理ID#219)

    * - 2018-2-28
      - \-
      - CVE-2018-1199への対応のため、利用するOSSをのバージョンを更新

        * TERASOLUNA Server Framework for Javaのバージョンを5.4.1.RELEASEに更新
        * Spring Frameworkのバージョンを4.3.14.RELEASEに更新
        * Spring Securityのバージョンを4.2.4.RELEASEに更新

    * - 2017-12-18
      - 日本語版
      - 初版

.. raw:: latex

   \newpage
