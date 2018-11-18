### 获取外汇牌价  

* GetExchangeData.pl  
  在线获取数据并采用Perl哈希结构保存。  
  调用示例：  
  > GetExchangeData.pl 2016-01-01 2017-01-01 2016.perldb  
  
* GetExchangeData_bin.pl  
  功能同上，使用 Storable 模块保存数据。  
  
* UpdateDB_ThisYear_bin.pl  
  更新本年的数据，截至日期为昨天。  
  例如今天是2017年11月08日，则日期范围是：2017-01-01日 -> 2017-11-07。  
  保存的文件为 2017.perldb.bin  
  
