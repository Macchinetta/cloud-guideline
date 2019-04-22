データベースシャーディング
================================================================================

.. only:: html

 .. contents:: 目次
    :depth: 3
    :local:

Overview
--------------------------------------------------------------------------------

本ガイドラインでは、AWSを使用したデータベースシャーディングについて説明する。

:doc:`../ImplementationAtEachLayer/PersistenceLayerScalability` や :doc:`../ArchitectureInDetail/DataAccessDetail/DataAccessMyBatis3` で説明したシャーディング方式を実現するにあたり、AWS上でシャーディングを実現する場合はシャードにはRDSを、シャードキー管理のための記憶装置にはKVS(Key-Value Store)であるDynamoDBを使用する。また、DynamoDBに格納するシャードキー情報は読み込み頻度が高く、値の更新の機会が少ないため、キャッシュ方式によりアクセスの負荷を低減する。DynamoDBへのアクセスにはSpring Data DynamoDBを使用する。シャードキー情報のキャッシュ化には :doc:`../ArchitectureInDetail/DataAccessDetail/CacheAbstraction` を使用する。

本ガイドラインでは、以下に示すイメージの赤枠破線部分について説明する。

  .. figure:: imagesDatabaseSharding/DatabaseShardingOverview.png
    :width: 90%
    :align: center

  .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
  .. list-table::
    :header-rows: 1
    :widths: 10 90

    * - 項番
      - 説明
    * - | (1)
      - Controllerが\ ``@ShardWithAccount``\と\ ``@Transactional``\付のServiceメソッドを呼び出す。
    * - | (2)
      - Sharding AOPがDynamoDB Repositoryを呼び出しシャードキーを特定する。
    * - | (3)
      - Sharding AOPは、(2)で特定したシャードキーをRouting Data Sourceへ伝播する。
    * - | (4)
      - Transaction AOPは、Transaction Managerを呼び出す。
    * - | (5)
      - Transaction Managerは、Routing Data SourceからConnectionを取得する。
    * - | (6)
      - Transaction Managerは、(5)で取得した\ ``Connection``\でトランザクションを開始しConnection Holderへ\ ``Connection``\を格納する。
    * - | (7)
      - Serviceは、Shard RepositoryのDBアクセスメソッドを呼び出す。
    * - | (8)
      - Shard Repositoryは、Mybatis Springを経由してDBへクエリを発行する。
    * - | (9)
      - Mybatis Springは、(6)で格納した\ ``Connection``\をConnection Holderから取得しDBへアクセスする。

.. _aws-dynamodb:

DynamoDB
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

DynamoDBについては、 `公式サイト <https://aws.amazon.com/jp/dynamodb/?sc_channel=PS&sc_campaign=acquisition_JP&sc_publisher=google&sc_medium=dynamodb_b&sc_content=dynamodb_p&sc_detail=aws%20dynamodb&sc_category=dynamodb&sc_segment=92610484225&sc_matchtype=p&sc_country=JP&sc_brand=brand&ef_id=WEkmJgAABWLDjcaM:20161215074309:s>`_ を参照されたい。

DynamoDBのガイドについては、 `Amazon DynamoDB ドキュメント <https://aws.amazon.com/jp/documentation/dynamodb/>`_ を参照されたい。

.. warning::
  DynamoDBにトランザクション機能はないため、RDB等との整合性をトランザクション機能により担保することができない点に注意されたい。
  また、デフォルトでは結果整合性モデルである点に注意されたい。詳細は `読み込み整合性 <http://docs.aws.amazon.com/ja_jp/amazondynamodb/latest/developerguide/HowItWorks.ReadConsistency.html>`_ を参照されたい。

How to use
--------------------------------------------------------------------------------

AWSを使用する場合、:doc:`../ArchitectureInDetail/DataAccessDetail/DataAccessMyBatis3` で説明した\ :ref:`get-shard-key-label`\の内容は、本ガイドラインで説明する以下の内容となる。

DynamoDBへアクセスする\ :ref:`aws-implementation-repository-setting`\と\ :ref:`aws-implementation-repository`\について説明する。

