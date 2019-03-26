キャッシュの抽象化（Cache Abstraction）
================================================================================

.. only:: html

 .. contents:: 目次
    :depth: 3
    :local:

Overview
--------------------------------------------------------------------------------

本ガイドラインでは、:doc:`../../ImplementationAtEachLayer/PersistenceLayerScalability` にて紹介しているキャッシュ方式の実現により、データアクセス処理の負荷低減および高速化する方法を紹介する。
キャッシュ方式の実現方法にはSpring Cache Abstractionを採用する。Spring Cache Abstractionによるキャッシュ実装の抽象化により、キャッシュ実装の置換を容易化したり、コーディング方法を統一化することによる習得コストの低減などが見込める。

セッションを外部管理化するためにキャッシュを利用する方法については、 :doc:`../../AWSCollaboration/SessionManagement` を参照されたい。

Springのガイドについては、 `Spring Cache Abstraction <https://docs.spring.io/spring/docs/5.1.4.RELEASE/spring-framework-reference/integration.html#cache>`_ を参照されたい。

.. _cache-local-heap:

ローカルヒープを使用したキャッシュ
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

以下で、キャッシュ実装にローカルヒープ領域を使用した場合の処理の流れを示す。

  .. figure:: imagesCacheAbstraction/cache-abstraction.png
    :width: 90%
    :align: center

  .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
  .. list-table::
    :header-rows: 1
    :widths: 10 90

    * - 項番
      - 説明
    * - | (1)
      - \ ``Controller``\または\ ``Service``\は、引数を渡しキャッシュ定義されたDomain Layerの\ ``Service``\メソッドを呼び出す。
    * - | (2)
      - Cache AOPは、引数を元にキャッシュキーを特定し\ ``SimpleCacheManager``\を使用して\ ``ConcurrentHashMap``\から既に登録済のキャッシュデータを取得する。

        キャッシュデータが取得出来た場合は\ ``Controller``\または\ ``Service``\へキャッシュデータを返却し、キャッシュデータが取得出来ない場合は(3)および(4)を実行する。
    * - | (3)
      - Cache AOPは、引数を渡しキャッシュ定義されたDomain Layerの\ ``Service``\メソッドを実行し戻り値を取得する。

        Cache AOPは、(2)で特定したキャッシュキーで、取得した戻り値を\ ``SimpleCacheManager``\を使用して\ ``ConcurrentHashMap``\へキャッシュデータとして格納する。
    * - | (4)
      - Cache AOPは、\ ``Controller``\または\ ``Service``\へ取得した戻り値を返却する。

.. _cache-redis:

Redisを使用したキャッシュ
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

以下で、キャッシュ実装にRedisを使用した場合の処理の流れを示す。
キャッシュを行う仕組みはローカルヒープを使用したキャッシュと同一であるが、\ ``CacheManager``\として\ ``RedisCacheManager``\を使用する。

  .. figure:: imagesCacheAbstraction/cache-abstraction-redis.png
    :width: 90%
    :align: center

  .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
  .. list-table::
    :header-rows: 1
    :widths: 10 90

    * - 項番
      - 説明
    * - | (1)
      - Cache AOPは、特定したキャッシュキーで、取得した戻り値を\ ``RedisCacheManager``\を使用してRedisへキャッシュデータとして格納する。また、ControllerまたはServiceへ取得した戻り値を返却する。
        Redisへのアクセスは、Spring Data Redisを使用して行われる。

キャッシュ方式の選択
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

本ガイドラインでは、ローカルヒープを使用したキャッシュとRedisを使用したキャッシュを紹介するが、各キャッシュ方式によって特徴が異なる。
そのため、アプリケーションの要件に応じて適したキャッシュ方式を選択されたい。

