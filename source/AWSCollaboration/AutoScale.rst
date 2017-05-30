オートスケーリングの利用
================================================================================

.. only:: html

 .. contents:: 目次
    :depth: 3
    :local:

Overview
--------------------------------------------------------------------------------

本ガイドラインは、AWSのオートスケーリングを利用する際に、アプリケーションで独自に作成したメトリクスの使用について説明する。
AWSのオートスケーリングについては、概要のみとし詳細は割愛するため、\ `Auto Scaling とは <http://docs.aws.amazon.com/ja_jp/autoscaling/latest/userguide/WhatIsAutoScaling.html>`_\を参照されたい。

|

オートスケーリングとは
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
オートスケーリングとは，Amazon EC2のインスタンスを，自動的に縮小・拡張することができる機能である。
また、インスタンスの数を常に一定に保つ為の利用も可能である。
詳細については、\ `Auto Scaling とは <http://docs.aws.amazon.com/ja_jp/autoscaling/latest/userguide/WhatIsAutoScaling.html>`_\を参照されたい。

|

オートスケーリングのメリット
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
オートスケーリングを利用するメリットは、主に耐障害性の向上、可用性の向上、及びコスト管理の強化である。
詳細については、\ `Auto Scaling のメリット <http://docs.aws.amazon.com/ja_jp/autoscaling/latest/userguide/auto-scaling-benefits.html>`_\を参照されたい。

|

オートスケーリング構成
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

アプリケーションのカスタムメトリクスを使用したAWS上での構成を以下に示す。

 .. figure:: ./imagesAutoScale/AutoScaleConstitution.png
   :alt: Screen image of Session management.
   :width: 80%

|

 .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
 .. list-table::
   :header-rows: 1
   :widths: 10 90

   * - 項番
     - 説明
   * - | (1)
     - | アプリケーションで作成したカスタムメトリクスを送信する。送信頻度については、スケジューラなどを使用して定期的に実行する。
   * - | (2)
     - | Amazon EC2 はメトリクスを Amazon CloudWatch に送信する。詳細は、\ `CloudWatch を使用したインスタンスのモニタリング <http://docs.aws.amazon.com/ja_jp/AWSEC2/latest/UserGuide/using-cloudwatch.html>`_\を参照されたい。
       | また、EC2 インスタンスから利用可能なメトリクスについては、\ `Amazon EC2 メトリクス <http://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/monitoring/ec2-metricscollected.html#ec2-metrics>`_\を参照されたい。
   * - | (3)
     - | CloudWatch は、指定した閾値にメトリクスが達すると、自動的にCloudWatch アラームに通知を送信する。
   * - | (4)
     - |  CloudWatch アラームは 1 つのメトリクスを監視し、ポリシーで指定した閾値にメトリクスが違反すると、メッセージを Auto Scaling に送信する。詳細は、\ `CloudWatch アラームを作成するインスタンス用 <http://docs.aws.amazon.com/ja_jp/AWSEC2/latest/UserGuide/using-cloudwatch-createalarm.html>`_\を参照されたい。
   * - | (5)
     - | Auto Scaling は関連付けられたポリシーを実行して、グループをスケールイン（インスタンスを終了）するか、グループをスケールアウト（インスタンスを起動）する。

|

利用上の注意事項
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
EC2インスタンスのステートレス化を行う必要がある。
具体的には、サーバが状態を持ってしまうと、スケールインの際に状態として保持しているデータがロストする。状態とは、アプリケーションのセッション情報やログファイル、あとは EC2 のホスト名やプライベート IP が決め打ちになっていることを指す。
また、スケールアウトの際も状態をもってしまうと、新たに起動したインスタンスに対して、リクエストを振り分けた際にデータが存在しないなどのエラーが発生する。


|


How to use
--------------------------------------------------------------------------------

AWSに標準で用意されているメトリクスを使用する場合、APに変更を加えることなく利用することができる。

AWSのオートスケーリングを標準のメトリクスで使用する方法は、AWS公式ドキュメント\ `Auto Scalingの使用開始 <http://docs.aws.amazon.com/ja_jp/autoscaling/latest/userguide/GettingStartedTutorial.html>`_\ を参照されたい。


How to extend
--------------------------------------------------------------------------------