Spring Data module for DynamoDBの詳細については、 `Spring Data DynamoDB <https://github.com/derjust/spring-data-dynamodb>`_ を参照されたい。

|

.. _aws-implementation-repository-setting:

シャードキーリポジトリの設定
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

以下に、pom.xmlで依存ライブラリの設定例を示す。

- \ ``xxx-parent/pom.xml``\

.. code-block:: xml

    <dependencyManagement>
      <dependencies>
        ・・・
        <!-- == Begin DynamoDB == -->
        <!-- (1) -->
        <dependency>
          <groupId>com.github.derjust</groupId>
          <artifactId>spring-data-dynamodb</artifactId>
          <version>${org.springframework.data.dynamodb-dependencies.version}</version>
        </dependency>
        <!-- == End DynamoDB == -->
      </dependencies>
    </dependencyManagement>
    <properties>
      ・・・
      <!-- (2) -->
      <org.springframework.data.dynamodb-dependencies.version>4.5.0</org.springframework.data.dynamodb-dependencies.version>
      ・・・
    </properties>

.. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
.. list-table::
  :header-rows: 1
  :widths: 10 90

  * - 項番
    - 説明
  * - | (1)
    - spring-data-dynamodbをバージョン指定で設定する。

      子pomでバージョン指定が不要になる。
  * - | (2)
    - spring-data-dynamodbのバージョンを設定する。

- \ ``xxx-domain/pom.xml``\

.. code-block:: xml

  ・・・
  <!-- (1) -->
  <dependency>
    <groupId>com.github.derjust</groupId>
    <artifactId>spring-data-dynamodb</artifactId>
  </dependency>
  ・・・

.. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
.. list-table::
  :header-rows: 1
  :widths: 10 90

  * - 項番
    - 説明
  * - | (1)
    - spring-data-dynamodbを設定する。

|

以下に、DynamoDBのリージョンとシャードキーリポジトリインタフェースの設定例を示す。

- \ ``xxx-env/src/main/resources/application-local.yml``\にDynamoDBのリージョンを設定

.. code-block:: yaml

  cloud:
    aws:
      ・・・
      # (1)
      dynamodb:
        region: ap-northeast-1

.. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
.. list-table::
  :header-rows: 1
  :widths: 10 90

  * - 項番
    - 説明
  * - | (1)
    - DynamoDBのリージョンを設定する。

|

- \ ``xxx-domain/src/main/resources/META-INF/spring/xxx-domain.xml``\にシャードキーリポジトリインタフェースの設定

.. code-block:: xml

  <!-- (1) -->
   <bean id="amazonDynamoDB"
     class="com.example.xxx.domain.common.dynamodb.DynamoDBClientFactory" factory-method="create">
     <!-- (2) -->
     <constructor-arg index ="0" value="${cloud.aws.dynamodb.region}" />
   </bean>
  <!-- (3) -->
  <dynamodb:repositories base-package="com.example.xxx.domain.common.shard.repository"
    amazon-dynamodb-ref="amazonDynamoDB" />

.. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
.. list-table::
  :header-rows: 1
  :widths: 10 90

  * - 項番
    - 説明
  * - | (1)
    - | DynamoDBへアクセスするための\ ``AmazonDynamoDB``\ を定義する。
      | \ ``DynamoDBClientFactory``\ を使用してインスタンスを生成する。
  * - | (2)
    - DynamoDBリージョンをコンストラクタ引数で設定する。
  * - | (3)
    - シャードキーリポジトリのパッケージをスキャン対象に設定する。

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

.. _aws-implementation-repository:

シャードキーリポジトリの実装
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

以下に、DynamoDBのテーブルShardAccountに格納されたデータのイメージを示す。

.. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
.. list-table::
  :header-rows: 1
  :widths: 20 80

  * - user_id
    - data_source_key
  * - | 0000000001
    - xxx1
  * - | 0000000002
    - xxx2
  * - | 0000000003
    - xxx3
  * - | ・・・
    - ・・・

