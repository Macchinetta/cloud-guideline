アップロードファイル管理(ダイレクトアップロード方式)
================================================================================

.. only:: html

 .. contents:: 目次
    :depth: 3
    :local:

Overview
--------------------------------------------------------------------------------
本ガイドラインでは、Amazon Simple Storage Service(以降、S3)とAWS Security Token Service(以降、STS)を使用したファイルのダイレクトアップロードについて説明する。

.. _AbstractOfDirectUpload:

処理方式概要
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
S3を使用したダイレクトアップロードを行う場合、
本ガイドラインではPOSTメソッドによるアップロードを推奨している。
方式のイメージは以下の通り。

.. figure:: ./imagesDirectFileUpload/DirectFileUploadUsingS3Overview.png
  :alt: Screen image of file upload.
  :width: 100%

.. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
.. list-table::
   :header-rows: 1
   :widths: 10 90

   * - 項番
     - 説明
   * - | (1)
     - | クライアント(ブラウザ)はアプリケーションに対して、ファイルアップロードの要求を行う。
   * - | (2)
     - | アプリケーションは、Amazon STSに対してAssumeRoleリクエストを発行し、一時的セキュリティ認証情報を取得する。
   * - | (3)
     - | アプリケーションは、POSTによるアップロード用のポリシードキュメントを作成する。
   * - | (4)
     - | アプリケーションは、(3)で作成したPOSTポリシードキュメントに対し、バージョン4の署名を行う。
   * - | (5)
     - | アプリケーションは、POSTポリシードキュメントを含む資格情報と、ダイレクトアップロード用のJavaScriptコードをクライアントに返却する。
   * - | (6)
     - | クライアントは、受け取ったJavaScriptを使用してブラウザから直接S3へファイルをアップロードする。アップロードにはHTTPのPOSTメソッドを使用する。

ブラウザからS3に対してダイレクトアップロードを行う方式は上記以外にも存在する。
例えばJavaScript内からaws-sdkを利用する方式や、S3の署名付きURLを利用する方式が考えられるが、
前者はaws-sdkの資格情報(アクセスキー、シークレットキー)がクライアント側に晒される問題があり、
後者ではアップロードするファイルにサイズ制限を設ける事ができない。
これらのセキュリティ上の問題を考慮し、本ガイドラインではPOSTによるアップロード方式を推奨している。

.. _UsingSecurityTokenService:

STSの利用
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
本ガイドラインで紹介する方式では、POSTによるファイルアップロードを行うが、アップロードの際にクライアントにAWSのアクセスキーが開示される。
アプリケーションで使用しているアクセスキーがそのまま開示されることはセキュリティ上問題である為、
STSを使用して取得した一時的なセキュリティ認証情報(アクセスキー・シークレットキー)を使用する。
これにより、クライアントに開示されるのは一時的なアクセスキーとなる。
一時的セキュリティ認証情報の有効期限を短くすることで、悪意あるユーザーに悪用されるリスクを抑える事ができる為、
本ガイドラインでは、最も短い有効期限(15分)を設定する例を紹介している。

また、STSで一時的セキュリティ認証情報を取得する際のリクエストとして、AssumeRoleリクエストを使用することで、以下が可能である。

- 一時的セキュリティ認証情報への既存のIAMロールの引き継ぎ
- 一時的セキュリティ認証情報へのユーザーポリシー設定

例えば、S3の特定バケットへのPutObjectのみを許可されたIAMロールを引き継ぎ、かつ特定のオブジェクトキーのみにPutObjectが許されたユーザーポリシーを追加できる。

一時的セキュリティ認証情報、およびAssumeRole利用については以下の公式ドキュメントにて説明されている。実装前に参照されたい。

 - \ `一時的セキュリティ認証情報 <http://docs.aws.amazon.com/ja_jp/IAM/latest/UserGuide/id_credentials_temp.html>`_\
 - \ `IAM ロールの切り替え（API） <http://docs.aws.amazon.com/ja_jp/IAM/latest/UserGuide/id_roles_use_switch-role-api.html>`_\

.. _UsingS3ForDirectUpload:

S3の利用
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
本ガイドラインで紹介するダイレクトアップロード方式で必要となる、S3の各機能について紹介する。
なお、S3の概要や基本的な利用法についてはここで紹介しない為、必要に応じて\ `公式ドキュメント <https://aws.amazon.com/jp/documentation/s3/>`_\ を参照されたい。

