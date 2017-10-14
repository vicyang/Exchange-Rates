### 获取外汇牌价历史记录  

* ### 环境
  Strawberry Perl V5.24 Portable
  需要安装的模块：HTML::TableExtract

* ## GetExchangeData_UpdateDB.pl
  每一次运行会先尝试读取 .perldb 文件，在原来的基础上更新数据
  以下两行分别为起始日期和结束日期，结束日期不建议设为当天，因为一般当天的数据还没有完全给出
  my $from = "2015-05-02";
  my $to   = "2017-10-10";

* 参考资料  
  [Parsing HTML with Perl](http://radar.oreilly.com/2014/02/parsing-html-with-perl-2.html)  
  [HTML::TableExtract](https://metacpan.org/pod/HTML::TableExtract)
