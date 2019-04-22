オンライン版クラウド拡張開発プロジェクトの作成
================================================================================

.. only:: html

 .. contents:: 目次
    :depth: 3
    :local:

|

本ガイドラインでは、クラウドネイティブなアプリケーション向けの開発プロジェクトを作成する方法について説明する。

|base_framework_name| の `マルチプロジェクト構成のブランクプロジェクト <https://github.com/Macchinetta/macchinetta-web-multi-blank>`_
を元に、カスタマイズを加えることで作成する。

|

.. _create_project_blankpj:

開発プロジェクトの作成
--------------------------------------------------------------------------------

開発プロジェクトの作成方法は、
|base_framework_name| Development Guideline `開発プロジェクトの作成 <https://macchinetta.github.io/server-guideline/1.5.2.RELEASE/ja/ImplementationAtEachLayer/CreateWebApplicationProject.html#createwebapplicationproject>`_
を参照されたい。

.. _create_project_customize:

開発プロジェクトのカスタマイズ
--------------------------------------------------------------------------------

:ref:`create_project_blankpj` で作成したプロジェクトを
クラウドネイティブなアプリケーション向けにカスタマイズが必要な箇所がいくつか存在する。

カスタマイズが必要な箇所を以下に示す。

* :ref:`create_project_springboot`
* :ref:`create_project_adding_dependencies`
* :ref:`create_project_making_entrypoint`

.. _create_project_springboot:

Spring Bootの利用
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

`Spring Cloud <http://projects.spring.io/spring-cloud/>`_ との親和性を高めるために、
オンライン版クラウド拡張開発プロジェクトでは `Spring Boot <https://projects.spring.io/spring-boot/>`_ を利用する。
Spring Bootを使用すると、プロジェクトのアーカイブ方式として「実行可能jarファイル」と「デプロイ可能warファイル」が選択できるが、
本ガイドラインでは、|base_framework_name| のノウハウを活用するため、**デプロイ可能warファイル** を採用する。
Spring Bootを使用したデプロイ可能warファイルの作成方法の詳細はSpring Bootの公式リファレンス
`Traditional deployment <http://docs.spring.io/spring-boot/docs/1.5.20.RELEASE/reference/html/howto-traditional-deployment.html>`_
を参照されたい。

Spring Bootを使用するとBean定義など多くの設定が自動で行われる。
このような自動設定の仕組みのことを\ ``Spring Boot Auto-configuration``\ といい、アプリケーション開発者は最小限の設定を行うだけでアプリケーションを構築することができる。
詳しくはSpring Bootの公式リファレンス `Auto-configuration <http://docs.spring.io/spring-boot/docs/1.5.20.RELEASE/reference/html/using-boot-auto-configuration.html>`_ を参照されたい。

.. _create_project_adding_dependencies:

依存ライブラリの追加
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

* project/pom.xml (プロジェクトrootのParent POM)

.. code-block:: xml

    <dependencyManagement>
        <!-- (1) -->
        <dependency>
            <groupId>org.springframework.cloud</groupId>
            <artifactId>spring-cloud-dependencies</artifactId>
            <version>Dalston.SR5</version>
            <type>pom</type>
            <scope>import</scope>
        </dependency>
    </dependencyManagement>

* project/xxx-web/pom.xml

.. code-block:: xml

    <dependencies>
        <!-- (2) -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter</artifactId>
        </dependency>
        <!-- (3) -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-configuration-processor</artifactId>
        <optional>true</optional>
        </dependency>
        <!-- (4) -->
        <dependency>
            <groupId>org.springframework.cloud</groupId>
            <artifactId>spring-cloud-config-client</artifactId>
        </dependency>
    <dependencies>