.. tabularcolumns:: |p{0.20\linewidth}|p{0.40\linewidth}|p{0.40\linewidth}|
.. list-table::
  :header-rows: 1
  :widths: 20 40 40

  * - キャッシュ方式
    - 特徴
    - 適したアプリケーション
  * - | ローカルヒープを使用したキャッシュ
    - | Redisを使用したキャッシュよりも高速であるが、APサーバインスタンスのローカルヒープにキャッシュを保持するため、サーバインスタンス間のキャッシュを同期することができない。また、キャッシュするデータ量に応じてサーバインスタンスのメモリ消費量が大きくなる。
    - | キャッシュ対象とするデータがマスタデータ等の運用中に更新されることが想定されないデータに限定されるアプリケーションなどに適している。
  * - | Redisを使用したキャッシュ
    - | キャッシュをRedisに保持するため、キャッシュデータを複数のサーバインスタンス間で同期することが可能である。また、キャッシュデータ量が大きくなってもサーバインスタンスのメモリ消費量が大きくなることはない。
    - | キャッシュ対象とするデータ量が大きく、運用中の更新が見込まれるアプリケーションなどに適している。

.. note::
  Spring Cache Abstractionを使用したキャッシュの実装では、複数のキャッシュ方式を併用することが可能である。
  詳細は、:ref:`muiti-cache-manager` を参照されたい。

How to use
--------------------------------------------------------------------------------

以下でSpring Cache Abstractionの利用にあたり、事前に必要な設定、およびアプリケーションでキャッシュデータへアクセスする方法を説明する。

.. _cache-setting:

Spring Cache Abstractionの設定
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
.. _cache-local-heap-setting:

ローカルヒープを使用したキャッシュの設定
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

キャッシュの機能を有効にするには、キャッシュマネージャの設定が必要になる。
以下に、ローカルヒープを使用したキャッシュマネージャの設定例を示す。

  .. code-block:: xml

    ・・・
    <!-- (1) -->
    <cache:annotation-driven order="-1" />
    ・・・
    <!-- (2) -->
    <bean id="cacheManager" class="org.springframework.cache.support.SimpleCacheManager">
        <!-- (3) -->
        <property name="caches">
            <set>
                <bean
                    class="org.springframework.cache.concurrent.ConcurrentMapCacheFactoryBean">
                    <property name="name" value="members" />
                </bean>
                ・・・
            </set>
        </property>
    </bean>

  .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
  .. list-table::
    :header-rows: 1
    :widths: 10 90

    * - 項番
      - 説明
    * - | (1)
      - アノテーションでのキャッシュを有効にする。

        キャッシュデータの管理をするため\ ``order="-1"``\を設定し、キャッシュインターセプタがトランザクションインターセプタより先に動作する設定とする。これにより、キャッシュデータの参照はトランザクション開始前に、登録と削除はトランザクションの終了後に行う。
    * - | (2)
      - キャッシュデータの格納場所にローカルヒープ領域を使用する場合は、Springが提供する\ ``SimpleCacheManager``\をキャッシュマネージャとして使用する。
    * - | (3)
      - \ ``caches``\プロパティに、実際にキャッシュデータを格納する「入れ物(Cache)」をBean定義する。\ ``SimpleCacheManager``\を使用する場合は、後述する\ ``@CacheConfig``\アノテーションに対応した数だけBean定義が必要になる。「入れ物」の実装にJDK標準の\ ``ConcurrentHashMap``\を使用する場合は\ ``ConcurrentMapCacheFactoryBean``\を使用する。\ ``@CacheConfig``\との関連付けのため、\ ``name``\プロパティには\ ``@CacheConfig``\の\ ``cacheNames``\に指定するキャッシュ名を設定する

  .. note::
      ローカルヒープ領域における「入れ物」の実装は、\ ``ConcurrentMapCacheFactoryBean``\以外のものもSpringに用意されている。
      詳細は `Springのリファレンス Configuring the cache storage <https://docs.spring.io/spring/docs/5.1.4.RELEASE/spring-framework-reference/integration.html#cache-store-configuration>`_ を参照されたい。