本ガイドラインでは、\ `Amazon EC2 メトリクス <http://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/monitoring/ec2-metricscollected.html#ec2-metrics>`_\で提供されていないメトリクスを、アプリケーションで実装する方法を示す。

|

カスタムメトリクスセンダの作成
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

\ `AWS SDK for Java <https://aws.amazon.com/jp/documentation/sdk-for-java/>`_\ を使用してカスタムメトリクスを作成した実装例を以下に示す。

- :file:`CloudWatchMetricSender.java`

 .. code-block:: java

   @ConfigurationProperties(prefix = "custom.metric")
   public class CloudWatchMetricSender implements InitializingBean {

       @Inject
       AWSCredentialsProvider awsCredentialsProvider;

       @Value("${cloud.aws.cloudwatch.region}")
       String region;

       // (1)
       @Value("${spring.application.name:autoScalingGroupName}")
       String autoScalingGroupName;

       @Inject
       CloudWatchMetricProperties cloudWatchMetricProperties;

       AmazonCloudWatchClient amazonCloudWatchClient;

       String instanceId;

       // (2)
       @Override
       public void afterPropertiesSet() throws Exception {
           this.amazonCloudWatchClient = new AmazonCloudWatchClient(awsCredentialsProvider);

           if (!StringUtils.isEmpty(region)) {
               this.amazonCloudWatchClient.setRegion(Region.getRegion(Regions
                       .fromName(region)));
           }

           try {
               InstanceInfo instanceInfo = EC2MetadataUtils.getInstanceInfo();
               if (Objects.isNull(instanceInfo)) {
                   resolveInstanceIdWithLocalHostAddress();
               } else {
                   this.instanceId = instanceInfo.getInstanceId();
               }

           } catch (AmazonClientException e) {
               resolveInstanceIdWithLocalHostAddress();
           }

       }

       @Scheduled(fixedRate = 5000) // (3)
       public void sendCloudWatch() {
           MemoryMXBean mBean = ManagementFactory.getMemoryMXBean();
           MemoryUsage heapUsage = mBean.getHeapMemoryUsage(); // (4)
           Dimension InstanceIdDimension = new Dimension().withName("instanceId")
                   .withValue(instanceId); // (5)

           Dimension AutoScalingGroupNameDimension = new Dimension().withName(
                   "AutoScalingGroupName").withValue(autoScalingGroupName); // (6)

           // (7)
           PutMetricDataRequest request = new PutMetricDataRequest()
                   .withNamespace(cloudWatchMetricProperties.getNamespace())
                   .withMetricData(
                   // Used
                           new MetricDatum().withDimensions(InstanceIdDimension,
                                   AutoScalingGroupNameDimension).withMetricName(
                                   "HeapMemory.Used").withUnit(
                                   StandardUnit.Bytes.toString()).withValue(
                                   (double) heapUsage.getUsed()),
                           // Max
                           new MetricDatum().withDimensions(InstanceIdDimension,
                                   AutoScalingGroupNameDimension).withMetricName(
                                   "HeapMemory.Max").withUnit(
                                   StandardUnit.Bytes.toString()).withValue(
                                   (double) heapUsage.getMax()),
                           // Committed
                           new MetricDatum().withDimensions(InstanceIdDimension,
                                   AutoScalingGroupNameDimension).withMetricName(
                                   "HeapMemory.Committed").withUnit(
                                   StandardUnit.Bytes.toString()).withValue(
                                   (double) heapUsage.getCommitted()),
                           // Utilization
                           new MetricDatum()
                                   .withDimensions(InstanceIdDimension,
                                           AutoScalingGroupNameDimension)
                                   .withMetricName("HeapMemory.Utilization")
                                   .withUnit(StandardUnit.Percent.toString())
                                   .withValue(
                                           100 * ((double) heapUsage.getUsed() / (double) heapUsage
                                                   .getMax()))

                   );

           amazonCloudWatchClient.putMetricData(request); // (8)
       }

       private void resolveInstanceIdWithLocalHostAddress() {
           try {
               this.instanceId = InetAddress.getLocalHost().getHostAddress();
           } catch (UnknownHostException e1) {
               this.instanceId = "localhost";
           }
       }

       public String getAutoScalingGroupName() {
           return autoScalingGroupName;
       }

       public void setAutoScalingGroupName(String autoScalingGroupName) {
           this.autoScalingGroupName = autoScalingGroupName;
       }

   }


 .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
 .. list-table::
   :header-rows: 1
   :widths: 10 90

   * - 項番
     - 説明
   * - | (1)
     - | \ `Auto Scaling グループメトリクスのディメンション <http://docs.aws.amazon.com/ja_jp/autoscaling/latest/userguide/as-instance-monitoring.html#as-group-metric-dimensions>`_\で使用するAutoScalingGroupName ディメンションの設定である
         \ ``custom.metric.auto-scaling-group-name``\が設定されていない場合に、\ ``spring.application.name``\をデフォルト値として\ ``autoScalingGroupName``\に設定する。
   * - | (2)
     - | AmazonCloudWatchClientで指定されたリージョンが存在する場合は設定して生成する。アプリケーションがEC2インスタンス上で実行されている場合は、EC2インスタンスを識別する為の、InstanceIdを取得する。EC2インスタンス上でない場合は、localhost文字列を設定する。
   * - | (3)
     - | CloudWatchメトリクスに送信するスケジュールを指定する。
   * - | (4)
     - | メモリ使用量を取得するための\ ``MemoryUsage``\を取得する。
   * - | (5)
     - | \ `Amazon EC2 メトリクスのディメンション <http://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/monitoring/ec2-metricscollected.html#ec2-metric-dimensions>`_\のInstanceIdディメンションを生成する。
   * - | (6)
     - | \ `Amazon EC2 メトリクスのディメンション <http://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/monitoring/ec2-metricscollected.html#ec2-metric-dimensions>`_\のAutoScalingGroupNameディメンションを生成する。
   * - | (7)
     - | CloudWatchメトリクスに送信する\ ``PutMetricDataRequest``\を生成して、メトリクス名に\ ``HeapMemory.Utilization``\、単位にパーセント表記する為の\ ``StandardUnit.Percent.toString()``\、値にメモリ使用率を計算指定して設定する。
   * - | (8)
     - | \ ``AmazonCloudWatchClient#putMetricData``\を使用して、CloudWatchメトリクスに送信する。

