ログ管理
================================================================================

.. only:: html

 .. contents:: 目次
    :depth: 3
    :local:

Overview
--------------------------------------------------------------------------------

本ガイドラインでは、AWS連携でログ管理を実現するための方法を :doc:`../ImplementationAtEachLayer/LogManagement`\  に則って示す。


ログ管理の構成
""""""""""""""""""""""""""""""""""""""""
AWS連携では、ログ収集管理ツールとして、\ `CloudWatch Logs <https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/logs/WhatIsCloudWatchLogs.html>`_\ と\ `CloudWatch Logs エージェント <https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/logs/AgentReference.html>`_\ を組み合わせて利用する。
AWSのサービスを利用した構成を以下に示す。
CloudWatch Logsについては、\ `Amazon CloudWatch Logs の概念 <https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/logs/CloudWatchLogsConcepts.html>`_\ を参照されたい。


 .. figure:: ./imagesLogManagement/LogManagementConstitution.png
   :alt: Screen image of LogManagement.
   :width: 100%


 .. tabularcolumns:: |p{0.10\linewidth}|p{0.90\linewidth}|
 .. list-table::
   :header-rows: 1
   :widths: 10 90

   * - 項番
     - 説明
   * - | (1)
     - | 指定されたアプリケーションのログを監視してデータを取得する。
   * - | (2)
     - | 取得したログデータを転送する。
   * - | (3)
     - | バックアップなどの必要であれば、集約したログデータをS3に保存する。
   * - | (4)
     - | \ `CloudWatch <http://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/monitoring/WhatIsCloudWatch.html>`_\ 以外の監視ツールや可視化ツールなどと連携するために必要であれば、集約したログデータを\ `Elasticsearch <http://docs.aws.amazon.com/ja_jp/elasticsearch-service/latest/developerguide/what-is-amazon-elasticsearch-service.html>`_\ に連携する。


 .. warning::
  CloudWatch Logs Agentの遅延は最大でbuffer_durationで設定した値（最小値は 5000ms で、デフォルト値は 5000ms ）なので、
  インスタンス障害時などは最大で5000msのログデータがロストする可能性がある。
  また、Auto Scalingの際のインスタンス破棄は、5秒後以降に実施されるように設定することで、ロストすることなくログを監視することが可能である。





How to use
--------------------------------------------------------------------------------
AWS環境での使用方法を示す。AWSのログ収集の仕組みは、ファイルシステムに出力されたログを別プロセスであるエージェントが監視収集する方法である。ゆえに、ログ出力の方法自体は |base_framework_name| Development Guidelineの「\ `ロギング <http://macchinetta.github.io/server-guideline/1.4.0.RELEASE/ja/ArchitectureInDetail/GeneralFuncDetail/Logging.html>`_\」に記載している方法をそのまま使用できる。

|

環境構築
""""""""""""""""""""""""""""""""""""""""""""""""""""""

CloudWatch Logs エージェントのインストール及び設定や、どのようなファイルローテーションがサポートされているかなどについては、\ `CloudWatch Logs エージェントのリファレンス <https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/logs/AgentReference.html>`_\を参照されたい。

.. note::

  CloudWatch上でログを確認する際に、ログの識別を行うための、log_group_nameでグループ分けを行い、障害発生時の障害発生インスタンスを特定するために、log_stream_nameでinstance_idなど設定することが望ましい。



|



制限事項
"""""""""""""""""""""""""""

CloudWatch Logsを使用する上で、いくつかの制限が存在する。詳細は、\ `CloudWatch Logs の制限 <https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/logs/cloudwatch_limits_cwl.html>`_\を参照されたい。

|


ログデータの表示
"""""""""""""""""""""""""""

CloudWatchを使用したログの確認方法の詳細は、\ `ログデータの表示 <https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/logs/ViewingLogData.html>`_\を参照されたい。

|



How to extend
--------------------------------------------------------------------------------
本ガイドラインでは、監視やバックアップ、リアルタイム分析を行う場合の方法について示す。



|

ログデータの監視
"""""""""""""""""""""""""""
ログデータの検索およびフィルタリングを行い、エラー発生時などにアラームを設定して通知する方法の詳細は、\ `ログデータの検索およびフィルタリング <https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/logs/MonitoringLogData.html>`_\を参照されたい。

|



ログデータのバックアップ
""""""""""""""""""""""""""""""""""""""""""""""""""""""

別途バックアップが必要な場合は、\ `ログデータを一括で Amazon S3 にエクスポートする <https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/logs/S3Export.html>`_\を参照されたい。

|


ログデータのリアルタイム処理
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

別途リアルタイム処理を行う場合は、\ `サブスクリプションを使用したログデータのリアルタイム処理 <https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/logs/Subscriptions.html>`_\を参照されたい。

|



.. raw:: latex

   \newpage
