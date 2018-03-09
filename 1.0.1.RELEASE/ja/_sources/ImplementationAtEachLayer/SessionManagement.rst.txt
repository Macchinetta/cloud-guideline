セッション外部管理
================================================================================

.. only:: html

 .. contents:: 目次
    :depth: 3
    :local:

Overview
--------------------------------------------------------------------------------

クラウド環境でオートスケーリングを利用した場合に、スケールイン発生時にセッションなどのアプリケーションサーバインスタンス固有の情報は失われてしまう。
その為、ロードバランサによるロードバランシングにおいてスティッキーセッションはOFFとし、アプリケーションの構造としてどのアプリケーションサーバインスタンスに
リクエストが割り振られた場合でも業務継続可能とする為のセッション外部管理方式を示す。

|

.. _session-management-label:

セッション外部管理方式
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

セッション外部管理を行うために、\ `Spring Session with Redis <http://docs.spring.io/spring-session/docs/1.3.1.RELEASE/reference/html5/#httpsession-redis>`_\を利用した方式を以下に示す。
Redis構成は、ユーザ数（同時セッション数）が後々スケールできるようシャーディングを用いた構成で紹介している。


.. figure:: ./imagesSessionManagement/SessionManagementOverview.png
   :alt: Screen image of Session Mamanagement.
   :width: 100%

.. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
.. list-table::
 :header-rows: 1
 :widths: 10 90

 * - 項番
   - 説明
 * - | (1)
   - | ユーザは、同一のセッションIDでアクセスを行う。
 * - | (2)
   - | \ ``SessionRepositoryFilter``\はセッションをラップする。
 * - | (3)
   - | \ `Apache Tiles <https://tiles.apache.org/>`_\ と \ `Tomcat <https://tomcat.apache.org/index.html>`_\ の組み合わせを使用している場合は、\ ``SessionEnforcerFilter``\を使用する必要がある。\ ``SessionEnforcerFilter``\はセッションが存在しない場合は、セッションを作成してリクエストURLにリダイレクトする。セッションが存在する場合は何も実施しない。また、セッションが存在しない場合は、リダイレクトが強制的に発生するため、URLパターンを適切に設定する必要がある。
     | \ `spring-session/issues/571 <https://github.com/spring-projects/spring-session/issues/571>`_\対応
 * - | (4)
   - | アプリケーションで作成したコントローラからgetSessionメソッドなどで、セッションへのアクセスを行った場合に、ラップ済みのセッションを通じてセッションを取得する。
 * - | (5)
   - | ラップ済みのセッションは、ローカルサーバのキャッシュにセッション情報が存在しない時はRedisから取得する。一度アクセスを行うと、そのリクエストの間はローカルにセッション情報をキャッシュする。シャーディングされたRedisからの取得は、データに対してkeyのhashを計算して、該当するhash slotにアクセスして取得する。
 * - | (6)
   - | レスポンスがコミットされたタイミングでRedisにセッション情報を格納する。

|

.. warning::
   本ガイドラインで採用しているSpring Session 1.3.1.RELEASEを使用する場合、デフォルトではCookieを用いてセッションIDを参照する\ `CookieHttpSessionStrategy`\ が使用されるが、当該バージョンにはセッションIDを設定したCookieが複数ある場合に、いずれか一つしか採用されない不具合が存在する。そのため、path属性を用いて複数のセッションIDを使い分けるような使い方はできない。詳細はSpring Sessionのissue \ `CookieHttpSessionStrategy should look at all cookies not just the first <https://github.com/spring-projects/spring-session/issues/275>`_\ を参照されたい。

|

.. _session_management_constitution:

セッション外部管理構成
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
セッション外部管理を行う為の基本的な構成を以下に示す。

.. figure:: ./imagesSessionManagement/SessionManagementArchitectonics.png
 :alt: Screen image of Session management.
 :width: 100%

.. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
.. list-table::
 :header-rows: 1
 :widths: 10 90

 * - 項番
   - 説明
 * - | (1)
   - | ロードバランサのリクエスト振り分けはスティッキーセッションを使用せず、動的なスケーリンググループ内のAPサーバに対して均等に振り分ける。
 * - | (2)
   - | アプリケーションではSpring Session with Redisを介してセッションへのアクセスを行う。
 * - | (3)
   - | Spring Session with Redisは、Sharding Redis Clusterのいずれかのシャードに対してセッションの保存を行う。各シャードでは、可用性向上のための非同期のレプリケーションが行われる。

|

セッション同期タイミング
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
リクエスト中に、一度取得したセッション情報はキャッシュされていて、以降はキャッシュからセッション情報を取得する為、他のリクエストでのセッション情報への変更は反映されない。
Redisへ永続化を行うタイミングで各リクエストで行ったセッション情報の変更は上書きで保存されるため、後から永続化が行われたリクエストのセッション情報が反映される。

また、Redisへのセッションの永続化のタイミングは、デフォルトがレスポンスのコミット時となっている。


|

