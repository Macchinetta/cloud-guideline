データベースリードレプリカ
================================================================================

.. only:: html

 .. contents:: 目次
    :depth: 3
    :local:

.. _drr_overview:

Overview
--------------------------------------------------------------------------------

本ガイドラインでは、AWSのAmazon RDS（以後、RDS）と\ ``spring-cloud-aws-jdbc``\ を使用してリードレプリカを行う場合について説明する。

リードレプリカの概要は、\ :ref:`read-replica-method-image-label`\ 、 AWS READ REPLICAの詳細は `AWS 公式サイト <https://aws.amazon.com/jp/rds/details/read-replicas/>`_ を参照されたい。


  .. figure:: imagesDatabaseReadReplica/DatabaseReadReplicaOverview.png
    :width: 90%
    :align: center

  .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
  .. list-table::
    :header-rows: 1
    :widths: 10 90

    * - 項番
      - 説明
    * - | (1)
      - Controllerが\ ``@Transactional``\アノテーション付のServiceメソッドを呼び出す。
    * - | (2)
      - \ ``TransactionInterceptor``\ は、\ ``DataSourceTransactionManager``\ のメソッドを呼び出してトランザクションの開始を依頼する。
    * - | (3)
      - \ ``DataSourceTransactionManager``\ は\ ``LazyConnectionDataSourceProxy``\ から\ ``Connection``\を取得する。
        このとき\ ``ReadOnlyRoutingDataSource``\ はトランザクションが読み取り専用の場合レプリカDBの\ ``DataSource``\ を返し、読み取り専用でない場合マスタDBの\ ``DataSource``\ を返却する。
    * - | (4)
      - (3)で取得した\ ``Connection``\でトランザクションを開始し\ ``Connection Holder``\ へ\ ``Connection``\を格納する。
    * - | (5)
      - ServiceはMyBatis Springを経由してDBへクエリを発行する。
    * - | (6)
      -  MyBatis Springは、(4)で格納した\ ``Connection``\を\ ``Connection Holder``\ から取得する。
    * - | (7)
      - MyBatis Springは、更新系の場合はマスタDBに、参照系の場合はレプリカDBにアクセスする。

|

.. _drr_implementation_policy:

実装方針
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
- レプリカDBへのデータのレプリケーションはRDSのリードレプリカを使用する
- \ ``spring-cloud-aws-jdbc``\ の仕組みを使用し、トランザクション単位でマスタDBとレプリカDBのデータソースを切り替える
- レプリカDBにアクセスする場合は、Springの\ ``@Transactional``\アノテーションの属性\ ``readOnly``\を\ ``true``\に設定する

RDSのリードレプリカの詳細は `AWS 公式サイト <https://aws.amazon.com/jp/rds/details/read-replicas/>`_ 、
Spring Cloud AWSの詳細は `Spring 公式サイト <http://cloud.spring.io/spring-cloud-static/spring-cloud-aws/1.2.1.RELEASE/#_read_replica_configuration>`_ を参照されたい。

.. warning::

    本ガイドの実装例は障害発生したレプリカDBのデータソースを選択する可能性を回避できない実装になっている。
    そのため、レプリカDBに障害が発生した場合に障害を回避することができない。
    本ガイドの実装例を利用する場合、レプリカDBの障害に対して運用面での対処（リードレプリカ復旧手順）を検討する必要がある。

.. _drr_restrictions:

リードレプリカ使用時の注意点
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
本ガイドラインで紹介するPostgreSQLのリードレプリカでは、マスタDBからのレプリケーションに遅延が生じるなど注意すべき点が存在する。

詳細は、AWS公式ドキュメント `PostgreSQL リードレプリカ <http://docs.aws.amazon.com/ja_jp/AmazonRDS/latest/UserGuide/USER_ReadRepl.html#USER_ReadRepl.PostgreSQL>`_ を参照されたい。


.. _drr_how_to_use:

How to use
----------------------------------------------------------------------------------

.. _drr_add_dependencies:

依存ライブラリの設定
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
Spring Cloud AWSを利用してRDSへのアクセスを行うための依存ライブラリの追加を行う。

- xxx-domain/pom.xml

  .. code-block:: xml

        <!-- (1) -->
        <dependency>
            <groupId>org.springframework.cloud</groupId>
            <artifactId>spring-cloud-aws-jdbc</artifactId>
        </dependency>


 .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
 .. list-table::
    :header-rows: 1
    :widths: 10 90

    * - 項番
      - 説明
    * - | (1)
      - | \ ``spring-cloud-aws-jdbc``\ の依存関係を追加する。


