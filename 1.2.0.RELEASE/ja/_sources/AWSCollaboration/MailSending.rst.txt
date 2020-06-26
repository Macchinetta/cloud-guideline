メール送信
================================================================================

.. only:: html

 .. contents:: 目次
    :depth: 3
    :local:

Overview
--------------------------------------------------------------------------------

本節では、Amazon Simple Email Service（以下、Amazon SES）を使用したEメール送信の実装方法について説明する。

.. note::

   本ガイドラインで説明の対象としているのはメールを送信する部分のみである。メール送信に係る処理方式については言及していない。

   また、Amazon SESが提供する機能についても、公式ドキュメントと記述が重複する為、メール送信に直接関わらないものは説明を割愛している。
   その為、本ガイドラインだけでなく、Amazon SESの公式ドキュメント\ `Amazon Simple Email Service (SES) <https://aws.amazon.com/jp/ses/>`_\を必ず参照した上で、開発に臨んで頂きたい。

.. _AboutSES:

Amazon SESとは
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

| Amazon SESは、Amazon Web Serviceが提供するEメールプラットフォームである。
| Amazon Web Service上で動作する為、ユーザはメールサーバ構築やネットワークの管理などのインフラ整備を行う必要がなく、容易にメールサービスを実装することができる。
| Amazon SESの詳細については、\ `Amazon Simple Email Service (SES) <https://aws.amazon.com/jp/ses/>`_\を参照されたい。

.. _UseSESWithJava:

JavaアプリケーションからのAmazon SESの利用
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
Amazon Web Serviceでは、JavaアプリケーションからAmazon SESを利用する為のAPIを提供している。

* **Amazon SES API(AWS SDK for Java)**

 | \ ``com.amazonaws.services.simpleemail.AmazonSimpleEmailServiceClient``\ をはじめとする、AWSが提供するSDKに含まれるAmazon SES用のAPI。
 | 詳細については\ `AWS SDK for Java <https://aws.amazon.com/jp/documentation/sdk-for-java/>`_\ および \ `Amazon SES APIを使用してEメールを送信する <http://docs.aws.amazon.com/ja_jp/ses/latest/DeveloperGuide/send-email-api.html>`_\を参照されたい。


* **SMTPインタフェース(Amazon SES SMTP Interface)**

 | SMTPを使用してAmazon SESにメール送信する為のインタフェース。
 | SMTPインタフェースの詳細については\ `Amazon SES SMTPインターフェイスを使用してEメールを送信する <http://docs.aws.amazon.com/ja_jp/ses/latest/DeveloperGuide/send-email-smtp.html>`_\を参照されたい。

.. _UseSESWithSpringCloudAWS:

Spring Cloud AWSのコンポーネントを使用したAmazon SESの利用
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
| Spring Cloudが提供する Spring Cloud for Amazon Web Services(以下、Spring Cloud AWS)を利用することで、設定ファイルの記述量を抑えてAmazon SESへのメール送信アプリケーションを実装することができる。
| **本ガイドラインでは、このSpring Cloud AWSを利用した実装方法について紹介する。**

Spring Cloud AWSを利用したメール送信については、Spring Cloud AWSのドキュメント\ `Sending mails <https://cloud.spring.io/spring-cloud-static/spring-cloud-aws/2.2.1.RELEASE/reference/html/#sending-mails>`_\ に紹介されている為、本ガイドラインと合わせて参照されたい。

.. _UseSESWithSpring:

Spring Frameworkのコンポーネントを使用したAmazon SESの利用
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
| Spring Frameworkはメール送信を行うためのコンポーネント（\ ``org.springframework.mail``\ パッケージ）を提供している。
| このパッケージに含まれるコンポーネントはメール送信に係る詳細なロジックを隠蔽し、低レベルのAPIハンドリング(JavaMailのAPI呼び出し)を代行する。
| 詳しくは、|base_framework_name| のガイドライン\ `Spring FrameworkのMail連携用コンポーネントについて <https://macchinetta.github.io/server-guideline/1.7.0.RELEASE/ja/ArchitectureInDetail/MessagingDetail/Email.html#spring-frameworkmail>`_\ に紹介されている為、参照されたい。

本ガイドラインで使用するコンポーネントを以下に示す。

* \ ``JavaMailSender``\
    | JavaMail用のメール送信インタフェース。
    | JavaMailの\ `MimeMessage <http://docs.oracle.com/javaee/7/api/javax/mail/internet/MimeMessage.html>`_\ とSpringの\ ``SimpleMailMessage``\ の両方に対応している。

* \ ``MimeMessageHelper``\
    | JavaMailのMimeMessageの作成を容易にするためのヘルパークラス。
    | MimeMessageHelperには、MimeMessageに値を設定するための便利なメソッドがいくつも用意されている。