制約事項
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

 * セッションの外部管理を行った場合は、「\ `同一セッション内のリクエストの同期化 <https://macchinetta.github.io/server-guideline/1.5.1.RELEASE/ja/ArchitectureInDetail/WebApplicationDetail/SessionManagement.html#id25>`_\ 」のような方法でリクエストを同期化することができないため、セッション情報の完全な同期が必要なケースは、セッションで情報を管理しないこと。

    .. note::
     二重送信防止で、セッションを利用したトランザクショントークンチェックは、トランザクショントークンの変更が即座に同期されないため、リクエストのタイミングに因っては、意図した動作をしないケースが存在する。
     そのため、セッションの外部管理を行う場合は、セッションを利用したトランザクショントークンチェックの機能面で制限が発生する点に注意する。
     代替手段としては、トランザクショントークンの永続化先をデータベースに変更してロックを使用した排他制御を行うか、アプリケーションを冪等に実装して二重送信が発生しても問題がないようにするとよい（後者の場合は二重送防止処理自体が不要になる）。

     本ガイドラインでは、トランザクショントークンの永続化先をデータベースに変更する拡張方法について説明している。拡張方法については、 :ref:`extend-transactiontoken-label` を参照。

 * Spring Session with Redisは、Keyspace Notificationsを使用してセッション生成・破棄イベントをアプリケーションに通知することが出来る。
   イベント通知は全てのアプリケーションサーバに対して行われ、各サーバにおいて\ ``HttpSessionListener``\が実行されるため、\ ``HttpSessionListener``\は冪等に実装する必要がある。
   また、RedisはKeyspace NotificationsがOFFになっているので、破棄イベントを実装する場合はKeyspace NotificationsをONに設定する必要がある。
   詳細は、\ `SessionDeletedEvent and SessionExpiredEvent <http://docs.spring.io/spring-session/docs/1.3.1.RELEASE/reference/html5/#api-redisoperationssessionrepository-sessiondestroyedevent>`_\ を参照されたい。


 * Servlet仕様では、セッションIDを示すHTTP Cookieの名称は、「JSESSIONID」だが、Spring Sessionを使用した場合のデフォルトは「SESSION」となる。
   変更方法は、\ `Spring Session - Custom Cookie <http://docs.spring.io/spring-session/docs/1.3.1.RELEASE/reference/html5/guides/custom-cookie.html>`_\を参照されたい。

|

Redis Clusterの一貫性保証
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
:ref:`session_management_constitution` で説明したとおり、Redis Clusterにおける各シャードでは、マスターノードからスレーブノードへの非同期のレプリケーションが行われている。
以下の条件を満たす場合、データの書き込み完了をクライアントに通知したにもかかわらず、データを失う可能性がある。

#. クライアントがマスタノードへの書き込み要求を行う。
#. マスターノードは書き込み処理を行い、書き込み完了をクライアントに通知する。
#. マスターノードからスレーブノードへのレプリケーションが完了する前にマスターノードがダウンする。
#. スレーブノードがマスターノードへ昇格する。

この時、レプリケーションされなかったデータについては消失することになる。
また、クライアントが書き込み要求を行っているマスターノードがシャードから分断された場合についても書き込み要求を行っていたノードのダウンが発生するため、レプリケーションが行われなかったデータは消失する。

Redis Clusterを使用したセッションの外部管理を行う場合は、データ消失の可能性がある点に留意すること。

より詳しい情報は、\ `Redis Cluster consistency guarantees <https://redis.io/topics/cluster-tutorial#redis-cluster-consistency-guarantees>`_\を参照されたい。

|

How to use
--------------------------------------------------------------------------------

\ `Spring Session with Redis <http://docs.spring.io/spring-session/docs/1.3.1.RELEASE/reference/html5/#httpsession-redis>`_\の利用方法を示す。

|

依存ライブラリの追加
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

セッション外部管理では、\ `Spring Session with Redis <http://docs.spring.io/spring-session/docs/1.3.1.RELEASE/reference/html5/#httpsession-redis>`_\を使用するための依存ライブラリを追加する必要がある。
定義方法は、以下を参照されたい。

- :file:`pom.xml`

 .. code-block:: xml

   <dependencies>
           <!-- (1) -->
           <dependency>
                   <groupId>org.springframework.session</groupId>
                   <artifactId>spring-session</artifactId>
           </dependency>
           <!-- (2) -->
           <dependency>
                   <groupId>org.springframework.boot</groupId>
                   <artifactId>spring-boot-starter-data-redis</artifactId>
           </dependency>
   </dependencies>


 .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
 .. list-table::
   :header-rows: 1
   :widths: 10 90

   * - 項番
     - 説明
   * - | (1)
     - | 依存ライブラリに\ ``spring-session``\を追加する。
   * - | (2)
     - | 依存ライブラリに\ ``spring-boot-starter-data-redis``\を追加する。

|

.. _springSessionRepositoryFilter-label:

Spring Sessionの設定
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

セッション外部管理を行うために、\ `Spring Session with Redis <http://docs.spring.io/spring-session/docs/1.3.1.RELEASE/reference/html5/#httpsession-redis>`_\を利用する。

