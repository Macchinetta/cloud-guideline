更新履歴
================================================================================

.. tabularcolumns:: |p{0.15\linewidth}|p{0.25\linewidth}|p{0.60\linewidth}|
.. list-table::
    :header-rows: 1
    :widths: 15 25 60

    * - 更新日付
      - 更新箇所
      - 更新内容

    * - 2019-4-22
      - \-
      - 1.0.2 RELEASE版公開

    * -
      - 全般
      - ガイドラインの誤記(タイプミスや単純な記述ミスなど)の修正

        記載内容の改善

        Macchinetta Server Framework for Java (1.x)への対応リンクを1.5.2 RELEASE版に更新

        利用するOSSのバージョン更新に伴うリンク修正

    * -
      - :doc:`../Introduction/Introduction`
      - 動作検証環境を更新

        * CentOS 7.4
        * Apache Tomcat 8.5.40

    * -
      - :doc:`../Overview/FrameworkStack`
      - TERASOLUNA Server Framework for Javaのバージョンを5.4.2.RELEASEに更新

        * spring-cloud-dependenciesのバージョンをDalston.SR5に更新
        * spring-cloud-dependenciesのバージョン更新に伴い利用するOSSのバージョンを更新

        spring-cloud-dependenciesによる定義をバージョン指定により更新しているライブラリを追加

        * spring-cloud-config-client 1.4.6.RELEASE
        * spring-cloud-config-server 1.4.6.RELEASE

        利用するOSS一覧の見直しに伴う修正

    * -
      - :doc:`../ImplementationAtEachLayer/SessionManagement`
      - 記載内容の修正

        * Apache TilesとTomcatの組み合わせでレスポンスにCookieが設定されない問題の説明削除(管理ID#165)

    * -
      - :doc:`../ImplementationAtEachLayer/EnvironmentValuesExternalManagement`
      - spring-cloud-dependenciesのバージョン更新に伴う修正

        * ディレクトリトラバーサル攻撃への脆弱性のnote追加(管理ID#341)

    * -
      - :doc:`../AWSCollaboration/DatabaseReadReplica`
      - リードレプリカの機能追加に伴う修正

        * マルチAZ構成でのフェイルオーバーによる可用性確保について追記(管理ID#219)

    * - 2018-2-28
      - \-
      - CVE-2018-1199への対応のため、利用するOSSをのバージョンを更新

        * TERASOLUNA Server Framework for Javaのバージョンを5.4.1.RELEASEに更新
        * Spring Frameworkのバージョンを4.3.14.RELEASEに更新
        * Spring Securityのバージョンを4.2.4.RELEASEに更新

    * - 2017-12-18
      - 日本語版
      - 初版

.. raw:: latex

   \newpage
