データベースリードレプリカ
================================================================================

.. only:: html

 .. contents:: 目次
    :depth: 3
    :local:

Overview
--------------------------------------------------------------------------------

本ガイドラインでは、AWSを使用してリードレプリカを行う場合について説明する。

.. todo::
  使用・拡張方法の調査が不十分のため詳細は後日記載する。

概要は、\ :ref:`read-replica-method-image-label`\、Spring Cloud AWSの詳細は `Spring 公式サイト <http://cloud.spring.io/spring-cloud-aws/spring-cloud-aws.html#_read_replica_configuration>`_ AWS READ REPLICAの詳細は `AWS 公式サイト <https://aws.amazon.com/jp/rds/details/read-replicas/>`_ を参照されたい。

How to use
------------------

- spring-cloud-aws-jdbcの仕組みを使用し、読み取り専用か更新かでデータソースを切り替える。
- 読み取り専用の場合は、Springの\ ``@Transactional``\アノテーションの属性\ ``readOnly``\を\ ``true``\に設定することでレプリカノードを参照する。

.. warning::

  spring-cloud-aws-jdbcを用いてリードレプリカ方式を実現する場合はデータソースをラップしないことを推奨する。例えば、ログ出力の為に\ ``net.sf.log4jdbc.Log4jdbcProxyDataSource``\等でデータソースをラップしていると、データソースの情報が正しく認識できずレプリカノードを正しく参照できなくなる。

.. raw:: latex

   \newpage