.. _UsingAccessPolicyForDirectUpload:

アクセスポリシー
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
S3の全てのリソースは、デフォルトでは所有者(リソース作成者のAWSアカウント)のみがアクセスできる設定となっている。
リソースに対するアクセス権限を付与する為に、アクセスポリシーを提供している。
アクセスポリシーは、バケットポリシーに代表されるリソースベースのポリシーと、ユーザーベースのポリシーに分けられる。

本方式では、STSから取得する一時的セキュリティ認証情報に対し、ユーザーベースのIAMポリシーを付与してアクセス制限を行う。

S3のアクセスポリシー、およびIAMポリシーについては、以下の公式ドキュメントにて説明されている。
アクセスポリシーを扱う上で重要な情報である為、時間を取って必ず一読頂きたい。

 - \ `Amazon S3 リソースへのアクセス許可の管理 <http://docs.aws.amazon.com/ja_jp/AmazonS3/latest/dev/s3-access-control.html>`_\
 - \ `AWS IAMポリシーのリファレンス <http://docs.aws.amazon.com/ja_jp/IAM/latest/UserGuide/reference_policies.html>`_\

.. _AboutPostUpload:

S3へのPOSTアップロード
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
S3はHTTPのPOSTメソッドによるファイルアップロードをサポートしており、本ガイドラインではこのPOSTアップロードを使用する。
詳細については \ `Authenticating Requests in Browser-Based Uploads Using POST (AWS Signature Version 4) <http://docs.aws.amazon.com/ja_jp/AmazonS3/latest/API/sigv4-UsingHTTPPOST.html>`_\ を参照されたい。

.. _AboutPostPolicy:

POSTポリシー
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
POSTを用いて非公開バケットへのファイルアップロードを行う場合、リクエストにPOSTポリシーを含める必要がある。
POSTポリシーには、AWSの資格情報に加え、アップロードファイルサイズの制限や、アップロード可能なオブジェクトキーパターンなどを含めることができる。
POSTポリシーに記載されていない情報がアップロードリクエストに含まれていた場合は、アップロードに失敗する。例えば、アップロード時にメタデータを付与したい場合、メタデータについての設定をPOSTポリシーに記載する必要がある。

S3のPOSTポリシーの詳細については\ `Creating a POST Policy <http://docs.aws.amazon.com/ja_jp/AmazonS3/latest/API/sigv4-HTTPPOSTConstructPolicy.html>`_\
および \ `Authenticating Requests: Browser-Based Uploads Using POST (AWS Signature Version 4) <http://docs.aws.amazon.com/ja_jp/AmazonS3/latest/API/sigv4-authentication-HTTPPOST.html>`_\ を参照されたい。

.. warning::
  POSTポリシーは、バケットポリシーやIAMポリシーとは異なる書式であり、AWS Policy Generatorでは作成できない。
  ポリシーを作成する際は、混同しないよう注意されたい。

.. _AddingMetadata:

メタデータの付与
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
S3のオブジェクトには、メタデータを付与することができる。
アップロードされたファイルを利用する際に、アップロードユーザの特定や、アップロードファイルの種別・用途等の情報が必要になるケースが考えられる。
ユースケースによって必要なメタデータを適宜付与するよう検討されたい。

メタデータには、システムメタデータとユーザー定義メタデータの2種類があり、
任意の名前(キー)と値を付与する場合には、ユーザー定義メタデータを使用する。
ユーザー定義メタデータを付与する際は、メタデータの名前を\ ``x-amz-meta-``\ から始める必要がある。

なお、本ガイドラインの実装例では、ユーザー定義メタデータとして、アップロードしたファイルの元ファイル名を保持する例を紹介している。

メタデータについての詳細は、\ `オブジェクトメタデータ <http://docs.aws.amazon.com/ja_jp/AmazonS3/latest/dev/UsingMetadata.html#object-metadata>`_\ を参照されたい。

.. _UsingSignatureV4:

署名バージョン4による署名
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
ダイレクトアップロード方式では、サーバサイドでのAWS SDKを用いたアップロードと違い、ブラウザからAWSに対して直接リクエストを行う。
その為、改ざんされていない正規のリクエストであることを証明する為、一時的セキュリティ認証情報を用いてPOSTポリシードキュメントに対して署名を行う。

署名については\ `AWS API リクエストへの署名 <https://docs.aws.amazon.com/ja_jp/general/latest/gr/signing_aws_api_requests.html>`_\ も併せて参照されたい。

