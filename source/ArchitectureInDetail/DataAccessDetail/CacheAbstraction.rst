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

Springのガイドについては、 `Spring Cache Abstraction <http://docs.spring.io/spring/docs/4.3.5.RELEASE/spring-framework-reference/html/cache.html>`_ を参照されたい。

.. note::
  現時点でのキャッシュ実装には記憶領域にローカルヒープ領域を使用する方法のみを紹介している。
  今後、他のキャッシュ実装の紹介も検討する。

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

        キャッシュデータが取得出来た場合は\ ``Controller``\または\ ``Service``\へキャッシュデータを返却し、キャッシュデータが取得出来ない場合は(3)を実行する。
    * - | (3)
      - Cache AOPは、引数を渡しキャッシュ定義されたDomain Layerの\ ``Service``\メソッドを実行し戻り値を取得する。

        Cache AOPは、(2)で特定したキャッシュキーで、取得した戻り値を\ ``SimpleCacheManager``\を使用して\ ``ConcurrentHashMap``\へキャッシュデータとして格納する。また、\ ``Controller``\または\ ``Service``\へ取得した戻り値を返却する。

How to use
--------------------------------------------------------------------------------

以下でSpring Cache Abstractionの利用にあたり、事前に必要な設定、およびアプリケーションでキャッシュデータへアクセスする方法を説明する。

.. _cache-local-heap-setting:

Spring Cache Abstractionの設定
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

キャッシュの機能を有効にするには、キャッシュマネージャーの設定が必要になる。
以下に、キャッシュマネージャーの設定例を示す。

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

        キャッシュデータの管理をするため\ ``order="-1"``\を設定し、キャッシュインタセプターがトランザクションインタセプターより先に動作する設定とする。これにより、キャッシュデータの参照はトランザクション開始前に、登録と削除はトランザクションの終了後に行う。
    * - | (2)
      - キャッシュデータの格納場所にローカルヒープ領域を使用する場合は、Springが提供する\ ``SimpleCacheManager``\をキャッシュマネージャとして使用する。
    * - | (3)
      - \ ``caches``\プロパティに、実際にキャッシュデータを格納する「入れ物(Cache)」をBean定義する。\ ``SimpleCacheManager``\を使用する場合は、後述する\ ``@CacheConfig``\アノテーションに対応した数だけBean定義が必要になる。「入れ物」の実装にJDK標準の\ ``ConcurrentHashMap``\を使用する場合は\ ``ConcurrentMapCacheFactoryBean``\を使用する。\ ``@CacheConfig``\との関連付けのため、\ ``name``\プロパティには\ ``@CacheConfig``\の\ ``cacheNames``\に指定するキャッシュ名を設定する

  .. note::
      ローカルヒープ領域における「入れ物」の実装は、\ ``ConcurrentMapCacheFactoryBean``\以外のものもSpringに用意されている。
      詳細は `Springのリファレンス Configuring the cache storage <https://docs.spring.io/spring/docs/4.3.5.RELEASE/spring-framework-reference/htmlsingle/#cache-store-configuration>`_ を参照されたい。

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
    * - | (2)
      - \ ``Cacheable``\アノテーションをキャッシュ対象の参照メソッドへ付与する。

        属性key(キャッシュキー)を設定する。この例では、文字列引数(customerNo)の値にプレフィックス'member/'を付けてキーにしている。例えば customerNo=000001 の場合、キャッシュキーは「member/000001」となり、キャッシュされる値はメソッドの戻り値となる。

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
          ShardingAccount findOne(String id);
        }

      .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
      .. list-table::
        :header-rows: 1
        :widths: 10 90

        * - 項番
          - 説明
        * - | (1)
          - \ ``Cacheable``\アノテーションの属性\ ``key``\で設定している、\ ``#a0``\がメソッド\ ``findOne``\の引数0番目(id)を指定している。

            詳細は `Springのリファレンス Available caching SpEL evaluation context <https://docs.spring.io/spring/docs/4.3.5.RELEASE/spring-framework-reference/html/cache.html#cache-spel-context>`_ を参照されたい。

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
    * - | (2)
      - \ :ref:`cache-data-regist`\で説明したキャッシュデータを登録または参照するメソッド定義。
    * - | (3)
      - \ ``CacheEvict``\アノテーションをキャッシュ対象の更新メソッドへ付与する。

        属性key(キャッシュキー)を設定する。この例では、引数であるMemberオブジェクトのフィールド(customerNo)の値にプレフィックス'member/'を付けてキーにしている。例えば customerNo=000001 の場合、キャッシュキーは「member/000001」となり、(2)でキャッシュされたキーを同じになるため、(2)でキャッシュされた値を削除する。

  .. warning::
    トランザクショナルなDBの値をキャッシュデータにしている場合は、DBの値更新時に完全なデータの同期が出来ない事に注意が必要である。

    DBの値が更新され、コミットされてからキャッシュデータが削除されるまでの間のデータ参照は古いキャッシュデータが参照される。



注意事項
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
- ローカルヒープ領域を利用した場合は、キャッシュが共有される範囲は同一のDIコンテナ内のみである。
- 特にローカルヒープ領域をキャッシュ格納場所に使用する場合は、キャッシュ対象データのサイズに注意すること。ヒープサイズに見合わない量のデータをキャッシュした場合、パフォーマンスが低下したりメモリ不足に陥る可能性がある。そのような場合には、ローカルヒープ領域外を格納場所として使用するなどを検討すること。

.. raw:: latex

   \newpage