.. tabularcolumns:: |p{0.10\linewidth}|p{0.30\linewidth}|p{0.60\linewidth}|
.. list-table::
   :header-rows: 1
   :widths: 10 30 60

   * - | 項番
     - | 依存ライブラリ
     - | 説明
   * - | (1)
     - | \ ``spring-cloud-dependencies``\
     - `Spring Cloud <http://projects.spring.io/spring-cloud/>`_ のBOM。
       プロジェクトのParent POMの\ ``dependencyManagement``\ に定義することで、Spring Cloud関連の依存ライブラリのバージョンを解決する。
       |release| で利用するOSSのバージョンについては、 :doc:`../Overview/FrameworkStack` を参照されたい。
   * - | (2)
     - \ ``spring-boot-starter``\
     - `Spring Boot <https://projects.spring.io/spring-boot/>`_ の機能を実現するために必要なライブラリの依存関係を集約したもので、
       Spring Boot特有のAuto-configuration、ロギング、YAMLなどが利用できるようになる。
   * - | (3)
     - \ ``spring-boot-configuration-processor``\
     - \ ``spring-boot-configuration-processor``\ の依存ライブラリを追加することで、
       Spring Bootの\ ``@ConfigurationProperties``\ アノテーションを使用して定義したプロパティのメタデータを生成することができる。
       詳細については、Spring Boot公式リファレンス
       `Generating your own meta-data using the annotation processor <http://docs.spring.io/spring-boot/docs/1.5.20.RELEASE/reference/html/configuration-metadata.html#configuration-metadata-annotation-processor>`_
       を参照されたい。
   * - | (4)
     - \ ``spring-cloud-config-client``\
     - `Spring Cloud Config <https://cloud.spring.io/spring-cloud-config/>`_ を利用するための依存ライブラリ。
       \ ``spring-cloud-config-client``\ に依存したSpring Bootアプリケーションとしてビルドすることで、Spring Cloud Configが利用できる。

.. _create_project_making_entrypoint:

エントリポイントの作成
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
Spring Bootを利用して、デプロイ可能なwarファイルを作成するために必要な設定クラスを作成する。
このクラスはSpring Bootのエントリポイントとして、アプリケーションの起動時に読み込まれ、Springアプリケーションに必要なサーブレットやフィルタ等の情報を設定する。

* \ ``Bootstrap.java``\

.. code-block:: java

    package com.example.xxx.app;

    import org.springframework.boot.autoconfigure.EnableAutoConfiguration;
    import org.springframework.boot.autoconfigure.jdbc.DataSourceAutoConfiguration;
    import org.springframework.boot.autoconfigure.jmx.JmxAutoConfiguration;
    import org.springframework.boot.autoconfigure.web.WebMvcAutoConfiguration;
    import org.springframework.boot.builder.SpringApplicationBuilder;
    import org.springframework.boot.web.support.SpringBootServletInitializer;
    import org.springframework.context.annotation.ImportResource;
    import org.springframework.boot.autoconfigure.security.servlet.SecurityAutoConfiguration;

    //(1)
    @ImportResource({ "classpath*:META-INF/spring/applicationContext.xml", "classpath*:META-INF/spring/spring-security.xml",
                      "classpath*:/META-INF/spring/spring-mvc.xml"}) //(2)
    //(3)
    @EnableAutoConfiguration(exclude = { DataSourceAutoConfiguration.class,
                                          JmxAutoConfiguration.class, WebMvcAutoConfiguration.class,
                                          SecurityAutoConfiguration.class })
    //(4)
    public class Bootstrap extends SpringBootServletInitializer {

        //(5)
        @Override
        protected SpringApplicationBuilder configure(SpringApplicationBuilder application) {
            //(6)
            setRegisterErrorPageFilter(false);
            return application.sources(Bootstrap.class);
        }
    }

.. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
.. list-table::
    :header-rows: 1
    :widths: 10 90

    * - | 項番
      - | 説明
    * - | (1)
      - Spring Frameworkのアノテーションコンフィグの仕組みである\ ``@ImportResource``\ を使用してXMLのBean定義ファイルを読み込んでいる。
        ここでは、classpath*:META-INF/spring/配下の\ ``applicationContext.xml``、\ ``spring-security.xml``\ を読み込むように設定している。
    * - | (2)
      - \ ``web.xml``\ において\ ``DispathcerServlet``\ の\ ``contextConfigLocation``\ で指定していた\ ``classpath*:/META-INF/spring/spring-mvc.xml``\ を追加する。
        Spring Bootを使用した際の制約で、``DispatcherServlet``\ ではなくエントリポイントでロードする必要がある。
        詳細は :ref:`create_project_constrait_embeddedtomcat_springboot` を参照されたい。
    * - | (3)
      - \ ``@EnableAutoConfiguration``\ の \ ``exclude``\ 属性を使用することで、特定のコンフィギュレーションクラスをAuto-configurationの適用対象から除外できる。
        本ガイドラインで作成するプロジェクトでは、
        \ ``DataSourceAutoConfiguration``、\ ``JmxAutoConfiguration``、\ ``WebMvcAutoConfiguration``、\ ``SecurityAutoConfiguration``\  を除外する必要がある。
    * - | (4) (5)
      - デプロイ可能なwarファイルを作成するために\ ``SpringBootServletInitializer``\ を継承したクラスを作成し、\ ``configure``\ メソッドをオーバーライドする。
        この実装を行うことで、通常はSpringが提供する\ ``ContextLoaderListener``\ が行っているサーブレットコンテキストの構築がSpring Bootによって行われる。
    * - | (6)
      - :ref:`create_project_constrait_webmvc_errorpage` への対応。Spring Bootの\ ``ErrorPageFilter``\ を無効にしている。

.. note::

   項番(2)で説明されているAuto-configurationクラスについて、除外対象のクラスと除外理由は以下の通り。

    .. tabularcolumns:: |p{0.30\linewidth}|p{0.70\linewidth}|
    .. list-table::
       :header-rows: 1
       :widths: 30 70

       * - | 除外対象クラス
         - | 説明
       * - | \ ``DataSourceAutoConfiguration``\
         - データソースを設定するAuto-configurationクラス。Spring Bootがデータソースが一つであることを想定しているため、
           |base_framework_name| のブランクプロジェクトのように複数のデータソースが定義されている場合、
           \ ``NoUniqueBeanDefinitionException``\ が発生する。
           これを回避するには\ ``DataSourceAutoConfiguration``\ をAuto-configurationから除外するか、
           データソースの１つに\ ``primary=true``\ を設定する必要がある。
           このクラスを除外せずに複数のデータソースを定義する方法は、Spring Boot公式リファレンス
           `Configure Two DataSource <http://docs.spring.io/spring-boot/docs/1.5.20.RELEASE/reference/htmlsingle/#howto-two-datasources>`_ を参照されたい。
       * - | \ ``JmxAutoConfiguration``\
         - JMXを設定するAuto-configurationクラス。デフォルトでは同一サーバに複数のAPを起動した場合、
           JMXのドメインが重複してBeanが登録できず\ ``UnableToRegisterMBeanException``\ が発生するため除外する。
       * - | \ ``WebMvcAutoConfiguration``\
         - Spring MVCを設定するAuto-configurationクラス。
           除外しない場合、\ ``<mvc:view-resolvers>``\ で作成したBeanが上書きされてしまうため不具合が発生する。
           詳細は :ref:`create_project_constrait_webmvc` を参照されたい。
       * - | \ ``SecurityAutoConfiguration``\
         - Spring Securityを設定するAuto-configurationクラス。
           \ ``SecurityAutoConfiguration``\ が有効である場合、\ ``WebSecurityConfigurerAdapter``\ を継承した\ ``SpringBootWebSecurityConfiguration.DefaultConfigurerAdapter``\ をBean生成しようとするが、
           \ ``DefaultConfigurerAdapter``\ をBean生成する際に必要となる\ ``ObjectPostProcessor``\ がないために\ ``NoSuchBeanDefinitionException``\ が発生する。
           事象を回避する実装として\ ``SecurityAutoConfiguration``\ をAuto-configurationから除外する。
           他にもSecurityConfigurationクラスに\ ``@EnableWebSecurity``\ を付与する実装もあるが、本ガイドラインでは :ref:`usexmlconfig` に則る。