.. _rdd_settings_for_datasource:

データソースの設定
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Spring Cloud AWS JDBCを利用してRDSへのアクセスを行うためのBean定義を行う。
Bean定義の詳細については、 Spring Cloud AWS `Data Access with JDBC <http://cloud.spring.io/spring-cloud-static/spring-cloud-aws/1.2.1.RELEASE/#_data_access_with_jdbc>`_ を参照されたい。

- xxx-domain.xml

  .. code-block:: xml

        <!-- (1) -->
        <?xml version="1.0" encoding="UTF-8"?>
        <beans xmlns="http://www.springframework.org/schema/beans"
            xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
            xmlns:jdbc="http://www.springframework.org/schema/cloud/aws/jdbc"
            xsi:schemaLocation="http://www.springframework.org/schema/cloud/aws/jdbc
            http://www.springframework.org/schema/cloud/aws/jdbc/spring-cloud-aws-jdbc.xsd">
        <!-- (2) -->
        <jdbc:data-source db-instance-identifier="myRdsDatabase" password="password" read-replica-support="true">
          <!-- (3) -->
          <jdbc:pool-attributes initialSize="1" maxActive="200" minIdle="10" testOnBorrow="true" validationQuery="SELECT 1" />
        </jdbc:data-source>


  .. tabularcolumns:: |p{0.10\linewidth}|p{0.30\linewidth}|p{0.60\linewidth}|
  .. list-table::
    :header-rows: 1
    :widths: 10 30 60

    * - 項番
      - 属性名
      - 内容
    * - | (1)
      - | xmlns:jdbc
      - | Spring Cloud AWS JDBCの Namespaceを定義する。
        | 値として\ ``http://www.springframework.org/schema/cloud/aws/jdbc``\ を指定する。
    * - |
      - | xsi:schemaLocation
      - | スキーマのURLを指定する。
        | 値に\ ``http://www.springframework.org/schema/cloud/aws/jdbc``\ と\ ``http://www.springframework.org/schema/cloud/aws/jdbc/spring-cloud-aws-jdbc.xsd``\ を追加する。
    * - | (2)
      - | \ ``db-instance-identifier``\
      - | RDSのマスタDBのインスタンス識別子を設定する。設定例では\ ``myRdsDatabase``\ というDBインスタンス識別子を指定している。
        | データソースは設定したDBインスタンス識別子名で登録される。設定例の場合\ ``myRdsDatabase``\ で参照できる。
    * - |
      - | \ ``password``\
      - | DBのパスワードを設定する。
    * - |
      - | \ ``read-replica-support``\
      - | リードレプリカを使用するかどうかを設定する。\ ``true``\ を指定した場合、読み取り専用トランザクションはレプリカDBにルーティングされ、書き込み操作時にはマスタDBにルーティングされる。
    * - | (3)
      - | \ ``jdbc:pool-attributes``\
      - | データソースのコネクションプールのプロパティを設定することができる。詳細はSpring公式サイト\ `Data source pool configuration <http://cloud.spring.io/spring-cloud-static/spring-cloud-aws/1.2.1.RELEASE/#_data_source_pool_configuration>`_\ を参照されたい。

  .. note::
      \ ``jdbc:data-source``\ 内の設定値はプロパティファイルに書き出して読み込ませることができない。
      環境によって設定値を変更する場合Springのプロファイルの仕組みを使って実現することができる。
      詳細はSpring公式サイト\ `XML bean definition profiles <https://docs.spring.io/spring/docs/4.3.14.RELEASE/spring-framework-reference/html/beans.html#beans-definition-profiles-xml>`_\ を参照されたい。

.. _rdd_settings_for_using_datasource:

データソース利用箇所の設定
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

データソースのBean名は\ ``db-instance-identifier``\ の設定値で登録されるため、データソースのBeanを参照する際は設定したマスタDBのインスタンス識別子に変更する必要がある。

- application-local.yml

  .. code-block:: yaml

    # (1)
    rds:
      dbInstanceIdentifier: myRdsDatabase

  .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
  .. list-table::
    :header-rows: 1
    :widths: 10 90

    * - 項番
      - 説明
    * - | (1)
      - \ :ref:`rdd_settings_for_datasource`\ で\ ``jdbc:data-source``\ 要素の\ ``db-instance-identifier``\ 属性に設定したRDSのマスタDBのインスタンス識別子を\ ``rds.dbInstanceIdentifier``\ に設定する。