.. _cache-redis-setting:

Redisを使用したキャッシュの設定
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

以下に、Redisを使用したキャッシュマネージャの設定例を示す。

- :file:`pom.xml`

 .. code-block:: xml

   <dependencies>
           <!-- (1) -->
           <dependency>
                   <groupId>org.springframework.data</groupId>
                   <artifactId>spring-data-redis</artifactId>
           </dependency>
           <!-- (2) -->
           <dependency>
                   <groupId>redis.clients</groupId>
                   <artifactId>jedis</artifactId>
           </dependency>
   </dependencies>


 .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
 .. list-table::
   :header-rows: 1
   :widths: 10 90

   * - 項番
     - 説明
   * - | (1)
     - | 依存ライブラリに\ ``spring-data-redis``\を追加する。
   * - | (2)
     - | 依存ライブラリに\ ``jedis``\を追加する。

|

- :file:`xxx-env.xml`

  .. code-block:: xml

    ・・・
    <!-- (1) -->
    <cache:annotation-driven order="-1" />
    ・・・
    <!-- (2) -->
    <bean id="cacheManager"
        class="org.springframework.data.redis.cache.RedisCacheManager"
        factory-method="create"
        c:connection-factory-ref="redisConnectionFactory"
        p:transaction-aware="true" />
    ・・・
    <!-- (3) -->
    <bean id="redisConnectionFactory"
        class="org.springframework.data.redis.connection.jedis.JedisConnectionFactory"
        p:host-name="${spring.redis.host}" p:port="${spring.redis.port}" />


  .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
  .. list-table::
    :header-rows: 1
    :widths: 10 90

    * - 項番
      - 説明
    * - | (1)
      - アノテーションでのキャッシュを有効にする。ローカルヒープを使用したキャッシュと同様に\ ``order="-1"``\を設定する。
    * - | (2)
      - キャッシュデータの格納場所にRedisを使用する場合は、Spring Data Redisが提供する\ ``RedisCacheManager``\をキャッシュマネージャとして使用する。
        \ ``RedisCacheManager``\の設定方法は `Support for the Spring Cache Abstraction <https://docs.spring.io/spring-data/redis/docs/2.1.4.RELEASE/reference/html/#redis:support:cache-abstraction>`_ を参照されたい。
    * - | (3)
      - キャッシュマネージャで利用する\ ``redisConnectionFactory``\を設定する。

|

- :file:`application.yml`

 .. code-block:: yaml

   spring:
     redis:
       # (1)
       host: 127.0.0.1
       port: 6379


 .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
 .. list-table::
   :header-rows: 1
   :widths: 10 90

   * - 項番
     - 説明
   * - | (1)
     - | \ ``spring.redis.host``\と\ ``spring.redis.port``\に接続するredisのホストとポートを設定する。

.. _cache-data-regist:

キャッシュするデータの選択
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