* web.xml

エントリポイントの作成にともなって、web.xmlに下記変更を加える。

.. code-block:: xml

    <!-- (1) -->
    <!-- 削除 ここから -->
    <listener>
        <listener-class>org.springframework.web.context.ContextLoaderListener</listener-class>
    </listener>
    <context-param>
        <param-name>contextConfigLocation</param-name>
        <param-value>
            classpath*:META-INF/spring/applicationContext.xml
            classpath*:META-INF/spring/spring-security.xml
        </param-value>
    </context-param>
    <!-- 削除 ここまで -->
    <!-- omitted -->
    <servlet>
        <servlet-name>appServlet</servlet-name>
        <servlet-class>org.springframework.web.servlet.DispatcherServlet</servlet-class>
        <init-param>
            <param-name>contextConfigLocation</param-name>
            <param-value></param-value> <!-- (2) -->
        </init-param>
        <load-on-startup>1</load-on-startup>
    </servlet>


.. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
.. list-table::
    :header-rows: 1
    :widths: 10 90

    * - | 項番
      - | 説明
    * - | (1)
      - \ ``ContextLoaderListener``\ を削除する。
        \ ``SpringBootServletInitializer``\ で\ ``ContextLoaderListener``\ を登録しているので、``web.xml``\ での定義は不要になる。
    * - | (2)
      - :ref:`create_project_constrait_embeddedtomcat_springboot` への対処。
        \ ``DispathcerServlet``\ の\ ``contextConfigLocation``\ 属性の設定値を削除する。
        \ ``contextConfigLocation``\ 属性を削除してしまうと例外が発生するので、
        空を設定することにより、　``DispathcerServlet``\ にダミーのコンテキストを設定しこれを回避する。
        また、自分でダミーファイルをデフォルト指定(\ ``WEB-INF/appServlet-servlet.xml``\ )に
        作成することで、``contextConfigLocation``\ 属性を削除しても例外が発生しなくなる。

.. _create_project_constrait:

オンライン版クラウド拡張開発プロジェクトで考慮すべき点・制約事項
--------------------------------------------------------------------------------

オンライン版クラウド拡張開発プロジェクトを作成するにあたり、下記について考慮しなければならない。

* :ref:`create_project_constrait_springboot`
* :ref:`create_project_constrait_embeddedtomcat`
* :ref:`create_project_constrait_webmvc`

.. _create_project_constrait_springboot:

Spring Boot使用に伴う制約事項
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. _create_project_constrait_springboot_profile:

Logbackの拡張の利用
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

Spring BootではLogbackの拡張を行っており追加の設定を行うことができるが、
デフォルトの設定ファイル名(``logback.xml``)では読み込みのタイミングが早すぎるため、Spring BootによるLogbackの拡張を利用することができない。

この拡張を利用するには、Spring Bootではデフォルトのファイル名ではなく、\ ``-spring``\ のサフィックスを付けた\ ``logback-spring.xml``\ を使用する必要がある。

詳細は、Spring Bootの公式リファレンス `Custom log configuration <http://docs.spring.io/spring-boot/docs/1.5.20.RELEASE/reference/html/boot-features-logging.html#boot-features-custom-log-configuration>`_
を参照されたい。

また、Logbackの設定例は |base_framework_name| Development Guideline
`Logbackの設定 <https://macchinetta.github.io/server-guideline/1.5.2.RELEASE/ja/ArchitectureInDetail/GeneralFuncDetail/Logging.html#id5>`_
を参照されたい。