.. note::
  AWSは署名バージョンとしてバージョン2とバージョン4の2種類をサポートしているが、本ガイドラインでは、AWSが推奨する署名バージョン4を採用した方式を説明している。

.. warning::
  本ガイドラインで紹介する方式のように、POSTでのアップロードを行う場合、
  \ `署名バージョン4を使用してAWSリクエストに署名する <https://docs.aws.amazon.com/ja_jp/general/latest/gr/sigv4_signing.html>`_\ に説明されている署名プロセスは適用できない為、注意が必要である。
  POSTアップロードのリクエストへの署名は、
  \ `Calculating a Signature <http://docs.aws.amazon.com/ja_jp/AmazonS3/latest/API/sigv4-UsingHTTPPOST.html#sigv4-post-signature-calc>`_\ で説明されているように、先述のPOSTポリシーに対して行う。

How to use
--------------------------------------------------------------------------------

.. _SettingsIAMRole:

IAMの設定
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
STSのAssumeRoleリクエストを使用して一時的セキュリティ認証情報を取得する為には、引受元のロールを作成する必要がある。
ロールの作成方法については、\ `IAMユーザーにアクセス権限を委任するロールの作成 <http://docs.aws.amazon.com/ja_jp/IAM/latest/UserGuide/id_roles_create_for-user.html>`_\ を参照されたい。

本方式ではPutObjectのみを使用する為、ダイレクトアップロード用のバケットに対するPutObject許可ポリシーがアタッチされたIAMロールを使用する。
PutObjectのみを許可するポリシーの例を以下に示す。

.. code-block:: json

  {
      "Version": "2012-10-17",
      "Statement": [
          {
              "Sid": "Stmt1499682024000",
              "Effect": "Allow",
              "Action": [
                  "s3:PutObject"
              ],
              "Resource": [
                  "arn:aws:s3:::direct-upload/*"
              ]
          }
      ]
  }

.. _HowToSettingOfCORS:

CORSの設定
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
アップロード先のバケットに対し、CORSの設定を行う。

localhostからのクロスオリジンリクエスト(POST)を許可する設定例を以下に示す。

.. code-block:: xml

  <?xml version="1.0" encoding="UTF-8"?>
  <CORSConfiguration xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
    <CORSRule>
      <AllowedOrigin>http://localhost:8080</AllowedOrigin>
      <AllowedMethod>POST</AllowedMethod>
      <AllowedHeader>*</AllowedHeader>
    </CORSRule>
  </CORSConfiguration>

設定の詳細については、\ `Cross-Origin Resource Sharing (CORS) <http://docs.aws.amazon.com/ja_jp/AmazonS3/latest/dev/cors.html>`_\ を参照されたい。

.. _HowToImplementsServerSide:

サーバサイドの実装
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
ダイレクトアップロードの為のサーバサイド実装について説明する。

.. _AddingLibrary:

依存ライブラリの追加
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
本方式の実装で必要となる依存ライブラリの追加を行う。

- pom.xml

  .. code-block:: xml

        <!-- (1) -->
        <dependency>
            <groupId>com.amazonaws</groupId>
            <artifactId>aws-java-sdk-sts</artifactId>
        </dependency>
        <!-- (2) -->
        <dependency>
            <groupId>com.amazonaws</groupId>
            <artifactId>aws-java-sdk-iam</artifactId>
        </dependency>

 .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
 .. list-table::
    :header-rows: 1
    :widths: 10 90

    * - 項番
      - 説明
    * - | (1)
      - | \ ``aws-java-sdk-sts``\ の依存関係を追加する。
    * - | (2)
      - | \ ``aws-java-sdk-iam``\ の依存関係を追加する。

.. _GetTemporaryCredentials:

一時的セキュリティ認証情報の取得
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
STSに対してAssumeRoleリクエストを発行し、既存ロールを受け継いだ一時的セキュリティ認証情報を取得する。
ここでは、Controllerから呼び出されるヘルパークラスとして、\ ``DirectUploadHelper``\ を作成する例を示しながら説明する。