- xxx-codelist.xml

  .. code-block:: xml

        <bean id="jdbcTemplateForCodeList" class="org.springframework.jdbc.core.JdbcTemplate">
            <!-- (1) -->
            <property name="dataSource" ref="${rds.dbInstanceIdentifier}" />
            <property name="fetchSize" value="${codelist.jdbc.fetchSize:1000}" />
        </bean>


  .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
  .. list-table::
    :header-rows: 1
    :widths: 10 90

    * - 項番
      - 説明
    * - | (1)
      - | \ ``jdbcTemplateForCodeList``\ の\ ``dataSource``\ のref属性にDBインスタンス識別子を設定する。

|

- xxx-env.xml 変更前

  .. code-block:: xml

    <!-- (1) -->
    <bean id="realDataSource" class="org.apache.commons.dbcp2.BasicDataSource"
        destroy-method="close">
        <property name="driverClassName" value="${database.driverClassName}" />
        <property name="url" value="${database.url}" />
        <property name="username" value="${database.username}" />
        <property name="password" value="${database.password}" />
        <property name="defaultAutoCommit" value="false" />
        <property name="maxTotal" value="${cp.maxActive}" />
        <property name="maxIdle" value="${cp.maxIdle}" />
        <property name="minIdle" value="${cp.minIdle}" />
        <property name="maxWaitMillis" value="${cp.maxWait}" />
    </bean>

    <!-- (2) -->
    <bean id="dataSource" class="net.sf.log4jdbc.Log4jdbcProxyDataSource">
        <constructor-arg index="0" ref="realDataSource" />
    </bean>

    <!-- (3) -->
    <jdbc:initialize-database data-source="dataSource" ignore-failures="ALL">
        <jdbc:script location="classpath:/database/${database}-schema.sql" encoding="UTF-8" />
        <jdbc:script location="classpath:/database/${database}-dataload.sql" encoding="UTF-8" />
    </jdbc:initialize-database>

    <!-- (4) -->
    <bean id="transactionManager"
        class="org.springframework.jdbc.datasource.DataSourceTransactionManager">
        <property name="dataSource" ref="dataSource" />
        <property name="rollbackOnCommitFailure" value="true" />
    </bean>

- xxx-env.xml 変更後

  .. code-block:: xml

    <!-- (1) -->
    <!-- 削除 -->

    <!-- (2) -->
    <!-- 削除 -->

    <!-- (3) -->
    <jdbc:initialize-database data-source="${rds.dbInstanceIdentifier}" ignore-failures="ALL">
        <jdbc:script location="classpath:/database/${database}-schema.sql" encoding="UTF-8" />
        <jdbc:script location="classpath:/database/${database}-dataload.sql" encoding="UTF-8" />
    </jdbc:initialize-database>

    <!-- (4) -->
    <bean id="transactionManager"
        class="org.springframework.jdbc.datasource.DataSourceTransactionManager">
        <property name="dataSource" ref="${rds.dbInstanceIdentifier}" />
        <property name="rollbackOnCommitFailure" value="true" />
    </bean>

  .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
  .. list-table::
    :header-rows: 1
    :widths: 10 90

    * - 項番
      - 説明
    * - | (1)
      - | 旧DataSource設定は不要のため削除する。
    * - | (2)
      - | データソースをラップしていると、データソースの情報が正しく認識できずレプリカノードを正しく参照できなくなるため削除する。

        .. warning::

              spring-cloud-aws-jdbcを用いてリードレプリカ方式を実現する場合はデータソースをラップしないことを推奨する。
              例えば、ログ出力の為に\ ``net.sf.log4jdbc.Log4jdbcProxyDataSource``\等でデータソースをラップしていると、データソースの情報が正しく認識できずレプリカノードを正しく参照できなくなる。

    * - | (3)
      - | \ ``jdbc:initialize-database``\ の\ ``data-source``\ 属性にDBインスタンス識別子を設定する。
    * - | (4)
      - | \ ``transactionManager``\ の\ ``dataSource``\ のref属性にDBインスタンス識別子を設定する。

|

- xxx-infra.xml

  .. code-block:: xml

    <!-- define the SqlSessionFactory -->
    <bean id="sqlSessionFactory" class="org.mybatis.spring.SqlSessionFactoryBean">
        <!-- (1) -->
        <property name="dataSource" ref="${rds.dbInstanceIdentifier}" />
        <property name="configLocation" value="classpath:/META-INF/mybatis/mybatis-config.xml" />
    </bean>

  .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
  .. list-table::
    :header-rows: 1
    :widths: 10 90

    * - 項番
      - 説明
    * - | (1)
      - | \ ``sqlSessionFactory``\ の\ ``dataSource``\ のref属性にDBインスタンス識別子を設定する。