.. warning::

   Spring Cloud Configを利用し\ ``logging.path``\ の設定値をConfigサーバに持たせる場合、Configサーバからプロパティを取得まするまでの間のログが意図しないディレクトリに出力されてしまう。
   これは\ `Custom log configuration <http://docs.spring.io/spring-boot/docs/1.5.20.RELEASE/reference/html/boot-features-logging.html#boot-features-custom-log-configuration>`_\
   に記載されているような設定ファイル名が存在するとSpring Bootが自動で読み込んでしまうが、\ ``logging.path``\ が未解決のためログの出力先を制御することができないため発生する。
   logbackを利用する場合、\ ``logback.xml``\ と\ ``logback-spring.xml``\ 以外の名前を利用すれば良い。
   設定ファイル名をSpring Bootが読み込みに行かない独自のファイル名に設定し、\ ``logging.config``\ のプロパティを設定することで意図しないログ出力を制御することができる。
   この方法を取った場合、logbackが読み込まれてから\ ``logging.path``\ が解決されるまでの間のログはSpring Bootのデフォルトの設定で標準出力に出力される。

   設定ファイル名を\ ``appName-logback-spring.xml``\ とし、Configサーバに持たせる\ ``application-development.yml``\ にプロパティを設定した場合の例を以下に示す。

   * application-development.yml

    .. code-block:: yaml

     logging:
       config: classpath:appName-logback-spring.xml

   Configサーバの使用方法については、 :doc:`../ImplementationAtEachLayer/EnvironmentValuesExternalManagement` を参照されたい。

.. _create_project_constrait_embeddedtomcat:

Spring Bootで組み込みTomcatを使用しない場合の制約事項
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

組み込みTomcatを使用しない場合、以下の制約が発生する。

* :ref:`create_project_constrait_embeddedtomcat_springboot`
* :ref:`create_project_constrait_embeddedtomcat_transactiontoken`
* :ref:`create_project_constrait_embeddedtomcat_actuator`
* :ref:`create_project_constrait_embeddedtomcat_cloudconfig`
* :ref:`create_project_constrait_embeddedtomcat_register_filter`

.. _create_project_constrait_embeddedtomcat_springboot:

DIコンテナの構築タイミングによりSpring Bootの機能が一部動作しない
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
DIコンテナの構築タイミングによって、Spring Bootの機能が一部動作しないことがある。
例えば、\ ``DispatcherServlet``\ で行われたコンポーネントスキャンでは、Spring Boot ActuatorにCustom HealthIndicatorを\ ``@Component``\ で定義しても動作させることができない。

Spring Bootではエントリポイントで、\ ``ContextLoaderListener``\ を登録し、コンテキストの読み込みを行っている。
また、|base_framework_name| のブランクプロジェクトでは\ ``DispatcherServlet``\ でもコンテキストの読み込みを行っている。
読み込みは、\ ``ContextLoaderListener``\ 、\ ``DispatcherServlet``\ の順で行われるため、
\ ``DispatcherServlet``\ 側で行われたコンポーネントスキャンでは、Spring Bootの機能への組み込みに間に合わず、動作しないことがある。

正常に動作させるためには、\ ``DispatcherServlet``\ で読み込みを行っていたXMLファイルをエントリポイントで読み込む必要がある。

.. note::

   Custom HealthIndicatorの例はあくまで一例であり、類似の意図しない動作が発生する可能性があるためDIコンテナの構築には注意されたい。

.. _create_project_constrait_embeddedtomcat_transactiontoken:

トランザクショントークンチェックを使用するための設定方法が異なる
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

|base_framework_name| Development Guideline `トランザクショントークンチェックを使用するための設定 <https://macchinetta.github.io/server-guideline/1.5.2.RELEASE/ja/ArchitectureInDetail/WebApplicationDetail/DoubleSubmitProtection.html#setting>`_
に記載されている設定方法を使用してもトランザクショントークンチェックが正常に動作しない。
これは、組み込みTomcatを使用しない場合にSpring BootによるrequestDataValueProcessorの
上書きが行われることにより、JSPにトランザクショントークンが埋め込まれないためである。

参考：`spring-boot#4676 <https://github.com/spring-projects/spring-boot/issues/4676>`_

以下のような実装を行うことでトランザクショントークンチェックを有効にすることが可能である。

* RequestDataValueProcessorPostProcessor