- AssumeRoleリクエストを発行する実装例

  .. code-block:: java

    @Component
    public class DirectUploadHelper implements InitializingBean {

        // omitted

        @Value("${upload.roleName}")
        String roleName; // (1)

        @Value("${upload.roleSessionName}")
        String roleSessionName; // (1)

        private String roleArn;

        private static final int STS_MIN_DURATION_MINUTES = 15;

        private Credentials getTemporaryCredentials(String bucketName, String objectKey) {

            String resourceArn = "arn:aws:s3:::" + bucketName + "/" + objectKey;

            // (2)
            Statement statement = new Statement(Statement.Effect.Allow)
                    .withActions(S3Actions.PutObject)
                    .withResources(new Resource(resourceArn));
            String iamPolicy = new Policy().withStatements(statement).toJson();

            int minDurationSeconds = (int) TimeUnit.MINUTES.toSeconds(STS_MIN_DURATION_MINUTES);

            // (3)
            AssumeRoleRequest assumeRoleRequest = new AssumeRoleRequest()
                    .withRoleArn(roleArn)
                    .withDurationSeconds(minDurationSeconds)
                    .withRoleSessionName(roleSessionName)
                    .withPolicy(iamPolicy);

            return AWSSecurityTokenServiceClientBuilder.defaultClient()
                    .assumeRole(assumeRoleRequest).getCredentials(); // (4)
        }

        // (5)
        @Override
        public void afterPropertiesSet() throws Exception {
            GetRoleRequest request = new GetRoleRequest();
            request.setRoleName(roleName);

            roleArn = AmazonIdentityManagementClientBuilder.defaultClient()
                    .getRole(request).getRole().getArn();
        }

        // omitted
    }

  .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
  .. list-table::
      :header-rows: 1
      :widths: 10 90

      * - 項番
        - 説明
      * - | (1)
        - | ロール名、ロールセッション名を取得する。
      * - | (2)
        - | 取得する一時的セキュリティ認証情報に付与するIAMポリシーを設定できる。
          | ここでは、アップロード対象のオブジェクトキーに対するPutObjectのみを許可するIAMポリシーを設定している。

          .. note::

           AssumeRoleで引き受けるロールが持っているIAMポリシーから、制限を緩める事はできない。

      * - | (3)
        - | AssumeRoleリクエストを発行する為のリクエストオブジェクトを生成する。
          | 引き受けるロールのARN、一時的セキュリティ認証情報の有効時間(分)、ロールセッション名、IAMポリシーを渡している。
      * - | (4)
        - | \ ``AWSSecurityTokenServiceClientBuilder``\ から\ ``AWSSecurityTokenServiceClient``\ を取得する。
          | 取得した\ ``AWSSecurityTokenServiceClient``\ に対してAssumeRoleリクエストを発行し、一時的セキュリティ認証情報として\ ``Credentials``\ を取得する。
      * - | (5)
        - | ロール名からロールARNを取得する。
          | \ ``AmazonIdentityManagementClientBuilder``\ から取得したIAMクライアントを介して、ロールARNを取得する。
          | ロールARNの取得はアプリケーション起動時にのみ行えば良い為、\ ``afterPropertiesSet``\ メソッドに実装している。

.. _CreatePOSTPolicy:

POSTポリシーの作成・署名
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
POSTによるアップロードリクエストに付加するPOSTポリシーを作成する。
引き続き、\ ``DirectUploadHelper``\ を実装する例を示しながら説明する。

