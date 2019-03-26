フレームワークスタック
================================================================================

.. only:: html

 .. contents:: 目次
    :depth: 3
    :local:

|framework_name| 概要
--------------------------------------------------------------------------------

本ガイドラインで使用するSoftware Frameworkは、|base_framework_name| で使用するものに加えて、クラウドベンダが提供するサービスと連携するためのOSSを組み合わせたものである。

|base_framework_name| で使用するSoftware Frameworkについては、 |base_framework_name| `Development Guideline <https://macchinetta.github.io/server-guideline/1.6.1.RELEASE/ja/Overview/FrameworkStack.html>`_  を参照されたい。

Software Frameworkの主な構成要素
--------------------------------------------------------------------------------
|framework_name| を構成するライブラリを以下に示す。
本ガイドラインでは、|base_framework_name| Development Guidelineで説明済みのライブラリについては説明を行わない。

.. figure:: ./imagesFrameworkStack/FrameworkStackOverview.png
   :alt: Screen image of framework stack.
   :width: 100%

環境依存値の外部管理
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
環境依存値の外部管理を行うフレームワークとして、Spring Cloud Configを利用する。

* `Spring Cloud Config <https://cloud.spring.io/spring-cloud-config/>`_

クラウドベンダ連携
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
クラウドベンダ連携を行うライブラリとして以下を利用する。

Spring Boot
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

以下の目的でSpring Bootを導入している。

* `Spring Cloud <https://spring.io/projects/spring-cloud/>`_ の利用
* `Spring Boot Actuator <https://docs.spring.io/spring-boot/docs/2.1.2.RELEASE/reference/htmlsingle/#production-ready-enabling>`_ の利用

.. note::

    Spring CloudはSpring Bootに依存した実装となっている。

.. note::

    本ガイドラインでは、|base_framework_name|  Development Guidelineで説明しているアプリケーション・アーキテクチャおよびノウハウを使用してクラウドネイティブなアプリケーションを開発するための方法を説明している。そのため、Spring Boot機能の利用は限定的なものとし、Spring Bootを使用することにより生じる制約や実装方法の相違点については適宜補足説明を行う。

Amazon Web Service
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

Amazon Web Serviceとの連携を行うフレームワークとして以下を利用する。

* `Spring Cloud for Amazon Web Services <https://cloud.spring.io/spring-cloud-aws/>`_
* `Spring Data DynamoDB <https://github.com/derjust/spring-data-dynamodb>`_
* `AWS SDK for Java <https://aws.amazon.com/jp/sdk-for-java/>`_

セッションの外部管理
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
Redisを使用したセッションの管理を行うフレームワークとして、Spring Session with Redisを利用する。

* `Spring Session with Redis <https://docs.spring.io/spring-session/docs/2.1.3.RELEASE/reference/html5/#httpsession-redis>`_

キャッシュの管理
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
Redisを使用したキャッシュの管理を行うフレームワークとして、Spring Data Redisを利用する。

* `Spring Data Redis <https://spring.io/projects/spring-data-redis/>`_

共通ライブラリ
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

|framework_name| で利用する共通ライブラリは、|base_framework_name| の共通ライブラリと同様である。

利用するOSSのバージョン
--------------------------------------------------------------------------------

|framework_name| |framework_version| で利用するOSSの一覧を以下に示す。
|base_framework_name| Development Guideline `利用するOSSのバージョン <https://macchinetta.github.io/server-guideline/1.6.1.RELEASE/ja/Overview/FrameworkStack.html#oss>`_ において説明済みのOSSについては記載しない。

|framework_name| と |base_framework_name| のバージョンの対応関係は、:ref:`cloud_native_application_framework_relation` を参照されたい。

.. tip::

    |base_framework_name| と同様に、 `Spring Boot Dependencies <https://spring.io/projects/spring-boot>`_\ にて依存関係を解決可能なライブラリについては原則として、\ ``spring-boot-dependencies``\ の定義に準じている。使用する\ ``spring-boot-dependencies``\ のバージョンは |base_framework_name| に準じる。

    `Spring Cloud <https://spring.io/projects/spring-cloud/>`_\ 関連のライブラリについては、\ ``spring-cloud-dependencies``\ による定義に準じている。使用する\ ``spring-cloud-dependencies``\ のバージョンは、`Release Notes <https://github.com/spring-projects/spring-cloud/wiki/Spring-Cloud-Greenwich-Release-Notes#greenwichrelease>`_\ に記載されているベースのSpring Bootバージョンが\ ``spring-boot-dependencies``\ のベースと同一となるバージョンを選定し、Greenwich.RELEASEとしている。

    上記に該当しないライブラリについては、個別にバージョンを指定している。