.. code-block:: java

  // (1)
  public class RequestDataValueProcessorPostProcessor implements BeanDefinitionRegistryPostProcessor {

      @Override
      public void postProcessBeanFactory(ConfigurableListableBeanFactory beanFactory) throws BeansException {
      }

      @Override
      public void postProcessBeanDefinitionRegistry(BeanDefinitionRegistry registry) throws BeansException {

          // (2)
          ConstructorArgumentValues cav = new ConstructorArgumentValues();
          List<RequestDataValueProcessor> values = new ArrayList<RequestDataValueProcessor>();
          values.add(new TransactionTokenRequestDataValueProcessor());
          values.add(new CsrfRequestDataValueProcessor());
          cav.addGenericArgumentValue(values);
          RootBeanDefinition rootBeanDefinition = new RootBeanDefinition(CompositeRequestDataValueProcessor.class, cav, null);

          // (3)
          registry.removeBeanDefinition("requestDataValueProcessor");
          registry.registerBeanDefinition("requestDataValueProcessor", rootBeanDefinition);
      }
  }

.. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
.. list-table::
    :header-rows: 1
    :widths: 10 90

    * - 項番
      - 内容
    * - | (1)
      - | \ ``BeanDefinitionRegistryPostProcessor``\ を実装することで、Beanのインスタンス化前にBean定義の変更を行うことができる。
    * - | (2)
      - | Bean定義を行うオブジェクトを生成する。
        | ここでは、\ ``TransactionTokenRequestDataValueProcessor``\ と\ ``CsrfRequestDataValueProcessor``\ を併用する \ ``CompositeRequestDataValueProcessor``\ を定義している。

        .. note::
          トランザクショントークンチェックとCSRFトークンチェックを併用したい場合、\ ``CsrfRequestDataValueProcessor``\ を追加する必要があるので留意されたい。

    * - | (3)
      - | 作成した\ ``CompositeRequestDataValueProcessor``\ オブジェクトでDIコンテナにrequestDataValueProcessorのBean名で登録されたオブジェクトを上書きする。

* xxx-web/src/main/resources/META-INF/spring/spring-mvc.xml

.. code-block:: xml

  <!-- (1) -->
  <bean class="com.example.xxx.app.RequestDataValueProcessorPostProcessor"/>

.. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
.. list-table::
    :header-rows: 1
    :widths: 10 90

    * - 項番
      - 内容
    * - | (1)
      - 作成したBean定義の上書きを行うクラスのBean定義を行う。

.. _create_project_constrait_embeddedtomcat_actuator:

Spring Boot Actuatorのエンドポイントのポートが変更できない
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

組み込みTomcatを使用しない場合、Spring Boot Actuatorのエンドポイントが使用するポートを
アプリケーションが使用するポートと別に設定することができない。
そのため、クラウドベンダが提供するロードバランサの機能を使用してエンドポイントのURLへの外部アクセスを遮断する必要がある。

詳細については、 :doc:`../ImplementationAtEachLayer/HealthCheck` を参照されたい。

.. _create_project_constrait_embeddedtomcat_cloudconfig:

Spring Cloud Configのリフレッシュ機能が使用できない
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

Spring Cloud Configを使用して構築したConfig Clientは設定変更を反映させるrefreshエンドポイント
を利用することができるが、組み込みTomcatを使用しない場合は当該機能を利用することができない。

詳細については、 :doc:`../ImplementationAtEachLayer/EnvironmentValuesExternalManagement` を参照されたい。

.. _create_project_constrait_embeddedtomcat_register_filter:

Filterが自動で登録され意図しない動作が発生する
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

Spring Bootのデフォルトでは、アプリケーションコンテキスト上のすべての\ ``Filter``\ を自動で登録する。
本ガイドラインでは、\ ``Filter``\ の登録をweb.xmlを使用して行っているため、\ ``Filter``\ が二重登録されるなど意図しない動作が発生する可能性がある。

以下のような実装を行うことでフィルタの自動登録を制御することが可能である。