- POSTポリシーを作成し、署名する実装例

  .. code-block:: java

    @Component
    public class DirectUploadHelper implements InitializingBean {

        // omitted

        // (1)
        @Value("${upload.durationseconds:30}")
        int durationSeconds;

        @Value("${upload.limitBytes}")
        int fileSizeLimit;

        // (2)
        @Inject
        ObjectMapper objectMapper;

        @Inject
        RegionProvider regionProvider;

        public DirectUploadAuthInfo getDirectUploadInfo(String bucketName,
                String fileName, SampleUserDetails userDetails) {

            String objectKey = createObjectKey(userDetails); // (3)

            Credentials credentials = getTemporaryCredentials(bucketName, objectKey); // (4)

            String regionName = regionProvider.getRegion().getName(); // (5)

            String serviceName = "s3";

            DateTime nowUTC = new DateTime(DateTimeZone.UTC); // (6)

            String date = nowUTC.toString("yyyyMMdd"); // (7)

            String acl = "private";

            String credentialString = credentials.getAccessKeyId() + "/" + date + "/"
                        + regionName + "/" + serviceName + "/" + "aws4_request";  // (8)

            String securityToken = credentials.getSessionToken();

            String s3endpoint = "s3-" + regionName + ".amazonaws.com";

            String targetUrl = "https://" + bucketName + "." + s3endpoint + "/";

            String algorithm = "AWS4-HMAC-SHA256"; // (9)

            String iso8601dateTime = nowUTC.toString("yyyyMMdd'T'HHmmss'Z'"); // (10)

            PostPolicy postPolicy = new PostPolicy();  // (11)
            postPolicy.setExpiration(nowUTC.plusSeconds(durationSeconds).toString()); // (12)
            postPolicy.setConditions(new String[][]{ // (13)
                { "eq", "$bucket", bucketName },
                { "eq", "$key", objectKey },
                { "eq", "$acl", acl },
                { "eq", "$x-amz-meta-filename", fileName },
                { "eq", "$x-amz-credential", credentialString },
                { "eq", "$x-amz-security-token", securityToken },
                { "eq", "$x-amz-algorithm", algorithm },
                { "eq", "$x-amz-date", iso8601dateTime },
                { "content-length-range", "0", fileSizeLimit }
            });

            String policyDocument = null;
            try {  // (14)
                policyDocument = objectMapper.writeValueAsString(postPolicy);
            } catch (JsonProcessingException e) {
                throw new SystemException("e.xx.fw.9001", "invalid policy.", e);
            }

            String base64policy = Base64.encodeBase64String(policyDocument.getBytes(
                        StandardCharsets.UTF_8)); // (15)

            byte[] signingKey = getSignatureKey(credentials.getSecretAccessKey(), date,
                        regionName, serviceName); // (16)

            String signatureForPolicy = Hex.encodeHexString(calculateHmacSHA256(
                        base64policy, signingKey)); // (17)

            // (18)
            DirectUploadAuthInfo res = new DirectUploadAuthInfo();
            res.setTargetUrl(targetUrl);
            res.setAcl(acl);
            res.setDate(iso8601dateTime);
            res.setObjectKey(objectKey);
            res.setSecurityToken(securityToken);
            res.setAlgorithm(algorithm);
            res.setCredential(credential);
            res.setSignature(signatureForPolicy);
            res.setPolicy(base64policy);
            res.setRawFileName(fileName);
            res.setFileSizeLimit(fileSizeLimit);

            return res;
        }

        // (3)
        private String createObjectKey(SampleUserDetails userDetails) {
            String userId = userDetails.getUsername();
            return userId + "/" + UUID.randomUUID();
        }

        private byte[] getSignatureKey(String key, String dateStamp, String region,
                String serviceName) {
            byte[] kSecret  = ("AWS4" + key).getBytes(StandardCharsets.UTF_8);
            byte[] kDate    = calculateHmacSHA256(dateStamp, kSecret);
            byte[] kRegion  = calculateHmacSHA256(region, kDate);
            byte[] kService = calculateHmacSHA256(serviceName, kRegion);
            byte[] kSigning = calculateHmacSHA256("aws4_request", kService);
            return kSigning;
        }

        private byte[] calculateHmacSHA256(String stringToSign, byte[] signingKey) {
            String algorithm = "HmacSHA256";
            Mac mac = null;
            try {
                mac = Mac.getInstance(algorithm);
            } catch (NoSuchAlgorithmException e) {
                throw new SystemException("e.xx.fw.9001", "invalid algorithm.", e);
            }
            try {
                mac.init(new SecretKeySpec(signingKey, algorithm));
            } catch (InvalidKeyException e) {
                throw new SystemException("e.xx.fw.9001", "invalid encoding key.", e);
            }

            return mac.doFinal(stringToSign.getBytes(StandardCharsets.UTF_8));
        }

        // (11)
        private class PostPolicy {

            private String expiration;

            private String[][] conditions;

            // accessor is omitted
        }
    }

  .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
  .. list-table::
      :header-rows: 1
      :widths: 10 90

      * - 項番
        - 説明
      * - | (1)
        - | POSTポリシー有効期間(秒)、アップロードサイズ上限(バイト)を取得する。
      * - | (2)
        - | \ ``ObjectMapper``\ 、\ ``RegionProvider``\ をインジェクションする。
      * - | (3)
        - | アップロードするオブジェクトキーを生成する。
          | 本実装例では、ログインしたユーザIDと、UUIDによるランダムな文字列を結合してオブジェクトキーとしている。
      * - | (4)
        - | \ :ref:`GetTemporaryCredentials`\ にて先述した一時的セキュリティ認証情報を取得する。
      * - | (5)
        - | \ ``RegionProvider``\ を使用して、リージョン名を取得する。
      * - | (6)
        - | UTCでの現在日時を取得する。
      * - | (7)
        - | Credential文字列作成に使用する為、取得したUTCの現在日時を"yyyyMMdd"形式にフォーマットする。
      * - | (8)
        - | Credential文字列を作成する。
          | Credential文字列の書式は、\ `Using the Authorization Header (AWS Signature Version 4) <http://docs.aws.amazon.com/ja_jp/AmazonS3/latest/API/sigv4-auth-using-authorization-header.html>`_\ を参照されたい。
      * - | (9)
        - | 署名計算用のアルゴリズム。署名バージョン4を使用する場合は\ ``AWS4-HMAC-SHA256``\ を指定する必要がある。
      * - | (10)
        - | 署名バージョン4に使用する日時情報\ ``x-amz-date``\ を作成する。
          | \ ``x-amz-date``\ はUTCでYYYYMMDD'T'HHMMSS'Z'のISO8601形式である必要がある。ミリ秒を含めてはいけない為、注意されたい。
          | 参考:\ `署名バージョン4の日付の処理 <https://docs.aws.amazon.com/ja_jp/general/latest/gr/sigv4-date-handling.html>`_\
      * - | (11)
        - | POSTポリシーを作成する。
          | 本実装例では、POSTポリシーを表す\ ``PostPolicy``\ クラスを作成した後、\ ``com.fasterxml.jackson.databind.ObjectMapper``\ によりJSON文字列に変換している。
      * - | (12)
        - | POSTポリシーに有効期限を示す日時情報を作成する。ISO8601形式であるが、\ ``x-amz-date``\ とは書式が異なる為、注意されたい。
          | 本例では、外部定義されている有効期間(秒)を現在日時に可算し、有効期限としている。
          | 参考:\ `Expiration <http://docs.aws.amazon.com/ja_jp/AmazonS3/latest/API/sigv4-HTTPPOSTConstructPolicy.html#sigv4-HTTPPOSTExpiration>`_\
      * - | (13)
        - | POSTポリシーの条件文(conditions)を作成する。
          | 本例では、値のマッチングタイプを完全一致(Exact Matches)としているが、必要に応じて前方一致(Starts With)や任意の値(Matching Any Content)とすることも可能である。
          | POSTポリシーに設定できる条件については\ `Creating a POST Policy <http://docs.aws.amazon.com/ja_jp/AmazonS3/latest/API/sigv4-HTTPPOSTConstructPolicy.html>`_\ を参照されたい。
      * - | (14)
        - | \ ``PostPolicy``\ クラスをJSON文字列に変換する。
      * - | (15)
        - | 作成したPOSTポリシーをBASE64エンコードする。
      * - | (16)
        - | 一時的セキュリティ認証情報のシークレットキーを元に、署名キーを取得する。
          | 本例では、\ `署名バージョン4の署名キーを取得する方法の例 <https://docs.aws.amazon.com/ja_jp/general/latest/gr/signature-v4-examples.html#signature-v4-examples-java>`_\ に示された実装例を元に実装している。
      * - | (17)
        - | 取得した署名キーを使用して、BASE64エンコード済のPOSTポリシーに対して署名計算を行う。
      * - | (18)
        - | クライアントでアップロードに必要となる情報を、オブジェクトに設定する。
          | 本オブジェクトの実装例は後述する。

