ヘルスチェック
===========================

.. only:: html

 .. contents:: 目次
    :depth: 3
    :local:

Overview
--------

本ガイドラインでは、「アプリケーションでのヘルスチェック」を行うための方式を紹介する。





ロードバランサの負荷分散と縮退運転
""""""""""""""""""""""""""""""""""

「ロードバランサの負荷分散と縮退運転」の詳細については、 |base_framework_name| Development Guidelineの\ `ロードバランサの負荷分散と縮退運転 <http://macchinetta.github.io/server-guideline/1.4.0.RELEASE/ja/ArchitectureInDetail/WebApplicationDetail/HealthCheck.html#healthcheckoverview-loadbalancer>`_\ を参照されたい。

ヘルスチェックの種類
""""""""""""""""""""

「ヘルスチェックの種類」の詳細については、 |base_framework_name| Development Guidelineの\ `ヘルスチェックの種類 <http://macchinetta.github.io/server-guideline/1.4.0.RELEASE/ja/ArchitectureInDetail/WebApplicationDetail/HealthCheck.html#id4>`_\ を参照されたい。

本ガイドラインで示すヘルスチェックの構成
""""""""""""""""""""""""""""""""""""""""

本ガイドラインでは、アプリケーションでのヘルスチェックを行うための方式を紹介する。
本アプリケーションではSpring Bootを採用している。Spring Boot自体がヘルスチェック機能であるSpring Boot Actuatorという仕組みを具備しているため、「アプリケーションでのヘルスチェック」の実現方式を、従来の独自で作成する方式ではなく、Spring Boot Actuatorを使用する方式を推奨する。本章ではSpring Boot Actuatorを使用した「アプリケーションでのヘルスチェック」の実現方法を紹介する。


 .. figure:: ./imagesHealthCheck/HealthCheckConfiguration.png
   :alt: Screen image of HealthCheck Configuration.
   :width: 100%


.. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
.. list-table::
   :header-rows: 1
   :widths: 10 90

   * - 項番
     - 説明
   * - | (1)
     - | LBからのリクエストを受け、各ヘルスチェックを実行する。エンドポイントはSpring Boot Actuatorの仕様により、/healthになる。詳細については、\ `Endpoints <http://docs.spring.io/spring-boot/docs/1.4.3.RELEASE/reference/html/production-ready-endpoints.html#production-ready-endpoints>`_\ を参照されたい。
   * - | (2)
     - | 各ヘルスチェックは、使用ミドルウェアなどの接続・稼動確認を実施する。例では、DataSourceHealthIndicatorからSQLを発行し、データベースが稼動していることを確認している。
       | これは、データベースアクセスを伴うアプリケーションの場合、アプリケーションが稼動していても、データベースに異常がある場合は正常に業務を行うことができないためである。
   * - | (3)
     - | レスポンスをJSON形式で返却する。


| 本ガイドラインのアプリケーションヘルスチェック方式で返却されるステータスコードおよびレスポンスは以下の通りである。LBは返却されたステータスコード、および必要に応じてレスポンスの内容を検査し、アプリケーションの稼動状況を判断する。

.. tabularcolumns:: |p{0.25\linewidth}|p{0.30\linewidth}|p{0.30\linewidth}|
.. list-table::
   :header-rows: 1
   :widths: 25 30 30

   * - ヘルスチェック処理結果
     - ステータスコード
     - レスポンス内容
   * - | 成功
     - | 200(正常)
     - | JSON形式で\ ``"status": "UP"``\
   * - | エラー発生
     - | 503(異常)
     - | JSON形式で\ ``"status": "DOWN"``\

「Spring Boot Actuatorの処理結果ステータス」の詳細については、\ `Writing custom HealthIndicators <http://docs.spring.io/spring-boot/docs/1.4.3.RELEASE/reference/htmlsingle/#_writing_custom_healthindicators>`_\ を参照されたい。



- :file:`ヘルスチェックのResponse内容の例`

 .. code-block:: json

   {
     "status": "UP",
     "redis": {
       "status": "UP",
       "version": "3.2.100"
     },
     "db": {
       "status": "UP",
       "dataSource": {
         "status": "UP",
         "database": "PostgreSQL",
         "hello": 1
       }
     }
   }




.. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
.. list-table::
   :header-rows: 1
   :widths: 10 90

   * - 名前
     - 説明
   * - | status
     - | ヘルスチェックの結果。全体の結果を表す。
   * - | redis
     - | ヘルスチェック対象の個別名称を表す。
   * - | redis:
       |   status
     - | ヘルスチェック対象の個別ステータスを表す。
   * - | redis:
       |   version
     - | 同一階層のこれ以降の項目は、個別の情報を表す。ここでは、バージョン情報のみを表示しているが、インジケータに拠って出力項目は異なる。

How to use
----------

Spring Boot Actuatorの導入
"""""""""""""""""""""""""""
Spring Boot Actuatorは、依存関係にjarを追加するだけで、導入可能となる。


pom.xmlで必要なjarを設定する。

- :file:`pom.xml`

 .. code-block:: xml



    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-actuator</artifactId>
    </dependency>


Spring Boot Actuatorの設定
"""""""""""""""""""""""""""

