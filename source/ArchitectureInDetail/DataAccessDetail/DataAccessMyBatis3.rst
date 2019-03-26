データベースシャーディング
==================================================

.. only:: html

 .. contents:: 目次
    :depth: 3
    :local:

.. |default-shard-name| replace:: 非シャード

Overview
------------------

:doc:`../../ImplementationAtEachLayer/PersistenceLayerScalability` で説明したシャーディング方式を、Springの\ ``RoutingDataSource``\ やAOPの仕組みを用いて実現する方法を説明する。

本ガイドラインでは、以下に示すイメージの赤枠破線部分(Spring提供機能以外)について説明する。枠線外のShardKey RepositoryとStorage Device(記憶装置)については、:doc:`../../ImplementationAtEachLayer/PersistenceLayerScalability` の \ :ref:`shardkey-management-policy`\ に基づき、Key-Value Store(KVS)を用いるのが望ましいため、クラウドプラットフォームで提供されるKVSを利用することを推奨する。クラウドプラットフォームにAWSを選択する場合のKVSについては、:doc:`../../AWSCollaboration/DatabaseSharding` を参照されたい。

なお、イメージの赤枠実線部分(Sharding AOP、Routing Data Source、ShardKey Repository)は横断的な機能のため、アプリケーション開発者全員が作成する必要はない。

  .. figure:: imagesDataAccessMyBatis3/data-access-mybatis3.png
    :width: 90%
    :align: center

  .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
  .. list-table::
    :header-rows: 1
    :widths: 10 90

    * - 項番
      - 説明
    * - | (1)
      - Controllerが\ :ref:`shard-with-account-annotaition-label`\と\ ``@Transactional``\アノテーション付のServiceメソッドを呼び出す。
    * - | (2)
      - Sharding AOPがShardKey Repositoryを呼び出しシャードを特定する。

        \ :ref:`resolve-use-shard-key-labal`\をするためのShardKey Repositoryの実装は、使用するStorage Deviceによって変わる。
    * - | (3)
      - Sharding AOPは、(2)で特定したシャードをRouting Data Sourceへ伝播する。
    * - | (4)
      - Transaction AOPは、Transaction Managerを呼び出す。
    * - | (5)
      - Transaction Managerは、Routing Data Sourceから(3)で伝播されたシャードの\ ``Connection``\を取得する。
    * - | (6)
      - Transaction Managerは、(5)で取得した\ ``Connection``\でトランザクションを開始しConnection Holderへ\ ``Connection``\を格納する。
    * - | (7)
      - Serviceは、Shard RepositoryのDBアクセスメソッドを呼び出す。
    * - | (8)
      - Shard Repositoryは、Mybatis Springを経由してDBへクエリを発行する。
    * - | (9)
      - Mybatis Springは、(6)で格納した\ ``Connection``\をConnection Holderから取得しDBへアクセスする。

|

実現方針
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

- RDB製品依存のシャーディングの仕組み(例：\ ``pg_shard``\等)は使用しない。
- 性能劣化やアプリケーションの複雑性の回避のため、分散トランザクションは使用しない。
- \ ``Spring``\の\ ``RoutingDataSource``\の仕組みを拡張し、シャード毎にデータソースを切り替える。
- テスト容易性のため、シャード切り替えの制御処理をプログラマティックに記述させない(AOPで宣言的に記述)

|

How to use
------------------

シャーディングを行うにあたり、各シャードに対しデータソースを定義する必要がある。
本ガイドラインで紹介する方式では、Springの仕組みを用いつつ以下の実装を独自に行う必要がある。

- \ :ref:`create-all-shard-datasource-label`\

  設定ファイルに定義された複数の接続情報などを元に、シャードとなるデータソースを動的に生成するための実装
- \ :ref:`shard-routing-data-source-label`\

  シャードキーに基づいて使用するシャード（データソース）を選択するデータソース（Springの\ ``RoutingDataSource``\ を拡張）
- \ :ref:`get-shard-key-label`\

  AOPによりメソッド呼び出し情報の中からシャードキーを抽出するための実装
- \ :ref:`resolve-use-shard-key-labal`\

  シャードキーから、割り当てられたシャードを決定するための実装
- \ :ref:`decide-shard-node-label`\

  新たな要素が追加されたときに、シャードキーからシャードを決定するための実装
- \ :ref:`sharding-in-application-label`\

  シャードの解決と割り当てをアプリケーションで実装

|

.. _create-all-shard-datasource-label:

各シャードのデータソースの生成
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

シャーディングをする場合は、|default-shard-name| とシャード毎にデータソース情報の定義が必要になる。
さらに、シャードの増減や冗長なデータソース情報の定義を避けるため、以下のことを考慮する必要がある。

- シャード数を増減させる際に、最小限の設定の変更だけで実現できる
- 冗長な設定を削減しつつ、シャード個別のチューニングも可能にする

上記を考慮した、各シャードのデータソースを生成する手順を以下に示す。

- \ :ref:`datasource-definition-label`\する。
- \ :ref:`datasource-mapping-label`\する。
- \ :ref:`datasource-mapping-object-label`\する。

|

.. _datasource-definition-label:

設定ファイルに各シャードのデータソース情報を定義
"""""""""""""""""""""""""""""""""""""""""""""""""""""

データソース情報の定義には、1つの共通情報と複数の個別情報があり、それぞれを定義する。

  以下に、\ ``xxx-env/src/main/resources/application-local.yml``\での設定を示す。

  .. code-block:: yaml

    database:
      # (1)
      common:
        data-source:
          # (5)
          driverClassName: org.postgresql.Driver
          maxActive: 96
          maxIdle: 16
          minIdle: 0
          maxWait: 90000
          password: postgres
          username: postgres
      # (2)
      default:
        schema:
          name: default
      # (3)
      data-sources:
        # (4)
        - schema: default
          # (5)
          url: jdbc:postgresql://localhost:5432/xxx
        - schema: xxx1
          url: jdbc:postgresql://localhost:5432/xxx1
        - schema: xxx2
          url: jdbc:postgresql://localhost:5432/xxx2
          # (6)
          maxActive: 30

  .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
  .. list-table::
    :header-rows: 1
    :widths: 10 90

    * - 項番
      - 説明
    * - | (1)
      - データソースの共通情報を設定する(任意設定)。ここで設定した値は、シャードの個別情報の設定値で上書きされる。

        全シャード共通のデータソース情報の基本となる設定値。
        データソースのプロパティキーを設定する。この例では、データソースに Tomcat 9.0 JDBC Connection Pool を使用した場合の設定例を示している。
        詳細は、`公式サイト <https://tomcat.apache.org/tomcat-9.0-doc/jdbc-pool.html#Common_Attributes>`_ を参照されたい。
    * - | (2)
      - |default-shard-name| (デフォルトスキーマ)を指定するキーを設定する。(必須)
    * - | (3)
      - 全てのシャードのデータソース個別情報を設定する。

        省略されたプロパティについては、(1)の設定値が反映される。
    * - | (4)
      - schema(データソースキー)を設定する。

        シャードのキーとなる値。 |default-shard-name| は１つ、シャードは１つ以上の設定が必須である。 |default-shard-name| の値は(2)で設定した値と同一になる。
    * - | (5)
      - データソースの設定値。

        データソースのプロパティキーを設定する。この例では、データソースに Tomcat 9.0 JDBC Connection Pool を使用した場合の設定例を示している。
        詳細は、`公式サイト <https://tomcat.apache.org/tomcat-9.0-doc/jdbc-pool.html#Common_Attributes>`_ を参照されたい。
    * - | (6)
      - maxActiveを30に個別設定する。

        共通情報を個別情報で上書きし、設定したシャード(schema=xxx2)だけmaxActiveが30となる。

|

.. _datasource-mapping-label:

定義されたデータソース情報をオブジェクトにマッピング
"""""""""""""""""""""""""""""""""""""""""""""""""""""

データソース情報の定義には、1つの共通情報と複数の個別情報の２種類が定義されるため、それぞれをデータベースのプロパティクラスにマッピングするため、これらのプロパティクラスを実装する。また、それぞれのクラスのBean定義をする必要もある。

- 共通情報プロパティクラスのBean定義

  以下に、共通情報プロパティクラス\ ``CommonDatabaseProperties``\のBean定義例を示す。

  .. code-block:: xml

    <bean id="commonDatabaseProperties"
      class="com.example.xxx.domain.common.shard.datasource.model.CommonDatabaseProperties" />

|

- 個別情報プロパティクラスのBean定義

  以下に、個別情報プロパティクラス\ ``DatabaseProperties``\のBean定義例を示す。

  .. code-block:: xml

    <bean id="databaseProperties"
      class="com.example.xxx.domain.common.shard.datasource.model.DatabaseProperties" />

|

- 共通情報プロパティクラスの実装

  以下に、共通情報プロパティクラス\ ``CommonDatabaseProperties``\の実装例を示す。

  .. code-block:: java

    // omitted...
    // (1)
    @ConfigurationProperties(prefix = "database.common")
    public class CommonDatabaseProperties {
        // (2)
        private Map<String, String> dataSource = new HashMap<>();

        // getter & setter
    }

  .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
  .. list-table::
    :header-rows: 1
    :widths: 10 90

    * - 項番
      - 説明
    * - | (1)
      - \ ``ConfigurationProperties``\アノテーションをクラスへ付与する。

        アノテーションの\ ``prefix``\属性に、\ :ref:`datasource-definition-label`\のプレフィックス\ ``database.common``\を指定する。
    * - | (2)
      - データソース情報をマッピングする\ ``Map``\クラスを設定する。

        データソース情報をマッピングする項目は、\ :ref:`datasource-definition-label`\のプロパティキー\ ``database.common.data-source``\の後のキー名と同じになる。定義されるプロパティキーの増減に対応するため\ ``Map``\クラスを使用している。

|

- 個別情報プロパティクラスの実装

  以下に、個別情報プロパティクラス\ ``DatabaseProperties``\の実装例を示す。

  .. code-block:: java

    // omitted...
    // (1)
    @ConfigurationProperties(prefix = "database")
    public class DatabaseProperties {
        // (2)
        private List<Map<String, String>> dataSources = new ArrayList<>();

        // getter & setter
    }

  .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
  .. list-table::
    :header-rows: 1
    :widths: 10 90

    * - 項番
      - 説明
    * - | (1)
      - \ ``ConfigurationProperties``\アノテーションをクラスへ付与する。

        アノテーションの\ ``prefix``\属性に、\ :ref:`datasource-definition-label`\のプレフィックス\ ``database``\を指定する。
    * - | (2)
      - データソース情報をマッピングするリストを設定する。

        データソース情報をマッピングする\ ``Map``\クラスのリスト。
        データソース情報をマッピングする項目は、\ :ref:`datasource-definition-label`\のプロパティキー\ ``database.data-sources``\の後のキー名と同じになる。定義されるプロパティキーの増減に対応するため\ ``Map``\クラスのリストを使用している。

|

.. _datasource-mapping-object-label:

マッピングされたデータベースのプロパティクラスを元にデータソースを生成
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

\ :ref:`datasource-mapping-label`\したプロパティクラスを元にデータソースを生成するため、データソースビルダクラスとデータソースファクトリクラスを実装する。また、それぞれのクラスのBean定義をする必要もある。

  .. note::
    データソースファクトリクラスは、使用するデータソースに合わせて実装できるよう、\ ``DataSourceFactory``\のインタフェースを用意し汎化しておく。

- データソースファクトリクラスのBean定義

  以下に、データソースファクトリクラス\ ``TomcatDataSourceFactory``\のBean定義例を示す。

  .. code-block:: xml

    <bean id="dataSourceFactory"
      class="com.example.xxx.domain.common.shard.datasource.pool.TomcatDataSourceFactory" />

|