|


.. _rdd_implements_for_read_replica:

リードレプリカへのアクセスを行うサービスクラスの実装
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

リードレプリカへのアクセスを行うサービスクラスの実装例を以下に示す。

- MemberUpdateServiceImpl.Java

  .. code-block:: java

    public class MemberUpdateServiceImpl implements MemberUpdateService {

      @Transactional(readOnly = true) //(1)
      public Member findMember(String customerNo) throws IOException {
        // omitted
      }

      @Transactional  // (2)
      public void updateMember(Member member) throws IOException {
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
      - | 読み取り処理は\ ``@Transactional(readOnly = true)``\ を指定することで、リードレプリカインスタンスを参照する。
    * - | (2)
      - | \ ``readOnly=true``\ でない場合、マスタDBにルーティングされ書き込み処理が行われる。


.. _drr_how_to_extend:

How to extend
----------------------------------------------------------------------------------

.. _drr_implements_with_sharding:

データベースシャーディングと併用する場合の実装
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

本ガイドラインで紹介している\ :doc:`../ArchitectureInDetail/DataAccessDetail/DataAccessMyBatis3`\ では各シャードに対してデータソースを定義する独自の実装を行っている。
このため、シャーティングと併用する場合\ :ref:`drr_how_to_use`\ で紹介した方法ではリードレプリカを使用することはできない。

この項では\ :doc:`../ArchitectureInDetail/DataAccessDetail/DataAccessMyBatis3`\ で紹介しているデータソースファクトリクラスを拡張することによって、
シャーディングとリードレプリカの併用を実現する方法を紹介する。

.. _drr_datasource_factory:

リードレプリカに対応したデータソースファクトリの実装
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
\ :ref:`datasource-mapping-object-label`\ で紹介しているデータソースファクトリクラスである\ ``TomcatDataSourceFactory``\ を拡張し、
リードレプリカに対応したデータソース( ``ReadOnlyRoutingDataSource``\ )を作成する\ ``AmazonRdsReadReplicaTomcatDataSourceFactory``\ を実装する。

|

- データソースファクトリクラスのBean定義

  以下に、データソースファクトリクラス\ ``AmazonRdsReadReplicaTomcatDataSourceFactory``\のBean定義例を示す。

  .. code-block:: xml

    <bean id="dataSourceFactory"
      class="com.example.xxx.domain.common.shard.datasource.pool.AmazonRdsReadReplicaTomcatDataSourceFactory" />

|

- \ ``TomcatDataSourceFactory``\ の修正

  \ :ref:`datasource-mapping-object-label`\ で実装したデータソースファクトリクラスを下記のように変更する。

  .. code-block:: java

    public class TomcatDataSourceFactory implements DataSourceFactory {

        protected static final String dbInstanceIdentifierKey = "dbInstanceIdentifier";

        protected org.apache.tomcat.jdbc.pool.DataSourceFactory factory = new org.apache.tomcat.jdbc.pool.DataSourceFactory();

        @Override
        public DataSource create(Map<String, String> dataSourceProperties,
                Map<String, String> commonDataSourceProperties) {
            DataSource ret = null;
            Properties properties = new Properties();
            if (!commonDataSourceProperties.isEmpty()) {
                properties.putAll(commonDataSourceProperties);
            }
            properties.putAll(dataSourceProperties);
            try {
                // (1)
                if (properties.containsKey(dbInstanceIdentifierKey)) {
                    ret = createReadReplicaDataSource(properties);
                } else {
                    ret = factory.createDataSource(properties);
                }
            } catch (Exception e) {
                throw new SystemException(LogMessages.E_AR_A0_L9008.getCode(), LogMessages.E_AR_A0_L9008
                        .getMessage(), e);
            }
            return ret;
        }

        // (2)
        protected DataSource createReadReplicaDataSource(Properties properties) throws Exception {
            throw new SystemException(LogMessages.E_AR_A0_L9010.getCode(), LogMessages.E_AR_A0_L9010
                    .getMessage(dbInstanceIdentifierKey));
        }
    }

  .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
  .. list-table::
    :header-rows: 1
    :widths: 10 90

    * - 項番
      - 説明
    * - | (1)
      -  | \ ``dbInstanceIdentifier``\ というキー名がプロパティに設定されている場合、\ ``createReadReplicaDataSource``\  メソッドを実行する。
    * - | (2)
      -  | リードレプリカに対応したデータソースを作成する\ ``createReadReplicaDataSource``\ メソッドを定義する。
          リードレプリカ対応データソースファクトリクラスによってオーバーライドされる想定のため、
          \ ``TomcatDataSourceFactory``\ を使用したまま\ ``dbInstanceIdentifierKey``\ を定義している場合、システム例外が発生するように設定している。

|

- リードレプリカに対応したデータソースファクトリクラスの実装

  上記で修正した\ ``TomcatDataSourceFactory``\ を拡張して実装する。

  以下に、リードレプリカに対応したデータソースファクトリクラスの実装例を示す。

  .. code-block:: java

    // (1)
    public class AmazonRdsReadReplicaTomcatDataSourceFactory extends TomcatDataSourceFactory {

        @Value("${database.rdsRegion}")
        private String defaultRegion;

        private static final String driverUrlOptionKey = "driverUrlOption";

        private static final String replicaRegionKey = "replicaRegion";

        private static final String driverClassNameKey = "driverClassName";

        private StaticDatabasePlatformSupport databasePlatformSupport = new StaticDatabasePlatformSupport();

        @Override
        // (2)
        protected DataSource createReadReplicaDataSource(Properties properties) throws Exception {
            // (3)
            String region = defaultRegion;
            if (!StringUtils.isEmpty(properties.getProperty(replicaRegionKey))) {
                region = properties.getProperty(replicaRegionKey);
            }
            AmazonRDS amazonRds = AmazonRDSClientBuilder.standard().withRegion(region).build();
            // (4)
            String dbInstanceIdentifier = (String) properties.get(dbInstanceIdentifierKey);
            DBInstance dbInstance = getDbInstance(amazonRds, dbInstanceIdentifier);
            // (5)
            if (dbInstance.getReadReplicaDBInstanceIdentifiers().isEmpty()) {
                return createDataSourceInstance(dbInstance, properties);
            }
            // (6)
            Map<Object, Object> replicaMap = new HashMap<>(
                    dbInstance.getReadReplicaDBInstanceIdentifiers().size());

            for (String replicaName : dbInstance.getReadReplicaDBInstanceIdentifiers()) {
                replicaMap.put(replicaName, createDataSourceInstance(amazonRds,
                        replicaName, properties));
            }

            // (7)
            ReadOnlyRoutingDataSource dataSource = new ReadOnlyRoutingDataSource();
            dataSource.setTargetDataSources(replicaMap);
            dataSource.setDefaultTargetDataSource(createDataSourceInstance(dbInstance, properties));

            // (8)
            dataSource.afterPropertiesSet();
            // (9)
            return new LazyConnectionDataSourceProxy(dataSource);
        }
        // (10)
        private DBInstance getDbInstance(AmazonRDS amazonRds,
                String identifier) throws IllegalStateException {
            DBInstance instance;
            try {
                DescribeDBInstancesResult describeDBInstancesResult = amazonRds
                        .describeDBInstances(new DescribeDBInstancesRequest()
                                .withDBInstanceIdentifier(identifier));
                instance = describeDBInstancesResult.getDBInstances().get(0);
            } catch (DBInstanceNotFoundException e) {
                throw new SystemException(LogMessages.E_AR_A0_L9009.getCode(), LogMessages.E_AR_A0_L9009
                        .getMessage(identifier), e);
            }
            return instance;
        }
        // (11)
        private DataSource createDataSourceInstance(AmazonRDS amazonRds,
                String identifier, Properties properties) throws Exception {
            DBInstance instance = getDbInstance(amazonRds, identifier);
            return createDataSourceInstance(instance, properties);
        }
        // (12)
        private DataSource createDataSourceInstance(DBInstance instance, Properties properties) throws Exception {
            properties.setProperty("url", createUrl(instance, properties));
            if (!properties.containsKey(driverClassNameKey)) {
                properties.setProperty(driverClassNameKey, getDriverClassName(instance));
            }
            return factory.createDataSource(properties);
        }
        // (13)
        private String createUrl(DBInstance instance, Properties properties) {
            StringBuilder sb = new StringBuilder();
            String url =
                    databasePlatformSupport.getDatabaseUrlForDatabase(
                    DatabaseType.fromEngine(instance.getEngine()),
                    instance.getEndpoint().getAddress(),
                    instance.getEndpoint().getPort(),
                    instance.getDBName());
            sb.append(url);
            if (properties.containsKey(driverUrlOptionKey)) {
                sb.append("?").append(properties.getProperty(driverUrlOptionKey));
            }
            return sb.toString();
        }
        //(14)
        private String getDriverClassName(DBInstance instance) {
            return databasePlatformSupport.getDriverClassNameForDatabase(
                    DatabaseType.fromEngine(instance.getEngine()));
        }
    }

  .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
  .. list-table::
    :header-rows: 1
    :widths: 10 90

    * - 項番
      - 説明
    * - | (1)
      - リードレプリカに対応したデータソースファクトリクラスを\ ``TomcatDataSourceFactory``\ クラスを拡張して作成する。
    * - | (2)
      - リードレプリカに対応したデータソース作成メソッドを実装する。
    * - | (3)
      - リージョンを指定して\ ``AmazonRDS``\ を作成する。
    * - | (4)
      - DBインスタンス識別子を使用して\ ``DBInstance``\ を取得する。
    * - | (5)
      - (4)で取得した\ ``DBInstance``\ の\ ``ReadReplicaDBInstanceIdentifiers``\ が空の場合、リードレプリカ非対応のデータソースを作成する。
    * - | (6)
      - \ ``ReadReplicaDBInstanceIdentifiers``\ を使用して、レプリカごとにインスタンスを作成する。
        作成したインスタンスは、インスタンス識別子をキーにして\ ``Map``\ に格納する。
    * - | (7)
      - \ ``ReadOnlyRoutingDataSource``\ を使用してリードレプリカに対応したデータソースを作成する。
    * - | (8)
      - \ ``afterPropertiesSet()``\ メソッドを呼び出し初期化を行う。
    * - | (9)
      - \ ``LazyConnectionDataSourceProxy``\ を使用して(7)作成したデータソースをラップして返却する。
    * - | (10)
      - DBインスタンス識別子から\ ``DBInstance``\ を作成して返却するメソッドを実装する。
    * - | (11)
      - DBインスタンス識別子を使用して\ ``DataSource``\ を作成するメソッドを実装する。
    * - | (12)
      - \ ``DBInstance``\ を使用して\ ``DataSource``\ を作成するメソッドを実装する。
    * - | (13)
      - \ ``DBInstance``\ とプロパティを使用してDBのURLを作成するメソッドを実装する。
    * - | (14)
      -  \ ``DBInstance``\ を使用してドライバークラス名を取得する。

|

.. _drr_settings_with_sharding:

設定ファイルの記述
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
データソースについての設定例を以下に示す。\ :ref:`datasource-definition-label`\ で説明済みの内容は省略するので必要に応じて参照されたい。

- application-local.yml

  .. code-block:: yaml

    database:
      # (1)
      rdsRegion: ap-northeast-1
      common:
        data-source:
          driverClassName: org.postgresql.Driver
          maxActive: 96
          maxIdle: 16
          minIdle: 0
          maxWait: 90000
          password: password
          username: username
      default:
        schema:
          name: default
      data-sources:
        - schema: default
          # (2)
          dbInstanceIdentifier: myRdsDatabase
          # (3)
          driverUrlOption: socketTimeout=120&connectTimeout=120
          # (4)
          replicaRegion: us-east-1
        - schema: example1
          dbInstanceIdentifier: anotherRdsDatabase
          # (5)
          password: another
          username: another
        - schema: example2
          # (6)
          url: jdbc:postgresql://localhost:5432/example2?socketTimeout=120&connectTimeout=120

  .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
  .. list-table::
    :header-rows: 1
    :widths: 10 90

    * - 項番
      - 説明
    * - | (1)
      - RDSのリージョンを設定する。
    * - | (2)
      - RDSのDBインスタンス識別子を設定する。ここでは\ ``myRdsDatabase``\ を設定している。
    * - | (3)
      - ドライバーのURLオプションを設定する。
    * - | (4)
      -  \ ``replicaRegion``\ は\ ``rdsRegion``\ に設定したリージョンと違う設定値を使用したい場合に設定する。
    * - | (5)
      - データソース個別設定を行う。ここでは\ ``password``\ と\ ``username``\ を個別に設定している。
    * - | (6)
      - DBインスタンス識別子ではなく、URLにRDSインスタンスのエンドポイントを指定する方法も併用できる。

|

.. raw:: latex

   \newpage