* DefaultFiltersBeanFactoryPostProcessor

.. code-block:: java

  //(1)
  public class DefaultFiltersBeanFactoryPostProcessor implements
                                                     BeanFactoryPostProcessor {

      @Override
      public void postProcessBeanFactory(ConfigurableListableBeanFactory bf) throws BeansException {
          DefaultListableBeanFactory beanFactory = (DefaultListableBeanFactory) bf;

          //(2)
          String[] beanNames = beanFactory.getBeanNamesForType(Filter.class);
          for (String beanName : beanNames) {
              BeanDefinition definition = BeanDefinitionBuilder
                      .genericBeanDefinition(FilterRegistrationBean.class)
                      .setScope(BeanDefinition.SCOPE_SINGLETON)
                      .addConstructorArgReference(beanName)
                      .addConstructorArgValue(new ServletRegistrationBean[] {})
                      .addPropertyValue("enabled", false).getBeanDefinition();

              beanFactory.registerBeanDefinition(beanName
                      + "FilterRegistrationBean", definition);
          }
      }
  }


.. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
.. list-table::
    :header-rows: 1
    :widths: 10 90

    * - 項番
      - 内容
    * - | (1)
      - | \ ``BeanFactoryPostProcessor``\ を実装することで、Beanのインスタンス化前にプロパティの変更を行うことができる。
    * - | (2)
      - | \ ``ConfigurableListableBeanFactory``\ の実装クラスである\ ``DefaultListableBeanFactory``\ からデフォルトで登録される\ ``Filter``\ のBean名を取得し、すべての\ ``Filter``\ を無効にしている。

* xxx-web/src/main/resources/META-INF/spring/spring-mvc.xml

.. code-block:: xml

  <!-- (1) -->
  <bean class="com.example.xxx.app.DefaultFiltersBeanFactoryPostProcessor"/>

.. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
.. list-table::
    :header-rows: 1
    :widths: 10 90

    * - 項番
      - 内容
    * - | (1)
      - 作成した\ ``DefaultFiltersBeanFactoryPostProcessor``\ のBean定義を追加する。

.. _create_project_constrait_webmvc:

WebMvcAutoConfigurationによる不具合
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Spring BootのAuto-configurationにより設定される\ ``WebMvcAutoConfiguration``\ によって
``<mvc:view-resolvers>``\ で作成したBeanが上書きされてしまうことで下記不具合が発生する。

これらの問題に対処したソースコード例は :ref:`create_project_making_entrypoint` を参照されたい。

.. _create_project_constrait_webmvc_tiles:

ViewResolverが上書きされViewの解決ができない
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

|base_framework_name| Development Guideline `HTMLを応答する <https://macchinetta.github.io/server-guideline/1.5.2.RELEASE/ja/ImplementationAtEachLayer/ApplicationLayer.html#html>`_
に従いTilesの連携におけるBean定義\ ``<mvc:view-resolvers>``\ を使用していると、Viewの解決ができなくなる不具合が発生する。

これは、Spring Bootを非組み込みTomcatで使用する場合に、``<mvc:view-resolvers>``\ で定義した
``ViewResolver``\ が\ ``WebMvcAutoConfiguration``\ によって上書きされてしまいViewの解決ができなくなるからで、
``WebMvcAutoConfiguration``\ をAuto-configurationから除外することで回避できる。

.. _create_project_constrait_webmvc_errorpage:

エラー画面表示の不具合
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

Spring Bootを非組み込みTomcatで使用する場合、上記の\ ``ViewResolver``\ が上書きされてしまうことに加え、
デフォルトで動作する\ ``ErrorPageFilter``\ が意図せぬ動作をしてしまうことで、
システム例外発生時などで定義したエラー画面が表示されず、真っ白な画面が表示されてしまう。

これは、エントリポイントの\ ``configure``\ メソッドで\ ``ErrorPageFilter``\ を無効化することと、
``WebMvcAutoConfiguration``\ をAuto-configurationから除外することで回避できる。

.. raw:: latex

   \newpage