* \ ``SimpleMailMessage``\
    | 単純なメールメッセージを作成するためのクラス。
    | 英文のプレーンテキストメールを作成する際に使用できる。
    | UTF-8等の特定のエンコード指定、HTMLメールや添付ファイル付きメールの送信、あるいはメールアドレスに個人名を付随させるといったリッチなメッセージの作成を行う際は、JavaMailの\ ``MimeMessage``\ を使用する必要がある。

How to use
--------------------------------------------------------------------------------

Amazon SESの設定
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
| Amazon SESを使用する為に必要な設定について説明する。
|
| Amazon SESの利用開始時点では、不正利用防止の為、サンドボックスと呼ばれる制限環境下で利用する事となる。
| サンドボックス内では、認証済のメールアドレスでのみ、メールの送信・受信が可能な為、メールアドレス認証を行う必要がある。
| メールアドレスの認証については、 \ `Amazon SES でのEメールアドレスの検証 <http://docs.aws.amazon.com/ja_jp/ses/latest/DeveloperGuide/verify-email-addresses.html>`_\を参照されたい。
|
| 製造フェーズ等の開発段階ではサンドボックス環境を利用し、本番環境を想定した試験等のタイミングでサンドボックス外に移行する運用が考えられる。
| サンドボックス外への移動については、 \ `Amazon SES サンドボックスの外への移動 <http://docs.aws.amazon.com/ja_jp/ses/latest/DeveloperGuide/request-production-access.html>`_\を参照されたい。

.. note::

   **メールの送信上限について**

   Amazon SESを利用する際には、24 時間当たりに送信できるメールの最大数と、1秒あたりに送信できるメールの最大数が存在する。制限はサンドボックス内・外どちらにも存在する。

   送信上限は必要に応じて引き上げ申請が可能な為、 \ `Amazon SES の送信制限の管理 <https://docs.aws.amazon.com/ja_jp/ses/latest/DeveloperGuide/manage-sending-limits.html>`_\および
   \ `Amazon SES の送信制限の引き上げ <https://docs.aws.amazon.com/ja_jp/ses/latest/DeveloperGuide/increase-sending-limits.html>`_\ を参照されたい。

.. note::

   **メールボックスシミュレータについて**

   テスト工程などでは、実在する宛先にメールを送らずに、バウンスやサプレッションリストへの送信確認などを行いたい場合が存在する。

   Amazon SESはメールボックスシミュレータを提供している為、特定のアドレスをToに設定して送信することで、いくつかのシミュレートを行う事ができる。
   詳細については\ `Amazon SES Eメール送信のテスト <https://docs.aws.amazon.com/ja_jp/ses/latest/DeveloperGuide/mailbox-simulator.html>`_\を参照されたい。

.. _SESHowToUseDependentLibrary:

依存ライブラリの設定
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

本ガイドラインで紹介する実装に必要となるライブラリの依存関係をpom.xmlに追加する。

記述例を以下に示す。

- xxx-domain/pom.xml

  .. code-block:: xml

      <dependencies>

          <!-- (1) -->
          <dependency>
              <groupId>org.springframework.cloud</groupId>
              <artifactId>spring-cloud-starter-aws</artifactId>
          </dependency>
          <!-- (2) -->
          <dependency>
              <groupId>com.amazonaws</groupId>
              <artifactId>aws-java-sdk-ses</artifactId>
          </dependency>
          <!-- (3) -->
          <dependency>
              <groupId>com.sun.mail</groupId>
              <artifactId>javax.mail</artifactId>
          </dependency>
          <!-- (4) -->
          <dependency>
              <groupId>com.sun.activation</groupId>
              <artifactId>javax.activation</artifactId>
          </dependency>

      </dependencies>

  .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
  .. list-table::
      :header-rows: 1
      :widths: 10 90

      * - 項番
        - 説明
      * - | (1)
        - | \ ``spring-cloud-starter-aws``\ をdependenciesに追加する。
      * - | (2)
        - | \ ``aws-java-sdk-ses``\ をdependenciesに追加する。
      * - | (3)
        - | \ ``javax.mail``\ をdependenciesに追加する。
      * - | (4)
        - | \ ``javax.activation``\ をdependenciesに追加する。


Spring Cloud AWSの設定
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
Spring Cloud AWSのメール送信コンポーネントを利用する為の設定を行う。

記述例を以下に示す。

