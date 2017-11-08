### 获取外汇牌价

* GetExchangeData.pl  
  在线获取数据并采用Perl哈希结构保存。  
  调用示例：  
  > GetExchangeData.pl 2016-01-01 2017-01-01 2016.perldb  

* GetExchangeData_bin.pl
  在线获取数据，通过 Storable 模块保存，提高存取效率。  
  调用格式同上  

* UpdateDB_ThisYear_bin.pl  
  更新本年的数据，截至日期为昨天。  
  比如 2017年11月08日，则数据范围为： 2017年01月01日 - 2017年11月07日。  
  保存的文件为 2017.perldb.bin  