.. _HowToImplementsDirectUploadAuthInfo:

クライアントへの返却用オブジェクトの実装
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
POSTポリシーやCredential文字列などの、クライアントに連携する情報を保持するオブジェクトを作成する。
以下は一例の為、実装にあたってクライアントに連携すべき情報が他にある場合は、適宜フィールドを追加されたい。

- POSTポリシー、認証情報等を持つオブジェクトの実装例

  .. code-block:: java

    public class DirectUploadAuthInfo {

        private String targetUrl;

        private String acl;

        private String policy;

        private String securityToken;

        private String objectKey;

        private String date;

        private String algorithm;

        private String credential;

        private String signature;

        private String rawFileName;

        private String fileSizeLimit;

        // accessor is omitted

    }

  .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
  .. list-table::
      :header-rows: 1
      :widths: 10 90

      * - フィールド
        - 説明
      * - | targetUrl
        - | POSTメソッドでアクセスする際の対象URL
      * - | acl
        - | アップロードしたファイルの公開範囲
      * - | policy
        - | POSTポリシードキュメント
          | POSTポリシーはBASE64エンコードされている必要がある。
      * - | securityToken
        - | 一時的セキュリティ認証情報のセキュリティトークン
      * - | objectKey
        - | アップロードするファイルのオブジェクトキー
      * - | date
        - | 日時情報
          | タイムゾーンはUTCで、YYYYMMDD'T'HHMMSS'Z'のISO8601形式である必要がある。
      * - | algorithm
        - | 署名アルゴリズム
          | 署名バージョン4の場合は\ ``AWS4-HMAC-SHA256``\ 固定。
      * - | credential
        - | 一時的セキュリティ認証情報やリージョン等の情報を含んだ文字列
      * - | signature
        - | POSTポリシーに対しての署名
      * - | rawFileName
        - | アップロードするファイルの元ファイル名
          | 本例では、アップロード時のメタデータに元ファイル名を含める為、本フィールドを作成している。
      * - | fileSizeLimit
        - | アップロードする際のサイズ上限
          | 本例では、JavaScript側にて、ファイルサイズ上限値を画面表示させたいケースを想定している。