- :file:`application.yml`

 .. code-block:: yaml

   
   spring:
     session:
       # (1)
       store-type: redis
       # (2)
       timeoutSecond: 1800

     # (3)
     redis:
       listener:
         concurrencyLimit: 2


 .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
 .. list-table::
   :header-rows: 1
   :widths: 10 90

   * - 項番
     - 説明
   * - | (1)
     - | \ ``spring.session.store-type``\にredisを指定する。
   * - | (2)
     - | セッションタイムアウトまでの時間を秒で設定する。ここでは、セッションタイムアウトまでの時間を1800秒(30分)に設定している。
   * - | (3)
     - | \ ``spring.redis.listener.concurrencyLimit``\にSubscribe処理の際に使用するスレッドの上限を設定する。

| 

- :file:`application-context.xml`

 .. code-block:: xml

   <!-- (1) -->
   <context:annotation-config/>
   <bean class="org.springframework.session.data.redis.config.annotation.web.http.RedisHttpSessionConfiguration">
      <!-- (2) -->
      <property name="maxInactiveIntervalInSeconds" value="${spring.session.timeoutSecond}"/>
   </bean>


 .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
 .. list-table::
   :header-rows: 1
   :widths: 10 90

   * - 項番
     - 説明
   * - | (1)
     - | \ ``<context：annotation-config />``\と\ ``RedisHttpSessionConfiguration``\の組み合わせで、\ ``springSessionRepositoryFilter``\のという名前のSpring Beanを作成する。
   * - | (2)
     - | \ ``RedisHttpSessionConfiguration``\ の \ ``maxInactiveIntervalInSeconds``\ に\ ``application.yml``\ で設定したセッションタイムアウトまでの時間を設定する。

|

- :file:`xxx-env.xml`

 .. code-block:: xml

   <!-- (1) -->
    <bean id="springSessionRedisTaskExecutor" class="org.springframework.core.task.SimpleAsyncTaskExecutor">
        <property name="concurrencyLimit" value="${spring.redis.listener.concurrencyLimit}" />
    </bean>


 .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
 .. list-table::
   :header-rows: 1
   :widths: 10 90

   * - 項番
     - 説明
   * - | (1)
     - | \ ``RedisMessageListenerContainer``\が使用する\ ``TaskExecutor``\ のBean定義を行う。

 .. note::
  \ ``RedisMessageListenerContainer``\は、Subscribe処理の際に\ ``springSessionRedisTaskExecutor``\ のBean名で定義された\ ``TaskExecutor``\ を使用し、Redis上のデータへアクセスを行う。
  デフォルトで使用される\ ``SimpleAsyncTaskExecutor``\ はSubscribeの都度、無制限に新規にスレッドを作成し、Redisのコネクションを取得するため、作成されるスレッド数を制限しておくことを推奨する。
  上記の例では、デフォルトで使用される\ ``SimpleAsyncTaskExecutor``\ に対して\ ``concurrencyLimit``\ を設定することで、作成されるスレッド数に上限を設定している。

|

