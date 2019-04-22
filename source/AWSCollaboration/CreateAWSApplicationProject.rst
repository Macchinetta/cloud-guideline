AWS向け開発プロジェクトの作成
================================================================================

.. only:: html

 .. contents:: 目次
    :depth: 3
    :local:

|

本ガイドラインでは、AWS向け開発プロジェクトを作成する方法について説明する。
ここでは、AWSの各機能を利用する上での共通的な設定のみ説明し、AWSの各機能毎の独自の設定については記述しない。

AWSの各機能を利用する際の機能毎の設定については、 :doc:`../AWSCollaboration/index` を参照されたい。

|

.. _create_aws_project_blankpj:

開発プロジェクトの作成
--------------------------------------------------------------------------------

本ガイドラインでは、オンライン版クラウド拡張開発プロジェクトに対してクラウドベンダとしてAWSを利用する場合の設定を追加する。

ベースとなる開発プロジェクトの作成は
:doc:`../ImplementationAtEachLayer/CreateWebApplicationProject`
を参照されたい。

.. _create_aws_project_customize:

開発プロジェクトのカスタマイズ
--------------------------------------------------------------------------------

:ref:`create_aws_project_blankpj` で作成したプロジェクトをAWS向けにカスタマイズする。
AWS利用する場合、AWSの機能毎にカスタマイズが必要な箇所がいくつか存在するが、ここではAWSを利用する際の共通的な設定のみ説明する。

カスタマイズが必要な箇所を以下に示す。

* :ref:`create_aws_project_adding_dependencies`
* :ref:`create_aws_project_stack`

.. _create_aws_project_adding_dependencies:

依存ライブラリの追加
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

* project/xxx-domain/pom.xml

.. code-block:: xml

    <dependencies>
        <!--(1)-->
        <dependency>
            <groupId>org.springframework.cloud</groupId>
            <artifactId>spring-cloud-starter-aws</artifactId>
        </dependency>
    <dependencies>

.. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
.. list-table::
    :header-rows: 1
    :widths: 10 90

    * - 項番
      - 説明
    * - | (1)
      - | \ ``spring-cloud-starter-aws``\ の依存関係を追加する。
          これにより、Spring Cloud for Amazon Web Servicesに関連する依存関係が解決される。


.. tip::

  \ ``spring-cloud-starter-aws``\ を追加すると、ページアクセスの統計情報をメトリクスのデータとして、Spring Cloud AWSがCloudWatchに自動で送信する。
  この情報が不要な場合、\ ``spring.metrics.export.enabled=false``\ のプロパティを設定することで送信を止めることができる。

.. _create_aws_project_stack:

スタックの自動検出の無効化
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
Amazon Elastic Compute Cloud(以後、EC2)上でアプリケーションを起動するためには、スタックの自動検出を無効化する必要がある。
事象についての詳細は :ref:`create_aws_project_constrait_amazon_service_exception` を参照されたい。

スタックの自動検出を無効にする設定例を以下に示す。

* application.yml

  .. code-block:: yaml

    cloud:
      aws:
        stack:
          auto: false

.. _create_aws_project_autoconfiguration:

Auto-Configurationの無効化
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
EC2上でアプリケーションを起動するためには、\ ``ElastiCacheAutoConfiguration``\ をAuto-configurationから除外する必要がある。
事象についての詳細は :ref:`create_aws_project_constrait_cannot_find_cache` を参照されたい。

\ ``ElastiCacheAutoConfiguration``\ を無効にする設定例を以下に示す。

* Bootstrap.java

  .. code-block:: java

    @EnableAutoConfiguration(exclude = { DataSourceAutoConfiguration.class,
                                          JmxAutoConfiguration.class, WebMvcAutoConfiguration.class,
                                          ElastiCacheAutoConfiguration.class }) //(1)
    public class Bootstrap extends SpringBootServletInitializer {
      // omitted
    }

  .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
  .. list-table::
    :header-rows: 1
    :widths: 10 90

    * - 項番
      - 説明
    * - | (1)
      - \ ``@EnableAutoConfiguration``\アノテーションの属性\ ``exclude``\に、\ ``ElastiCacheAutoConfiguration.class``\
        を指定することで、\ ``ElastiCache``\の自動設定を除外する。



.. _create_aws_project_constrait:

AWS向けプロジェクトで考慮すべき点・制約事項
--------------------------------------------------------------------------------

.. _create_aws_project_constrait_credential:

AWS認証情報（Credentials)の管理
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

AWS リソースへのアクセスを必要とする場合、AWS認証情報（Credentials)がアプリケーションに設定されている必要がある。
セキュリティの観点から、アクセスキーを直接コードに埋め込むことは推奨されていない。
AWSの公式ドキュメントでは、下記のどちらかにアクセスキーを配置することが推奨されている。

* AWS 認証情報ファイル
* 環境変数

詳細は
`IAM ユーザのアクセスキーを適切に管理する <http://docs.aws.amazon.com/ja_jp/general/latest/gr/aws-access-keys-best-practices.html#iam-user-access-keys>`_
を参照されたい。

.. note::

  Spring Cloud AWSでは\ ``com.amazonaws.auth.DefaultAWSCredentialsProviderChain``\ を利用して
  AWS認証情報をアプリケーションに設定する。特定のクライアントが指定されていない場合、下記のAWS認証情報が利用される。

  * 環境変数\ ``AWS_ACCESS_KEY_ID``\ と\ ``AWS_SECRET_ACCESS_KEY``\
  * システムプロパティ\ ``aws.accessKeyId``\ と\ ``aws.secretKey``\
  * ユーザのAWS 認証情報ファイル
  * AWSインスタンスプロファイルの認証情報

  詳細はSpring Cloud AWSの公式リファレンス
  `SDK credentials configuration <http://cloud.spring.io/spring-cloud-static/spring-cloud-aws/1.2.1.RELEASE/#_sdk_credentials_configuration>`_
  を参照されたい。