.. _HowToImplementsDirectUploadController:

Controllerの実装
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
アップロード要求を受け付けるControllerの実装例について説明する。

- Controller実装例

  .. code-block:: java

    @Controller
    @RequestMapping("upload")
    public class DirectUploadController {

        @Value("${upload.bucketName}")
        String directUploadBucketName;

        @Inject
        DirectUploadHelper directUploadHelper; // (1)

        @GetMapping // (2)
        public String upload() {
            return "upload/index";
        }

        @GetMapping(params = "info") // (3)
        @ResponseBody // (4)
        public DirectUploadAuthInfo getInfoForDirectUpload(
                @RequestParam("filename") String fileName, // (5)
                @AuthenticationPrincipal SampleUserDetails userDetails) { // (6)

            return directUploadHelper.getDirectUploadInfo(directUploadBucketName,
                    fileName, userDetails); // (7)
        }
    }

  .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
  .. list-table::
      :header-rows: 1
      :widths: 10 90

      * - 項番
        - 説明
      * - | (1)
        - | 一時的セキュリティ認証情報の取得、POSTポリシーの作成・署名等を行うヘルパークラスをインジェクションする。
          | ヘルパークラスの実装例は\ :ref:`GetTemporaryCredentials`\ および\ :ref:`CreatePOSTPolicy`\ に示している。
      * - | (2)
        - | ダイレクトアップロード画面へ遷移させるハンドラメソッドを作成する。
      * - | (3)
        - | ダイレクトアップロードに必要な情報をクライアントに返却するハンドラメソッドを作成する。
          | 本メソッドはクライアントサイドで実装したJavaScriptから呼び出される。
      * - | (4)
        - | \ ``ResponseBody``\ アノテーションを付与することで、メソッドの返却オブジェクトをJSON文字列に変換してクライアントに返却できる。
      * - | (5)
        - | アップロード対象のファイル名をオブジェクトキーとする為、引数でファイル名を受け取る。
      * - | (6)
        - | 本実装例では、アップロードを行ったユーザIDをオブジェクトキーの接頭辞として使用する為、\ ``AuthenticationPrincipal``\ アノテーションを使用し、ログインユーザ情報を引数で受け取る。
      * - | (7)
        - | ヘルパークラスのメソッドを呼び出し、POSTによるアップロード時に必要となる情報を持つオブジェクトを作成する。
          | 作成したオブジェクトを呼び出し元に返却する。

.. _SettingPropertiesSample:

外部定義プロパティ値の設定
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
本ガイドラインの実装例で使用している外部定義プロパティ例を以下に示す。

  .. code-block:: yaml

        upload:
          bucketName: direct-upload  #(1)
          roleName: s3-direct  #(2)
          roleSessionName: s3-direct01  #(3)
          durationseconds: 30  #(4)
          limitBytes: 819200  #(5)

  .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
  .. list-table::
      :header-rows: 1
      :widths: 10 90

      * - 項番
        - 説明
      * - | (1)
        - | アップロード先のS3バケット名
      * - | (2)
        - | 一時的セキュリティ認証情報にて引き受けるIAMロールのロール名

          .. note::

           AssumeRoleリクエストではロールARNを使用するが、ロールARNにはAWSのアカウントIDが含まれる為、
           本ガイドラインではロール名からロールARNを取得する実装例を紹介している。

      * - | (3)
        - | AssumeRoleリクエストによって取得した一時的セキュリティ認証情報の識別名
      * - | (4)
        - | 一時的セキュリティ認証情報の有効期限(秒)
      * - | (5)
        - | アップロードファイルサイズの上限(バイト)