.. note::
  Spring Cloud AWSにはメトリクスを送信するための\ ``CloudWatchMetricSender``\ インタフェースとその実装である\ ``BufferingCloudWatchMetricSender``\ が用意されている。
  しかし、\ ``BufferingCloudWatchMetricSender``\ はエンドユーザのリクエストが発生しないとメトリクス情報を送信することができない。
  また、\ ``CloudWatchMetricSender``\ インタフェースではメトリクスを一回につき１つしか送信できず、冗長なデータ送信を伴ってしまう。
  以上の制約があるため本ガイドラインでは、Spring Cloud AWSの\ ``CloudWatchMetricSender``\ は使用せず、カスタムメトリクスセンダを独自に実装する方法を紹介している。

|

- :file:`applicationContext.xml`

 .. code-block:: xml

      <!-- (1) -->
      <bean id="cloudWatchMetricSender"
        class="com.example.xxx.common.metrics.CloudWatchMetricSender">
        <constructor-arg ref="environment" />
      </bean>

 .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
 .. list-table::
   :header-rows: 1
   :widths: 10 90

   * - 項番
     - 説明
   * - | (1)
     - | 作成したカスタムメトリクスを使用する場合は、Bean定義ファイルに\ ``CloudWatchMetricSender``\クラスのbean定義が必要となる。

|



- :file:`application.yml`

 .. code-block:: yaml

   custom:
     metric:
       auto-scaling-group-name: autoScalingGroupName

 .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
 .. list-table::
   :header-rows: 1
   :widths: 10 90

   * - プロパティ名
     - 説明
   * - | custom.metric.auto-scaling-group-name
     - | \ `Auto Scaling グループメトリクスのディメンション <http://docs.aws.amazon.com/ja_jp/autoscaling/latest/userguide/as-instance-monitoring.html#as-group-metric-dimensions>`_\で使用するAutoScalingGroupName ディメンションを明示的に設定する場合に使用する。
         指定しない場合はデフォルト値として\ ``spring.application.name``\で指定した値が使用される。

|

.. raw:: latex

   \newpage