.. warning::

    Spring Boot使用時はデフォルトの設定の状態では環境変数に設定したAWS認証情報は利用できない。
    これはAuto-configurationによって\ ``com.amazonaws.auth.DefaultAWSCredentialsProviderChain``\ が利用されなくなるためである。

    環境変数からAWS認証情報を取得するためには下記設定を行う必要がある。

    #. \ ``cloud.aws.credentials.instanceProfile=false``\
    #. \ ``cloud.aws.credentials.profileName=``\ (空)

    * application.ymlの設定例

      .. code-block:: yaml

        cloud:
          aws:
            credentials:
              instanceProfile: false
              profileName:

.. tip::

    開発者のPCなどのEC2インスタンス以外の環境で、Spring Cloud AWSを利用したAWSリソースへのアクセスを行うアプリケーションを実行する場合、AWS認証情報（Credentials）の取得に長時間を要する。
    これは、認証情報取得の際に実行される\ ``AWSCredentialsProvider``\ のうちの一つである\ ``InstanceProfileCredentialsProvider``\ が認証情報を取得できずにリトライを繰り返すためである。

    認証情報の取得はAWSリソースへのアクセスが発生する都度行われるため、アプリケーションのレスポンスが著しく低下する。
    そのため、EC2インスタンス以外の環境では\ ``InstanceProfileCredentialsProvider``\ を無効にしておくことが望ましい。

    \ ``InstanceProfileCredentialsProvider``\ は\ ``cloud.aws.credentials.instanceProfile=false``\ プロパティを設定しておくことで無効化できる。

    * application.ymlの設定例

      .. code-block:: yaml

        cloud:
          aws:
            credentials:
              instanceProfile: false

.. _create_aws_project_constrait_s3Permission:

Amazon S3のアクセス許可設定
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Amazon Simple Storage Service(以降、S3)に
個人情報などの機密性の高い情報を含むファイルのアップロードを行う場合、
S3バケットに対するアクセス許可を適切に付与する必要がある。

本ガイドラインでは下記の章でS3を使用する。これらの機能を使用する場合、アクセス許可の設定が必要なことに注意されたい。

* :doc:`../ImplementationAtEachLayer/EnvironmentValuesExternalManagement`
* :doc:`../AWSCollaboration/FileManagement/UploadFileManagement`
* :doc:`../AWSCollaboration/StaticContents`

アクセス許可を付与する際には、

#. アプリケーションが行うバケットアクセスに必要なアクセス許可
#. メンテナンスなどの運用上必要なアクセス許可

のみを付与するものとし、不要なアクセス許可を付与しないこと。

バケットポリシーを使用して、アプリケーションが使用するIAMユーザに対してアクセス許可を付与する場合以下のようになる。

  .. code-block:: json

    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Sid": "Stmt1478067513034",
                "Effect": "Allow",
                "Principal": {
                    "AWS": "arn:aws:iam::XXXXXXXXXXXX:user/appuser"
                },
                "Action": [
                    "s3:GetObject",
                    "s3:PutObject",
                    "s3:DeleteObject",
                    "s3:ListBucket"
                ],
                "Resource": [
                    "arn:aws:s3:::myBucket/*",
                    "arn:aws:s3:::myBucket"
                ]
            }
        ]
    }

上記例は、appuserに対して、myBucket配下のファイル（オブジェクト）の参照・更新・削除を行うアクセス許可を付与している。
S3 Management ConsoleもしくはAWS CLIから設定することでアクセス許可を付与することができる。

アクセス許可の詳細については、Amazon Simple Storage Service ドキュメント 開発者ガイド
`Amazon S3 リソースへのアクセス許可の管理 <https://docs.aws.amazon.com/ja_jp/AmazonS3/latest/dev/s3-access-control.html>`_
を参照されたい。

.. _create_aws_project_constrait_amazon_service_exception:

Amazon EC2上でAPを起動するとAmazonServiceExceptionが発生する
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
EC2上でアプリケーションを起動しようとすると、
\ ``Caused by: com.amazonaws.AmazonServiceException: Stack for i-xxxxx does not exist...``\ が発生する。
Spring Cloud AWSのAuto-configurationである\ ``ContextStackAutoConfiguration``\ によって、
アプリケーションのスタック名自動検出が有効になり、AWS CloudFormationのスタックが見つからない場合、
\ ``AmazonServiceException``\ が発生しAPが起動しない。

\ ``cloud.aws.stack.auto = false``\ を設定し、スタックの自動検出を無効化することで回避することができる。

設定例は :ref:`create_aws_project_stack` を参照されたい。

.. _create_aws_project_constrait_cannot_find_cache:

Amazon EC2上でElastiCache Redis使用時の注意
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
EC2上でアプリケーションを起動しようとすると、\ ``Spring Boot: java.lang.IllegalArgumentException: Cannot find cache named 'xxx' for CacheableOperation``\が発生する。
Spring Cloud AWSのAuto-configurationである\ ``ElastiCacheAutoConfiguration``\ によって、ElastiCacheの自動設定が有効になり、AWS ElastiCacheに\ ``cache named``\の設定がされていない場合、\ ``IllegalArgumentException``\ が発生しAPが起動しない。
そのため、\ ``ElastiCacheAutoConfiguration``\の自動設定を除外する。

設定例は :ref:`create_aws_project_autoconfiguration` を参照されたい。


.. raw:: latex

   \newpage