.. note::

  DynamoDBは、AWSアカウントとリージョンの組み合わせの単位でテーブル名がユニークとなっている必要がある。そのため、たとえば開発環境とテスト環境で同一のAWSアカウントとリージョンを使用して、データを排他的に管理したい場合は同名のテーブルを使用することができない。

  一方で、\ ``@DynamoDBTable``\ に設定するテーブル名を、変数化やプロファイル対応させてプログラマティックに動的に変更することは、DynamoDBのSDKやSpring Data DynamoDBの仕様上難しい。

  そのため、同一アプリケーションを複数の排他的な環境で実行したい場合には、AWSアカウントもしくはリージョンを別にすることを推奨する。

|

DynamoDBへアクセスする為には、テーブルデータに対応したエンティティクラスとシャードキーリポジトリクラスを作成する。
以下に、DynamoDBのエンティティクラス\ ``ShardingAccount``\とシャードキーリポジトリクラス\ ``AccountShardKeyRepository``\の実装例を示す。

Spring DataのRepositoryの詳細については、`Spring Data JPA <http://terasolunaorg.github.io/guideline/5.4.2.RELEASE/ja/ArchitectureInDetail/DataAccessDetail/DataAccessJpa.html#repository>`_ を参照されたい。

- エンティティクラス\ ``ShardingAccount``\

.. code-block:: java

  package com.example.xxx.domain.common.shard.model;

  import java.io.Serializable;

  import com.amazonaws.services.dynamodbv2.datamodeling.DynamoDBAttribute;
  import com.amazonaws.services.dynamodbv2.datamodeling.DynamoDBHashKey;
  import com.amazonaws.services.dynamodbv2.datamodeling.DynamoDBTable;
  // (1)
  @DynamoDBTable(tableName = "ShardAccount")
  public class ShardingAccount implements Serializable {

    private static final long serialVersionUID = 1L;
    // (2)
    @DynamoDBHashKey(attributeName = "user_id")
    private String userId;
    // (3)
    @DynamoDBAttribute(attributeName = "data_source_key")
    private String dataSourceKey;
    // setter and getter
  }

.. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
.. list-table::
  :header-rows: 1
  :widths: 10 90

  * - 項番
    - 説明
  * - | (1)
    - DynamoDBエンティティとして使用するためのアノテーション\ ``DynamoDBTable``\を付与しテーブル名を設定する。
  * - | (2)
    - ユーザID(ハッシュキー)の項目名を定義する。

      アノテーション\ ``DynamoDBHashKey``\
  * - | (3)
    - データソースキーの項目名を定義する。

|

- リポジトリクラス\ ``AccountShardKeyRepository``\

.. code-block:: java

  package com.example.xxx.domain.common.shard.repository;

  import org.socialsignin.spring.data.dynamodb.repository.EnableScan;
  import org.springframework.data.repository.CrudRepository;

  import com.example.xxx.domain.common.shard.model.ShardingAccount;
  // (1)
  @EnableScan
  // (2)
  public interface AccountShardKeyRepository extends CrudRepository<ShardingAccount, String> {
    // (3)
    @Override
    @Cacheable(key = "'shardid/' + #a0")
    ShardingAccount findOne(String id);
  }

.. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
.. list-table::
  :header-rows: 1
  :widths: 10 90

  * - 項番
    - 説明
  * - | (1)
    - DynamoDBリポジトリとして使用するためのアノテーション\ ``EnableScan``\を付与する。
  * - | (2)
    - \ ``CrudRepository``\のサブインタフェースとして実装する。
  * - | (3)
    - キャッシュの為、メソッドをオーバーライドしている。キャッシュの詳細は、:doc:`../ArchitectureInDetail/DataAccessDetail/CacheAbstraction` を、\ ``@Cacheable``\アノテーションの属性\ ``key``\で設定している\ ``#a0``\については、\ :ref:`cache-data-regist`\を参照されたい。

      キャッシュが不要な場合は、本メソッドのオーバーライドは不要である。

|

シャードキーリポジトリの使用
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

シャードキーリポジトリは\ :ref:`aws-implementation-repository`\で説明したように、\ ``CrudRepository``\のサブインタフェースとして実装し\ ``CrudRepository``\をそのまま使用するため追加実装は不要である。

.. raw:: latex

   \newpage
