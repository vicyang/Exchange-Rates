### 获取外汇牌价历史记录  

* ### Branch threads1.0  
  多线程，通过命令行传参调用，示例：  
  GetExchangeData.pl 2017-01-01 2017-01-31 test.perldb  

  保存结构  
  ```
  {
    '2015-04-01' => 
    {
      '22:01:08' => ['618.56','613.6','621.04','621.04','614.34','614.34'],
      '19:03:26' => ['618.56','613.6','621.04','621.04','614.34','614.34'],
      '18:53:14' => ['618.56','613.6','621.04','621.04','614.34','614.34']
    }
    '2015-04-02' => { ... }
  }
  ```

  * ### 效率  
    获取2017-01-01至2017-01-31的区间数据，耗时在10-20秒之间  

* 参考资料  
  [Parsing HTML with Perl](http://radar.oreilly.com/2014/02/parsing-html-with-perl-2.html)  
  [HTML::TableExtract](https://metacpan.org/pod/HTML::TableExtract)