.. tabularcolumns:: |p{0.15\linewidth}|p{0.25\linewidth}|p{0.25\linewidth}|p{0.15\linewidth}|p{0.05\linewidth}|p{0.05\linewidth}|p{0.05\linewidth}|
.. list-table::
    :header-rows: 1
    :stub-columns: 1
    :widths: 15 25 25 15 5 5 5

    * - Type
      - GroupId
      - ArtifactId
      - Version
      - Spring Boot Dependencies
      - Spring Cloud
      - Remarks
    * - Spring Boot
      - org.springframework.boot
      - spring-boot-configuration-processor
      - 2.1.2.RELEASE
      - \*
      -
      -
    * - Spring Boot
      - org.springframework.boot
      - spring-boot-starter
      - 2.1.2.RELEASE
      - \*
      -
      -
    * - Spring Boot
      - org.springframework.boot
      - spring-boot-starter-actuator
      - 2.1.2.RELEASE
      - \*
      -
      -
    * - 環境依存値の外部管理
      - javax.inject
      - javax.inject
      - 1
      -
      -
      - \*4
    * - キャッシュ管理
      - org.springframework.data
      - spring-data-keyvalue
      - 2.1.4.RELEASE
      - \*
      -
      -
    * - キャッシュ管理
      - org.springframework.data
      - spring-data-redis
      - 2.1.4.RELEASE
      - \*
      -
      -
    * - キューイング活用
      - org.springframework
      - spring-jms
      - 4.3.21.RELEASE
      -
      -
      - \*3
    * - クラウドベンダ連携
      - com.amazonaws
      - amazon-sqs-java-messaging-lib
      - 1.0.4
      -
      -
      - \*2
    * - クラウドベンダ連携
      - com.amazonaws
      - aws-java-sdk-dynamodb
      - 1.11.415
      -
      -
      - \*2
    * - クラウドベンダ連携
      - com.amazonaws
      - aws-java-sdk-iam
      - 1.11.415
      -
      - \*
      -
    * - クラウドベンダ連携
      - com.amazonaws
      - aws-java-sdk-ses
      - 1.11.415
      -
      - \*
      -
    * - クラウドベンダ連携
      - com.amazonaws
      - aws-java-sdk-sts
      - 1.11.415
      -
      - \*
      -
    * - クラウドベンダ連携
      - com.sun.mail
      - javax.mail
      - 1.6.2
      - \*
      -
      -
    * - クラウドベンダ連携
      - org.apache.tomcat
      - tomcat-jdbc
      - 9.0.10
      - \*
      -
      - \*1
    * - クラウドベンダ連携
      - org.springframework.cloud
      - spring-cloud-aws-context
      - 2.1.0.RELEASE
      -
      - \*
      -
    * - クラウドベンダ連携
      - org.springframework.cloud
      - spring-cloud-aws-jdbc
      - 2.1.0.RELEASE
      -
      - \*
      -
    * - クラウドベンダ連携
      - org.springframework.cloud
      - spring-cloud-config-client
      - 2.1.0.RELEASE
      -
      - \*
      -
    * - クラウドベンダ連携
      - org.springframework.cloud
      - spring-cloud-config-server
      - 2.1.0.RELEASE
      -
      - \*
      -
    * - クラウドベンダ連携
      - org.springframework.cloud
      - spring-cloud-starter-aws
      - 2.1.0.RELEASE
      -
      - \*
      -
    * - クラウドベンダ連携
      - com.github.derjust
      - spring-data-dynamodb
      - 5.0.4
      -
      -
      - \*2
    * - セッション管理
      - org.springframework.session
      - spring-session-data-redis
      - 2.1.3.RELEASE
      - \*
      -
      -
    * - セッション管理
      - redis.clients
      - jedis
      - 2.9.1
      - \*
      -
      -

#. | Spring Boot Dependenciesによりバージョンが定義されているが、TERASOLUNA Server Framework 5.5.1.RELEASEによるバージョン定義を優先しているライブラリ
#. | クラウドベンダ連携のために個別に導入するライブラリ
#. | Spring Boot Dependenciesによりバージョンが定義されているが、個別にバージョン定義を更新しているライブラリ
#. | TERASOLUNA Server Framework 5.5.1.RELEASEによりバージョンが定義されているライブラリ

 * \ ``tomcat-jdbc``\ の詳細は :doc:`../Introduction/Introduction` を参照のこと。

.. raw:: latex

   \newpage