基本的にAuto Configが必要な設定を行うため、何も設定する必要はないが、アプリケーションの機能とSpring Boot Actuatorの管理機能のパスを明示的に区別するために、\ ``management.context-path``\を設定する。

- :file:`application.yml`

 .. code-block:: yaml

   spring:
     application:
       name: xxx
   management:
     context-path: /management


Spring Boot ActuatorのヘルスチェックのエンドポイントのURLは、デフォルトでは\ ``http://localhost:8080/<コンテキストパス>/health``\ が使用されるが、上記の例では、\ ``http://localhost:8080/xxx/management/health``\ が使用される。


ヘルスチェック対象
""""""""""""""""""

Spring Boot Actuatorがサポートしているヘルスチェック対象は、\ `Auto-configured HealthIndicators <https://docs.spring.io/spring-boot/docs/1.4.3.RELEASE/reference/htmlsingle/#_auto_configured_healthindicators>`_\ を参照されたい。




.. note::

    ヘルスチェックは、実施可能な状況であれば、実施される。実施可能な状況とは、DIコンテナ上にヘルスチェックの対象となるリソースに関連するBeanが存在した場合などが対象となる。
    例えば、dbチェックの場合はSpringのBean定義にDataSourceが存在した場合を表す。
    不要なヘルスチェックが実施される場合は \ ``management.health.インジケータ名称.enabled``\プロパティにfalseを設定する必要がある。




エンドポイントのアクセス保護
""""""""""""""""""""""""""""

Spring Boot Actuatorのエンドポイントは、外部に公開するべきでない情報が取得できるため、ロードバランサで外部からアクセスを遮断する必要がある。

ヘルスチェックの対象となるアプリケーションを外部のTomcatにデプロイした場合は、Spring Boot Actuatorのエンドポイントは同一ポートでしか稼動できないため、ロードバランサのL7ルーティングを使用して、保護する必要がある。


.. note::

    Spring Bootに内包されたTomcatを使用する場合は、アプリケーションとSpring Boot Actuator機能でポートを分けることができるため、ロードバランサで対象のポートを保護する。また、「Spring Boot Actuator自体のアクセス保護機能」については、\ `Security with HealthIndicators <https://docs.spring.io/spring-boot/docs/1.4.3.RELEASE/reference/htmlsingle/#_security_with_healthindicators>`_\ を参照されたい。


How to extend
-------------

カスタムインジケータ
""""""""""""""""""""
Spring Boot Actuatorが用意しているデフォルトのヘルスインジケータのみでヘルスチェックを実現できない場合は、カスタムヘルスチェックインジケータを登録することができる。
カスタムヘルスチェックインジケータは、\ ``HealthIndicator``\インタフェースの実装に、\ ``@Component``\を付与することで登録される。
「Spring Bootを使用したコンポーネントスキャンの定義方法」については、\ `Structuring your code <http://docs.spring.io/spring-boot/docs/1.4.3.RELEASE/reference/html/using-boot-structuring-your-code.html>`_\ を参照されたい。




- :file:`DynamodbHealthIndicator.java`

 .. code-block:: java

   @Component
   @ConditionalOnProperty(value = "management.health.dynamodb.enabled", matchIfMissing = true) // (1)
   public class DynamodbHealthIndicator extends AbstractHealthIndicator {

       private AmazonDynamoDB amazonDynamoDB;

       @Autowired
       public DynamodbHealthIndicator(AmazonDynamoDB amazonDynamoDB) {
           this.amazonDynamoDB = amazonDynamoDB;
       }

       @Override
       protected void doHealthCheck(Builder builder) throws Exception {  // (2)

           if (this.amazonDynamoDB == null) {
               builder.up().withDetail("amazonDynamoDB", "unknown");
               return;
           }
           try {
               ListTablesResult listTablesResult = amazonDynamoDB.listTables();
               builder.up().withDetail("amazonDynamoDB", listTablesResult
                       .getTableNames()); // (3)
           } catch (Exception e) {
               builder.down(e); // (4)
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
     - | 他のヘルスチェックインジケータと同様に、プロパティで実行可否を制御する。
   * - | (2)
     - | \ ``AbstractHealthIndicator``\の抽象メソッドを実装する。
   * - | (3)
     - | 疎通確認が成功した場合に、\ ``Builder``\に稼働状況の成功と詳細情報を追加する。
   * - | (4)
     - | 疎通確認が失敗した場合に、\ ``Builder``\に稼働状況の失敗と原因例外を追加する。



Appendix
--------------------------------------------------------------------------------


Spring Boot Actuatorが提供するエンドポイント
"""""""""""""""""""""""""""""""""""""""""""""

「Spring Boot Actuatorが提供するエンドポイント」の詳細については、\ `Endpoints <http://docs.spring.io/spring-boot/docs/1.4.3.RELEASE/reference/html/production-ready-endpoints.html#production-ready-endpoints>`_\ を参照されたい。


.. raw:: latex

   \newpage