- xxx-infra.xml

 .. code-block:: xml

    <!-- (1) -->
    <beans xmlns="http://www.springframework.org/schema/beans"
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        xmlns:aws-mail="http://www.springframework.org/schema/cloud/aws/mail"
        xsi:schemaLocation="http://www.springframework.org/schema/beans http://www.springframework.org/schema/beans/spring-beans.xsd
            http://www.springframework.org/schema/cloud/aws/mail
            http://www.springframework.org/schema/cloud/aws/mail/spring-cloud-aws-mail.xsd">

        <!-- (2) -->
        <aws-mail:mail-sender id="sesMailSender" region="us-east-1"/>


 .. tabularcolumns:: |p{0.26\linewidth}|p{0.26\linewidth}|p{0.74\linewidth}|
 .. list-table::
    :header-rows: 1
    :widths: 10 26 64

    * - 項番
      - 属性名
      - 内容
    * - | (1)
      - xmlns:aws-mail
      - | aws-mail Namespaceを定義する。
        | 値として\ ``http://www.springframework.org/schema/cloud/aws/mail``\ を指定する。
    * -
      - xsi:schemaLocation
      - | スキーマのURLを指定する。
        | 値に\ ``http://www.springframework.org/schema/cloud/aws/mail``\ と\ ``http://www.springframework.org/schema/cloud/aws/mail/spring-cloud-aws-mail.xsd``\ を追加する。
    * - | (2)
      - \-
      - | \ ``<aws-mail:mail-sender/>``\ を利用して、Spring Cloud AWSが提供する\ ``JavaMailSender``\の実装クラスをDIコンテナに登録する。
    * -
      - \ ``id``\
      - | \ ``JavaMailSender``\の実装クラスがDIコンテナに登録される際のBeanIDとなる。
    * -
      - \ ``region``\
      - | Amazon SESで個別のリージョンを指定する必要がある場合、\ ``region``\属性にリージョンを指定する。

        .. note::

           本ガイドライン執筆現在、Amazon SESは限られたリージョンでしかサービスを提供していない。Amazon SES利用の際には留意して頂きたい。


なお、上記の設定は、Spring BootのAuto-configurationが提供する\ ``org.springframework.cloud.aws.autoconfigure.mail.MailSenderAutoConfiguration``\が無効になっている事が前提である。
デフォルトでは\ ``MailSenderAutoConfiguration``\は有効になっている為、本設定を行う際は、必ずAuto-configurationの設定を確認すること。

.. note::

   \ ``MailSenderAutoConfiguration``\ が提供するBean定義では、Amazon SESをEC2とは異なるリージョンで使用する場合に、リージョン情報の差し替えに対応できない。
   その為、本ガイドラインではaws-mail Namespaceを使用する方法を紹介している。


\ ``MailSenderAutoConfiguration``\を無効にする設定例を以下に示す。

- Bootstrap.java

  .. code-block:: java

      package com.example.xxx.app;

      import org.springframework.boot.autoconfigure.EnableAutoConfiguration;
      import org.springframework.cloud.aws.autoconfigure.mail.MailSenderAutoConfiguration;
      import org.springframework.boot.web.support.SpringBootServletInitializer;

      // omitted

      @EnableAutoConfiguration(exclude = MailSenderAutoConfiguration.class)
      public class Bootstrap extends SpringBootServletInitializer {

          // omitted
      }

  .. note::

     上記の記述例は、\ ``MailSenderAutoConfiguration``\の除外にフォーカスして紹介している。
     \ ``Bootstrap``\ クラスのその他の定義例については、:ref:`create_project_making_entrypoint` にて紹介している為、必要に応じて参照されたい。

  .. warning::

     \ ``MailSenderAutoConfiguration``\ というクラス名のAuto-configurationクラスは複数存在する。

     除外する際はパッケージ名まで確認の上、\ ``org.springframework.cloud.aws.autoconfigure.mail.MailSenderAutoConfiguration``\を対象とすること。

SimpleMailMessageによるメール送信方法
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
英文のプレーンテキストメール（エンコードの指定や添付ファイル等が不要なメール）を送信する場合は、Springが提供している\ ``SimpleMailMessage``\クラスを使用する。

実装例については、|base_framework_name| のガイドライン\ `SimpleMailMessageによるメール送信方法 <https://macchinetta.github.io/server-guideline/1.7.0.RELEASE/ja/ArchitectureInDetail/MessagingDetail/Email.html#simplemailmessage>`_\ を参照されたい。

MimeMessageによるメール送信方法
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
英文以外のメールやHTMLメール、添付ファイルの送信を行う場合、\ ``javax.mail.internet.MimeMessage``\ クラスを使用する。
本ガイドラインでは\ ``MimeMessageHelper``\ クラスを使用してMimeMessageを作成する方法を推奨している。

実装例については、|base_framework_name| のガイドライン\ `MimeMessageによるメール送信方法 <https://macchinetta.github.io/server-guideline/1.7.0.RELEASE/ja/ArchitectureInDetail/MessagingDetail/Email.html#id8>`_\ を参照されたい。

.. raw:: latex

   \newpage