- :file:`web.xml`

 .. code-block:: xml

   <!-- (1) -->
   <filter>
       <filter-name>springSessionRepositoryFilter</filter-name>
       <filter-class>org.springframework.web.filter.DelegatingFilterProxy</filter-class>
   </filter>
   <filter-mapping>
       <filter-name>springSessionRepositoryFilter</filter-name>
       <url-pattern>/*</url-pattern>
       <dispatcher>REQUEST</dispatcher>
       <dispatcher>ERROR</dispatcher>
   </filter-mapping>
   
   ・・・
   
   <session-config>
      ...
     
      <!-- (2) -->
      <session-timeout>30</session-timeout>
     
      ...
    </session-config>


 .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
 .. list-table::
   :header-rows: 1
   :widths: 10 90

   * - 項番
     - 説明
   * - | (1)
     - | \ ``DelegatingFilterProxy``\を使用して\ ``springSessionRepositoryFilter``\を登録する。また、セッションが存在しない状態でフィルタを通過する前にエラーが発生した場合にも\ ``springSessionRepositoryFilter``\ が適用されるよう、\ ``dispatcher``\ に\ ``ERROR``\ も設定する。設定については、\ `XML Servlet Container Initialization <http://docs.spring.io/spring-session/docs/1.3.1.RELEASE/reference/html5/guides/httpsession-xml.html#xml-servlet-container-initialization>`_\を参照されたい。
   * - | (2)
     - | セッションタイムアウトの時間は、\ ``RedisHttpSessionConfiguration``\で設定しているので、 \ ``web.xml``\ に \ ``session-timeout``\ 項目があれば、削除する。

 .. note::
  \ ``dispatcher``\ に指定する値はシステム要件に応じて全てのリクエストに対して\ ``springSessionRepositoryFilter``\ が適用されるよう設定すること。
  例えば、JSPのincludeを行っている場合は\ ``dispatcher``\ に\ ``INCLUDE``\ を追加する必要がある。

 .. note::
  \ ``DelegatingFilterProxy``\ は\ ``filter-name``\ で指定した名前(上記の例では\ ``springSessionRepositoryFilter``\ )でDIコンテナからBeanを取得して、処理を委譲する。対象のBeanは\ ``Filter``\ を実装する必要がある。Springの下で統一的に\ ``Filter``\ が管理でき、コンテナ上の各種Beanを利用して\ ``Filter``\ が実装できるなどのメリットがある。

 .. warning::
  \ ``springSessionRepositoryFilter``\の登録順序は、\ ``HttpSession``\を使用する他の ``Filter``\より前に登録する必要がある。

|

Apache TilesとTomcatの組み合わせでレスポンスにCookieが設定されない問題の対応
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
| Spring Sessionを使用する際に、\ `Apache Tiles <https://tiles.apache.org/>`_\ と \ `Tomcat <https://tomcat.apache.org/index.html>`_\ の組み合わせでアプリケーションを作成している場合に、レスポンスにCookieが設定されない問題に対応する必要がある。
| この問題に対する詳細は、\ `spring-session/issues/571 <https://github.com/spring-projects/spring-session/issues/571>`_\を参照されたい。



|

SessionEnforcerFilter の作成および設定
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
SessionEnforcerFilter の作成および設定方法を以下に示す。

- :file:`SessionEnforcerFilter.java`

 .. code-block:: java

   public class SessionEnforcerFilter extends OncePerRequestFilter {

      ...
      
      private RequestMatcher excludeUseSessionRequestMathcer;
      
      public void setRequestMathcer(RequestMatcher excludeUseSessionRequestMathcer) { //(1)
        this.excludeUseSessionRequestMathcer = excludeUseSessionRequestMathcer;
      }

      @Override
      protected void doFilterInternal(HttpServletRequest request, 
                                      HttpServletResponse response,
                                      FilterChain chain)
                                      throws ServletException, IOException {
         
         HttpServletRequest httpServletRequest = request;
         HttpServletResponse httpServletResponse = response;

         if (this.excludeRequestMatcher != null
                 && this.excludeRequestMatcher.matches(httpServletRequest)) {
             chain.doFilter(httpServletRequest, response);
             return;
         }

         if (httpServletRequest.getRequestedSessionId() == null
                 && httpServletRequest.getMethod().toUpperCase().equals("GET")) {

             httpServletRequest.getSession(); //(2)

             StringBuilder requestURI = new StringBuilder(httpServletRequest.getRequestURI());
             if (httpServletRequest.getQueryString() != null) {
                 requestURI.append("?").append(httpServletRequest.getQueryString());
             }

             httpServletResponse.sendRedirect(requestURI.toString()); //(3)
         } else {
             chain.doFilter(httpServletRequest, response);
         }

       ...

   }

 .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
 .. list-table::
   :header-rows: 1
   :widths: 10 90

   * - 項番
     - 説明 
   * - | (1)
     - | \ ``SessionEnforcerFilter``\ を適用しないpathを設定する。
   * - | (2)
     - | セッションIDが送信されず、HTTPリクエストがGETの場合に、 \ ``HttpSession``\を強制的に作成する。セッションIDが不正な場合や、タイムアウトしたセッションは、後続のフィルターで適切な処理を別途行う必要がある。 詳細は、:ref:`Warning <session-management-session-enforcerfilter-label>` を参照されたい。
   * - | (3)
     - | リクエストを受け付けたパスでリダイレクト実施する。

|

- :file:`application-context.xml`

 .. code-block:: xml

   <!-- (1) -->
   <bean id="sessionEnforcerFilter"
       class="com.example.xxx.app.common.session.SessionEnforcerFilter">
       <!-- (2) -->
       <property name="excludeRequestMatcher" ref="excludeEnforceSessionRequestMatcher"/>
   </bean>
   
   <!-- (3) -->
   <bean id="excludeEnforceSessionRequestMatcher"
       class="org.springframework.security.web.util.matcher.AntPathRequestMatcher">
       <constructor-arg value="/health/**"/>
   </bean>


 .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
 .. list-table::
   :header-rows: 1
   :widths: 10 90

   * - 項番
     - 説明
   * - | (1)
     - | \ ``sessionEnforcerFilter``\を Bean定義する。
   * - | (2)
     - | \ ``sessionEnforcerFilter``\ を適用しないパス設定を行ったBeanを\ ``sessionEnforcerFilter``\に設定する。
   * - | (3)
     - | \ ``sessionEnforcerFilter``\ を適用しないパス設定をBean定義する。設定例では、 :doc:`./HealthCheck` と併用時に、リダイレクトによって死活監視が正常に実施できなくなることを防止するため、ヘルスチェックURL以外にフィルタを適用する為のURLパターンを設定している。

|

- :file:`web.xml`

 .. code-block:: xml

   <!-- (1) -->
    <filter>
        <filter-name>sessionEnforcerFilter</filter-name>
        <filter-class>org.springframework.web.filter.DelegatingFilterProxy</filter-class>
    </filter>
    <filter-mapping>
        <filter-name>sessionEnforcerFilter</filter-name>
        <url-pattern>/*</url-pattern>
        <dispatcher>REQUEST</dispatcher>
        <dispatcher>ERROR</dispatcher>
    </filter-mapping>


 .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
 .. list-table::
   :header-rows: 1
   :widths: 10 90

   * - 項番
     - 説明
   * - | (1)
     - | \ ``sessionEnforcerFilter``\を :ref:`springSessionRepositoryFilter-label` で登録した\ ``springSessionRepositoryFilter``\の直後に登録する。
     
|

    .. note::

      本ガイドラインで紹介している\ ``SessionEnforcerFilter``\はセッションが存在しない場合に、セッションを作成してリクエストURLにリダイレクトする実装を行うことで問題に対応している。
      リダイレクトを強制的に発生させているため、システム要件に応じて使用するURLパターンとリダイレクト先のURL不整合が生じないよう留意する必要がある。
    
    .. _session-management-session-enforcerfilter-label:

    .. warning::
     \ ``SessionEnforcerFilter``\を使用する場合は、セッションIDが不正の場合や、セッションがタイムアウトしている可能性があるため、Spring Securityなどで別途セッションタイムアウト検知、CSRF対策を行うことが必要である。Spring Securityでセッションタイムアウト検知を行う設定方法は、 `無効なセッションを使ったリクエストの検知 <https://macchinetta.github.io/server-guideline/1.5.1.RELEASE/ja/Security/SessionManagement.html#springsecuritysessiondetectinvalidsession>`_ 、CSRF対策を行う設定方法は、`CSRF対策 <https://macchinetta.github.io/server-guideline/1.5.1.RELEASE/ja/Security/CSRF.html>`_ を参照されたい。

.. _spring-data-redis-setting-label:

Spring Data Redisの設定
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
\ ``spring-boot-starter-data-redis``\を使用している為、基本的な設定はAutoConfigurationにて行われる。
詳細な設定については、Spring Boot Reference Guideの \ `Common application properties <https://docs.spring.io/spring-boot/docs/1.5.7.RELEASE/reference/html/common-application-properties.html#common-application-properties>`_\ の# REDIS (RedisProperties)を参照されたい。

|

.. _session-management-endpoint-label:

エンドポイントの設定
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
エンドポイント設定は、Spring Data Redisの設定にて定義する。
詳細は、\ `Redis Cluster <http://docs.spring.io/spring-data/redis/docs/1.8.7.RELEASE/reference/html/#cluster>`_\を参照されたい。


- :file:`application.yml`

 .. code-block:: yaml

   spring:
     redis:
       cluster:
         # (1)
         nodes:
           - 127.0.0.1:30001
           - 127.0.0.1:30002
           - 127.0.0.1:30003

|

 .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
 .. list-table::
   :header-rows: 1
   :widths: 10 90

   * - 項番
     - 説明
   * - | (1)
     - | \ ``spring.redis.cluster.nodes``\にすべてのノードを追加する。
         詳細は、\ `Enabling Redis Cluster <http://docs.spring.io/spring-data/redis/docs/1.8.7.RELEASE/reference/html/#_enabling_redis_cluster>`_\を参照されたい。


|

クラウドベンダーの利用
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

クラウドベンダー提供の環境を利用する場合のガイドラインについて記載箇所を示しておく。

Amazon Web Service
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

クラウドベンダーとしてAWSを使用する場合のセッション外部管理については、
:doc:`../AWSCollaboration/SessionManagement`
を参照されたい。

How to extend
--------------------------------------------------------------------------------

本ガイドラインでは、拡張方法や応用的な使用方法を示す。

|

セッション永続化タイミングの変更
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

セッション永続化のタイミングは、デフォルトでレスポンスのコミット時になっているが、以下の様に定義することで\ ``setAttribute``\ および\ ``removeAttribute``\ メソッド呼び出し時に変更することができる。


- :file:`application.yml`

 .. code-block:: yaml

   spring:
     session:
       redis:
         flush-mode: immediate #(1)

|

 .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
 .. list-table::
   :header-rows: 1
   :widths: 10 90

   * - 項番
     - 説明
   * - | (1)
     - | \ ``spring.session.redis.flush-mode``\に\ ``immediate``\を設定する。デフォルトは、\ ``on-save``\となっている。


 .. warning::
   \ ``immediate``\を設定する際の注意事項を以下に示す。

    * \ ``setAttrubute``\ の実行回数が多い場合は、頻繁にIOが発生するため性能に影響が出る。
    * \ ``setAttrubute``\ が複数実行される処理に並行し、readしている人が別にいた場合に、変更途中のセッションが読まれてしまう可能性が高まる。
    * \ ``getAttribute``\ を使用して取得したオブジェクトに対する変更を行っても永続化は行われない。ただし、他の属性に対する\ ``setAttribute``\ および\ ``removeAttribute``\ メソッド実行時に全てのセッション情報が永続化される。

 .. note::
   \ ``immediate``\を設定している場合でも、レスポンスのコミット時の永続化は行われる。

|

HttpSessionListenerを利用する場合の設定方法
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
HttpSessionListenerを使用する場合の設定方法を以下に示す。詳細は、\ `HttpSessionListener <http://docs.spring.io/spring-session/docs/1.3.1.RELEASE/reference/html5/#httpsession-httpsessionlistener>`_\を参照されたい。

- :file:`applicationContext.xml`

 .. code-block:: xml

   <!-- (1) -->
   <bean class="org.terasoluna.gfw.web.logging.HttpSessionEventLoggingListener" />

|

 .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
 .. list-table::
   :header-rows: 1
   :widths: 10 90

   * - 項番
     - 説明
   * - | (1)
     - | 使用する\ ``HttpSessionListener``\をBean定義する。

|

.. _extend-transactiontoken-label:

TransactionTokenの拡張方法
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
|base_framework_name| Development Guideline `4.5. 二重送信防止 <https://macchinetta.github.io/server-guideline/1.5.1.RELEASE/ja/ArchitectureInDetail/WebApplicationDetail/DoubleSubmitProtection.html#id1>`_ にて説明しているトランザクショントークンチェックについて、共通ライブラリから提供しているトランザクショントークンチェック機能はトークン情報の格納先をセッションとしている。
そのため、Spring Sessionによるセッションの外部管理を行う場合、セッションの同期化を行うことができないことにより二重送信を防止できないケースがある。
本ガイドラインでは、MyBatis3を使用してトークン情報の格納先をデータベースへ変更する拡張方法について説明する。

実装が必要な要素は以下のとおり。

* トランザクショントークン情報を格納するテーブル
* DBアクセスを行うRepositoryインタフェースおよびマッピングファイル
* トランザクショントークン情報の生成およびテーブルへの格納を行う\ ``TransactionTokenStore``\インターフェースの実装クラス
* セッション破棄時にトランザクショントークン情報の削除を行う\ ``EventListener``\クラス
* アプリケーションから利用するためのBean定義

テーブル構成例
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

本ガイドラインで紹介する拡張方法では、以下のようなテーブルにトランザクショントークン情報を格納する実装を行う。

- :file:`createtable.sql`

 .. code-block:: sql

    create table transaction_token (
        token_name varchar(256) not null,
        token_key varchar(32) not null,
        token_value varchar(32) not null,
        session_id  varchar(256) not null,
        sequence bigint,
        constraint pk_transaction_token primary key (token_name, token_key, session_id)
    );

    create index transaction_token_index_delete_older on transaction_token(token_name, session_id);
    create index transaction_token_index_delete_older_sequence on transaction_token(sequence);
    create index transaction_token_index_clean on transaction_token(session_id);

    create sequence transaction_token_sequence;

Repositoryインタフェースおよびマッピングファイル
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

DBアクセスを行うRepositoryインタフェースおよびマッピングファイルを作成する。

- :file:`StoredTransactionTokenRepository.java`

 .. code-block:: java

    public interface StoredTransactionTokenRepository {

        // (1)
        StoredTransactionToken findOneForUpdate(@Param("tokenName") String tokenName, @Param("tokenKey") String tokenKey, @Param("sessionId") String sessionId);

        // (2)
        void delete(@Param("tokenName") String tokenName, @Param("tokenKey") String tokenKey, @Param("sessionId") String sessionId);

        // (3)
        void insert(StoredTransactionToken token);

        // (4)
        void deleteOlderThanLatest(@Param("tokenName") String tokenName, @Param("sessionId") String sessionId, @Param("num") int num);

        // (5)
        void deleteBySessionId(@Param("sessionId") String sessionId);
    }

 .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
 .. list-table::
   :header-rows: 1
   :widths: 10 90

   * - 項番
     - 説明
   * - | (1)
     - | トークン名およびトークンキーを元にレコードを取得するメソッド。
       | \ ``StoredTransactionToken``\は、テーブル構成に対応するEntityクラスである。
   * - | (2)
     - | トークン名およびトークンキーを元にレコードを削除するメソッド。
   * - | (3)
     - | レコードを1件挿入するメソッド。
   * - | (4)
     - | トークン名およびセッションIDを元に、タイムスタンプ降順で指定件数以降のレコードを削除するメソッド。
   * - | (5)
     - | セッション破棄時に、セッションIDに紐づくレコードを削除するメソッド。

- :file:`StoredTransactionTokenRepository.xml`

 .. code-block:: xml

    <mapper namespace="com.example.domain.repository.StoredTransactionTokenRepository">

            <resultMap id="storedTransactionTokenresultMap" type="StoredTransactionToken">
                <id property="tokenName" column="token_name" />
                <id property="tokenKey" column="token_key" />
                <result property="tokenValue" column="token_value" />
                <result property="sessionId" column="session_id" />
                <result property="sequence" column="sequence" />
            </resultMap>

            <!-- (1) -->
            <select id="findOneForUpdate" resultMap="storedTransactionTokenresultMap">
                <![CDATA[
                    SELECT
                        token_name,
                        token_key,
                        token_value,
                        session_id,
                        sequence
                    FROM
                        transaction_token
                    WHERE
                        token_name = #{tokenName}
                    AND
                        token_key = #{tokenKey}
                    AND
                        session_id = #{sessionId}
                    FOR UPDATE
                ]]>
            </select>

            <!-- (2) -->
            <delete id="delete">
                <![CDATA[
                    DELETE FROM transaction_token
                    WHERE
                        token_name = #{tokenName}
                    AND
                        token_key = #{tokenKey}
                    AND
                        session_id = #{sessionId}
                ]]>
            </delete>

            <!-- (3) -->
            <insert id="insert" parameterType="StoredTransactionToken">
                <![CDATA[
                    INSERT INTO transaction_token
                    (
                        token_name,
                        token_key,
                        token_value,
                        session_id,
                        sequence
                    )
                    VALUES
                    (
                        #{tokenName},
                        #{tokenKey},
                        #{tokenValue},
                        #{sessionId},
                        nextval('transaction_token_sequence')
                    )
                ]]>
            </insert>

            <!-- (4) -->
            <delete id="deleteOlderThanLatest">
                <![CDATA[
                    DELETE FROM transaction_token
                    WHERE sequence IN (
                    SELECT sequence FROM transaction_token
                    WHERE
                        token_name = #{tokenName}
                    AND
                        session_id = #{sessionId}
                    ORDER BY sequence DESC
                    OFFSET #{num}
                    )
                ]]>
            </delete>

            <!-- (5) -->
            <delete id="deleteBySessionId">
                <![CDATA[
                    DELETE FROM transaction_token
                    WHERE
                        session_id = #{sessionId}
                ]]>
            </delete>
    </mapper>

 .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
 .. list-table::
   :header-rows: 1
   :widths: 10 90

   * - 項番
     - 説明
   * - | (1)
     - | \ ``findOneForUpdate``\メソッドに対応するSQL。
       | SELECT FOR UPDATEを使用し、ロックを取得することでトランザクショントークンのチェック処理に対して排他制御を行う。
   * - | (2)
     - | \ ``delete``\メソッドに対応するSQL。
   * - | (3)
     - | \ ``insert``\メソッドに対応するSQL。
   * - | (4)
     - | \ ``deleteOlderThanLatest``\メソッドに対応するSQL。
   * - | (5)
     - | \ ``deleteBySessionId``\メソッドに対応するSQL。

TransactionTokenStoreの実装
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

トークン情報の格納を行う\ ``TransactionTokenStore``\インターフェースの実装クラスを作成する。
実装する各メソッドの役割については、\ `TransactionTokenStore <https://github.com/terasolunaorg/terasoluna-gfw/blob/release/5.4.1.RELEASE/terasoluna-gfw-common-libraries/terasoluna-gfw-web/src/main/java/org/terasoluna/gfw/web/token/transaction/TransactionTokenStore.java>`_\インターフェースを参照のこと。

- :file:`MyBatisTransactionTokenStore.java`

 .. code-block:: java

    public class MyBatisTransactionTokenStore implements TransactionTokenStore {

        @Inject
        StoredTransactionTokenRepository tokenRepository;

        @Inject
        JodaTimeDateFactory dateFactory;

        private final int transactionTokenSizePerTokenName;

        private final TokenStringGenerator generator;

        public MyBatisTransactionTokenStore(int transactionTokenSizePerTokenName, TokenStringGenerator generator) {
            this.transactionTokenSizePerTokenName = transactionTokenSizePerTokenName;
            this.generator = generator;
        }

        public MyBatisTransactionTokenStore(int transactionTokenSizePerTokenName) {
            this(transactionTokenSizePerTokenName, new TokenStringGenerator());
        }

        public MyBatisTransactionTokenStore() {
            this(10, new TokenStringGenerator());
        }

        @Override
        @Transactional(propagation = Propagation.REQUIRES_NEW)
        public String getAndClear(TransactionToken transactionToken) { // (1)
            String name = transactionToken.getTokenName();
            String key = transactionToken.getTokenKey();
            String sessionId = getSession().getId();

            try {
                StoredTransactionToken token = tokenRepository.findOneForUpdate(name, key, sessionId);
                if (token == null) {
                    return null;
                }

                tokenRepository.delete(name, key, sessionId);
                return token.getTokenValue();
            } catch (PessimisticLockingFailureException e) {
            }
            return null;
        }

        @Override
        @Transactional(propagation = Propagation.REQUIRES_NEW)
        public void remove(TransactionToken transactionToken) { // (2)
            String name = transactionToken.getTokenName();
            String key = transactionToken.getTokenKey();
            String sessionId = getSession().getId();
            tokenRepository.delete(name, key, sessionId);
        }

        @Override
        @Transactional(propagation = Propagation.REQUIRES_NEW)
        public String createAndReserveTokenKey(String tokenName) { // (3)
            String sessionId = getSession().getId();
            tokenRepository.deleteOlderThanLatest(tokenName, sessionId, transactionTokenSizePerTokenName - 1);
            return generator.generate(UUID.randomUUID().toString());
        }

        @Override
        @Transactional(propagation = Propagation.REQUIRES_NEW)
        public void store(TransactionToken transactionToken) { // (4)
            StoredTransactionToken token = new StoredTransactionToken();
            token.setTokenName(transactionToken.getTokenName());
            token.setTokenKey(transactionToken.getTokenKey());
            token.setTokenValue(transactionToken.getTokenValue());
            token.setSessionId(getSession().getId());
            tokenRepository.insert(token);

            getSession();
        }

        HttpSession getSession() {
            return getRequest().getSession(true);
        }

        HttpServletRequest getRequest() {
            return ((ServletRequestAttributes) RequestContextHolder
                    .currentRequestAttributes()).getRequest();
        }
    }

 .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
 .. list-table::
   :header-rows: 1
   :widths: 10 90

   * - 項番
     - 説明
   * - | (1)
     - | \ ``getAndClear``\メソッドを実装する。
       | データベースに格納したトランザクショントークン情報のレコードをロックした上で取得し、トランザクショントークン情報をデータベースから削除する。
       | 当該メソッドはトランザクショントークンチェック時に動作し、チェックに使用するレコードをロックして排他制御を行うことで、同一のトランザクショントークン情報が複数回使用されないことを保証する。
   * - | (2)
     - | \ ``remove``\メソッドを実装する。
       | 当該メソッドは\ ``@TransactionTokenCheck``\を付与したメソッド終了後に動作し、トランザクショントークン情報の削除を行う。
   * - | (3)
     - | \ ``createAndReserveTokenKey``\メソッドを実装する。
       | 当該メソッドは\ ``@TransactionTokenCheck``\を付与したメソッド終了後に動作し、次回チェック用のトランザクショントークン情報の生成を行うとともに、トークン名およびセッションIDに紐づく古い世代のレコードを削除する。
   * - | (4)
     - | \ ``store``\メソッドを実装する。
       | 当該メソッドはトランザクショントークン情報のデータベースへの格納を行う。
       | セッションが無効になった際に格納されたトランザクショントークン情報の削除を行うため、INSERTを行った後にセッションを取得し、\ ``ApplicationEvent``\による通知を行う。


HttpSessionListenerの実装
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

セッション破棄時の\ ``HttpSessionDestroyedEvent``\を検知してトランザクショントークン情報の削除を行う\ ``EventListener``\クラスを作成する。

- :file:`TransactionTokenCleaningListener.java`

 .. code-block:: java

    public class TransactionTokenCleaningListener {

        private static final Logger logger = LoggerFactory.getLogger(TransactionTokenCleaningListener.class);

        @Inject
        StoredTransactionTokenRepository tokenRepository;

        @EventListener // (1)
        @Transactional
        public void sessionDestroyed(HttpSessionDestroyedEvent event) {
            String sessionId = event.getSession().getId();
            try {
                tokenRepository.deleteBySessionId(sessionId);
                logger.info("Transaction tokens created by sessionId={} have been cleaned.", sessionId);
            } catch (DataAccessException e) {
                logger.warn("Failed to clean abandoned transaction tokens created by sessionId={}.", sessionId, e);
                // ignore
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
     - | \ ``@EventListener``\アノテーションを付与し、セッション破棄時にPublishされる\ ``HttpSessionDestroyedEvent``\を検知してセッションIDによるトランザクショントークン情報の削除を行うメソッドを実装する。

アプリケーションでの利用方法
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
本ガイドラインで紹介する拡張方法を使用した場合においても、ControllerやJSPからの利用方法は同一である。詳細は、`トランザクショントークンチェックのControllerでの利用方法 <https://macchinetta.github.io/server-guideline/1.5.1.RELEASE/ja/ArchitectureInDetail/WebApplicationDetail/DoubleSubmitProtection.html#controller>`_ および `トランザクショントークンチェックのView(JSP)での利用方法 <https://macchinetta.github.io/server-guideline/1.5.1.RELEASE/ja/ArchitectureInDetail/WebApplicationDetail/DoubleSubmitProtection.html#view-jsp>`_ を参照されたい。

本ガイドラインでは、アプリケーションから利用するためのBean定義方法について説明する。

|base_framework_name| Development Guideline `4.5.2.3.5. トランザクショントークンチェックを使用するための設定 <https://macchinetta.github.io/server-guideline/1.5.1.RELEASE/ja/ArchitectureInDetail/WebApplicationDetail/DoubleSubmitProtection.html#setting>`_ にて説明している、\ ``HandlerInterceptor``\の設定について、\ ``TransactionTokenInterceptor``\で使用される\ ``TransactionTokenStore``\の実装クラスが作成した\ ``MyBatisTransactionTokenStore``\となるようBean定義を行う。

- :file:`spring-mvc.xml`

 .. code-block:: xml

    <mvc:interceptor>
        <mvc:mapping path="/**" />
        <mvc:exclude-mapping path="/resources/**" />
        <mvc:exclude-mapping path="/**/*.html" />
        <bean
            class="org.terasoluna.gfw.web.token.transaction.TransactionTokenInterceptor">
            <!-- (1) -->
            <constructor-arg index="0">
                <bean class="org.terasoluna.gfw.web.token.TokenStringGenerator" />
            </constructor-arg>
            <constructor-arg index="1">
                <bean class="org.terasoluna.gfw.web.token.transaction.TransactionTokenInfoStore" />
            </constructor-arg>
            <constructor-arg index="2">
                <bean class="com.example.token.MyBatisTransactionTokenStore" />
            </constructor-arg>
        </bean>
    </mvc:interceptor>

 .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
 .. list-table::
   :header-rows: 1
   :widths: 10 90

   * - 項番
     - 説明
   * - | (1)
     - | \ ``TransactionTokenInterceptor``\のコンストラクタとして、\ ``TokenStringGenerator``\、\ ``TransactionTokenInfoStore``\および作成した\ ``MyBatisTransactionTokenStore``\を指定する。

\ `HttpSessionListener`\によるトークン削除を有効化するため、以下の設定を行う。

- :file:`applicationContext.xml`

 .. code-block:: xml

    <!-- (1) -->
    <bean id="transactionTokenCleaningListener" class="com.example.token.TransactionTokenCleaningListener" />

 .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
 .. list-table::
   :header-rows: 1
   :widths: 10 90

   * - 項番
     - 説明
   * - | (1)
     - | 作成した\ ``TransactionTokenCleaningListener``\のBean定義を行う。

.. raw:: latex

   \newpage