.. _HowToImplementsClientSide:

クライアントサイドの実装
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
ダイレクトアップロードの為のクライアントサイド実装について説明する。

.. _HowToImplementsDirectUploadJavaScript:

JavaScriptの実装
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
アップロード画面に埋め込むJavaScriptの実装例について説明する。
なお、本実装例では、JavaScriptライブラリであるjQueryを使用している。

- html実装例

  .. code-block:: html

    <!-- omitted -->

    <input type="file" id="file" name="file"/>
    <button type="button" id="uploadFile" onclick="">登録</button>

    <!-- omitted -->

- JavaScript実装例

  .. code-block:: javascript

    $("#uploadFile").on('click', function(){
        var file = $('#file').prop('files')[0]; // (1)

        var getAjax = function () {
            var uploadFileName = file.name;
            var dfd = new $.Deferred();

            $.ajax({ // (2)
                url: '${pageContext.request.contextPath}/upload?info&filename=' + uploadFileName,
                type: 'GET'
            }).then(function(data) {
                // omitted
            }).catch(function(jqXHR, textStatus, errorThrown) {
                // omitted
            });
            return dfd.promise();
        }

        var postAjax = function (getresult) {
            var dfd = new $.Deferred();
            var formData = new FormData(); // (3)
            formData.append('key', getresult.objectKey);
            formData.append('x-amz-credential', getresult.credential);
            formData.append('acl', getresult.acl);
            formData.append('x-amz-security-token',getresult.securityToken);
            formData.append('x-amz-algorithm', getresult.algorithm);
            formData.append('x-amz-date', getresult.date);
            formData.append('x-amz-meta-filename', getresult.rawFileName);
            formData.append('policy', getresult.policy);
            formData.append('x-amz-signature', getresult.signature);
            formData.append('file',file);

            $.ajax({ // (4)
                url: getresult.targetUrl,
                type: 'POST',
                data: formData,
                contentType: false,
                processData: false
            }).then(function(data, textStatus, jqXHR) {
                // omitted
            }).catch(function(jqXHR, textStatus, errorThrown) {
                // omitted
            });
            return dfd.promise();
        }

        if (file) {
            getAjax()
            .then(postAjax)
            .catch(function(jqXHR, textStatus, errorThrown, getresult) {
                // omitted
            });
        } else {
            // omitted
        }
        return false;
    });

  .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
  .. list-table::
      :header-rows: 1
      :widths: 10 90

      * - 項番
        - 説明
      * - | (1)
        - | 選択されたファイルを取得する。
      * - | (2)
        - | ajaxメソッドを使用し、サーバサイドアプリケーションに対してGETリクエストを発行する。
      * - | (3)
        - | GETに対するレスポンスとして、ダイレクトアップロードに使用する認証情報等を受け取った後、ダイレクトアップロード用のリクエストを作成する。
          | フォームを作成し、サーバサイドから受け取った情報をリクエストボディに格納する。
          | フォームのフィールドについては、\ `Creating an HTML Form <http://docs.aws.amazon.com/ja_jp/AmazonS3/latest/API/sigv4-HTTPPOSTForms.html#sigv4-HTTPPOSTFormFields>`_\ を参照されたい。

          .. note::

           fileは最後に追加する必要がある為、注意されたい。

      * - | (4)
        - | ajaxメソッドを使用し、S3に対してダイレクトアップロードのPOSTリクエストを発行する。

.. note::

  本実装例では、クライアントサイドでのファイルサイズチェック実装は割愛しているが、
  実開発ではPOSTポリシーとJavaScriptの両方でファイルサイズチェックを行う事が望ましい。

.. _DirectUploadErrorHandling:

エラーハンドリングについて
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
S3に対するダイレクトアップロードが失敗した場合、S3からXML形式のエラードキュメントが返却される。
ファイルサイズ制限超過やポリシー違反など、失敗原因ごとのエラーメッセージを表示したい場合にはこのエラードキュメントからエラーコードを取得する事で、原因の細分化が可能である。

エラーレスポンスの詳細については、\ `REST エラーレスポンス <http://docs.aws.amazon.com/ja_jp/AmazonS3/latest/dev/UsingRESTError.html>`_\ を参照されたい。

.. raw:: latex

   \newpage