以下にキャッシュしたいデータを定義する方法を説明する。
Spring Cache Abstractionでは、メソッドにアノテーションを定義することでキャッシュ対象データを選択する方式をとる。
対象メソッドの戻り値がキャッシュ対象のデータとなる。

  .. code-block:: java

    // omitted...
    // (1)
    @CacheConfig(cacheNames = "members")
    public class MemberUpdateServiceImpl implements MemberUpdateService {
      // omitted...
      @Transactional(readOnly = true)
      // (2)
      @Cacheable(key = "'member/' + #customerNo")
      public Member findMember(String customerNo) throws IOException {
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
      - \ ``CacheConfig``\アノテーションをクラスへ付与する。

        このクラス内のキャッシュアノテーションの属性cacheNamesを設定する。
        ここで設定したcacheNamesはredisに格納する際のキープレフィックス（この例では「members::」）となる。
    * - | (2)
      - \ ``Cacheable``\アノテーションをキャッシュ対象の参照メソッドへ付与する。

        属性key(キャッシュキー)を設定する。この例では、文字列引数(customerNo)の値にプレフィックス'member/'を付けてキーにしている。例えば customerNo=000001 の場合、キャッシュキーは「members::member/000001」となり、キャッシュされる値はメソッドの戻り値となる。

  .. warning::

    Spring Cache Abstractionのアノテーションを使用する場合は、\ ``@Cacheable``\、\ ``@CachePut``\と\ ``@CacheEvict``\アノテーションの属性 *value* (または *cacheNames* )の値は、Spring frameworkがキャッシュオペレーション作成時に必須の値となるため設定すること。

    また、インタフェースにSpring Cache Abstractionのアノテーションを付与することは基本的に推奨していない。理由としては、インタフェースのメソッドの引数名はデフォルトでは取得できないためである。この制約に対しSpringは代替手段として、インタフェースしか実装しない場合(Proxyとなるインタフェース、例えばDynamoDBのリポジトリ等)にメソッドの\ ``@Cacheable``\を付与する際は、メソッド引数のインデックスを指定することで引数へのアクセスを実現することが可能である。

    以下に、インデックス指定の例を示す。

      .. code-block:: java

        @CacheConfig(cacheNames = "shardids")
        @EnableScan
        public interface AccountShardKeyRepository
                                                extends
                                                CrudRepository<ShardingAccount, String> {
          @Override
          // (1)
          @Cacheable(key = "'shardid/' + #a0")
          Optional<ShardingAccount> findById(String id);
        }

      .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
      .. list-table::
        :header-rows: 1
        :widths: 10 90

        * - 項番
          - 説明
        * - | (1)
          - \ ``Cacheable``\アノテーションの属性\ ``key``\で設定している、\ ``#a0``\がメソッド\ ``findById``\の引数0番目(id)を指定している。

            詳細は `Springのリファレンス Available caching SpEL evaluation context <https://docs.spring.io/spring/docs/5.1.4.RELEASE/spring-framework-reference/integration.html#cache-spel-context>`_ を参照されたい。

キャッシュしたデータの削除
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

キャッシュデータは、対象データが更新または、削除された場合にキャッシュデータの削除が必要になる。

以下にキャッシュしたデータを削除する定義方法を説明する。
Spring Cache Abstractionでは、メソッドにアノテーションを定義することでキャッシュ対象データを削除する方式をとる。
メソッドで定義したアノテーションキーが削除対象データのキーとなる。

  .. code-block:: java

    // omitted...
    // (1)
    @CacheConfig(cacheNames = "members")
    public class MemberUpdateServiceImpl implements MemberUpdateService {
      // omitted...
      @Transactional(readOnly = true)
      // (2)
      @Cacheable(key = "'member/' + #customerNo")
      public Member findMember(String customerNo) throws IOException {
        // omitted...
      }
      // (3)
      // omitted...
      @CacheEvict(key = "'member/' + #member.customerNo")
      public void updateMember(Member member) {
        // omitted...
      }
    }

  .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
  .. list-table::
    :header-rows: 1
    :widths: 10 90

    * - 項番
      - 説明
    * - | (1)
      - \ ``CacheConfig``\アノテーションをクラスへ付与する。
        ここで設定したcacheNamesはredisに格納する際のキープレフィックス（この例では「members::」）となる。
    * - | (2)
      - \ :ref:`cache-data-regist`\で説明したキャッシュデータを登録または参照するメソッド定義。
    * - | (3)
      - \ ``CacheEvict``\アノテーションをキャッシュ対象の更新メソッドへ付与する。

        属性key(キャッシュキー)を設定する。この例では、引数であるMemberオブジェクトのフィールド(customerNo)の値にプレフィックス'member/'を付けてキーにしている。例えば customerNo=000001 の場合、キャッシュキーは「members::member/000001」となり、(2)でキャッシュされたキーを同じになるため、(2)でキャッシュされた値を削除する。

  .. warning::
    トランザクショナルなDBの値をキャッシュデータにしている場合は、DBの値更新時に完全なデータの同期が出来ない事に注意が必要である。

    DBの値が更新され、コミットされてからキャッシュデータが削除されるまでの間のデータ参照は古いキャッシュデータが参照される。



注意事項
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
- ローカルヒープ領域を利用した場合は、キャッシュが共有される範囲は同一のDIコンテナ内のみである。
- 特にローカルヒープ領域をキャッシュ格納場所に使用する場合は、キャッシュ対象データのサイズに注意すること。ヒープサイズに見合わない量のデータをキャッシュした場合、パフォーマンスが低下したりメモリ不足に陥る可能性がある。そのような場合には、ローカルヒープ領域外を格納場所として使用するなどを検討すること。
- 本ガイドラインで説明しているセッションの外部管理の方法と、:ref:`cache-redis-setting` にて説明した方法でRedisを使用したキャッシュを併用する場合、接続先のRedisは同一のRedisとなる。高負荷での運用が想定されるアプリケーションについては、セッション情報とキャッシュを格納するRedisを別にすることでコネクション数の枯渇を回避することが出来る。キャッシュ格納用のRedisの設定方法については、 :ref:`redis-setting-for-multi-instance` を参照。

How to extend
--------------------------------------------------------------------------------

.. _redis-setting-for-multi-instance:

目的別に接続先Redisを指定する
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

高負荷での運用が想定される場合等、セッションの外部管理やキャッシュの格納等の複数の目的でRedisを使用する際に、利用目的別に接続先のRedisを別にすることが望ましいケースがある。

以下に、キャッシュ格納用のRedisを目的別に設定する方法を示す。

  .. code-block:: xml

    ・・・
    <cache:annotation-driven order="-1" />
    ・・・
    <!-- (1) -->
    <bean id="cacheManager"
        class="org.springframework.data.redis.cache.RedisCacheManager"
        factory-method="create"
        c:connection-factory-ref="jedisConnectionFactoryForCache"
        p:transaction-aware="true" />

    <!-- (2) -->
    <bean id="jedisConnectionFactoryForCache"
        class="org.springframework.data.redis.connection.jedis.JedisConnectionFactory">
        <constructor-arg index="0">
            <!-- (3) -->
            <bean
                class="org.springframework.data.redis.connection.RedisClusterConfiguration">
                <constructor-arg>
                    <list>
                        <value>${redis.cache.cluster.node1}</value>
                        <value>${redis.cache.cluster.node2}</value>
                        <value>${redis.cache.cluster.node3}</value>
                    </list>
                </constructor-arg>
            </bean>
        </constructor-arg>
        <constructor-arg index="1">
            <!-- (4) -->
            <bean class="redis.clients.jedis.JedisPoolConfig">
                <property name="maxTotal" value="${redis.cache.maxTotal}" />
                <property name="maxIdle" value="${redis.cache.maxIdle}" />
                <property name="maxWaitMillis" value="${redis.cache.maxWaitMillis}" />
                <property name="minIdle" value="${redis.cache.minIdle}" />
            </bean>
        </constructor-arg>
    </bean>

    <!-- (5) -->
    <bean id="jedisConnectionFactoryForSession" primary="true"
        class="org.springframework.data.redis.connection.jedis.JedisConnectionFactory">
        <constructor-arg index="0">
            <bean
                class="org.springframework.data.redis.connection.RedisClusterConfiguration">
                <constructor-arg>
                    <list>
                        <value>${redis.session.cluster.node1}</value>
                    </list>
                </constructor-arg>
            </bean>
        </constructor-arg>
        <constructor-arg index="1">
            <bean class="redis.clients.jedis.JedisPoolConfig">
                <property name="maxTotal" value="${redis.session.maxTotal}" />
                <property name="maxIdle" value="${redis.session.maxIdle}" />
                <property name="maxWaitMillis" value="${redis.session.maxWaitMillis}" />
                <property name="minIdle" value="${redis.session.minIdle}" />
            </bean>
        </constructor-arg>
    </bean>

  .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
  .. list-table::
    :header-rows: 1
    :widths: 10 90

    * - 項番
      - 説明
    * - | (1)
      - キャッシュマネージャとして\ `RedisCacheManager`\を使用する。
    * - | (2)
      - \ `JedisConnectionFactory`\を使用したコネクションファクトリのBean定義を行う。コンストラクタに\ `RedisClusterConfiguration`\と\ `JedisPoolConfig`\を指定し、接続先のRedisクラスタの指定および接続設定を行う。AutoConfigurationによる\ `RedisConnectionFactory`\のBean定義との重複を避けるため、idを"jedisConnectionFactory"とは異なる文字列とする。

        .. note::

         \ `JedisConnectionFactory`\のコンストラクタに\ `RedisClusterConfiguration`\を指定する場合、接続先のRedisはクラスタ構成であることが必須となる。スタンドアローン構成のRedisに接続する場合は\ `JedisConnectionFactory`\に直接接続先のServerとPortを指定すること。
         指定方法については、`Spring Data Redisのリファレンス <https://docs.spring.io/spring-data/redis/docs/2.1.4.RELEASE/reference/html/#redis:connectors:jedis>`_ を参照されたい。

    * - | (3)
      - \ `RedisClusterConfiguration`\のBean定義を行う。コンストラクタの引数に接続先のノードを指定する。
    * - | (4)
      - \ `JedisPoolConfig`\のBean定義を行う。
    * - | (5)
      - \ `RedisConnectionFactory`\インタフェースの実装クラスをBean定義すると、AutoConfigurationによる\ `RedisConnectionFactory`\のBean定義が無効となる。そのため、Spring Sessionがセッション情報をRedisに格納するために使用する\ `JedisConnectionFactory`\のBean定義を行う。\ `primary="true"`\を指定し、Spring Sessionが\ `RedisTemplate`\を生成する際に優先的に使用させる。

  プロパティキーに対応する値の設定を行う。

  .. code-block:: yaml

   redis:
     cache:
       cluster:
         # (1)
         node1:
           127.0.0.1:30001
         node2:
           127.0.0.1:30002
         node3:
           127.0.0.1:30003
       # (2)
       maxTotal: 8
       maxIdle: 8
       maxWaitMillis: -1
       minIdle: 0
     session:
       cluster:
         # (3)
         node1:
           127.0.0.1:30004
         node2:
           127.0.0.1:30005
         node3:
           127.0.0.1:30006
       # (4)
       maxTotal: 8
       maxIdle: 8
       maxWaitMillis: -1
       minIdle: 0

  .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
  .. list-table::
    :header-rows: 1
    :widths: 10 90

    * - 項番
      - 説明
    * - | (1)
      - キャッシュを格納するRedisの接続先ノードを指定する。
    * - | (2)
      - キャッシュを格納するRedisの\ `JedisPoolConfig`\に設定するプロパティを指定する。
    * - | (3)
      - セッションを格納するRedisの接続先ノードを指定する。
    * - | (4)
      - セッションを格納するRedisの\ `JedisPoolConfig`\に設定するプロパティを指定する。

.. _muiti-cache-manager:

複数のキャッシュマネージャを併用する
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Spring Cache Abstractionでは、複数のキャッシュマネージャを別のBean名で定義しておき、\ `@Cacheable`\アノテーションの\ `cacheManager`\属性に指定することで、キャッシュ対象データ毎に使用するキャッシュマネージャを指定することが可能である。
詳細は、`Custom cache resolution <Custom cache resolution <https://docs.spring.io/spring/docs/5.1.4.RELEASE/spring-framework-reference/integration.html#cache-annotations-cacheable-cache-resolver>`_ を参照されたい。

.. raw:: latex

   \newpage