- データソースビルダクラスのBean定義

  以下に、データソースビルダクラス\ ``RoutingDataSourceBuilder``\のBean定義例を示す。

  .. code-block:: xml

    <bean id="routingDataSourceBuilder"
      class="com.example.xxx.domain.common.shard.datasource.RoutingDataSourceBuilder">
      <!-- (1) -->
      <constructor-arg index="0" ref="databaseProperties" />
      <constructor-arg index="1" ref="commonDatabaseProperties" />
      <constructor-arg index="2" ref="dataSourceFactory" />
    </bean>

  .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
  .. list-table::
    :header-rows: 1
    :widths: 10 90

    * - 項番
      - 説明
    * - | (1)
      - コンストラクタの引数でデータソースの個別情報プロパティクラス、共通情報プロパティクラスとデータソースファクトリクラスを設定する。

|

- データソースファクトリクラスの実装

  データソースファクトリクラスは\ ``DataSourceFactory``\のインタフェースを使用し、使用するデータソースに合わせて実装する。

  以下に、\ ``org.apache.tomcat.jdbc.pool.DataSource``\を使用したデータソースファクトリクラスの実装例を示す。

  .. code-block:: java

    // (1)
    public class TomcatDataSourceFactory implements DataSourceFactory {
        // (2)
        private org.apache.tomcat.jdbc.pool.DataSourceFactory factory = new org.apache.tomcat.jdbc.pool.DataSourceFactory();

        @Override
        // (3)
        public DataSource create(Map<String, String> dataSourceProperties,
            Map<String, String> commonDataSourceProperties) {
            DataSource ret = null;
            Properties properties = new Properties();
            if (!commonDataSourceProperties.isEmpty()) {
                // (4)
                properties.putAll(commonDataSourceProperties);
            }
            // (5)
            properties.putAll(dataSourceProperties);
            try {
                // (6)
                ret = factory.createDataSource(properties);
            } catch (Exception e) {
                throw new SystemException(LogMessages.E_AR_A0_L9008.getCode(), LogMessages.E_AR_A0_L9008
                        .getMessage(), e);
            }
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
      - データソースファクトリクラスは、\ ``DataSourceFactory``\インタフェースの実装クラスとして作成する。
    * - | (2)
      - データソースを作成する\ ``org.apache.tomcat.jdbc.pool.DataSourceFactory``\のインスタンスを定義する。
    * - | (3)
      - データソース作成メソッドを実装する。
    * - | (4)
      - データソースの共通情報が定義されていたら共通情報を設定する。
    * - | (5)
      - データソースの個別情報で共通情報を上書きマージする。
    * - | (6)
      - データソースを作成する。

|

- データソースビルダクラスの実装

  以下に、データソースビルダクラス\ ``RoutingDataSourceBuilder``\の実装例を示す。

  .. code-block:: java

    // omitted...
    // (1)
    public class RoutingDataSourceBuilder implements InitializingBean {
      // (2)
      @Value("${database.default.schema.name:default}")
      private String databaseDefaultSchemaName;
      // (3)
      private DatabaseProperties databaseProperties;
      // (4)
      private CommonDatabaseProperties commonDatabaseProperties;
      // (5)
      private DataSourceFactory dataSourceFactory;
      // (6)
      @Inject
      ApplicationContext applicationContext;
      // (7)
      @Inject
      DefaultListableBeanFactory factory;
      // (8)
      public RoutingDataSourceBuilder(DatabaseProperties databaseProperties,
              CommonDatabaseProperties commonDatabaseProperties,
              DataSourceFactory dataSourceFactory) {
          // omitted...
          this.databaseProperties = databaseProperties;
          this.commonDatabaseProperties = commonDatabaseProperties;
          this.dataSourceFactory = dataSourceFactory;
      }
      // (9)
      @Override
      public void afterPropertiesSet() throws Exception {
          List<Map<String, String>> dataSources = databaseProperties
                  .getDataSources();
          Map<Object, Object> targetDataSources = new HashMap<>();
          boolean defaultTargetDataSourceFlg = false;
          for (Map<String, String> dataSourceProperties : dataSources) {
              String sourceKey = dataSourceProperties
                      .get(ShardKeyResolver.SCHEMA_KEY_NAME);
              try {
                  javax.sql.DataSource source = dataSourceFactory.create(
                          dataSourceProperties, commonDatabaseProperties
                                  .getDataSource());
                  factory.registerSingleton(sourceKey, source);
              } catch (IllegalStateException e) {
                  throw new SystemException(LogMessages.E_AR_A0_L9007.getCode(), LogMessages.E_AR_A0_L9007
                          .getMessage(sourceKey), e);
              } catch (Exception e) {
                  throw new SystemException(LogMessages.E_AR_A0_L9008.getCode(), LogMessages.E_AR_A0_L9008
                          .getMessage(), e);
              }

              if (databaseDefaultSchemaName.equals(sourceKey)) {
                  // (10)
                  this.defaultTargetDataSource = applicationContext
                          .getBean(sourceKey);
                  defaultTargetDataSourceFlg = true;
              } else {
                  // (11)
                  targetDataSources.put(sourceKey, applicationContext
                          .getBean(sourceKey));
              }
          }
          if (!defaultTargetDataSourceFlg) {
              throw new SystemException(LogMessages.E_AR_A0_L9006.getCode(), LogMessages.E_AR_A0_L9006
                      .getMessage());
          }
          if (targetDataSources.isEmpty()) {
              throw new SystemException(LogMessages.E_AR_A0_L9005.getCode(), LogMessages.E_AR_A0_L9005
                      .getMessage());
          }
          this.targetDataSources = targetDataSources;
      }
      // (12)
      public Map<Object, Object> getTargetDataSources() {
          return targetDataSources;
      }
      // (13)
      public Object getDefaultTargetDataSource() {
          return defaultTargetDataSource;
      }
    }

  .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
  .. list-table::
    :header-rows: 1
    :widths: 10 90

    * - 項番
      - 説明
    * - | (1)
      - データソースビルダクラスは、\ ``InitializingBean``\の実装クラスとして作成する。
    * - | (2)
      - \ :ref:`datasource-definition-label`\で指定した、 |default-shard-name| (デフォルトスキーマ)キーをインジェクトする。
    * - | (3)
      - コンストラクタで設定される、データソースの個別情報プロパティクラスを保持するフィールドを定義する。
    * - | (4)
      - コンストラクタで設定される、データソースの共通情報プロパティクラスを保持するフィールドを定義する。
    * - | (5)
      - コンストラクタで設定される、データソースファクトリクラスを保持するフィールドを定義する。
    * - | (6)
      - \ ``ApplicationContext``\のインジェクトする。

        一度登録したデータソースを取得するために使用する。
    * - | (7)
      - \ ``DefaultListableBeanFactory``\のインジェクトする。

        データソースを実行時に動的にインスタンス化し、SpringのDIコンテナに登録してBeanとして扱えるようにするために使用する。
    * - | (8)
      - コンストラクタの引数で(2)、(3)と(4)を取得する。
    * - | (9)
      - \ ``InitializingBean``\のメソッド\ ``afterPropertiesSet()``\をオーバーライドし、データソースを作成する。
    * - | (10)
      - |default-shard-name| のデータソースを保持する。
    * - | (11)
      - シャードのデータソースを保持する。
    * - | (12)
      - シャードのデータソースを取得するメソッドを定義する。
    * - | (13)
      - |default-shard-name| のデータソースを取得するメソッドを定義する。

|

.. _shard-routing-data-source-label:

シャーディング対応データソース（ルーティングデータソース）
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

\ :ref:`create-all-shard-datasource-label`\で生成されたデータソースを、シャーディング対応データソースに格納するため、\ :ref:`routing-data-source-label`\と\ :ref:`data-source-key-holder-label`\を実装する。データソースキーホルダクラスは、後述の\ :ref:`decide-shard-node-label`\で決定したデータソースキーを保持・伝播する入れ物のことである。また、それぞれのクラスのBean定義をする必要もある。

.. _data-source-key-holder-label:

データソースキーホルダクラス
"""""""""""""""""""""""""""""""""""""""""""""""""""""

  以下に、データソースキーホルダクラス\ ``DataSourceLookupKeyHolder``\のBean定義例を示す。

  .. code-block:: xml

    <bean id="dataSourceLookupKeyHolder"
      class="com.example.xxx.domain.common.shard.datasource.RoutingDataSourceLookupKeyHolder" />

|

  以下に、データソースキーホルダクラス\ ``RoutingDataSourceLookupKeyHolder``\の実装例を示す。

  .. code-block:: java

    // omitted...
    public class RoutingDataSourceLookupKeyHolder {
        // (1)
        private static final ThreadLocal<String> contextHolder = new ThreadLocal<>();
        // (2)
        public void set(String dataSourceKey) {
            contextHolder.set(dataSourceKey);
        }
        // (3)
        public String get() {
            return (String) contextHolder.get();
        }
        // (4)
        public void clear() {
            contextHolder.remove();
        }
    }

  .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
  .. list-table::
    :header-rows: 1
    :widths: 10 90

    * - 項番
      - 説明
    * - | (1)
      - スレッド毎にデータソースキーを保持する変数を定義する。
    * - | (2)
      - データソースキーを設定するメソッドを定義する。
    * - | (3)
      - データソースキーを取得するメソッドを定義する。
    * - | (4)
      - 保持したデータソースキーを削除するメソッドを定義する。

|

.. _routing-data-source-label:

ルーティングデータソースクラス
"""""""""""""""""""""""""""""""""""""""""""""""""""""

  \ ``RoutingDataSource``\は、Springが提供する、複数のデータソースを定義し動的に切り替えを行う仕組みである。簡単な使用方法は `こちら <https://macchinetta.github.io/server-guideline/1.6.1.RELEASE/ja/ArchitectureInDetail/DataAccessDetail/DataAccessCommon.html#data-access-common-todo-multiple-datasource-howtoextends>`_ を参照すること。

  以下に、ルーティングデータソースクラス\ ``RoutingDataSource``\のBean定義例を示す。

  .. code-block:: xml

    <bean id="routingDataSource"
      class="com.example.xxx.domain.common.shard.datasource.RoutingDataSource">
      <!-- (1) -->
      <constructor-arg index="0" ref="routingDataSourceBuilder" />
      <constructor-arg index="1" ref="dataSourceLookupKeyHolder" />
    </bean>

  .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
  .. list-table::
    :header-rows: 1
    :widths: 10 90

    * - 項番
      - 説明
    * - | (1)
      - コンストラクタの引数でデータソースビルダクラスと\ :ref:`data-source-key-holder-label`\を設定する。

|

  以下に、ルーティングデータソースクラス\ ``RoutingDataSource``\の実装例を示す。

  .. code-block:: java

    // omitted...
    // (1)
    public class RoutingDataSource extends AbstractRoutingDataSource {
        // omitted...
        // (2)
        @Value("${database.default.schema.name:default}")
        private String databaseDefaultSchemaName;
        // (3)
        private RoutingDataSourceLookupKeyHolder dataSourceLookupKeyHolder;
        // (4)
        public RoutingDataSource(
                RoutingDataSourceBuilder routingDataSourceBuilder,
                RoutingDataSourceLookupKeyHolder dataSourceLookupKeyHolder) {
            super.setDefaultTargetDataSource(routingDataSourceBuilder.getDefaultTargetDataSource());
            super.setTargetDataSources(routingDataSourceBuilder.getTargetDataSources());
            this.dataSourceLookupKeyHolder = dataSourceLookupKeyHolder;
        }
        // (5)
        @Override
        protected Object determineCurrentLookupKey() {
            // (6)
            return dataSourceLookupKeyHolder.get();
        }
    }

  .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
  .. list-table::
    :header-rows: 1
    :widths: 10 90

    * - 項番
      - 説明
    * - | (1)
      - 実装クラスは、\ ``AbstractRoutingDataSource``\のサブクラスとして実装する。
    * - | (2)
      - \ :ref:`datasource-definition-label`\で指定した、デフォルトキーをインジェクトする。
    * - | (3)
      - コンストラクタで設定される、\ :ref:`data-source-key-holder-label`\を保持するフィールドを定義する。
    * - | (4)
      - コンストラクタでデータソースビルダクラスと\ :ref:`data-source-key-holder-label`\を取得する。

        データソースビルダクラスから |default-shard-name| のデータソースとシャードのデータソースのリストを取得して親クラスのコンストラクタへ渡す。
    * - | (5)
      - キー選択のメソッドをオーバーライドする。
    * - | (6)
      - \ :ref:`data-source-key-holder-label`\からデータソースキーを取得する。

        \ :ref:`data-source-key-holder-label`\から取得した値が\ ``null``\の場合は、 |default-shard-name| のデータソースが選択される。

|

.. _get-shard-key-label:

シャードキーの取得
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

\ :ref:`resolve-use-shard-key-labal`\をするため、後述の\ :ref:`shard-with-account-annotaition-label`\と\ :ref:`shard-account-param-annotaition-label`\の情報を元にメソッド引数からシャードキーの値を取得する\ :ref:`sharding-account-helper-label`\と、\ :ref:`shard-routing-data-source-label`\で説明した\ :ref:`data-source-key-holder-label`\にデータソースキーを設定する\ :ref:`sharding-interceptor-label`\を実装する。また、それぞれのクラスのBean定義をする必要もある。

また、トランザクション境界となるサービスクラスの対象メソッドにシャード対象であることを示すアノテーションを付与する必要がある。
以下で、付与する\ :ref:`shard-with-account-annotaition-label`\と\ :ref:`shard-account-param-annotaition-label`\についても説明する。

.. _shard-with-account-annotaition-label:

\ ``@ShardWithAccount``\アノテーション
"""""""""""""""""""""""""""""""""""""""""""""""""""""

\ ``@ShardWithAccount``\アノテーションは、トランザクションを開始するサービスメソッドに付与し属性\ ``value``\にシャードキーを保持するオブジェクトのパスを設定する。

  以下に、\ ``@ShardWithAccount``\アノテーションの実装例を示す。

  .. code-block:: java

    // (1)
    @Target({ ElementType.METHOD })
    @Retention(RetentionPolicy.RUNTIME)
    @Documented
    public @interface ShardWithAccount {
        // (2)
        String value() default "";
    }

  .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
  .. list-table::
    :header-rows: 1
    :widths: 10 90

    * - 項番
      - 説明
    * - | (1)
      - 付与する対象をメソッドに設定する。
    * - | (2)
      - 属性\ ``value``\。

        シャードキーを保持するオブジェクトのパスを設定する。

|


  以下に、\ :ref:`shard-with-account-annotaition-label`\の使用例を示す。

  .. code-block:: java

    // omitted...
    public class TicketReserveServiceImpl implements TicketReserveService {
        // omitted...
        // (1)
        @Transactional
        // (2)
        @ShardWithAccount("reservation.repMember.customerNo")
        public String registerMemberReservation(Reservation reservation) {
            // omitted...
        }
        @Transactional
        // (3)
        public TicketReserveDto registerReservation(String reserveNo, Reservation reservation) {
            // omitted...
        }
        // omitted...
    }

  .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
  .. list-table::
    :header-rows: 1
    :widths: 10 90

    * - 項番
      - 説明
    * - | (1)
      - メソッドにトランザクション境界を示す\ ``@Transactional``\アノテーションを付与する。
    * - | (2)
      - メソッドにシャード対象であることを示す\ :ref:`shard-with-account-annotaition-label`\を付与し、属性\ ``value``\にシャードキーを保持するオブジェクトのパス\ ``reservation.repMember.customerNo``\を設定する。

        シャードキーを保持するオブジェクトは、引数\ ``reservation``\のプロパティである\ ``repMember``\が保持する\ ``java.lang.String``\型のプロパティ\ ``customerNo``\となる。
    * - | (3)
      - メソッドにシャード対象であることを示す\ :ref:`shard-with-account-annotaition-label`\が付与されていないため、|default-shard-name| にアクセスする。

|

.. _shard-account-param-annotaition-label:

\ ``@ShardAccountParam``\アノテーション
"""""""""""""""""""""""""""""""""""""""""""""""""""""

\ ``@ShardAccountParam``\アノテーションは、\ :ref:`shard-with-account-annotaition-label`\が付与されたメソッドの引数に付与するマーカーアノテーションである。メソッド引数が複数ある場合に、シャードキーを保持するオブジェクトを特定するために使用する。

  以下に、\ ``@ShardAccountParam``\アノテーションの実装例を示す。

  .. code-block:: java

    // (1)
    @Target({ ElementType.PARAMETER })
    @Retention(RetentionPolicy.RUNTIME)
    @Documented
    public @interface ShardAccountParam {

    }

  .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
  .. list-table::
    :header-rows: 1
    :widths: 10 90

    * - 項番
      - 説明
    * - | (1)
      - 付与する対象を引数に設定する。

|

  以下に、\ :ref:`shard-account-param-annotaition-label`\の使用例を示す。

  .. code-block:: java

    // omitted...
    public class TicketReserveServiceImpl implements TicketReserveService {
        // omitted...
        // (1)
        @Transactional
        // (2)
        @ShardWithAccount("reservation.repMember.customerNo")
        // (3)
        public String registerMemberReservation(String xxxxxxx, @ShardAccountParam Reservation reservation) {
            // omitted...
        }
        // omitted...
    }

  .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
  .. list-table::
    :header-rows: 1
    :widths: 10 90

    * - 項番
      - 説明
    * - | (1)
      - メソッドにトランザクション境界を示す\ ``@Transactional``\アノテーションを付与する。
    * - | (2)
      - メソッドにシャード対象であることを示す\ :ref:`shard-with-account-annotaition-label`\を付与する。
    * - | (3)
      - 引数\ ``Reservation``\がシャードキーを保持するオブジェクトであるため、第2引数\ ``Reservation``\に\ :ref:`shard-account-param-annotaition-label`\アノテーションを付与する。

|

.. _sharding-account-helper-label:

シャードアカウントヘルパークラス
"""""""""""""""""""""""""""""""""""""""""""""""""""""

  以下に、シャードアカウントヘルパークラス \ ``ShardAccountHelper``\のBean定義例を示す。

  .. code-block:: xml

    <bean id="shardAccountHelper"
      class="com.example.xxx.domain.common.shard.helper.ShardAccountHelper" />

|

  以下に、シャードアカウントヘルパークラス\ ``ShardAccountHelper``\の実装例を示す。

  .. code-block:: java

    public class ShardAccountHelper {
        // omitted...
        // (1)
        public String getAccountValue(MethodInvocation invocation) throws Exception {
            String ret = null;
            // (2)
            Object target = invocation.getThis();
            if (target == null) {
                return null;
            }
            // (3)
            Class<?> targetClass = AopUtils.getTargetClass(target);
            // (4)
            Object[] arguments = invocation.getArguments();
            Class<?>[] classes = null;
            if (null != arguments && arguments.length > 0) {
                classes = invocation.getMethod().getParameterTypes();
            } else {
                return null;
            }
            // (5)
            Method method = ReflectionUtils.findMethod(targetClass, invocation
                    .getMethod().getName(), classes);
            // (6)
            ShardWithAccount shardWithAccount = AnnotationUtils.findAnnotation(
                    method, ShardWithAccount.class);
            if (null != shardWithAccount) {
                // (7)
                String value = shardWithAccount.value();
                if ("".equals(value)) {
                    return null;
                }
                String[] values = value.split("[.]");
                Object obj = null;
                int argumentsLength = 0;
                if (arguments.length == 1) {
                    obj = arguments[0];
                } else {
                    ShardAccountParam shardAccountParam = null;
                    Parameter[] parameters = method.getParameters();
                    for (Parameter parameter : parameters) {
                        // // (8)
                        shardAccountParam = AnnotationUtils.findAnnotation(
                                parameter, ShardAccountParam.class);
                        if (null != shardAccountParam) {
                            // (9)
                            obj = arguments[argumentsLength];
                            break;
                        }
                        argumentsLength++;
                    }
                    if (null == shardAccountParam && values.length > 1) {
                        // omitted...
                    }
                }
                if (null == obj) {
                    // omitted...
                }
                // (10)
                if (values.length == 1) {
                    ret = obj.toString();
                } else {
                    String exp = value.substring(value.indexOf(".") + 1);
                    ExpressionParser expressionParser = new SpelExpressionParser();
                    Expression expression = expressionParser.parseExpression(exp);
                    ret = expression.getValue(obj, String.class);
                }
            }
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
      - シャードキーを取得するメソッドを定義する。
    * - | (2)
      - 実行対象のオブジェクトを取得する。
    * - | (3)
      - 実行対象のクラスを取得する。
    * - | (4)
      - 実行対象メソッドの引数を取得する。
    * - | (5)
      - 実行対象のメソッドを取得する。
    * - | (6)
      - 実行対象のメソッドに付与された\ :ref:`shard-with-account-annotaition-label`\を取得する。
    * - | (7)
      - \ :ref:`shard-with-account-annotaition-label`\の属性valueの値を取得する。
    * - | (8)
      - メソッド引数が複数の場合に\ :ref:`shard-account-param-annotaition-label`\を取得する。
    * - | (9)
      - \ :ref:`shard-account-param-annotaition-label`\が付与されている引数のオブジェクトを取得する。
    * - | (10)
      - 対象オブジェクトからシャードキーの値を取得する。

|

.. _sharding-interceptor-label:

シャーディングインターセプタクラス
"""""""""""""""""""""""""""""""""""""""""""""""""""""

  以下に、シャーディングインターセプタクラス \ ``AccountShardInterceptor``\のBean定義例を示す。

  .. code-block:: xml

    <bean id="accountShardInterceptor"
      class="com.example.xxx.domain.common.shard.interceptor.AccountShardInterceptor">
      <!-- (1) -->
      <constructor-arg index="0" ref="accountShardKeyRepository" />
      <constructor-arg index="1" ref="shardAccountHelper" />
      <constructor-arg index="2" ref="dataSourceLookupKeyHolder" />
    </bean>

    <aop:config>
      <!-- omitted... -->
      <!-- (2) -->
      <aop:advisor order="-1" advice-ref="accountShardInterceptor"
        pointcut="@annotation(com.example.xxx.domain.common.shard.annotation.ShardWithAccount)" />
    </aop:config>

  .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
  .. list-table::
    :header-rows: 1
    :widths: 10 90

    * - 項番
      - 説明
    * - | (1)
      - コンストラクタの引数でシャードキーリポジトリクラス、\ :ref:`sharding-account-helper-label`\と\ :ref:`data-source-key-holder-label`\を設定する。
    * - | (2)
      - AOPの設定をする。

        ここでは、\ :ref:`shard-with-account-annotaition-label`\が付与されたメソッド呼び出し時にシャーディングインターセプタクラスが動作する設定にしている。また、トランザクション開始前にシャードキーを取得するため、\ ``order="-1"``\を設定しトランザクションインターセプタより先に動作する設定とする。

|

  以下に、シャーディングインターセプタクラス\ ``AccountShardInterceptor``\の実装例を示す。

  .. code-block:: java

    // omitted...
    // (1)
    public class AccountShardInterceptor implements MethodInterceptor, InitializingBean {
        // (2)
        private AccountShardKeyRepository accountShardKeyRepository;
        // (3)
        private ShardAccountHelper shardAccountHelper;
        // (4)
        private RoutingDataSourceLookupKeyHolder dataSourceLookupKeyHolder;
        // (5)
        public AccountShardInterceptor(
                AccountShardKeyRepository accountShardKeyRepository,
                ShardAccountHelper shardAccountHelper,
                RoutingDataSourceLookupKeyHolder dataSourceLookupKeyHolder) {
            this.accountShardKeyRepository = accountShardKeyRepository;
            this.shardAccountHelper = shardAccountHelper;
            this.dataSourceLookupKeyHolder = dataSourceLookupKeyHolder;
        }
        // omitted...
        // (6)
        @Override
        public Object invoke(MethodInvocation invocation) throws Throwable {
            // (7)
            String beforeKey = dataSourceLookupKeyHolder.get();

            String dataSourceKey = null;
            // (8)
            String account = shardAccountHelper.getAccountValue(invocation);
            if (null != account) {
                // (9)
                Optional<ShardingAccount> shardingAccount = accountShardKeyRepository
                        .findById(acccount);
                if (shardingAccount != null) {
                    // (10)
                    dataSourceKey = shardingAccount.get().getDataSourceKey();
                }
            }
            // (11)
            dataSourceLookupKeyHolder.set(dataSourceKey);

            Object ret = null;
            try {
                ret = invocation.proceed();
            } finally {
                // (12)
                if (null != beforeKey) {
                    dataSourceLookupKeyHolder.set(beforeKey);
                } else {
                    dataSourceLookupKeyHolder.clear();
                }
            }
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
      - シャーディングインターセプタクラスは、\ ``MethodInterceptor``\と\ ``InitializingBean``\の実装クラスとして作成する。
    * - | (2)
      - コンストラクタで設定される、シャードキーリポジトリクラスを保持するフィールドを定義する。
    * - | (3)
      - コンストラクタで設定される、\ :ref:`sharding-account-helper-label`\を保持するフィールドを定義する。
    * - | (4)
      - コンストラクタで設定される、\ :ref:`data-source-key-holder-label`\を保持するフィールドを定義する。
    * - | (5)
      - コンストラクタ引数でシャードキーリポジトリクラス、\ :ref:`sharding-account-helper-label`\と\ :ref:`data-source-key-holder-label`\を取得する。
    * - | (6)
      - シャードキーを設定する実行メソッドを定義する。
    * - | (7)
      - シャードのネスト処理に対応するため、一つ前のシャードキーを保持する。
    * - | (8)
      - \ :ref:`sharding-account-helper-label`\からシャードキーを取得する。
    * - | (9)
      - シャードキーリポジトリクラスがKVSに問い合わせ結果を取得する。
    * - | (10)
      - (9)の結果からデータソースキーを取得する。
    * - | (11)
      - \ :ref:`data-source-key-holder-label`\に(7)で取得したデータソースキーを設定する。
    * - | (12)
      - \ :ref:`data-source-key-holder-label`\の状態を戻す。

|

.. _resolve-use-shard-key-labal:

使用するシャードの解決
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

データソースキーは、前出で説明した通りクラウドプラットフォームで提供されるKVSを利用することを前提とする。KVSに永続化したシャードキー情報とデータソースキーのマッピングを取得するため、シャードキーリポジトリクラスの実装とBean定義が必要となる。

シャードキーリポジトリクラスの実装は、使用するKVSに合わせて実装する。AWSの場合は、KVSに\ :ref:`aws-dynamodb`\を使用する。

|

.. _decide-shard-node-label:

シャードの割り当て決定
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

\ :ref:`resolve-use-shard-key-labal`\により、シャードキーに対応するシャードを解決するためには、事前にシャードキーとシャードのマッピング情報を\ :ref:`shardkey-management-policy`\に従って管理されている必要がある。シャーディング対象のデータの要素が新たに作成された際に、その要素のシャードキーをインプットとし、何かしらのルールに従って割り当てるシャードを決定し、そのマッピング情報を保存する。ここでは、シャードキーを元にラウンドロビンでシャードを割り当てる例を紹介する。
なお、**この割り当ては新たな要素が作成されたタイミングのみ実行すること**。一度シャードの割り当てが実行された以降は、\ :ref:`resolve-use-shard-key-labal`\により割り当てられたシャードを解決する。

シャードの割り当てを決定するため、シャードキーの値を元にデータソースキーを決定するシャードキーリゾルバクラスを実装する。また、このクラスのBean定義をする必要もある。

  .. note::
    シャードキーリゾルバクラスは、シャードの割り当てロジックを変更できるよう、\ ``ShardKeyResolver``\のインタフェースを用意し汎化しておく。また、シャードの割り当てを決定する時は、シャードキーをラウンドロビンのようにアクセス数が均等になるようにシャードをマッピングする。

.. _shard-key-resolver-label:

シャードキーリゾルバクラス
"""""""""""""""""""""""""""""""""""""""""""""""""""""

  以下に、シャードキーリゾルバクラス \ ``DataSourceKeyResolver``\のBean定義例を示す。

  .. code-block:: xml

    <bean id="shardKeyResolver"
        class="com.example.xxx.domain.common.shard.datasource.DataSourceKeyResolver">
        <!-- (1) -->
        <constructor-arg index="0" ref="databaseProperties" />
    </bean>

  .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
  .. list-table::
    :header-rows: 1
    :widths: 10 90

    * - 項番
      - 説明
    * - | (1)
      - コンストラクタの引数でデータソースの個別情報プロパティクラスを設定する。

|

  以下に、シャードキーリゾルバクラス \ ``DataSourceKeyResolver``\の実装例を示す。

  .. code-block:: java

    // omitted...
    // (1)
    public class DataSourceKeyResolver implements ShardKeyResolver, InitializingBean {
        // (2)
        @Value("${database.default.schema.name:default}")
        private String databaseDefaultSchemaName;
        // (3)
        private DatabaseProperties databaseProperties;
        // (4)
        private List<Map<String, String>> dataSources;
        // (5)
        public DataSourceKeyResolver(DatabaseProperties databaseProperties) {
            this.databaseProperties = databaseProperties;
        }
        // (6)
        @Override
        public void afterPropertiesSet() throws Exception {
            this.dataSources = new ArrayList<>();
            for (Map<String, String> dataSource : this.databaseProperties
                    .getDataSources()) {
                if (!databaseDefaultSchemaName.equals(dataSource
                        .get(ShardKeyResolver.SCHEMA_KEY_NAME))) {
                    this.dataSources.add(dataSource);
                }
            }
        }
        // (7)
        @Override
        public String resolveShardKey(String shardKey) {
            Integer key = Integer.valueOf(shardKey);
            int dataSourceIndex = key % (dataSources.size());
            Map<String, String> dataSource = dataSources.get(dataSourceIndex);
            return dataSource.get(ShardKeyResolver.SCHEMA_KEY_NAME);
        }
    }

  .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
  .. list-table::
    :header-rows: 1
    :widths: 10 90

    * - 項番
      - 説明
    * - | (1)
      - シャードキーリゾルバクラスは、\ ``ShardKeyResolver``\と\ ``InitializingBean``\インタフェースの実装クラスとして作成する。
    * - | (2)
      - \ :ref:`datasource-definition-label`\で指定した、デフォルトキーをインジェクトする。
    * - | (3)
      - コンストラクタで設定される、データソースの個別情報プロパティクラスを保持するフィールドを定義する。
    * - | (4)
      - シャード用データソースキーのリストを保持するフィールドを定義する。
    * - | (5)
      - コンストラクタの引数でデータソースの個別情報プロパティクラスを取得する。
    * - | (6)
      - \ ``InitializingBean``\のメソッド\ ``afterPropertiesSet()``\をオーバーライドし、シャード用データソースキーのリストを作成する。

        データソースの個別情報プロパティクラスからシャードのデータソースキーのリストを作成する。
    * - | (7)
      - 引数のシャードキーを元にシャードの割り当てをするメソッドを定義する。

        引数のシャードキー(例では数値)をシャード用データソースキーのリストサイズで除算した余りをインデックスとして、シャード用データソースキーのリストからデータソースキーを取得し返却する。

|

.. _sharding-in-application-label:

アプリケーションでのシャーディングの利用
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

アプリケーションでシャーディングを利用する方法について、チケット予約を例に以下の通り説明する。

- \ :ref:`allocation-shard-label`\をする。
- \ :ref:`resolve-shard-label`\をする

前提条件として、会員のチケット予約情報のDBはシャード対象としてKVSにマッピング情報が登録されている。また、フライトの空席情報のDBはシャード対象外( |default-shard-name| )とする。

.. _allocation-shard-label:

シャードの割り当て
"""""""""""""""""""""""""""""""""""""""""""""""""""""

シャードを割り当てるには、シャードキーを決定してシャードとマッピングする必要がある。

  以下で、新規会員登録を例に、会員情報登録サービスクラス\ ``MemberRegisterServiceImpl``\の実装を元に説明する。

  .. code-block:: java

    @Service
    public class MemberRegisterServiceImpl implements MemberRegisterService {
      // omitted...
      // (1)
      @Inject
      private ShardKeyResolver shardKeyResolver;

      @Override
      @Transactional
      public Member register(Member member) {
          // omitted...
          // (2)
          int insertMemberCount = memberRepository.insert(member);
          // omitted...
          // (3)
          ShardingAccount shardingAccount = new ShardingAccount();
          // (4)
          shardingAccount.setId(member.getCustomerNo());
          // (5)
          shardingAccount.setDataSourceKey(shardKeyResolver.resolveShardKey(member.getCustomerNo()));
          // (6)
          accountShardKeyRepository.save(shardingAccount);
          // omitted...
          return member;
      }
    }

  .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
  .. list-table::
    :header-rows: 1
    :widths: 10 90

    * - 項番
      - 説明
    * - | (1)
      - \ :ref:`shard-key-resolver-label`\をインジェクトする。
    * - | (2)
      - 会員情報を登録し、お客様番号を取得する。
    * - | (3)
      - シャードのマッピング情報のオブジェクトをインスタンス化する。
    * - | (4)
      - マッピング情報のシャードキーに(2)で取得したお客様番号を設定する。
    * - | (5)
      - \ :ref:`shard-key-resolver-label`\へ(2)で取得したお客様番号を渡してデータソースキーを取得しシャードに設定する。
    * - | (6)
      - シャードのマッピング情報をKVSに登録する。

  .. note::
    シャード対象となるデータを新規で登録する場合は、シャードを特定するシャードキーを作成してデータベースへデータを登録し、KVSへシャードのマッピング情報を登録する処理が必要になる。これらの処理のトランザクション境界が別々の場合に、最後の登録処理で例外が発生すると、最初に登録したデータを削除する処理が必要となる事に注意する。

    処理順序や例外発生のタイミングによってKVSだけにデータが登録されることが予想されるため、シャードキーとシャードのマッピング情報を保持するKVSは、不要データの削除を定期的に行うことを推奨する。

    上記の例では、DBのトランザクション境界内で最初にデータベースへ登録し、最後にKVSへ登録を行っている。これは、KVSの登録で例外発生した場合に、最初に登録したデータベースの削除処理を回避するためである。

|

.. _resolve-shard-label:

シャードの解決
"""""""""""""""""""""""""""""""""""""""""""""""""""""

シャードを解決するには、トランザクション境界となるサービスクラスの対象メソッドにシャード対象であることを示す\ :ref:`shard-with-account-annotaition-label`\を付与する。

なお、\ :ref:`shard-with-account-annotaition-label`\が付与されていない場合は、|default-shard-name| にアクセスする。

  以下で、チケット予約を例に、チケット予約サービスクラス\ ``TicketReserveServiceImpl``\の実装を元に説明する。

  .. code-block:: java

    @Service
    public class TicketReserveServiceImpl implements TicketReserveService {
        // (1)
        @Inject
        TicketSharedService ticketSharedService;
        // (2)
        @Inject
        FlightRepository flightRepository;
        // (3)
        @Inject
        ReservationRepository reservationRepository;
        // omitted...
        @Transactional
        // (4)
        @ShardWithAccount("reservation.repMember.customerNo")
        public String registerMemberReservation(Reservation reservation) {
        }
        @Transactional
        // (5)
        public TicketReserveDto registerReservation(String reserveNo, Reservation reservation) {
        }
        // omitted...
    }

  .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
  .. list-table::
    :header-rows: 1
    :widths: 10 90

    * - 項番
      - 説明
    * - | (1)
      - チケット共通サービスをインジェクトする。
    * - | (2)
      - フライト情報リポジトリをインジェクトする。
    * - | (3)
      - チケット予約情報リポジトリをインジェクトする。
    * - | (4)
      - メソッド\ ``registerMemberReservation``\はシャード対象のため、\ :ref:`shard-with-account-annotaition-label`\を付与する。

        会員のチケット予約情報を登録するメソッドのため、シャード対象となる。
    * - | (5)
      - メソッド\ ``registerReservation``\はシャード対象外のため、\ :ref:`shard-with-account-annotaition-label`\を付与しない。

        フライトの空席数を更新するメソッドのため、シャード対象外となる。

.. raw:: latex

   \newpage
